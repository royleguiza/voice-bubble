import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/voice_note.dart';
import 'package:voice_bubble_stt/services/notes_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  var pathProviderAvailable = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({'voice_notes_v1': '[]'});
    tempDir = Directory.systemTemp.createTempSync('notes_storage_');
    pathProviderAvailable = true;
    File('${tempDir.path}/voice_notes.json').writeAsStringSync('[]');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
      'plugins.flutter.io/path_provider_macos',
      'plugins.flutter.io/path_provider_linux',
      'plugins.flutter.io/path_provider_windows',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall call) async {
          if (!pathProviderAvailable) {
            throw PlatformException(code: 'unavailable');
          }
          return tempDir.path;
        },
      );
    }
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
      'plugins.flutter.io/path_provider_macos',
      'plugins.flutter.io/path_provider_linux',
      'plugins.flutter.io/path_provider_windows',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('NotesService - contrato', () {
    test('expone claves canonicas', () {
      expect(NotesService.notesKey, 'voice_notes_v1');
      expect(NotesService.maxNotes, 50);
    });

    test('persiste STRING con JSON array de claves exactas', () async {
      final s = NotesService();
      expect(await s.addNote(titulo: 'T', cuerpo: 'C'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('voice_notes_v1');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect((decoded.single as Map).keys.toSet(),
          {'id', 'titulo', 'cuerpo', 'createdAt', 'updatedAt'});
    });

    test('primera instalación inicializa ambos espejos y permite la primera nota',
        () async {
      SharedPreferences.setMockInitialValues({});
      final file = File('${tempDir.path}/voice_notes.json');
      if (file.existsSync()) file.deleteSync();
      final service = NotesService();
      expect(await service.addNote(titulo: 'Primera', cuerpo: 'nota'), isTrue);
      expect(service.notes.single.titulo, 'Primera');
      expect(file.existsSync(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(NotesService.notesKey), isNotNull);
    });
  });

  group('NotesService - CRUD', () {
    test('addNote agrega al inicio y persiste', () async {
      final s = NotesService();
      expect(await s.addNote(titulo: 'Uno', cuerpo: 'u'), isTrue);
      expect(await s.addNote(titulo: 'Dos', cuerpo: 'd'), isTrue);
      final fresh = NotesService();
      await fresh.load();
      expect(fresh.notes.map((n) => n.titulo).toList(), ['Dos', 'Uno']);
    });

    test('addFromTranscription usa titulo vacio (Sin titulo)', () async {
      final s = NotesService();
      expect(await s.addFromTranscription('Hola mundo desde widget'), isTrue);
      final n = s.notes.first;
      expect(n.titulo, '');
      expect(n.cuerpo, 'Hola mundo desde widget');
    });

    test('addFromTranscription titulo largo guarda sin titulo', () async {
      final s = NotesService();
      final long = 'a' * 40;
      await s.addFromTranscription(long);
      expect(s.notes.first.titulo, '');
      expect(s.notes.first.cuerpo, long);
    });

    test('updateNote cambia titulo y cuerpo', () async {
      final s = NotesService();
      await s.addNote(titulo: 'Viejo', cuerpo: 'viejo');
      final id = s.notes.first.id;
      expect(await s.updateNote(id, titulo: 'Nuevo'), isTrue);
      expect(s.notes.first.titulo, 'Nuevo');
    });

    test('deleteNote elimina', () async {
      final s = NotesService();
      await s.addNote(titulo: 'a', cuerpo: 'a');
      await s.addNote(titulo: 'b', cuerpo: 'b');
      final id = s.notes.last.id;
      expect(await s.deleteNote(id), isTrue);
      expect(s.notes.length, 1);
    });
  });

  group('NotesService - limites', () {
    test('rechaza nota 51', () async {
      final s = NotesService();
      for (var i = 0; i < 50; i++) {
        expect(await s.addNote(titulo: 't$i', cuerpo: 'c$i'), isTrue);
      }
      expect(await s.addNote(titulo: 'extra', cuerpo: 'x'), isFalse);
      expect(s.notes.length, 50);
    });

    test('rechaza cuerpo 2001', () async {
      final s = NotesService();
      expect(await s.addNote(titulo: 't', cuerpo: 'a' * 2001), isFalse);
    });

    test('permite titulo vacio (Sin titulo)', () async {
      final s = NotesService();
      expect(await s.addNote(titulo: '', cuerpo: 'c'), isTrue);
      expect(s.notes.first.titulo, '');
      expect(await s.addNote(titulo: '  ', cuerpo: 'd'), isTrue);
      expect(s.notes.first.titulo, '');
    });

    test('search filtra insensible a mayusculas', () async {
      final s = NotesService();
      await s.addNote(titulo: 'Reunion', cuerpo: 'presupuesto');
      await s.addNote(titulo: 'Compra', cuerpo: 'super');
      expect(s.search('reunion').length, 1);
      expect(s.search('SUPER').length, 1);
      expect(s.search('').length, 2);
    });
  });

  group('NotesService - tolerancia', () {
    test('JSON invalido no carga una lista vacia', () async {
      SharedPreferences.setMockInitialValues({'voice_notes_v1': '{bad'});
      final s = NotesService();
      expect(await s.load(), isFalse);
      expect(s.notes, isEmpty);
    });

    test('tipo incorrecto no carga una lista vacia', () async {
      SharedPreferences.setMockInitialValues({'voice_notes_v1': '"solo"'});
      final s = NotesService();
      expect(await s.load(), isFalse);
      expect(s.notes, isEmpty);
    });
  });

  test('missing mirror repairs from the valid mirror without losing notes',
      () async {
    final service = NotesService();
    expect(await service.addNote(titulo: 'Base', cuerpo: 'base'), isTrue);
    final id = service.notes.single.id;
    final file = File('${tempDir.path}/voice_notes.json');
    file.deleteSync();

    expect(await service.load(), isTrue);
    expect(file.existsSync(), isTrue);
    expect(service.notes.single.id, id);
    expect(await service.updateNote(id, cuerpo: 'cambia'), isTrue);
    expect(service.notes.single.cuerpo, 'cambia');
  });

  test('corrupt index blocks mutation and preserves both stored values', () async {
    final service = NotesService();
    expect(await service.addNote(titulo: 'Base', cuerpo: 'base'), isTrue);
    final id = service.notes.single.id;
    final file = File('${tempDir.path}/voice_notes.json');
    final prefs = await SharedPreferences.getInstance();
    final published = prefs.getString(NotesService.notesKey);
    file.writeAsStringSync('{bad');

    expect(await service.load(), isFalse);
    expect(await service.addNote(titulo: 'Otra', cuerpo: 'otra'), isFalse);
    expect(await service.updateNote(id, cuerpo: 'cambia'), isFalse);
    expect(await service.deleteNote(id), isFalse);
    expect(service.notes.single.id, id);
    expect(file.readAsStringSync(), '{bad');
    expect(prefs.getString(NotesService.notesKey), published);
  });

  test('unavailable index blocks mutation and preserves the last snapshot', () async {
    final service = NotesService();
    expect(await service.addNote(titulo: 'Base', cuerpo: 'base'), isTrue);
    final id = service.notes.single.id;
    pathProviderAvailable = false;

    expect(await service.load(), isFalse);
    expect(await service.addNote(titulo: 'Otra', cuerpo: 'otra'), isFalse);
    expect(await service.updateNote(id, cuerpo: 'cambia'), isFalse);
    expect(await service.deleteNote(id), isFalse);
    expect(service.notes.single.id, id);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(NotesService.notesKey)!) as List, hasLength(1));
  });

  test('fallo de token limpia lock y reintenta antes de ejecutar', () async {
    final file = File('${tempDir.path}/voice_notes.json');
    var attempts = 0;
    final service = NotesService(
      lockWriter: (lock, token) {
        attempts += 1;
        if (attempts == 1) {
          throw const FileSystemException('sin token');
        }
        lock.writeAsStringSync(token, flush: true);
      },
    );

    expect(await service.addNote(titulo: 'Base', cuerpo: 'base'), isTrue);
    expect(attempts, 2);
    expect(file.existsSync(), isTrue);
    expect(File('${tempDir.path}/${NotesService.lockFileName}').existsSync(), isFalse);
  });

  test('fallo de archivo no confirma preferencias', () async {
    final seed = NotesService();
    expect(await seed.addNote(titulo: 'Base', cuerpo: 'base'), isTrue);
    final file = File('${tempDir.path}/voice_notes.json');
    final prefs = await SharedPreferences.getInstance();
    var fileWrites = 0;
    var failFileWrites = false;
    final service = NotesService(
      fileWriter: (target, encoded) async {
        fileWrites += 1;
        if (failFileWrites) return false;
        final tmp = File('${target.path}.fixture.tmp');
        tmp.writeAsStringSync(encoded, flush: true);
        tmp.renameSync(target.path);
        return target.existsSync() && target.readAsStringSync() == encoded;
      },
    );
    expect(await service.load(), isTrue);
    final previousPrefs = prefs.getString(NotesService.notesKey);
    final previousFile = file.readAsStringSync();
    failFileWrites = true;

    expect(await service.addNote(titulo: 'Otra', cuerpo: 'otra'), isFalse);
    expect(fileWrites, 2);
    expect(file.readAsStringSync(), previousFile);
    expect(prefs.getString(NotesService.notesKey), previousPrefs);
    expect(service.notes.single.titulo, 'Base');
  });

  test('fallo transitorio de lectura de prefs tras load válido no usa snapshot vacío',
      () async {
    final seed = NotesService();
    expect(await seed.addNote(titulo: 'Base', cuerpo: 'base'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    final previousRaw = prefs.getString(NotesService.notesKey)!;
    var reads = 0;
    final service = NotesService(
      prefsRawReader: () async {
        reads += 1;
        if (reads == 1) return previousRaw;
        throw StateError('lectura transitoria');
      },
    );

    expect(await service.load(), isTrue);
    expect(await service.addNote(titulo: 'Otra', cuerpo: 'otra'), isFalse);
    expect(service.notes.single.titulo, 'Base');
    final file = File('${tempDir.path}/voice_notes.json');
    expect(file.existsSync(), isTrue);
    expect(jsonDecode(file.readAsStringSync()) as List, hasLength(1));
    expect(jsonDecode(prefs.getString(NotesService.notesKey)!) as List, hasLength(1));
  });

  test('setString fallido restaura prefs y archivo y no confirma', () async {
    final seed = NotesService();
    expect(await seed.addNote(titulo: 'Base', cuerpo: 'base'), isTrue);
    final file = File('${tempDir.path}/voice_notes.json');
    final prefs = await SharedPreferences.getInstance();
    var prefsWrites = 0;
    var failPrefsWrites = false;
    final service = NotesService(
      prefsWriter: (preferences, key, value) async {
        prefsWrites += 1;
        await preferences.setString(key, value);
        return !failPrefsWrites;
      },
    );
    expect(await service.load(), isTrue);
    final previousPrefs = prefs.getString(NotesService.notesKey);
    final previousFile = file.readAsStringSync();
    failPrefsWrites = true;

    expect(await service.addNote(titulo: 'Otra', cuerpo: 'otra'), isFalse);
    expect(prefsWrites, 2);
    expect(file.readAsStringSync(), previousFile);
    expect(prefs.getString(NotesService.notesKey), previousPrefs);
    expect(service.notes.single.titulo, 'Base');
  });

  group('VoiceNote model', () {
    test('toJson/fromJson round-trip', () {
      final n = VoiceNote(
        id: '1',
        titulo: 'T',
        cuerpo: 'C',
        createdAt: DateTime(2026, 1, 1, 10),
        updatedAt: DateTime(2026, 1, 1, 11),
      );
      final json = n.toJson();
      final restored = VoiceNote.fromJson(json);
      expect(restored.id, n.id);
      expect(restored.titulo, n.titulo);
      expect(restored.cuerpo, n.cuerpo);
    });

    test('fromJson rechaza campos obligatorios ausentes', () {
      expect(
        () => VoiceNote.fromJson({}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => VoiceNote.fromJson({
          'id': '1',
          'titulo': '',
          'cuerpo': 'C',
          'createdAt': '2026-01-01T10:00:00',
          'updatedAt': 'no-date',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('audioPath opcional: round-trip y ausente en viejas', () {
      final withAudio = VoiceNote(
        id: 'a',
        titulo: '',
        cuerpo: 'C',
        createdAt: DateTime(2026, 1, 1, 10),
        updatedAt: DateTime(2026, 1, 1, 11),
        audioPath: '/tmp/notes_audio/x.wav',
      );
      expect(withAudio.hasAudio, isTrue);
      final restored = VoiceNote.fromJson(withAudio.toJson());
      expect(restored.audioPath, '/tmp/notes_audio/x.wav');
      expect(restored, withAudio);

      final legacy = VoiceNote.fromJson({
        'id': 'b',
        'titulo': '',
        'cuerpo': 'C',
        'createdAt': '2026-01-01T10:00:00.000',
        'updatedAt': '2026-01-01T11:00:00.000',
      });
      expect(legacy.audioPath, isNull);
      expect(legacy.hasAudio, isFalse);
      expect(legacy.toJson().containsKey('audioPath'), isFalse);
    });
  });

  group('NotesService - audio conservado (texto + audio)', () {
    test('addFromTranscription guarda audioPath cuando viene', () async {
      final s = NotesService();
      expect(
          await s.addFromTranscription('Hola', audioPath: '/tmp/a.wav'),
          isTrue);
      expect(s.notes.first.audioPath, '/tmp/a.wav');
      expect(s.notes.first.hasAudio, isTrue);
    });

    test('addFromTranscription sin audio deja null (notas a mano)',
        () async {
      final s = NotesService();
      expect(await s.addFromTranscription('Hola'), isTrue);
      expect(s.notes.first.audioPath, isNull);
    });

    test('updateNote clearAudioPath limpia el campo', () async {
      final s = NotesService();
      expect(
          await s.addFromTranscription('Hola', audioPath: '/tmp/a.wav'),
          isTrue);
      final id = s.notes.first.id;
      expect(await s.updateNote(id, clearAudioPath: true), isTrue);
      expect(s.notes.first.audioPath, isNull);
      expect(s.notes.first.hasAudio, isFalse);
    });
  });
}
