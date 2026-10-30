import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/ui/theme_mode.dart';

import '../helpers/settings_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = SettingsHarness();

  setUp(() => h.setUp());
  tearDown(h.tearDown);

  const secureStore = FlutterSecureStorage(aOptions: StorageService.espOptions);

  group('Ajustes 2026 - raíz y navegación', () {
    testWidgets('la raíz lista todas las secciones como filas', (tester) async {
      await h.pump(tester);

      expect(find.text('Ajustes'), findsOneWidget);
      for (final page in const [
        'transcripcion',
        'ia',
        'teclado',
        'burbuja',
        'trackpad',
        'snippets',
        'claves',
        'notas',
      ]) {
        expect(byKey('nav-$page'), findsOneWidget, reason: page);
      }
      expect(byKey('about-open-button'), findsOneWidget);
      expect(byKey('theme-selector'), findsOneWidget);
    });

    testWidgets('sin clave ni teclado muestra "Terminá de configurar"',
        (tester) async {
      await h.pump(tester);

      expect(byKey('setup-section'), findsOneWidget);
      expect(byKey('setup-groq-row'), findsOneWidget);
      expect(byKey('setup-keyboard-row'), findsOneWidget);
    });

    testWidgets('con clave y teclado activo no muestra la configuración',
        (tester) async {
      h.setUp(secure: {'groq_api_key': 'gsk_lista_1234'});
      h.keyboardEnabled = true;
      h.keyboardSelected = true;
      await h.pump(tester);

      expect(byKey('setup-section'), findsNothing);
      expect(rowShows('nav-transcripcion', 'Groq'), isTrue);
      expect(rowShows('nav-teclado', 'Activo'), isTrue);
    });

    testWidgets('cada fila abre su página y Volver regresa a la raíz',
        (tester) async {
      await h.pump(tester);

      const pages = {
        'transcripcion': 'Transcripción',
        'ia': 'Inteligencia artificial',
        'teclado': 'Teclado',
        'burbuja': 'Barra flotante',
        'trackpad': 'Trackpad',
        'snippets': 'Snippets',
        'claves': 'Claves',
        'notas': 'Notas y widgets',
      };
      for (final entry in pages.entries) {
        await openPage(tester, entry.key);
        expect(byKey('settings-back-button'), findsOneWidget,
            reason: entry.key);
        expect(byKey('nav-${entry.key}'), findsNothing, reason: entry.key);
        await goBack(tester);
        expect(byKey('nav-${entry.key}'), findsOneWidget, reason: entry.key);
      }
    });

    testWidgets('el Back del sistema sube un nivel antes de salir',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'teclado');
      await tapKey(tester, 'nav-sonido');
      expect(byKey('kb-haptics-switch'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('nav-sonido'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('nav-teclado'), findsOneWidget);
    });

    testWidgets('solo se construye la página visible', (tester) async {
      await h.pump(tester);
      expect(byKey('kb-terminal-row-switch'), findsNothing);
      expect(byKey('kb-trackpad-enabled-switch'), findsNothing);
    });
  });

  group('Ajustes 2026 - clave de Groq', () {
    testWidgets('sin clave la fila dice Agregar y abre el sheet',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'transcripcion');

      expect(rowShows('api-key-row', 'Agregar'), isTrue);
      await tapKey(tester, 'api-key-row');
      expect(byKey('api-key-input-field'), findsOneWidget);
      expect(byKey('api-key-save-button'), findsOneWidget);
      expect(byKey('api-key-delete-button'), findsNothing);
    });

    testWidgets('el campo de la clave es oculto', (tester) async {
      await h.pump(tester);
      await openPage(tester, 'transcripcion');
      await tapKey(tester, 'api-key-row');

      final field = tester.widget<TextField>(find.descendant(
        of: byKey('api-key-input-field'),
        matching: find.byType(TextField),
      ));
      expect(field.obscureText, isTrue);
    });

    testWidgets('una clave sin gsk_ muestra error y no se guarda',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'transcripcion');
      await tapKey(tester, 'api-key-row');

      await tester.enterText(byKey('api-key-input-field'), 'sk_otra_cosa_123');
      await tapKey(tester, 'api-key-save-button');

      expect(find.text('Las claves de Groq empiezan con gsk_.'), findsOneWidget);
      expect(byKey('api-key-input-field'), findsOneWidget);
      expect(await secureStore.read(key: 'groq_api_key'), isNull);
    });

    testWidgets('guardar escribe la bóveda, cierra el sheet y muestra la cola',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'transcripcion');
      await tapKey(tester, 'api-key-row');

      await tester.enterText(byKey('api-key-input-field'), 'gsk_espejo_9876');
      await tapKey(tester, 'api-key-save-button');

      expect(byKey('api-key-input-field'), findsNothing);
      expect(rowShows('api-key-row', '••••9876'), isTrue);
      expect(await secureStore.read(key: 'groq_api_key'), 'gsk_espejo_9876');
      final p = await prefs();
      // Contrato K3/SPK-02: la clave va a la bóveda (la lee el IME); jamás
      // a prefs planas. Solo se publican presencia y datos no sensibles.
      expect(p.getString('kb_stt_api_key'), isNull);
      expect(p.getBool('kb_stt_key_configured'), isTrue);
      expect(p.getString('kb_stt_model'), CloudSttService.model);
      expect(p.getString('kb_stt_url'), CloudSttService.endpoint);
    });

    testWidgets('Cancelar cierra el sheet y conserva la clave guardada',
        (tester) async {
      h.setUp(secure: {'groq_api_key': 'gsk_original_1111'});
      await h.pump(tester);
      await openPage(tester, 'transcripcion');
      await tapKey(tester, 'api-key-row');

      await tester.enterText(byKey('api-key-input-field'), 'gsk_descartada');
      await tapKey(tester, 'api-key-cancel-button');

      expect(byKey('api-key-input-field'), findsNothing);
      expect(rowShows('api-key-row', '••••1111'), isTrue);
      expect(await secureStore.read(key: 'groq_api_key'), 'gsk_original_1111');
    });

    testWidgets('Eliminar clave limpia bóveda y presencia', (tester) async {
      h.setUp(secure: {'groq_api_key': 'gsk_a_borrar_22'});
      await h.pump(tester);
      final p = await prefs();
      expect(p.getBool('kb_stt_key_configured'), isTrue);

      await openPage(tester, 'transcripcion');
      await tapKey(tester, 'api-key-row');
      await tapKey(tester, 'api-key-delete-button');

      expect(await secureStore.read(key: 'groq_api_key'), isNull);
      expect(p.getBool('kb_stt_key_configured'), isFalse);
      expect(rowShows('api-key-row', 'Agregar'), isTrue);
    });

    testWidgets('al abrir con clave y sin espejo se publica (backfill)',
        (tester) async {
      h.setUp(secure: {'groq_api_key': 'previa'});
      await h.pump(tester);

      final p = await prefs();
      expect(p.getString('kb_stt_api_key'), isNull);
      expect(p.getBool('kb_stt_key_configured'), isTrue);
    });

    testWidgets('con el espejo ya publicado no se reescribe al abrir',
        (tester) async {
      h.setUp(
        secure: {'groq_api_key': 'gsk_vigente_77'},
        prefs: {
          'kb_stt_key_configured': true,
          'kb_stt_url': 'https://custom.example/stt',
        },
      );
      await h.pump(tester);

      final p = await prefs();
      expect(p.getBool('kb_stt_key_configured'), isTrue);
      // saveSttMirror no corrió: no publicó modelo ni idioma.
      expect(p.getString('kb_stt_model'), isNull);
      expect(p.getString('kb_stt_url'), 'https://custom.example/stt');
    });

    testWidgets('el modo de grabación persiste al elegir Mantener',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'transcripcion');

      expect(rowShows('record-mode-selector', 'Tocar'), isTrue);
      await pickOption(
          tester, 'record-mode-selector', StorageService.recordModeHold);

      expect(rowShows('record-mode-selector', 'Mantener'), isTrue);
      expect(await h.storage.loadRecordMode(), StorageService.recordModeHold);
    });
  });

  group('Ajustes 2026 - inteligencia artificial', () {
    testWidgets('sin clave de Google las acciones quedan ocultas',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'ia');

      expect(rowShows('gemini-key-row', 'Agregar'), isTrue);
      expect(byKey('geminiActionsSwitch'), findsNothing);
      expect(byKey('geminiTestButton'), findsNothing);
    });

    testWidgets('guardar la clave de Google muestra acciones', (tester) async {
      await h.pump(tester);
      await openPage(tester, 'ia');
      await tapKey(tester, 'gemini-key-row');

      await tester.enterText(
          byKey('gemini-key-input-field'), 'AIzaPruebaGemini42');
      await tapKey(tester, 'gemini-key-save-button');

      expect(byKey('gemini-key-input-field'), findsNothing);
      expect(rowShows('gemini-key-row', '••••ni42'), isTrue);
      expect(byKey('geminiActionsSwitch'), findsOneWidget);
      expect(byKey('geminiTestButton'), findsOneWidget);
    });
  });

  group('Ajustes 2026 - Acerca de y apariencia', () {
    testWidgets('la tarjeta de la app abre Acerca de con diagnóstico',
        (tester) async {
      await h.pump(tester);
      await tapKey(tester, 'about-open-button');

      expect(byKey('about-version'), findsOneWidget);
      expect(rowShows('about-version', '1.0.0'), isTrue);
      expect(byKey('about-channel-errors'), findsOneWidget);
    });

    testWidgets('elegir Oscura persiste y aplica el tema', (tester) async {
      await h.pump(tester);
      expect(rowShows('theme-selector', 'Automática'), isTrue);

      await pickOption(tester, 'theme-selector', 'oscuro');

      expect(await h.storage.loadThemeMode(), 'oscuro');
      expect(appThemeMode.value, ThemeMode.dark);
      expect(rowShows('theme-selector', 'Oscura'), isTrue);
      appThemeMode.value = ThemeMode.system;
    });
  });

  group('Ajustes 2026 - burbuja flotante', () {
    testWidgets('muestra burbuja apagada e historial encendido por defecto',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'burbuja');

      expect(switchValue(tester, 'bubble-active-switch'), isFalse);
      expect(switchValue(tester, 'bubble-history-switch'), isTrue);
    });

    testWidgets('el historial de la burbuja persiste (hito B6)',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'burbuja');

      await tapKey(tester, 'bubble-history-switch');

      expect(switchValue(tester, 'bubble-history-switch'), isFalse);
      expect(await h.storage.loadBubbleHistoryEnabled(), isFalse);
    });

    testWidgets('encender con permiso arranca la burbuja', (tester) async {
      await h.pump(tester);
      await openPage(tester, 'burbuja');

      await tapKey(tester, 'bubble-active-switch');

      expect(h.bubbleLog.map((c) => c.method), contains('startBubble'));
      expect(switchValue(tester, 'bubble-active-switch'), isTrue);
      expect(await h.storage.loadFloatingBubbleEnabled(), isTrue);
    });

    testWidgets('sin permiso pide confirmación antes de abrir el ajuste',
        (tester) async {
      h.canDrawOverlays = false;
      await h.pump(tester);
      await openPage(tester, 'burbuja');

      await tapKey(tester, 'bubble-active-switch');

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(h.bubbleLog.map((c) => c.method),
          isNot(contains('requestOverlayPermission')));
      expect(switchValue(tester, 'bubble-active-switch'), isFalse);
    });

    testWidgets('apagar detiene la burbuja y guarda', (tester) async {
      await h.pump(tester);
      await openPage(tester, 'burbuja');
      await tapKey(tester, 'bubble-active-switch');

      await tapKey(tester, 'bubble-active-switch');

      expect(h.bubbleLog.map((c) => c.method), contains('stopBubble'));
      expect(await h.storage.loadFloatingBubbleEnabled(), isFalse);
    });

    testWidgets('la fila de permiso con permiso concedido avisa',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'burbuja');

      await tapKey(tester, 'burbuja-overlay-permission-row');

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Ajustes 2026 - notas y widgets', () {
    testWidgets('guardar audio sin conexión persiste', (tester) async {
      await h.pump(tester);
      await openPage(tester, 'notas');

      await tapKey(tester, 'notes-deferred-queue-switch');

      expect(await h.storage.loadNotesDeferredQueueEnabled(), isTrue);
    });

    testWidgets('el micrófono del widget pasa a la izquierda', (tester) async {
      await h.pump(tester);
      await openPage(tester, 'notas');

      await pickOption(tester, 'widget-mic-position-selector', 'left');

      expect(await h.storage.getWidgetMicPosition(), 'left');
    });
  });

  group('Ajustes 2026 - estado del teclado', () {
    testWidgets('consulta el estado del teclado al abrir', (tester) async {
      await h.pump(tester);
      final methods = h.keyboardLog.map((c) => c.method);
      expect(methods, contains('isKeyboardEnabled'));
      expect(methods, contains('isKeyboardSelected'));
    });

    testWidgets('sin habilitar muestra los dos pasos y abre Android',
        (tester) async {
      await h.pump(tester);
      await openPage(tester, 'teclado');

      expect(byKey('kb-status-setup'), findsOneWidget);
      await tapKey(tester, 'kb-open-settings-button');
      expect(h.keyboardLog.map((c) => c.method),
          contains('openKeyboardSettings'));
    });

    testWidgets('habilitado sin elegir ofrece el selector', (tester) async {
      h.keyboardEnabled = true;
      await h.pump(tester);
      await openPage(tester, 'teclado');

      expect(byKey('kb-open-settings-button'), findsNothing);
      await tapKey(tester, 'kb-picker-button');
      expect(h.keyboardLog.map((c) => c.method),
          contains('showInputMethodPicker'));
    });

    testWidgets('activo muestra la confirmación', (tester) async {
      h.keyboardEnabled = true;
      h.keyboardSelected = true;
      await h.pump(tester);
      await openPage(tester, 'teclado');

      expect(byKey('kb-status-active'), findsOneWidget);
      expect(find.text('VoiceBubble está activo'), findsOneWidget);
    });

    testWidgets('al volver de Android relee el estado y abre el selector',
        (tester) async {
      await h.pump(tester);
      h.keyboardEnabled = true;
      h.keyboardLog.clear();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      final methods = h.keyboardLog.map((c) => c.method);
      expect(methods, contains('isKeyboardEnabled'));
      expect(methods, contains('showInputMethodPicker'));
    });
  });

  group('Ajustes 2026 - accesibilidad', () {
    testWidgets('las filas de navegación anuncian título y valor',
        (tester) async {
      final handle = tester.ensureSemantics();
      await h.pump(tester);

      expect(
        tester.getSemantics(byKey('nav-burbuja')),
        matchesSemantics(label: 'Barra flotante, Apagada', isButton: true),
      );
      handle.dispose();
    });

    testWidgets('respeta Reduced Motion (sin animación de página)',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await h.pump(tester);

      await tester.tap(byKey('nav-teclado'));
      await tester.pump();
      expect(byKey('kb-terminal-row-switch'), findsOneWidget);
      expect(byKey('nav-teclado'), findsNothing);
    });
  });
}
