import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

Transcription _makeTranscription(String text) {
  return Transcription(
    text: text,
    timestamp: DateTime(2025, 1, 1),
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

    test('load() restores previously saved transcriptions (desc)', () async {
      // fromJson normaliza a hora local: los esperados se construyen con
      // toLocal() para que DateTime.== compare igualdad de bandera isUtc.
      final t1 = Transcription(
          text: 'hello', timestamp: DateTime.utc(2026, 8, 23, 9).toLocal());
      final t2 = Transcription(
          text: 'world', timestamp: DateTime.utc(2026, 8, 23, 10).toLocal());
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          jsonEncode(t1.toJson()),
          jsonEncode(t2.toJson()),
        ],
      });

      final service = StorageService();
      await service.load();

      // Orden descendente impuesto por load() (AT-D1).
      expect(service.transcriptions.length, 2);
      expect(service.transcriptions[0], t2);
      expect(service.transcriptions[1], t1);
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
      await service1.add(
          Transcription(text: 'alpha', timestamp: DateTime.utc(2026, 8, 23, 9)));
      await service1.add(Transcription(
          text: 'beta', timestamp: DateTime.utc(2026, 8, 23, 10)));

      // Second instance: load and verify
      final service2 = StorageService();
      await service2.load();

      expect(service2.transcriptions.length, 2);
      expect(service2.transcriptions[0].text, 'beta');
      expect(service2.transcriptions[1].text, 'alpha');
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

  group('StorageService - tecla de capa codigo del teclado', () {
    test('default visible cuando no hay clave guardada', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      expect(await service.loadKeyboardCodeKeyVisible(), isTrue);
    });

    test('persiste oculto y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveKeyboardCodeKeyVisible(false);
      expect(await service.loadKeyboardCodeKeyVisible(), isFalse);
    });

    test('persiste visible y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveKeyboardCodeKeyVisible(false);
      await service.saveKeyboardCodeKeyVisible(true);
      expect(await service.loadKeyboardCodeKeyVisible(), isTrue);
    });

    test('usa la clave compartida con el teclado nativo', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveKeyboardCodeKeyVisible(false);
      // El lado Kotlin lee "flutter.kb_code_key_visible" en
      // FlutterSharedPreferences; el plugin antepone "flutter." al guardar.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kb_code_key_visible'), isFalse);
    });
  });

  group('StorageService - tecla de idioma del teclado', () {
    test('default visible cuando no hay clave guardada', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      expect(await service.loadKeyboardLanguageKeyVisible(), isTrue);
    });

    test('persiste oculto y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveKeyboardLanguageKeyVisible(false);
      expect(await service.loadKeyboardLanguageKeyVisible(), isFalse);
    });

    test('persiste visible y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveKeyboardLanguageKeyVisible(false);
      await service.saveKeyboardLanguageKeyVisible(true);
      expect(await service.loadKeyboardLanguageKeyVisible(), isTrue);
    });

    test('usa la clave compartida con el teclado nativo', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveKeyboardLanguageKeyVisible(false);
      // El lado Kotlin lee "flutter.kb_language_key_visible" en
      // FlutterSharedPreferences; el plugin antepone "flutter." al guardar.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kb_language_key_visible'), isFalse);
    });
  });

  group('StorageService - espejo D7 de credenciales STT (K3)', () {
    test('saveSttMirror escribe key y valores canonicos del motor', () async {
      final service = StorageService();
      await service.saveSttMirror(apiKey: 'gsk_prueba_123');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_stt_api_key'), 'gsk_prueba_123');
      expect(prefs.getString('kb_stt_url'), CloudSttService.endpoint);
      expect(prefs.getString('kb_stt_model'), CloudSttService.model);
      expect(prefs.getString('kb_stt_language'), CloudSttService.language);
    });

    test('clearSttMirror elimina todas las claves del espejo', () async {
      final service = StorageService();
      await service.saveSttMirror(apiKey: 'gsk_temporal');
      await service.clearSttMirror();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_stt_api_key'), isNull);
      expect(prefs.getString('kb_stt_url'), isNull);
      expect(prefs.getString('kb_stt_model'), isNull);
      expect(prefs.getString('kb_stt_language'), isNull);
    });
  });

  group('StorageService - load(): orden y merge conservador', () {
    test(
        'load() ordena desc por timestamp aunque el disco este desordenado (AT-D1)',
        () async {
      final base = DateTime.utc(2026, 8, 23, 10);
      String entry(String text, int minutes) => jsonEncode({
            'text': text,
            'timestamp': base.add(Duration(minutes: minutes)).toIso8601String(),
          });

      // El lado Kotlin escribe un Set de strings: el orden de llegada no
      // esta garantizado. Se siembra deliberadamente desordenado.
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          entry('medio', 10),
          entry('viejo', 0),
          entry('nuevo', 20),
        ],
      });

      final service = StorageService();
      await service.load();

      expect(
        service.transcriptions.map((t) => t.text).toList(),
        ['nuevo', 'medio', 'viejo'],
      );
    });

    test(
        'load() conserva la entrada en memoria que falta en disco (AT-C10)',
        () async {
      final service = StorageService();
      await service.add(Transcription(
        text: 'recien dictada',
        timestamp: DateTime.utc(2026, 8, 23, 12),
      ));

      // El disco "retrocede": solo contiene lo viejo, como cuando una
      // escritura externa aun no incluye lo recien anadido en memoria.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('transcriptions', [
        jsonEncode(Transcription(
          text: 'vieja',
          timestamp: DateTime.utc(2026, 8, 23, 9),
        ).toJson()),
      ]);

      await service.load();

      // La transcripcion nueva NO se pierde pese a no estar en disco.
      expect(
        service.transcriptions.map((t) => t.text).toList(),
        ['recien dictada', 'vieja'],
      );
    });
  });
}
