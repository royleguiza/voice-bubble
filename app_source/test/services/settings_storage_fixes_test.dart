import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

class FakeFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.unmodifiable(_store);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.clear();
  }

  @override
  Future<bool> isCupertinoProtectedDataAvailable() async => false;

  @override
  void registerListener({
    required String key,
    required void Function(String value) listener,
  }) {}

  @override
  void unregisterAllListenersForKey({required String key}) {}

  @override
  void unregisterAllListeners() {}
}

Transcription _makeTranscription(String text, {bool isLocal = true}) {
  return Transcription(
    text: text,
    timestamp: DateTime(2025, 1, 1),
    isLocal: isLocal,
  );
}

void main() {
  group('FlutterSecureStorage - API key', () {
    late FakeFlutterSecureStorage fakeStorage;

    setUp(() {
      fakeStorage = FakeFlutterSecureStorage();
    });

    test('se usa para guardar API key', () async {
      await fakeStorage.write(key: 'groq_api_key', value: 'test_key_123');
      expect(fakeStorage._store['groq_api_key'], 'test_key_123');
    });

    test('se usa para leer API key', () async {
      await fakeStorage.write(key: 'groq_api_key', value: 'my_secret');
      final key = await fakeStorage.read(key: 'groq_api_key');
      expect(key, 'my_secret');
    });

    test('se usa para borrar API key', () async {
      await fakeStorage.write(key: 'groq_api_key', value: 'to_delete');
      await fakeStorage.delete(key: 'groq_api_key');
      final key = await fakeStorage.read(key: 'groq_api_key');
      expect(key, isNull);
    });
  });

  group('SettingsScreen - Sección Modelo de transcripción', () {
    Widget buildTestableWidget() {
      return const MaterialApp(
        home: SettingsScreen(),
      );
    }

    testWidgets('existe la sección "Modelo de transcripción" en Settings',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Modelo de transcripción'), findsOneWidget);
    });

    testWidgets('muestra info del modo Cloud', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Modo Cloud'), findsOneWidget);
      expect(find.text('Groq Whisper Large V3 (whisper-large-v3)'),
          findsOneWidget);
    });

    testWidgets('muestra info del modo Local', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Modo Local'), findsOneWidget);
      expect(find.text('Speech-to-Text del sistema Android'), findsOneWidget);
    });
  });

  group('StorageService - FIFO de 20 elementos', () {
    test('mantiene máximo 20 elementos', () async {
      final service = StorageService();
      for (var i = 0; i < 20; i++) {
        await service.add(_makeTranscription('item $i'));
      }
      expect(service.transcriptions.length, 20);
    });

    test('elimina el más antiguo cuando se supera el límite de 20',
        () async {
      final service = StorageService();
      final transcriptions = <Transcription>[];
      for (var i = 0; i < 25; i++) {
        final t = _makeTranscription('item $i');
        transcriptions.add(t);
        await service.add(t);
      }

      expect(service.transcriptions.length, 20);
      expect(service.transcriptions[0], transcriptions[24]);
      expect(service.transcriptions[19], transcriptions[5]);
    });

    test('mantiene el orden FIFO (más nuevo primero)', () async {
      final service = StorageService();
      final t1 = _makeTranscription('primero');
      final t2 = _makeTranscription('segundo');
      final t3 = _makeTranscription('tercero');

      await service.add(t1);
      await service.add(t2);
      await service.add(t3);

      expect(service.transcriptions.map((t) => t.text).toList(),
          ['tercero', 'segundo', 'primero']);
    });
  });

  group('Transcription - Serialización JSON', () {
    test('preserva todos los campos en la serialización', () {
      final original = Transcription(
        text: 'Hola mundo',
        timestamp: DateTime(2025, 7, 15, 10, 30, 0),
        isLocal: true,
      );

      final json = original.toJson();
      expect(json.containsKey('text'), isTrue);
      expect(json.containsKey('timestamp'), isTrue);
      expect(json.containsKey('isLocal'), isTrue);

      final restored = Transcription.fromJson(json);
      expect(restored.text, original.text);
      expect(restored.timestamp, original.timestamp);
      expect(restored.isLocal, original.isLocal);
    });

    test('preserva isLocal false en round-trip', () {
      final original = Transcription(
        text: 'Cloud mode',
        timestamp: DateTime(2025, 8, 1),
        isLocal: false,
      );

      final json = original.toJson();
      final restored = Transcription.fromJson(json);
      expect(restored.isLocal, false);
      expect(restored.text, 'Cloud mode');
    });

    test('preserva caracteres especiales en texto', () {
      final original = Transcription(
        text: 'Acentos: áéíóú ñ, comillas: "hello"',
        timestamp: DateTime(2025, 1, 1),
        isLocal: true,
      );

      final json = original.toJson();
      final restored = Transcription.fromJson(json);
      expect(restored.text, original.text);
    });
  });
}
