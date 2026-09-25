import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _PendingIndexState { corrupt, valid }

class _PendingReadResult {
  const _PendingReadResult(
    this.items, {
    required this.state,
    required this.writable,
  });

  final List<PendingNote> items;
  final _PendingIndexState state;
  final bool writable;
}

class _NoteMirrorRead {
  const _NoteMirrorRead({
    required this.authoritative,
    required this.paths,
  });

  final bool authoritative;
  final Set<String> paths;
}

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
    if (id is! String || id.trim().isEmpty ||
        audioPath is! String || audioPath.trim().isEmpty ||
        createdAtMs is! int || createdAtMs <= 0) {
      throw const FormatException('Pendiente inválido');
    }
    return PendingNote(
      id: id,
      audioPath: audioPath,
      createdAtMs: createdAtMs,
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
  static const String lockFileName = 'flutter.voice_notes_pending_v1.lock';
  static const int maxPending = 15;
  static const String pendingDirName = 'pending_notes';
  static const int lockTimeoutMs = 10000;
  static const int lockStaleMs = 30000;
  static const int lockHeartbeatMs = 5000;
  static const int lockPollMs = 50;
  static const String notesKey = 'voice_notes_v1';
  static const String notesFileName = 'voice_notes.json';
  static const String notesLockFileName = '$notesFileName.lock';
  static const int audioSweepGraceMs = 86400000;

  /// WAVs conservados junto a la nota ya transcrita (texto + audio).
  /// Pedido del dueño 2026-09-23: el audio permanece aunque se transcriba.
  static const String notesAudioDirName = 'notes_audio';

  List<PendingNote> _items = [];

  List<PendingNote> get items => List.unmodifiable(_items);

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<Directory?> _baseDir() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _dir() async {
    try {
      final base = await _baseDir();
      if (base == null) return null;
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
      final base = await _baseDir();
      if (base == null) return null;
      final dir = Directory('${base.path}/$notesAudioDirName');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    } catch (_) {
      return null;
    }
  }

  Future<bool> load() async {
    await _withFileLock<bool>(notesLockFileName, _reconcileNotesAudioLocked);
    final result = await _withFileLock<bool>(lockFileName, () async {
      if (!await _reconcilePendingAudioLocked()) return false;
      final read = await _loadRaw();
      if (read.state != _PendingIndexState.valid) return false;
      _items = read.items;
      return _persist();
    });
    return result ?? false;
  }

  Future<_PendingReadResult> _loadRaw() async {
    try {
      final prefs = await _prefs();
      await prefs.reload();
      final raw = prefs.getString(pendingKey);
      if (raw == null) {
        final base = await _baseDir();
        if (base != null && _hasPendingAudio(base)) {
          return const _PendingReadResult(
            [],
            state: _PendingIndexState.corrupt,
            writable: false,
          );
        }
        return const _PendingReadResult(
          [],
          state: _PendingIndexState.valid,
          writable: true,
        );
      }
      if (raw.trim().isEmpty) {
        return const _PendingReadResult(
          [],
          state: _PendingIndexState.corrupt,
          writable: false,
        );
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const _PendingReadResult(
          [],
          state: _PendingIndexState.corrupt,
          writable: false,
        );
      }
      final out = <PendingNote>[];
      for (final element in decoded) {
        if (element is! Map) {
          return const _PendingReadResult(
            [],
            state: _PendingIndexState.corrupt,
            writable: false,
          );
        }
        final item = PendingNote.fromJson(Map<String, dynamic>.from(element));
        if (!File(item.audioPath).existsSync()) {
          return const _PendingReadResult(
            [],
            state: _PendingIndexState.corrupt,
            writable: false,
          );
        }
        out.add(item);
      }
      return _PendingReadResult(
        out,
        state: _PendingIndexState.valid,
        writable: true,
      );
    } catch (_) {
      return const _PendingReadResult(
        [],
        state: _PendingIndexState.corrupt,
        writable: false,
      );
    }
  }

  bool _hasPendingAudio(Directory base) {
    try {
      final directory = Directory('${base.path}/$pendingDirName');
      if (!directory.existsSync()) return false;
      return directory.listSync().any(
            (entry) => entry is File && entry.path.endsWith('.wav'),
          );
    } catch (_) {
      return true;
    }
  }

  Future<bool> _reconcileNotesAudioLocked() async {
    final base = await _baseDir();
    if (base == null) return false;
    final read = await _readNotesAudioIndex();
    return _reconcileAudioDirectory(
      Directory('${base.path}/$notesAudioDirName'),
      read,
    );
  }

  Future<_NoteMirrorRead> _readNotesAudioIndex() async {
    try {
      final prefs = await _prefs();
      await prefs.reload();
      final prefsMirror = _parseNoteMirror(prefs.getString(notesKey));
      final base = await _baseDir();
      if (base == null) {
        return const _NoteMirrorRead(
          authoritative: false,
          paths: <String>{},
        );
      }
      final notesFile = File('${base.path}/$notesFileName');
      final fileMirror = _parseNoteMirror(
        notesFile.existsSync() ? notesFile.readAsStringSync() : null,
      );
      return _NoteMirrorRead(
        authoritative: prefsMirror.authoritative && fileMirror.authoritative,
        paths: <String>{...prefsMirror.paths, ...fileMirror.paths},
      );
    } catch (_) {
      return const _NoteMirrorRead(
        authoritative: false,
        paths: <String>{},
      );
    }
  }

  _NoteMirrorRead _parseNoteMirror(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _NoteMirrorRead(
        authoritative: false,
        paths: <String>{},
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException();
      final paths = <String>{};
      for (final element in decoded) {
        if (element is! Map) throw const FormatException();
        final note = Map<String, dynamic>.from(element);
        final id = note['id'];
        final title = note['titulo'];
        final body = note['cuerpo'];
        final createdRaw = note['createdAt'];
        final updatedRaw = note['updatedAt'];
        final created = createdRaw is String ? DateTime.tryParse(createdRaw) : null;
        final updated = updatedRaw is String ? DateTime.tryParse(updatedRaw) : null;
        if (id is! String || id.trim().isEmpty ||
            title is! String || body is! String ||
            created == null || updated == null || updated.isBefore(created)) {
          throw const FormatException();
        }
        final audioPath = note['audioPath'];
        if (audioPath != null) {
          if (audioPath is! String || audioPath.trim().isEmpty) {
            throw const FormatException();
          }
          paths.add(File(audioPath).absolute.path);
        }
      }
      return _NoteMirrorRead(authoritative: true, paths: paths);
    } catch (_) {
      return const _NoteMirrorRead(
        authoritative: false,
        paths: <String>{},
      );
    }
  }

  Future<bool> _reconcilePendingAudioLocked() async {
    final read = await _loadRaw();
    final base = await _baseDir();
    if (base == null) return false;
    return _reconcileAudioDirectory(
      Directory('${base.path}/$pendingDirName'),
      _NoteMirrorRead(
        authoritative: read.state == _PendingIndexState.valid,
        paths: read.items.map((item) => File(item.audioPath).absolute.path).toSet(),
      ),
    );
  }

  bool _reconcileAudioDirectory(
    Directory directory,
    _NoteMirrorRead read,
  ) {
    try {
      if (!directory.existsSync()) return true;
      var claimsReady = true;
      for (final entity in directory.listSync()) {
        if (entity is! File || !entity.path.endsWith('.wav')) continue;
        final file = entity;
        final claim = File(file.parent.path, '.${file.uri.pathSegments.last}.pending');
        if (!read.authoritative) {
          claimsReady = _registerSweepClaim(claim) && claimsReady;
          continue;
        }
        if (read.paths.contains(file.absolute.path)) {
          if (!_removeSweepClaim(claim)) return false;
          continue;
        }
        final age = DateTime.now().difference(file.lastModifiedSync()).inMilliseconds;
        if (claim.existsSync()) {
          final claimAge =
              DateTime.now().difference(claim.lastModifiedSync()).inMilliseconds;
          if (claimAge >= audioSweepGraceMs && !_removeSweepClaim(claim)) {
            return false;
          }
        } else if (age >= audioSweepGraceMs) {
          try {
            file.deleteSync();
          } catch (_) {
            return false;
          }
          if (file.existsSync()) return false;
        }
      }
      return read.authoritative && claimsReady;
    } catch (_) {
      return false;
    }
  }

  bool _registerSweepClaim(File claim) {
    try {
      if (claim.isFile) return true;
      if (claim.existsSync()) return false;
      claim.writeAsStringSync('1', flush: true);
      claim.setLastModifiedSync(DateTime.now());
      return claim.isFile;
    } catch (_) {
      return false;
    }
  }

  bool _removeSweepClaim(File claim) {
    try {
      if (claim.existsSync()) claim.deleteSync();
      return !claim.existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _persist() async {
    try {
      final prefs = await _prefs();
      return await prefs.setString(
        pendingKey,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      return false;
    }
  }

  Future<_PendingReadResult?> _loadForMutation() async {
    final read = await _loadRaw();
    return read.writable ? read : null;
  }

  /// Mueve/copia el WAV [tempPath] a la cola durable y lo registra.
  /// Devuelve el item encolado o null si falla o el archivo no existe.
  Future<PendingNote?> enqueueFromTemp(String tempPath) async {
    final result = await _withFileLock(lockFileName, () async {
      final read = await _loadForMutation();
      if (read == null) return null;
      _items = read.items;
      final src = File(tempPath);
      if (!src.existsSync()) return null;

      final dir = await _dir();
      if (dir == null) return null;

      final id =
          '${DateTime.now().microsecondsSinceEpoch}-${_items.length}';
      final destPath = '${dir.path}/$id.wav';
      final claim = File(dir.path, '.${id}.wav.pending');
      var committed = false;
      try {
        claim.writeAsStringSync('1', flush: true);
        if (!_publishCopy(src, File(destPath))) return null;

        final previous = List<PendingNote>.from(_items);
        final item = PendingNote(
          id: id,
          audioPath: destPath,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        _items.insert(0, item);
        final victims = _pruneOldest();
        if (!await _persist()) {
          _items = previous;
          return null;
        }
        committed = true;
        for (final victim in victims) {
          await _deleteAudio(victim);
        }
        if (src.existsSync()) {
          try {
            src.deleteSync();
          } catch (_) {}
        }
        _deleteClaim(claim);
        return item;
      } finally {
        if (!committed) _deleteClaim(claim);
      }
    });
    return result;
  }

  List<PendingNote> _pruneOldest() {
    final victims = _items.skip(maxPending).toList();
    _items = _items.take(maxPending).toList();
    return victims;
  }

  Future<bool> _deleteAudio(PendingNote item) async {
    final file = File(item.audioPath);
    try {
      if (file.existsSync()) file.deleteSync();
      return !file.existsSync();
    } catch (_) {
      final directory = file.parent;
      _registerSweepClaim(
        File(directory.path, '.${file.uri.pathSegments.last}.pending'),
      );
      return false;
    }
  }

  bool _publishCopy(File src, File dest) {
    File? temporary;
    try {
      final tmp = File(
        '${dest.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      temporary = tmp;
      src.copySync(tmp.path);
      if (!tmp.existsSync() || tmp.lengthSync() != src.lengthSync()) {
        return false;
      }
      tmp.renameSync(dest.path);
      return dest.existsSync() && dest.lengthSync() == src.lengthSync();
    } catch (_) {
      return false;
    } finally {
      final path = temporary;
      if (path != null) {
        try {
          if (path.existsSync()) path.deleteSync();
        } catch (_) {}
      }
    }
  }

  void _deleteClaim(File claim) {
    try {
      if (claim.existsSync()) claim.deleteSync();
    } catch (_) {}
  }

  /// Quita de la cola. [deleteAudio]=true borra el WAV (éxito o descarte).
  Future<bool> remove(String id, {bool deleteAudio = true}) async {
    final result = await _withFileLock<bool>(lockFileName, () async {
      final read = await _loadForMutation();
      if (read == null) return false;
      _items = read.items;
      final idx = _items.indexWhere((e) => e.id == id);
      if (idx == -1) return false;
      final previous = List<PendingNote>.from(_items);
      final victim = _items.removeAt(idx);
      if (!await _persist()) {
        _items = previous;
        return false;
      }
      if (deleteAudio) {
        await _deleteAudio(victim);
      }
      return true;
    });
    return result ?? false;
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
    return _publishCopy(src, File(destPath)) ? destPath : null;
  }

  /// Copia el WAV de un pendiente a `notes_audio/` (éxito de
  /// "Transcribir con nube"): la nota queda con texto + audio.
  /// El original pendiente lo borra `transcribe()` en éxito, así que
  /// el efecto neto es un traslado. Devuelve la ruta durable o null si falla.
  Future<String?> promoteToKept(PendingNote item) async {
    final src = File(item.audioPath);
    if (!src.existsSync()) return null;
    final dir = await _audioDir();
    if (dir == null) return null;
    final destPath = '${dir.path}/${item.id}.wav';
    return _publishCopy(src, File(destPath)) ? destPath : null;
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
  Future<bool> discardAll() async {
    final result = await _withFileLock<bool>(lockFileName, () async {
      final read = await _loadForMutation();
      if (read == null) return false;
      _items = read.items;
      final previous = List<PendingNote>.from(_items);
      _items = [];
      if (!await _persist()) {
        _items = previous;
        return false;
      }
      for (final e in previous) {
        await _deleteAudio(e);
      }
      return true;
    });
    return result ?? false;
  }

  /// Solo lectura para tests/UI: existe el WAV en disco.
  bool audioExists(PendingNote item) {
    try {
      return File(item.audioPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<T?> _withFileLock<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final base = await _baseDir();
    if (base == null) return null;
    final lockFile = File('${base.path}/$name');
    try {
      lockFile.parent.createSync(recursive: true);
    } catch (_) {
      return null;
    }
    final token =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}';
    final deadline = DateTime.now().add(
      const Duration(milliseconds: lockTimeoutMs),
    );
    var acquired = false;
    while (!acquired && DateTime.now().isBefore(deadline)) {
      var created = false;
      try {
        lockFile.createSync(exclusive: true);
        created = true;
        lockFile.writeAsStringSync(
          '$token\n${DateTime.now().millisecondsSinceEpoch}\n',
          flush: true,
        );
        if (!lockFile.readAsStringSync().startsWith('$token\n')) {
          throw StateError('lock token no persistido');
        }
        acquired = true;
      } catch (_) {
        if (created) {
          try {
            lockFile.deleteSync();
          } catch (_) {}
        }
        if (_isStale(lockFile)) {
          try {
            lockFile.deleteSync();
          } catch (_) {}
        }
        await Future<void>.delayed(
          const Duration(milliseconds: lockPollMs),
        );
      }
    }
    if (!acquired) return null;
    final heartbeatMs = min(lockHeartbeatMs, max(1, lockStaleMs ~/ 3)).toInt();
    final heartbeat = Timer.periodic(
      Duration(milliseconds: heartbeatMs),
      (_) {
        try {
          if (lockFile.readAsStringSync().startsWith('$token\n')) {
            lockFile.setLastModifiedSync(DateTime.now());
          }
        } catch (_) {}
      },
    );
    try {
      return await action();
    } finally {
      heartbeat.cancel();
      try {
        if (lockFile.existsSync() &&
            lockFile.readAsStringSync().startsWith('$token\n')) {
          lockFile.deleteSync();
        }
      } catch (_) {}
    }
  }

  bool _isStale(File lockFile) {
    try {
      if (!lockFile.existsSync()) return false;
      final age = DateTime.now()
          .difference(lockFile.lastModifiedSync())
          .inMilliseconds;
      return age > lockStaleMs;
    } catch (_) {
      return false;
    }
  }
}
