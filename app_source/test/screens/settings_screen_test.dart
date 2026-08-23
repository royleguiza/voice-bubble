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
    // Superficie alta (800x2000 logicos) para que toda la pagina de Settings
    // sea visible sin scroll: la tarjeta del teclado alargo la lista.
    tester.view.physicalSize = const Size(1600, 4000);
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
    testWidgets('renders AppBar with "Configuración" title', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Configuración'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
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

    testWidgets('shows TextField for API key input', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('gsk_...'), findsOneWidget);
    });

    testWidgets('shows save button with Icons.save', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('shows delete button when API key exists', (tester) async {
      FlutterSecureStorage.setMockInitialValues(
          {'groq_api_key': 'existing_key'});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('does not show delete button when no API key', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('shows "Acerca de" section', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Acerca de'), findsOneWidget);
    });

    testWidgets('shows version "VoiceBubble STT v0.1.0"', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('VoiceBubble STT v0.1.0'), findsOneWidget);
    });

    testWidgets('shows app description text', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.text('Transcripción de voz a texto con Groq Whisper.'),
        findsOneWidget,
      );
    });

    testWidgets('TextField accepts text input', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'test_api_key_123');
      await tester.pumpAndSettle();

      expect(find.text('test_api_key_123'), findsOneWidget);
    });

    testWidgets('save button stores the API key in FlutterSecureStorage',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'my_secret_key');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'groq_api_key'), 'my_secret_key');
    });

    testWidgets('delete button clears the API key from FlutterSecureStorage',
        (tester) async {
      FlutterSecureStorage.setMockInitialValues(
          {'groq_api_key': 'key_to_delete'});
      await tester.pumpWidget(buildTestableWidget(tester));
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
            of: find.text('Activar burbuja flotante'),
            matching: find.byType(SwitchListTile),
          ),
          matching: find.byType(Switch),
        );

    testWidgets('shows Floating Bubble switch tile', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Burbuja flotante'), findsOneWidget);
      expect(find.text('Activar burbuja flotante'), findsOneWidget);
      expect(bubbleSwitch(), findsOneWidget);
    });

    testWidgets('toggling switch ON starts bubble when permission granted',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
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

      await tester.tap(bubbleSwitch());
      await tester.pumpAndSettle();

      expect(find.text('Permiso de superposición'), findsOneWidget);
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

      final switchFinder = bubbleSwitch();
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(bubbleLog.map((c) => c.method), contains('stopBubble'));
      expect(await storageService.loadFloatingBubbleEnabled(), isFalse);
    });
  });

  group('SettingsScreen - Teclado VoiceBubble', () {
    testWidgets('renderiza seccion de teclado con estado y boton de ajustes',
        (tester) async {
      mockKeyboardChannel();
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Teclado VoiceBubble'), findsOneWidget);
      expect(find.text('Abrir ajustes del sistema'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsOneWidget);
    });

    testWidgets('muestra "No habilitado" cuando el teclado esta apagado',
        (tester) async {
      mockKeyboardChannel(enabled: false, selected: false);
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('No habilitado'), findsOneWidget);
    });

    testWidgets('muestra "Activo" cuando esta habilitado y seleccionado',
        (tester) async {
      mockKeyboardChannel(enabled: true, selected: true);
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Activo'), findsOneWidget);
    });

    testWidgets('muestra estado intermedio habilitado sin seleccionar',
        (tester) async {
      mockKeyboardChannel(enabled: true, selected: false);
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Habilitado, falta seleccionarlo'), findsOneWidget);
    });

    testWidgets('el boton abre los ajustes del sistema', (tester) async {
      mockKeyboardChannel();
      await tester.pumpWidget(buildTestableWidget(tester));
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

      expect(find.text('Fila terminal'), findsOneWidget);
      expect(find.textContaining('Desactívala si usás Termux'),
          findsOneWidget);
      expect(terminalSwitch(), findsOneWidget);
      expect(tester.widget<Switch>(terminalSwitch()).value, isTrue);
    });

    testWidgets('alternar el switch persiste la preferencia', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
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

      expect(tester.widget<Switch>(terminalSwitch()).value, isFalse);
    });
  });

  group('SettingsScreen - Espejo D7 de credenciales para el teclado', () {
    testWidgets('guardar la API key escribe el espejo con valores canonicos',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'gsk_espejo_123');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(await storageService.loadSttMirroredApiKey(), 'gsk_espejo_123');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_stt_provider'), 'groq');
      expect(prefs.getString('kb_stt_model'), CloudSttService.model);
      expect(prefs.getString('kb_stt_url'), CloudSttService.endpoint);
    });

    testWidgets('borrar la API key limpia el espejo', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'groq_api_key': 'a_borrar'});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await storageService.saveSttMirror(apiKey: 'a_borrar');
      expect(await storageService.loadSttMirroredApiKey(), 'a_borrar');

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(await storageService.loadSttMirroredApiKey(), isNull);
    });

    testWidgets('al abrir Ajustes con key existente se re-espeja (backfill)',
        (tester) async {
      FlutterSecureStorage.setMockInitialValues({'groq_api_key': 'previa'});
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(await storageService.loadSttMirroredApiKey(), 'previa');
    });
  });
}
