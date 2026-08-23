import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

Transcription _makeTranscription(String text, {bool isLocal = true}) {
  return Transcription(
    text: text,
    timestamp: DateTime(2025, 1, 1),
    isLocal: isLocal,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService', () {
    test('initial state has empty transcriptions list', () {
      final service = StorageService();
      expect(service.transcriptions, isEmpty);
    });

    test('load() restores previously saved transcriptions', () async {
      final t1 = _makeTranscription('hello');
      final t2 = _makeTranscription('world');
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          jsonEncode(t1.toJson()),
          jsonEncode(t2.toJson()),
        ],
      });

      final service = StorageService();
      await service.load();

      expect(service.transcriptions.length, 2);
      expect(service.transcriptions[0], t1);
      expect(service.transcriptions[1], t2);
    });

    test('load() gracefully ignores corrupt JSON entries', () async {
      final t1 = _makeTranscription('valid');
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          jsonEncode(t1.toJson()),
          'not valid json',
          '{invalid json}',
        ],
      });

      final service = StorageService();
      await service.load();

      expect(service.transcriptions.length, 1);
      expect(service.transcriptions[0], t1);
    });

    test('add() adds a transcription to the list', () async {
      final service = StorageService();
      final t = _makeTranscription('test');
      await service.add(t);

      expect(service.transcriptions.length, 1);
      expect(service.transcriptions[0], t);
    });

    test('add() places new transcription at index 0', () async {
      final service = StorageService();
      final t1 = _makeTranscription('first');
      final t2 = _makeTranscription('second');

      await service.add(t1);
      await service.add(t2);

      expect(service.transcriptions[0], t2);
      expect(service.transcriptions[1], t1);
    });

    test('add() maintains FIFO order with newest first', () async {
      final service = StorageService();
      final t1 = _makeTranscription('one');
      final t2 = _makeTranscription('two');
      final t3 = _makeTranscription('three');

      await service.add(t1);
      await service.add(t2);
      await service.add(t3);

      expect(service.transcriptions.map((t) => t.text).toList(),
          ['three', 'two', 'one']);
    });

    test('add() limits list to max 20 items', () async {
      final service = StorageService();
      for (var i = 0; i < 20; i++) {
        await service.add(_makeTranscription('item $i'));
      }
      expect(service.transcriptions.length, 20);
    });

    test('add() removes oldest when exceeding 20', () async {
      final service = StorageService();
      final transcriptions = <Transcription>[];
      for (var i = 0; i < 25; i++) {
        final t = _makeTranscription('item $i');
        transcriptions.add(t);
        await service.add(t);
      }

      expect(service.transcriptions.length, 20);
      // Newest first: item 24 down to item 5 (indices 24..5)
      expect(service.transcriptions[0], transcriptions[24]);
      expect(service.transcriptions[19], transcriptions[5]);
    });

    test('clear() empties the list', () async {
      final service = StorageService();
      await service.add(_makeTranscription('test'));
      expect(service.transcriptions.length, 1);

      await service.clear();
      expect(service.transcriptions, isEmpty);
    });

    test('clear() persists the empty state', () async {
      final service = StorageService();
      await service.add(_makeTranscription('test'));
      await service.clear();

      // Reload in a fresh instance to verify persistence
      final freshService = StorageService();
      await freshService.load();
      expect(freshService.transcriptions, isEmpty);
    });

    test('transcriptions getter returns unmodifiable list', () {
      final service = StorageService();
      expect(
        () => service.transcriptions.add(_makeTranscription('test')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('multiple add() calls maintain correct order', () async {
      final service = StorageService();
      final letters = ['a', 'b', 'c', 'd', 'e'];
      for (final l in letters) {
        await service.add(_makeTranscription(l));
      }

      final result = service.transcriptions.map((t) => t.text).toList();
      expect(result, ['e', 'd', 'c', 'b', 'a']);
    });

    test('persistence across load() calls (save then load in new instance)',
        () async {
      // First instance: add items
      final service1 = StorageService();
      await service1.add(_makeTranscription('alpha', isLocal: true));
      await service1.add(_makeTranscription('beta', isLocal: false));

      // Second instance: load and verify
      final service2 = StorageService();
      await service2.load();

      expect(service2.transcriptions.length, 2);
      expect(service2.transcriptions[0],
          _makeTranscription('beta', isLocal: false));
      expect(service2.transcriptions[1],
          _makeTranscription('alpha', isLocal: true));
    });

    test('floating bubble setting defaults to false', () async {
      final service = StorageService();
      final enabled = await service.loadFloatingBubbleEnabled();
      expect(enabled, isFalse);
    });

    test('floating bubble setting persists correctly', () async {
      final service = StorageService();
      await service.saveFloatingBubbleEnabled(true);
      final enabled = await service.loadFloatingBubbleEnabled();
      expect(enabled, isTrue);

      await service.saveFloatingBubbleEnabled(false);
      final disabled = await service.loadFloatingBubbleEnabled();
      expect(disabled, isFalse);
    });
  });

  group('StorageService - fila terminal del teclado', () {
    test('default visible cuando no hay clave guardada', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      expect(await service.loadKeyboardTerminalRowVisible(), isTrue);
    });

    test('persiste oculto y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveKeyboardTerminalRowVisible(false);
      expect(await service.loadKeyboardTerminalRowVisible(), isFalse);
    });

    test('persiste visible y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveKeyboardTerminalRowVisible(false);
      await service.saveKeyboardTerminalRowVisible(true);
      expect(await service.loadKeyboardTerminalRowVisible(), isTrue);
    });

    test('usa la clave compartida con el teclado nativo', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveKeyboardTerminalRowVisible(false);
      // El lado Kotlin lee "flutter.kb_terminal_row_visible" en
      // FlutterSharedPreferences; el plugin antepone "flutter." al guardar.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kb_terminal_row_visible'), isFalse);
    });
  });
}
