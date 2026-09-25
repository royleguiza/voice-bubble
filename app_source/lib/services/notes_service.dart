import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_note.dart';

enum _NotesReadState { missing, empty, valid, corrupt, unavailable }
enum _NotesPersistState { saved, failed, rollbackFailed }
enum _PrefsWriteState { saved, failed, rollbackFailed }

class _PrefsRawReadResult {
  const _PrefsRawReadResult(
    this.raw, {
    required this.available,
  });

  final String? raw;
  final bool available;
}

class _NotesReadResult {
  const _NotesReadResult(
    this.notes, {
    required this.complete,
    required this.writable,
  });

  final List<VoiceNote> notes;
  final bool complete;
  final bool writable;
}

/// Servicio de notas independientes (50 max) — no toca historial 20.
///
/// Persistencia dual idéntica a `StorageService` para historial:
/// - prefs clave `voice_notes_v1` (string JSON array)
/// - archivo `voice_notes.json` atomico (tmp+rename) para widget nativo
/// La lectura fusiona ambas fuentes y dedup por id.
class NotesService {
  static const String notesKey = 'voice_notes_v1';
  static const String notesFileName = 'voice_notes.json';
  static const String lockFileName = '$notesFileName.lock';
  static const int lockTimeoutMs = 10000;
  static const int lockStaleMs = 30000;
  static const int lockHeartbeatMs = 5000;
  static const int lockPollMs = 50;
  static const int maxNotes = 50;
  static const int maxTituloLength = 80;
  static const int maxCuerpoLength = 2000;

  final Future<bool> Function(File file, String encoded)? _fileWriter;
  final Future<bool> Function(
    SharedPreferences preferences,
    String key,
    String value,
  )? _prefsWriter;
  final void Function(File file, String token)? _lockWriter;
  final Future<String?> Function()? _prefsRawReader;

  NotesService({
    Future<bool> Function(File file, String encoded)? fileWriter,
    Future<bool> Function(
      SharedPreferences preferences,
      String key,
      String value,
    )? prefsWriter,
    void Function(File file, String token)? lockWriter,
    Future<String?> Function()? prefsRawReader,
  })  : _fileWriter = fileWriter,
        _prefsWriter = prefsWriter,
        _lockWriter = lockWriter,
        _prefsRawReader = prefsRawReader;

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

  Future<_NotesReadResult> _loadMerged() async {
    final prefs = await _readPrefs();
    final file = await _readFile();
    final bothMissing = file.state == _NotesReadState.missing &&
        prefs.state == _NotesReadState.missing;
    final oneMissing = (file.state == _NotesReadState.missing &&
            _isAuthoritative(prefs.state)) ||
        (prefs.state == _NotesReadState.missing &&
            _isAuthoritative(file.state));
    final complete = bothMissing || oneMissing ||
        (_isAuthoritative(file.state) && _isAuthoritative(prefs.state));
    if (!complete) {
      return const _NotesReadResult(
        [],
        complete: false,
        writable: false,
      );
    }
    final byId = <String, VoiceNote>{};
    for (final n in [...file.notes, ...prefs.notes]) {
      final existing = byId[n.id];
      if (existing == null || n.updatedAt.isAfter(existing.updatedAt)) {
        byId[n.id] = n;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final limited = merged.length > maxNotes
        ? merged.sublist(0, maxNotes)
        : merged;
    return _NotesReadResult(
      limited,
      complete: true,
      writable: true,
    );
  }

  bool _isAuthoritative(_NotesReadState state) {
    return state == _NotesReadState.empty || state == _NotesReadState.valid;
  }

  Future<_NotesReadResult> _readPrefs() async {
    try {
      final prefs = await _prefs();
      await prefs.reload();
      final raw = prefs.getString(notesKey);
      if (raw == null) {
        return const _NotesReadResult(
          [],
          complete: true,
          writable: true,
        );
      }
      return _decode(raw);
    } catch (_) {
      return const _NotesReadResult(
        [],
        complete: false,
        writable: false,
      );
    }
  }

  Future<_NotesReadResult> _readFile() async {
    try {
      final file = await _getFile();
      if (file == null) {
        return const _NotesReadResult(
          [],
          complete: false,
          writable: false,
        );
      }
      if (!file.existsSync()) {
        return const _NotesReadResult(
          [],
          complete: true,
          writable: true,
        );
      }
      return _decode(file.readAsStringSync());
    } catch (_) {
      return const _NotesReadResult(
        [],
        complete: false,
        writable: false,
      );
    }
  }

  _NotesReadResult _decode(String raw) {
    if (raw.trim().isEmpty) {
      return const _NotesReadResult(
        [],
        complete: false,
        writable: false,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return const _NotesReadResult(
          [],
          complete: false,
          writable: false,
        );
      }
      final out = <VoiceNote>[];
      for (final element in decoded) {
        if (element is! Map) {
          return const _NotesReadResult(
            [],
            complete: false,
            writable: false,
          );
        }
        out.add(VoiceNote.fromJson(Map<String, dynamic>.from(element)));
      }
      return _NotesReadResult(
        out,
        complete: true,
        writable: true,
      );
    } catch (_) {
      return const _NotesReadResult(
        [],
        complete: false,
        writable: false,
      );
    }
  }

  Future<bool> load() async {
    final result = await _withFileLock<bool>(lockFileName, () async {
      final merged = await _loadMerged();
      if (!merged.complete) return false;
      final previous = List<VoiceNote>.from(_notes);
      _notes = merged.notes;
      if (await _persist() != _NotesPersistState.saved) {
        _notes = previous;
        return false;
      }
      return true;
    });
    return result ?? false;
  }

  Future<_NotesPersistState> _persist() async {
    final file = await _getFile();
    if (file == null) return _NotesPersistState.failed;
    final encoded = jsonEncode(_notes.map((n) => n.toJson()).toList());
    final previousPrefsRead = await _readPrefsRaw();
    if (!previousPrefsRead.available) return _NotesPersistState.failed;
    final previousPrefs = previousPrefsRead.raw;
    final previousFileExists = file.existsSync();
    final String? previousFile;
    try {
      previousFile = previousFileExists ? file.readAsStringSync() : null;
    } catch (_) {
      return _NotesPersistState.failed;
    }
    if (!await _writeFileAtomically(file, encoded)) {
      return _NotesPersistState.failed;
    }
    final prefsState = await _savePrefs(encoded, previousPrefs);
    if (prefsState == _PrefsWriteState.saved) {
      return _NotesPersistState.saved;
    }
    final fileRestored =
        await _restoreFile(file, previousFileExists, previousFile);
    if (!fileRestored || prefsState == _PrefsWriteState.rollbackFailed) {
      return _NotesPersistState.rollbackFailed;
    }
    return _NotesPersistState.failed;
  }

  Future<_PrefsRawReadResult> _readPrefsRaw() async {
    try {
      final reader = _prefsRawReader;
      final raw = reader == null
          ? await _readActualPrefsRaw()
          : await reader();
      return _PrefsRawReadResult(raw, available: true);
    } catch (_) {
      return const _PrefsRawReadResult(null, available: false);
    }
  }

  Future<String?> _readActualPrefsRaw() async {
    final prefs = await _prefs();
    await prefs.reload();
    return prefs.getString(notesKey);
  }

  Future<_PrefsWriteState> _savePrefs(
    String encoded,
    String? previous,
  ) async {
    late SharedPreferences prefs;
    try {
      prefs = await _prefs();
    } catch (_) {
      return _PrefsWriteState.rollbackFailed;
    }
    try {
      final writer = _prefsWriter;
      final saved = writer == null
          ? await prefs.setString(notesKey, encoded)
          : await writer(prefs, notesKey, encoded);
      if (saved && prefs.getString(notesKey) == encoded) {
        return _PrefsWriteState.saved;
      }
    } catch (_) {}
    try {
      final restored = previous == null
          ? await prefs.remove(notesKey)
          : await prefs.setString(notesKey, previous);
      return restored && prefs.getString(notesKey) == previous
          ? _PrefsWriteState.failed
          : _PrefsWriteState.rollbackFailed;
    } catch (_) {
      return _PrefsWriteState.rollbackFailed;
    }
  }

  Future<bool> _writeFileAtomically(File file, String encoded) async {
    final writer = _fileWriter;
    if (writer != null) return writer(file, encoded);
    File? temporary;
    try {
      final tmp = File(
        '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      temporary = tmp;
      tmp.writeAsStringSync(encoded, flush: true);
      tmp.renameSync(file.path);
      return file.existsSync() && file.readAsStringSync() == encoded;
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

  Future<bool> _restoreFile(
    File file,
    bool existed,
    String? contents,
  ) async {
    try {
      if (!existed) {
        if (file.existsSync()) file.deleteSync();
        return !file.existsSync();
      }
      if (contents == null || !await _writeFileAtomically(file, contents)) {
        return false;
      }
      return file.existsSync() && file.readAsStringSync() == contents;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addFromTranscription(String text, {String? audioPath}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > maxCuerpoLength) return false;
    final result = await _withFileLock<bool>(lockFileName, () async {
      final read = await _loadMerged();
      if (!read.writable) return false;
      final previous = List<VoiceNote>.from(_notes);
      _notes = read.notes;
      if (_notes.length >= maxNotes) return false;
      final now = DateTime.now();
      final note = VoiceNote(
        id: _nextId(),
        titulo: '',
        cuerpo: trimmed,
        createdAt: now,
        updatedAt: now,
        audioPath: audioPath,
      );
      _notes.insert(0, note);
      if (_notes.length > maxNotes) {
        _notes = _notes.sublist(0, maxNotes);
      }
      if (await _persist() != _NotesPersistState.saved) {
        _notes = previous;
        return false;
      }
      return true;
    });
    return result ?? false;
  }

  Future<bool> addNote({
    required String titulo,
    required String cuerpo,
  }) async {
    final t = titulo.trim();
    final c = cuerpo.trim();
    if (c.isEmpty) return false;
    if (t.length > maxTituloLength || c.length > maxCuerpoLength) {
      return false;
    }
    final result = await _withFileLock<bool>(lockFileName, () async {
      final read = await _loadMerged();
      if (!read.writable) return false;
      final previous = List<VoiceNote>.from(_notes);
      _notes = read.notes;
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
      if (await _persist() != _NotesPersistState.saved) {
        _notes = previous;
        return false;
      }
      return true;
    });
    return result ?? false;
  }

  Future<bool> updateNote(
    String id, {
    String? titulo,
    String? cuerpo,
    bool clearAudioPath = false,
  }) async {
    if (titulo != null && titulo.length > maxTituloLength) {
      return false;
    }
    if (cuerpo != null &&
        (cuerpo.trim().isEmpty || cuerpo.length > maxCuerpoLength)) {
      return false;
    }
    final result = await _withFileLock<bool>(lockFileName, () async {
      final read = await _loadMerged();
      if (!read.writable) return false;
      final previous = List<VoiceNote>.from(_notes);
      _notes = read.notes;
      final idx = _notes.indexWhere((n) => n.id == id);
      if (idx == -1) return false;
      final now = DateTime.now();
      final prevAudio = _notes[idx].audioPath;
      _notes[idx] = _notes[idx].copyWith(
        titulo: titulo?.trim(),
        cuerpo: cuerpo?.trim(),
        updatedAt: now,
        clearAudioPath: clearAudioPath,
      );
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (await _persist() != _NotesPersistState.saved) {
        _notes = previous;
        return false;
      }
      if (clearAudioPath) _deleteAudioFile(prevAudio);
      return true;
    });
    return result ?? false;
  }

  Future<bool> deleteNote(String id) async {
    final result = await _withFileLock<bool>(lockFileName, () async {
      final read = await _loadMerged();
      if (!read.writable) return false;
      final previous = List<VoiceNote>.from(_notes);
      _notes = read.notes;
      final before = _notes.length;
      final victim = _notes.where((n) => n.id == id).toList();
      if (victim.isEmpty) return false;
      _notes = _notes.where((n) => n.id != id).toList();
      if (_notes.length == before) return false;
      if (await _persist() != _NotesPersistState.saved) {
        _notes = previous;
        return false;
      }
      for (final n in victim) {
        _deleteAudioFile(n.audioPath);
      }
      return true;
    });
    return result ?? false;
  }

  /// Borra el WAV conservado de una nota (nunca lanza; IO síncrona para
  /// no colgar bajo fakeAsync en tests).
  void _deleteAudioFile(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  Future<T?> _withFileLock<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final target = await _getFile();
    if (target == null) return null;
    final lockFile = File('${target.parent.path}/$name');
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
      } catch (_) {
        if (_isStale(lockFile)) {
          try {
            lockFile.deleteSync();
          } catch (_) {}
        }
      }
      if (created) {
        try {
          final writer = _lockWriter;
          if (writer == null) {
            lockFile.writeAsStringSync(
              '$token\n${DateTime.now().millisecondsSinceEpoch}\n',
              flush: true,
            );
          } else {
            writer(
              lockFile,
              '$token\n${DateTime.now().millisecondsSinceEpoch}\n',
            );
          }
          acquired = true;
        } catch (_) {
          try {
            lockFile.deleteSync();
          } catch (_) {}
        }
      }
      if (!acquired) {
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
