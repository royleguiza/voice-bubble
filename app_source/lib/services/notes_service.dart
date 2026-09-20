import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_note.dart';

/// Servicio de notas independientes (50 max) — no toca historial 20.
///
/// Persistencia dual idéntica a `StorageService` para historial:
/// - prefs clave `voice_notes_v1` (string JSON array)
/// - archivo `voice_notes.json` atomico (tmp+rename) para widget nativo
/// La lectura fusiona ambas fuentes y dedup por id.
class NotesService {
  static const String notesKey = 'voice_notes_v1';
  static const String notesFileName = 'voice_notes.json';
  static const String _tmpSuffix = '.tmp';
  static const int maxNotes = 50;
  static const int maxTituloLength = 80;
  static const int maxCuerpoLength = 2000;

  int _idCounter = 0;
  String _nextId() {
    _idCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<File?> _getFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$notesFileName');
    } catch (_) {
      return null;
    }
  }

  List<VoiceNote> _notes = [];

  List<VoiceNote> get notes => List.unmodifiable(_notes);

  /// Lee prefs + archivo, dedup por id, ordena por updatedAt desc.
  Future<List<VoiceNote>> _loadMerged() async {
    final prefsRaw = await _readPrefs();
    final fileRaw = await _readFile();
    final byId = <String, VoiceNote>{};
    for (final n in [...fileRaw, ...prefsRaw]) {
      if (n.id.isEmpty) continue;
      // Gana el mas reciente por updatedAt si colisiona.
      final existing = byId[n.id];
      if (existing == null || n.updatedAt.isAfter(existing.updatedAt)) {
        byId[n.id] = n;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return merged.length > maxNotes ? merged.sublist(0, maxNotes) : merged;
  }

  Future<List<VoiceNote>> _readPrefs() async {
    try {
      final prefs = await _prefs();
      try {
        await prefs.reload();
      } catch (_) {}
      final raw = prefs.getString(notesKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const [];
      final out = <VoiceNote>[];
      for (final e in decoded) {
        if (e is Map<dynamic, dynamic>) {
          out.add(VoiceNote.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<VoiceNote>> _readFile() async {
    try {
      final file = await _getFile();
      if (file == null || !file.existsSync()) return const [];
      final content = file.readAsStringSync().trim();
      if (content.isEmpty) return const [];
      final decoded = jsonDecode(content);
      if (decoded is! List<dynamic>) return const [];
      final out = <VoiceNote>[];
      for (final e in decoded) {
        if (e is Map<dynamic, dynamic>) {
          out.add(VoiceNote.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> load() async {
    final merged = await _loadMerged();
    _notes = merged;
    await _persist();
  }

  Future<void> _persist() async {
    await _savePrefs();
    await _saveFile();
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await _prefs();
      final arr = _notes.map((n) => n.toJson()).toList();
      await prefs.setString(notesKey, jsonEncode(arr));
    } catch (_) {}
  }

  Future<void> _saveFile() async {
    try {
      final file = await _getFile();
      if (file == null) return;
      final tmp = File('${file.path}$_tmpSuffix');
      tmp.writeAsStringSync(
        jsonEncode(_notes.map((n) => n.toJson()).toList()),
        flush: true,
      );
      if (tmp.existsSync()) {
        try {
          tmp.renameSync(file.path);
        } catch (_) {
          tmp.copySync(file.path);
          try {
            tmp.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Crea nota desde transcripcion. Titulo = primeras 32 chars del cuerpo.
  Future<bool> addFromTranscription(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > maxCuerpoLength) return false;
    await _ensureLoaded();
    if (_notes.length >= maxNotes) return false;
    final now = DateTime.now();
    final titulo = trimmed.length > 32
        ? '${trimmed.substring(0, 32).trim()}...'
        : trimmed;
    final note = VoiceNote(
      id: _nextId(),
      titulo: titulo.isEmpty ? 'Nota' : titulo,
      cuerpo: trimmed,
      createdAt: now,
      updatedAt: now,
    );
    _notes.insert(0, note);
    if (_notes.length > maxNotes) {
      _notes = _notes.sublist(0, maxNotes);
    }
    await _persist();
    return true;
  }

  Future<bool> addNote({
    required String titulo,
    required String cuerpo,
  }) async {
    final t = titulo.trim();
    final c = cuerpo.trim();
    if (t.isEmpty || c.isEmpty) return false;
    if (t.length > maxTituloLength || c.length > maxCuerpoLength) return false;
    await _ensureLoaded();
    if (_notes.length >= maxNotes) return false;
    final now = DateTime.now();
    final note = VoiceNote(
      id: _nextId(),
      titulo: t,
      cuerpo: c,
      createdAt: now,
      updatedAt: now,
    );
    _notes.insert(0, note);
    await _persist();
    return true;
  }

  Future<bool> updateNote(
    String id, {
    String? titulo,
    String? cuerpo,
  }) async {
    if (titulo != null &&
        (titulo.trim().isEmpty || titulo.length > maxTituloLength)) {
      return false;
    }
    if (cuerpo != null &&
        (cuerpo.trim().isEmpty || cuerpo.length > maxCuerpoLength)) {
      return false;
    }
    await _ensureLoaded();
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return false;
    final now = DateTime.now();
    _notes[idx] = _notes[idx].copyWith(
      titulo: titulo?.trim(),
      cuerpo: cuerpo?.trim(),
      updatedAt: now,
    );
    // Reordena por updatedAt desc.
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
    return true;
  }

  Future<bool> deleteNote(String id) async {
    await _ensureLoaded();
    final before = _notes.length;
    _notes = _notes.where((n) => n.id != id).toList();
    if (_notes.length == before) return false;
    await _persist();
    return true;
  }

  Future<void> _ensureLoaded() async {
    if (_notes.isEmpty) {
      final merged = await _loadMerged();
      // Si hay datos en disco pero memoria vacia, cargarlos sin re-persistir
      // innecesariamente si ya estan en prefs.
      if (merged.isNotEmpty) _notes = merged;
    }
  }

  /// Busqueda simple insensible a mayusculas en titulo+cuerpo.
  List<VoiceNote> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return notes;
    return _notes
        .where((n) =>
            n.titulo.toLowerCase().contains(q) ||
            n.cuerpo.toLowerCase().contains(q))
        .toList();
  }
}
