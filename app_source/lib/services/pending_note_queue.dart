import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un audio dictado en Notas que quedó sin transcribir (sin red / fallo
/// reintentable). Persistido en clave Dart-only `voice_notes_pending_v1`.
///
/// El WAV vive en `getApplicationSupportDirectory()/pending_notes/<id>.wav`
/// (NO en temp: el SO purga cache). El envío a la nube SOLO ocurre cuando el
/// usuario toca "Transcribir con nube" — nunca automático al detectar red.
class PendingNote {
  final String id;
  final String audioPath;
  final int createdAtMs;

  const PendingNote({
    required this.id,
    required this.audioPath,
    required this.createdAtMs,
  });

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMs).toLocal();

  Map<String, dynamic> toJson() => {
        'id': id,
        'audioPath': audioPath,
        'createdAtMs': createdAtMs,
      };

  factory PendingNote.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final audioPath = json['audioPath'];
    final createdAtMs = json['createdAtMs'];
    return PendingNote(
      id: id is String ? id : '',
      audioPath: audioPath is String ? audioPath : '',
      createdAtMs: createdAtMs is int ? createdAtMs : 0,
    );
  }
}

/// Cola FIFO de audios pendientes de transcripción cloud en Notas.
///
/// Contrato (plan-notas-cola-nube.md D-C1..D-C5):
/// - Cap [maxPending] (FIFO: descarta el más viejo y su WAV).
/// - Clave SOLO Dart (no entra a contract-keys.txt / bridgeKeys).
/// - WAV durable bajo appSupport/pending_notes/.
/// - Cero HTTP en este servicio: la UI dispara el envío.
class PendingNoteQueue {
  static const String pendingKey = 'voice_notes_pending_v1';
  static const int maxPending = 15;
  static const String pendingDirName = 'pending_notes';

  /// WAVs conservados junto a la nota ya transcrita (texto + audio).
  /// Pedido del dueño 2026-09-23: el audio permanece aunque se transcriba.
  static const String notesAudioDirName = 'notes_audio';

  List<PendingNote> _items = [];

  List<PendingNote> get items => List.unmodifiable(_items);

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<Directory?> _dir() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/$pendingDirName');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _audioDir() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/$notesAudioDirName');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    _items = await _loadRaw();
  }

  Future<List<PendingNote>> _loadRaw() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(pendingKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <PendingNote>[];
      for (final e in decoded) {
        if (e is Map<String, dynamic>) {
          final p = PendingNote.fromJson(e);
          if (p.id.isNotEmpty && p.audioPath.isNotEmpty) out.add(p);
        } else if (e is Map) {
          final p = PendingNote.fromJson(
              Map<String, dynamic>.from(e));
          if (p.id.isNotEmpty && p.audioPath.isNotEmpty) out.add(p);
        }
      }
      // FIFO: más reciente primero en la lista (insert en 0 al encolar).
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await _prefs();
      await prefs.setString(
        pendingKey,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _ensureLoaded() async {
    if (_items.isEmpty) {
      _items = await _loadRaw();
    }
  }

  /// Mueve/copía el WAV [tempPath] a la cola durable y lo registra.
  /// Devuelve el item encolado o null si falla o el archivo no existe.
  Future<PendingNote?> enqueueFromTemp(String tempPath) async {
    await _ensureLoaded();
    final src = File(tempPath);
    // Sync IO: dart:io async se cuelga bajo fakeAsync (lección 10).
    if (!src.existsSync()) return null;

    final dir = await _dir();
    if (dir == null) return null;

    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_items.length}';
    final destPath = '${dir.path}/$id.wav';

    try {
      // Sync IO: seguro bajo fakeAsync (lección 10 de los tests).
      src.copySync(destPath);
      if (src.existsSync()) {
        // Si el original era temporal, lo retiramos para no duplicar.
        try {
          src.deleteSync();
        } catch (_) {}
      }
    } catch (_) {
      return null;
    }

    final item = PendingNote(
      id: id,
      audioPath: destPath,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _items.insert(0, item);
    await _pruneOldest();
    await _persist();
    return item;
  }

  Future<void> _pruneOldest() async {
    while (_items.length > maxPending) {
      final victim = _items.removeLast();
      await _deleteAudio(victim);
    }
  }

  Future<void> _deleteAudio(PendingNote item) async {
    try {
      final f = File(item.audioPath);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  /// Quita de la cola. [deleteAudio]=true borra el WAV (éxito o descarte).
  Future<bool> remove(String id, {bool deleteAudio = true}) async {
    await _ensureLoaded();
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return false;
    final victim = _items.removeAt(idx);
    if (deleteAudio) {
      await _deleteAudio(victim);
    }
    await _persist();
    return true;
  }

  /// Copia [srcPath] a `notes_audio/` para conservarlo junto a la nota
  /// ya transcrita (texto + audio). No toca la cola. Devuelve la ruta
  /// durable o null si falla. IO síncrona (segura bajo fakeAsync).
  Future<String?> keepCopyForNote(String srcPath) async {
    final src = File(srcPath);
    if (!src.existsSync()) return null;
    final dir = await _audioDir();
    if (dir == null) return null;
    final destPath =
        '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.wav';
    try {
      src.copySync(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  /// Copia el WAV de un pendiente a `notes_audio/` (éxito de
  /// "Transcribir con nube"): la nota queda con texto + audio.
  /// El original pendiente lo borra `transcribe()` en éxito, así que el
  /// efecto neto es un traslado. Devuelve la ruta durable o null si falla.
  Future<String?> promoteToKept(PendingNote item) async {
    final src = File(item.audioPath);
    if (!src.existsSync()) return null;
    final dir = await _audioDir();
    if (dir == null) return null;
    final destPath = '${dir.path}/${item.id}.wav';
    try {
      src.copySync(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  /// Borra un WAV conservado en `notes_audio/` (al borrar la nota o al
  /// limpiar un huérfano tras un fallo). Nunca lanza.
  void deleteKeptAudio(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  /// Descarta todos los pendientes y sus audios (toggle OFF / limpieza).
  Future<void> discardAll() async {
    await _ensureLoaded();
    for (final e in _items) {
      await _deleteAudio(e);
    }
    _items = [];
    await _persist();
  }

  /// Solo lectura para tests/UI: existe el WAV en disco.
  bool audioExists(PendingNote item) {
    try {
      return File(item.audioPath).existsSync();
    } catch (_) {
      return false;
    }
  }
}
