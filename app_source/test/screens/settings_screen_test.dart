import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/ui/theme_mode.dart';
import 'package:voice_bubble_stt/widgets/settings_tab_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(FloatingBubbleService.channelName);
  const keyboardChannel = MethodChannel(KeyboardService.channelName);

  late StorageService storageService;
  late List<MethodCall> bubbleLog;
  late List<MethodCall> keyboardLog;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();
    bubbleLog = <MethodCall>[];
    keyboardLog = <MethodCall>[];

    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      bubbleLog.add(call);
      switch (call.method) {
        case 'canDrawOverlays':
          return true;
        case 'requestOverlayPermission':
          return true;
        case 'startBubble':
          return true;
        case 'stopBubble':
          return true;
        case 'isBubbleRunning':
          return false;
        default:
          return null;
      }
    });
    // Estado inicial reproducible y keyboardLog determinista para todos los
    // tests que no registran su propio handler (mockKeyboardChannel lo
    // reemplaza). En produccion el canal nativo siempre responde.
    messenger.setMockMethodCallHandler(keyboardChannel,
        (MethodCall call) async {
      keyboardLog.add(call);
      switch (call.method) {
        case 'isKeyboardEnabled':
          return false;
        case 'isKeyboardSelected':
          return false;
        case 'openKeyboardSettings':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(keyboardChannel, null);
  });

  void mockKeyboardChannel({bool enabled = false, bool selected = false}) {
    messenger.setMockMethodCallHandler(keyboardChannel, (MethodCall call) async {
      keyboardLog.add(call);
      switch (call.method) {
        case 'isKeyboardEnabled':
          return enabled;
        case 'isKeyboardSelected':
          return selected;
        case 'openKeyboardSettings':
          return true;
        default:
          return null;
      }
    });
  }

  Widget buildTestableWidget(
    WidgetTester tester, {
    FloatingBubbleService? bubbleService,
    KeyboardService? keyboardService,
  }) {
    // Superficie alta (800x2400 logicos) para que toda la pagina de Settings
    // sea visible sin scroll: la tarjeta del teclado y la seccion de snippets
    // alargan la lista (9.1-17 / 9.1-21).
    tester.view.physicalSize = const Size(1600, 4800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    return MaterialApp(
      home: SettingsScreen(
        storageService: storageService,
        floatingBubbleService: bubbleService ?? FloatingBubbleService(),
        keyboardService:
            keyboardService ?? KeyboardService(channel: keyboardChannel),
      ),
    );
  }

  group('SettingsScreen - API Key & General', () {
    testWidgets('muestra título General v2 sin AppBar', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      // Título de página + etiqueta del tab (ambos "General").
      expect(find.text('General'), findsNWidgets(2));
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('shows "API Key de Groq" section header', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('API Key de Groq'), findsOneWidget);
    });

    testWidgets('shows description text about Groq', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Necesaria para el modo Cloud. Obtén tu clave en console.groq.com'),
        findsOneWidget,
      );
    });

    testWidgets('shows TextField for API key input after CTA (v1)', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('api-cta-button')), findsOneWidget);
      expect(find.text('Ingresa tu API Key'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('api-cta-button')));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('gsk_...'), findsOneWidget);
    });

    testWidgets('shows save button with Icons.save in edit mode (v1)', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('api-cta-button')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('shows validation error for non-gsk key (v1)', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('api-cta-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bad_key');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.textContaining('gsk_'), findsWidgets);
    });

    testWidgets('shows delete button when API key exists (v1 detail)', (tester) async {
      FlutterSecureStorage.setMockInitialValues(
          {'groq_api_key': 'gsk_existing_1234'});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('api-loaded-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('api-loaded-button')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('does not show delete button when no API key', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('shows "Acerca de" button in Inicio opening sheet (v1)', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('about-open-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('about-open-button')));
      await tester.pumpAndSettle();

      expect(find.text('VoiceBubble STT v1.0.0'), findsOneWidget);
    });

    testWidgets('shows version "VoiceBubble STT v1.0.0" in sheet (v1)', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('about-open-button')));
      await tester.pumpAndSettle();

      expect(find.text('VoiceBubble STT v1.0.0'), findsOneWidget);
    });

    testWidgets('shows app description text in sheet (v1)', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('about-open-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Transcripción de voz a texto con Groq Whisper.'),
        findsOneWidget,
      );
    });

    testWidgets('el sheet Acerca muestra el selector de tema en Sistema (v2)',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('about-open-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('about-theme-selector')),
          findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);
    });

    testWidgets('elegir Oscuro persiste el tema (v2)', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('about-open-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();

      expect(await storageService.loadThemeMode(), 'oscuro');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'oscuro');
      appThemeMode.value = ThemeMode.system;
    });

    testWidgets('TextField accepts text input in edit mode (v1)', (tester) async {      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('api-cta-button')));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'gsk_test_input_123');
      await tester.pumpAndSettle();

      expect(find.text('gsk_test_input_123'), findsOneWidget);
    });

    testWidgets('save button stores the API key in FlutterSecureStorage (v1)',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('api-cta-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'gsk_my_secret_123');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'groq_api_key'), 'gsk_my_secret_123');
    });

    testWidgets('delete button clears the API key from FlutterSecureStorage (v1)',
        (tester) async {
      FlutterSecureStorage.setMockInitialValues(
          {'groq_api_key': 'gsk_key_to_delete'});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('api-loaded-button')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'groq_api_key'), isNull);
    });
  });

  group('SettingsScreen - Floating Bubble Toggle & Permissions', () {
    Finder bubbleSwitch() => find.descendant(
          of: find.ancestor(
            of: find.text('Activar burbuja'),
            matching: find.byType(SwitchListTile),
          ),
          matching: find.byType(Switch),
        );

    testWidgets('shows Floating Bubble switch tile (v2 general tab)', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();

      expect(find.text('BURBUJA FLOTANTE'), findsOneWidget);
      expect(find.text('Activar burbuja'), findsOneWidget);
      expect(bubbleSwitch(), findsOneWidget);
    });

    testWidgets('shows bubble history switch ON by default (hito B6)',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();

      final historySwitch = find.byKey(const ValueKey('bubble-history-switch'));
      expect(find.text('Historial en la burbuja'), findsOneWidget);
      expect(historySwitch, findsOneWidget);
      expect(
        tester.widget<Switch>(
          find.descendant(
            of: historySwitch,
            matching: find.byType(Switch),
          ),
        ).value,
        isTrue,
      );
    });

    testWidgets('toggling history switch persists the preference (hito B6)',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();

      final historySwitch = find.descendant(
        of: find.byKey(const ValueKey('bubble-history-switch')),
        matching: find.byType(Switch),
      );
      await tester.tap(historySwitch);
      await tester.pumpAndSettle();

      expect(await storageService.loadBubbleHistoryEnabled(), isFalse);
      expect(tester.widget<Switch>(historySwitch).value, isFalse);
    });

    testWidgets('toggling switch ON starts bubble when permission granted',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();

      final switchFinder = bubbleSwitch();
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      expect(bubbleLog.map((c) => c.method), contains('startBubble'));
      expect(await storageService.loadFloatingBubbleEnabled(), isTrue);
    });

    testWidgets('toggling switch ON shows permission dialog if not permitted',
        (tester) async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        bubbleLog.add(call);
        if (call.method == 'canDrawOverlays') return false;
        if (call.method == 'requestOverlayPermission') return true;
        return null;
      });

      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();

      await tester.tap(bubbleSwitch());
      await tester.pumpAndSettle();

      expect(find.text('Permiso de superposición'), findsWidgets);
      expect(find.text('Configurar'), findsOneWidget);

      await tester.tap(find.text('Configurar'));
      await tester.pumpAndSettle();

      expect(bubbleLog.map((c) => c.method),
          contains('requestOverlayPermission'));
    });

    testWidgets('toggling switch OFF stops bubble and updates storage',
        (tester) async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        bubbleLog.add(call);
        if (call.method == 'isBubbleRunning') return true;
        if (call.method == 'stopBubble') return true;
        return true;
      });
      await storageService.saveFloatingBubbleEnabled(true);

      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();

      final switchFinder = bubbleSwitch();
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(bubbleLog.map((c) => c.method), contains('stopBubble'));
      expect(await storageService.loadFloatingBubbleEnabled(), isFalse);
    });

    testWidgets('general muestra fila de permiso con chevron (v2)',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();

      expect(find.text('Permiso superposición'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('burbuja-overlay-permission-row')),
          findsOneWidget);
    });

    testWidgets('tocar la fila de permiso con permiso concedido avisa (v2)',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();

      await tester.tap(
          find.byKey(const ValueKey('burbuja-overlay-permission-row')));
      await tester.pumpAndSettle();

      expect(
          find.text('Permiso de superposición concedido'), findsOneWidget);
    });
  });

  group('SettingsScreen - Teclado VoiceBubble', () {
    testWidgets('renderiza seccion de teclado con estado y boton de ajustes',
        (tester) async {
      mockKeyboardChannel();
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(find.text('Teclado'), findsNWidgets(2));
      expect(find.text('Abrir ajustes del sistema'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsOneWidget);
    });

    testWidgets('muestra "No habilitado" cuando el teclado esta apagado',
        (tester) async {
      mockKeyboardChannel(enabled: false, selected: false);
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(find.text('No habilitado'), findsOneWidget);
    });

    testWidgets('muestra "Activo" cuando esta habilitado y seleccionado',
        (tester) async {
      mockKeyboardChannel(enabled: true, selected: true);
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(find.text('Activo'), findsOneWidget);
    });

    testWidgets('muestra estado intermedio habilitado sin seleccionar',
        (tester) async {
      mockKeyboardChannel(enabled: true, selected: false);
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(find.text('Habilitado, falta seleccionarlo'), findsOneWidget);
    });

    testWidgets('el boton abre los ajustes del sistema', (tester) async {
      mockKeyboardChannel();
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir ajustes del sistema'));
      await tester.pumpAndSettle();

      expect(keyboardLog.map((c) => c.method),
          contains('openKeyboardSettings'));
    });

    testWidgets('consulta el estado inicial del teclado al montar la pantalla',
        (tester) async {
      mockKeyboardChannel(enabled: true, selected: true);
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(keyboardLog.map((c) => c.method), contains('isKeyboardEnabled'));
      expect(
          keyboardLog.map((c) => c.method), contains('isKeyboardSelected'));
    });

    testWidgets('el boton refrescar vuelve a consultar el estado',
        (tester) async {
      mockKeyboardChannel(enabled: false);
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      final consultasIniciales = keyboardLog.length;
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(keyboardLog.length, greaterThan(consultasIniciales));
      expect(find.text('No habilitado'), findsOneWidget);
    });
  });

  group('SettingsScreen - Fila terminal del teclado', () {
    Finder terminalSwitch() => find.descendant(
          of: find.ancestor(
            of: find.text('Fila terminal'),
            matching: find.byType(SwitchListTile),
          ),
          matching: find.byType(Switch),
        );

    testWidgets('muestra el switch con estado por defecto visible',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(find.text('Fila terminal'), findsOneWidget);
      expect(find.textContaining('Desactívala si usás Termux'),
          findsOneWidget);
      expect(terminalSwitch(), findsOneWidget);
      expect(tester.widget<Switch>(terminalSwitch()).value, isTrue);
    });

    testWidgets('alternar el switch persiste la preferencia', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      await tester.tap(terminalSwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(terminalSwitch()).value, isFalse);
      expect(await storageService.loadKeyboardTerminalRowVisible(), isFalse);

      await tester.tap(terminalSwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(terminalSwitch()).value, isTrue);
      expect(await storageService.loadKeyboardTerminalRowVisible(), isTrue);
    });

    testWidgets('refleja el valor previamente guardado', (tester) async {
      SharedPreferences.setMockInitialValues({'kb_terminal_row_visible': false});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(terminalSwitch()).value, isFalse);
    });
  });

  group('SettingsScreen - Tecla de capa código', () {
    Finder codeKeySwitch() => find.descendant(
          of: find.ancestor(
            of: find.text('Tecla de capa código'),
            matching: find.byType(SwitchListTile),
          ),
          matching: find.byType(Switch),
        );

    testWidgets('muestra el switch con estado por defecto visible',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(find.text('Tecla de capa código'), findsOneWidget);
      expect(
          find.textContaining('liberar espacio en la barra inferior'),
          findsOneWidget);
      expect(codeKeySwitch(), findsOneWidget);
      expect(tester.widget<Switch>(codeKeySwitch()).value, isTrue);
    });

    testWidgets('alternar el switch persiste la preferencia', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      await tester.tap(codeKeySwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(codeKeySwitch()).value, isFalse);
      expect(await storageService.loadKeyboardCodeKeyVisible(), isFalse);

      await tester.tap(codeKeySwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(codeKeySwitch()).value, isTrue);
      expect(await storageService.loadKeyboardCodeKeyVisible(), isTrue);
    });

    testWidgets('refleja el valor previamente guardado', (tester) async {
      SharedPreferences.setMockInitialValues({'kb_code_key_visible': false});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(codeKeySwitch()).value, isFalse);
    });
  });

  group('SettingsScreen - Tecla de idioma', () {
    Finder languageKeySwitch() => find.descendant(
          of: find.ancestor(
            of: find.text('Tecla de idioma'),
            matching: find.byType(SwitchListTile),
          ),
          matching: find.byType(Switch),
        );

    testWidgets('muestra el switch con estado por defecto visible',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(find.text('Tecla de idioma'), findsOneWidget);
      expect(find.textContaining('dictás en un solo idioma'),
          findsOneWidget);
      expect(languageKeySwitch(), findsOneWidget);
      expect(tester.widget<Switch>(languageKeySwitch()).value, isTrue);
    });

    testWidgets('alternar el switch persiste la preferencia', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      await tester.tap(languageKeySwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(languageKeySwitch()).value, isFalse);
      expect(await storageService.loadKeyboardLanguageKeyVisible(), isFalse);

      await tester.tap(languageKeySwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(languageKeySwitch()).value, isTrue);
      expect(await storageService.loadKeyboardLanguageKeyVisible(), isTrue);
    });

    testWidgets('refleja el valor previamente guardado', (tester) async {
      SharedPreferences.setMockInitialValues({'kb_language_key_visible': false});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(languageKeySwitch()).value, isFalse);
    });
  });

  group('SettingsScreen - bóveda STT para el teclado (SPK-02)', () {
    testWidgets('guardar la API key escribe bóveda sin espejo plano',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('api-cta-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'gsk_espejo_123');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      // Contrato K3/SPK-02: la key va a la bóveda (la lee el IME vía
      // SecureStore); jamás a prefs planas.
      const secure =
          FlutterSecureStorage(aOptions: StorageService.espOptions);
      expect(await secure.read(key: 'groq_api_key'), 'gsk_espejo_123');
      expect(prefs.getString('kb_stt_api_key'), isNull);
      expect(prefs.getBool('kb_stt_key_configured'), isTrue);
      expect(prefs.getString('kb_stt_model'), CloudSttService.model);
      expect(prefs.getString('kb_stt_url'), CloudSttService.endpoint);
    });

    testWidgets('borrar la API key limpia bóveda y presencia', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'groq_api_key': 'gsk_a_borrar'});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await storageService.saveSttMirror(apiKey: 'gsk_a_borrar');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kb_stt_key_configured'), isTrue);

      await tester.tap(find.byKey(const ValueKey('api-loaded-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(prefs.getString('kb_stt_api_key'), isNull);
      expect(prefs.getBool('kb_stt_key_configured'), isFalse);
    });

    testWidgets('al abrir Ajustes con key existente se republica (backfill)',
        (tester) async {
      FlutterSecureStorage.setMockInitialValues({'groq_api_key': 'previa'});
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      // Backfill: presencia + no sensibles, sin espejo plano.
      expect(prefs.getString('kb_stt_api_key'), isNull);
      expect(prefs.getBool('kb_stt_key_configured'), isTrue);
    });
  });

  group('SettingsScreen - Tabs v2 Navigation & State', () {
    testWidgets('arranca en General por defecto y muestra los 5 tabs',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsTabBar), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-general')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-teclado')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-trackpad')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-snippets')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-credenciales')), findsOneWidget);

      expect(find.text('API Key de Groq'), findsOneWidget);
      expect(find.text('Toque'), findsOneWidget);
      expect(find.text('Mantener'), findsOneWidget);
    });

    testWidgets('navega a todos los tabs y actualiza el contenido visible',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      // General ya visible: burbuja integrada
      expect(find.text('BURBUJA FLOTANTE'), findsOneWidget);
      expect(find.text('Activar burbuja'), findsOneWidget);

      // Navegar a Teclado
      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();
      expect(find.text('Teclado'), findsNWidgets(2));
      expect(find.text('Altura del teclado'), findsOneWidget);

      // Navegar a Trackpad
      await tester.tap(find.byKey(const ValueKey('tab-trackpad')));
      await tester.pumpAndSettle();
      expect(find.text('Trackpad'), findsWidgets);
      expect(find.text('Superficie Táctil Split Wings'), findsOneWidget);

      // Navegar a Snippets
      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();
      expect(find.text('Snippets'), findsWidgets);
      expect(find.byKey(const ValueKey('snippets-add-button')), findsOneWidget);

      // Navegar a Claves
      await tester.tap(find.byKey(const ValueKey('tab-credenciales')));
      await tester.pumpAndSettle();
      expect(find.text('Claves'), findsWidgets);
      expect(
          find.byKey(const ValueKey('credenciales-add-nombre')), findsOneWidget);

      // Acerca vive como sheet desde General
      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('about-open-button')));
      await tester.pumpAndSettle();
      expect(find.text('VoiceBubble STT v1.0.0'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Regresar a General
      expect(find.text('API Key de Groq'), findsOneWidget);
    });

    testWidgets('General integra burbuja y acerca sin accesos (v2)',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('bubble-history-switch')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('about-open-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();
      expect(find.text('Teclado'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();
      expect(find.text('Activar burbuja'), findsOneWidget);
    });

    testWidgets('persiste el estado de los inputs al cambiar de pestaña y volver',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('api-cta-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'gsk_temporal_test');
      await tester.pumpAndSettle();
      expect(find.text('gsk_temporal_test'), findsOneWidget);

      // Cambiar a Teclado y luego a Snippets
      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      // Volver a Inicio
      await tester.tap(find.byKey(const ValueKey('tab-general')));
      await tester.pumpAndSettle();

      expect(find.text('gsk_temporal_test'), findsOneWidget);
    });

    testWidgets('SettingsTabBar respeta accesibilidad y Reduced Motion',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            accessibleNavigation: true,
          ),
          child: MaterialApp(
            home: SettingsScreen(
              storageService: storageService,
              floatingBubbleService: FloatingBubbleService(),
              keyboardService: KeyboardService(channel: keyboardChannel),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pump();

      expect(find.text('Teclado'), findsNWidgets(2));
    });
  });

}
