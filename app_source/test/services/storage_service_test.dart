import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

    test('bubble history defaults to true (hito B6)', () async {
      final service = StorageService();
      expect(await service.loadBubbleHistoryEnabled(), isTrue);
    });

    test('bubble history persists correctly (hito B6)', () async {
      final service = StorageService();
      await service.saveBubbleHistoryEnabled(false);
      expect(await service.loadBubbleHistoryEnabled(), isFalse);

      await service.saveBubbleHistoryEnabled(true);
      expect(await service.loadBubbleHistoryEnabled(), isTrue);
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

  group('StorageService - imágenes del portapapeles opt-in (SPK-10)', () {
    test('default OFF cuando no hay clave guardada (texto primero)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      expect(await service.getClipboardImagesEnabled(), isFalse);
    });

    test('persiste activado y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setClipboardImagesEnabled(true);
      expect(await service.getClipboardImagesEnabled(), isTrue);
    });

    test('usa la clave compartida con el teclado nativo', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setClipboardImagesEnabled(true);
      // El lado Kotlin lee "flutter.kb_clipboard_images_enabled".
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kb_clipboard_images_enabled'), isTrue);
    });

    test('la clave pertenece al puente verificado por el CI', () {
      expect(StorageService.bridgeKeys,
          contains(StorageService.kbClipboardImagesEnabledKey));
    });
  });

  group('StorageService - espaciado de teclas anti-fantasma', () {
    test('default normal cuando no hay clave guardada', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      expect(await service.getKeySpacing(), 'normal');
    });

    test('persiste amplio y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setKeySpacing('amplio');
      expect(await service.getKeySpacing(), 'amplio');
    });

    test('persiste extra y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setKeySpacing('extra');
      expect(await service.getKeySpacing(), 'extra');
    });

    test('rechaza valor invalido y conserva el anterior', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setKeySpacing('amplio');
      await service.setKeySpacing('gigante');
      expect(await service.getKeySpacing(), 'amplio');
    });

    test('usa la clave compartida con el teclado nativo', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setKeySpacing('compacto');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_key_spacing'), 'compacto');
    });

    test('la clave pertenece al puente verificado por el CI', () {
      expect(StorageService.bridgeKeys,
          contains(StorageService.kbKeySpacingKey));
    });
  });

  group('StorageService - estilo háptico de teclas', () {
    test('default nitido cuando no hay clave guardada', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      expect(await service.getHapticStyle(), 'nitido');
    });

    test('persiste firme y lo recupera', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setHapticStyle('firme');
      expect(await service.getHapticStyle(), 'firme');
    });

    test('rechaza valor invalido y conserva el anterior', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setHapticStyle('suave');
      await service.setHapticStyle('martillo');
      expect(await service.getHapticStyle(), 'suave');
    });

    test('usa la clave compartida con el teclado nativo', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setHapticStyle('suave');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_haptic_style'), 'suave');
    });

    test('la clave pertenece al puente verificado por el CI', () {
      expect(StorageService.bridgeKeys,
          contains(StorageService.kbHapticStyleKey));
    });
  });

  group('StorageService - feedback del micrófono', () {
    test('defaults: hápticas ON y sonidos OFF', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      expect(await service.getMicHapticsEnabled(), isTrue);
      expect(await service.getMicHapticStart(), isTrue);
      expect(await service.getMicHapticRecording(), isTrue);
      expect(await service.getMicHapticPaste(), isTrue);
      expect(await service.getMicHapticCancel(), isTrue);
      expect(await service.getMicSoundsEnabled(), isFalse);
    });

    test('persiste toggles y sonidos', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.setMicHapticCancel(false);
      await service.setMicSoundsEnabled(true);
      expect(await service.getMicHapticCancel(), isFalse);
      expect(await service.getMicSoundsEnabled(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kb_mic_haptic_cancel'), isFalse);
      expect(prefs.getBool('kb_mic_sounds_enabled'), isTrue);
    });

    test('las 6 claves pertenecen al puente verificado por el CI', () {
      for (final key in [
        StorageService.kbMicHapticsEnabledKey,
        StorageService.kbMicHapticStartKey,
        StorageService.kbMicHapticRecordingKey,
        StorageService.kbMicHapticPasteKey,
        StorageService.kbMicHapticCancelKey,
        StorageService.kbMicSoundsEnabledKey,
      ]) {
        expect(StorageService.bridgeKeys, contains(key));
      }
    });

    test('estilos de inicio/fin con default 1 y validación', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      expect(await service.getMicStartStyle(), '3');
      expect(await service.getMicStopStyle(), '3');
      await service.setMicStartStyle('3');
      await service.setMicStopStyle('4');
      expect(await service.getMicStartStyle(), '3');
      expect(await service.getMicStopStyle(), '4');
      await service.setMicStartStyle('9');
      expect(await service.getMicStartStyle(), '3');
      expect(StorageService.bridgeKeys,
          contains(StorageService.kbMicStartStyleKey));
      expect(StorageService.bridgeKeys,
          contains(StorageService.kbMicStopStyleKey));
    });
  });

  group('StorageService - bóveda STT sin espejo plano (SPK-02)', () {
    test('saveSttMirror guarda en bóveda y publica presencia/config', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveSttMirror(apiKey: 'gsk_prueba_123');

      // La key vive en la bóveda (misma que lee el IME vía SecureStore);
      // secure sigue siendo la fuente de verdad para la app.
      const secure =
          FlutterSecureStorage(aOptions: StorageService.espOptions);
      expect(await secure.read(key: 'groq_api_key'), 'gsk_prueba_123');
      final prefs = await SharedPreferences.getInstance();
      // SPK-02: jamás espejo plano.
      expect(prefs.getString('kb_stt_api_key'), isNull);
      expect(prefs.getBool('kb_stt_key_configured'), isTrue);
      expect(prefs.getString('kb_stt_url'), CloudSttService.endpoint);
      expect(prefs.getString('kb_stt_model'), CloudSttService.model);
      expect(prefs.getString('kb_stt_language'), CloudSttService.language);
    });

    test('repairSttMirror republica presencia y limpia el legado', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues(
          {'kb_stt_api_key': 'gsk_legada'});
      final service = StorageService();
      // Simula instalación pre-SPK-02: bóveda con key y espejo plano vivo.
      const secure =
          FlutterSecureStorage(aOptions: StorageService.espOptions);
      await secure.write(key: 'groq_api_key', value: 'gsk_reparada');
      final repaired = await service.repairSttMirror();
      expect(repaired, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_stt_api_key'), isNull);
      expect(prefs.getBool('kb_stt_key_configured'), isTrue);
    });

    test('clearSttMirror elimina bóveda y config', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final service = StorageService();
      await service.saveSttMirror(apiKey: 'gsk_temporal');
      await service.clearSttMirror();

      const secure =
          FlutterSecureStorage(aOptions: StorageService.espOptions);
      expect(await secure.read(key: 'groq_api_key'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_stt_api_key'), isNull);
      expect(prefs.getBool('kb_stt_key_configured'), isFalse);
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

  group('StorageService - puente verificado por el CI (contrato)', () {
    // Snapshot del triángulo Kotlin==contrato==Dart: agregar una clave al
    // puente exige actualizar aquí + docs/contract-keys.txt + Kotlin el
    // mismo día (docs/contrato-claves.md).
    const expectedBridgeKeys = {
      'bubble_history_enabled',
      'kb_bottom_elevation_dp',
      'kb_clipboard_images_enabled',
      'kb_code_key_visible',
      'kb_haptic_style',
      'kb_haptics_enabled',
      'kb_height_profile',
      'kb_invert_toolbar',
      'kb_key_spacing',
      'kb_language_key_visible',
      'kb_mic_haptic_cancel',
      'kb_mic_haptic_paste',
      'kb_mic_haptic_recording',
      'kb_mic_haptic_start',
      'kb_mic_haptics_enabled',
      'kb_mic_sounds_enabled',
      'kb_mic_start_style',
      'kb_mic_stop_style',
      'kb_snippets_seeded',
      'kb_spacebar_alignment',
      'kb_spacebar_trackpad_mode',
      'kb_stt_api_key',
      'kb_stt_language',
      'kb_stt_model',
      'kb_stt_url',
      'kb_terminal_row_visible',
      'kb_trackpad_accel_curve',
      'kb_trackpad_auto_return',
      'kb_trackpad_button_layout',
      'kb_trackpad_enabled',
      'kb_trackpad_haptic',
      'kb_trackpad_pointer_style',
      'kb_trackpad_scroll_direction',
      'kb_trackpad_scroll_position',
      'kb_trackpad_secondary_click',
      'kb_trackpad_sensitivity',
      'kb_trackpad_tap_to_click',
      'kb_trackpad_toolbar_visible',
      'transcriptions',
      'vb_cred_pass_v1',
      'vb_cred_show_user',
      'vb_credentials_v1',
      'voice_snippets_v1',
    };

    test('bridgeKeys cubre exactamente el contrato (43 claves)', () {
      expect(StorageService.bridgeKeys.length, 43);
      expect(Set.of(StorageService.bridgeKeys), expectedBridgeKeys);
    });

    test('floating_bubble_enabled es solo-Dart (burbuja va por canal)',
        () async {
      // Aclaración de divergencia: la burbuja se gobierna por MethodChannel,
      // Kotlin jamás lee esta pref; por eso NO entra al puente.
      expect(StorageService.bridgeKeys, isNot(contains('floating_bubble_enabled')));
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveFloatingBubbleEnabled(true);
      expect(await service.loadFloatingBubbleEnabled(), isTrue);
    });

    test('theme_mode es solo-Dart con default sistema (rediseño v2)',
        () async {
      // El IME jamás lee el tema: no entra al puente ni al contrato.
      expect(StorageService.bridgeKeys, isNot(contains('theme_mode')));
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      expect(await service.loadThemeMode(), 'sistema');
      await service.saveThemeMode('oscuro');
      expect(await service.loadThemeMode(), 'oscuro');
      await service.saveThemeMode('invalido');
      expect(await service.loadThemeMode(), 'oscuro');
    });
  });
}
