import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(FloatingBubbleService.channelName);

  late StorageService storageService;
  late List<MethodCall> bubbleLog;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();
    bubbleLog = <MethodCall>[];

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
  });

  Widget buildTestableWidget({
    FloatingBubbleService? bubbleService,
  }) {
    return MaterialApp(
      home: SettingsScreen(
        storageService: storageService,
        floatingBubbleService: bubbleService ?? FloatingBubbleService(),
      ),
    );
  }

  group('SettingsScreen - API Key & General', () {
    testWidgets('renders AppBar with "Configuración" title', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Configuración'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows "API Key de Groq" section header', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('API Key de Groq'), findsOneWidget);
    });

    testWidgets('shows description text about Groq', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Necesaria para el modo Cloud. Obtén tu clave en console.groq.com'),
        findsOneWidget,
      );
    });

    testWidgets('shows TextField for API key input', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('gsk_...'), findsOneWidget);
    });

    testWidgets('shows save button with Icons.save', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('shows delete button when API key exists', (tester) async {
      FlutterSecureStorage.setMockInitialValues(
          {'groq_api_key': 'existing_key'});
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('does not show delete button when no API key', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('shows "Acerca de" section', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Acerca de'), findsOneWidget);
    });

    testWidgets('shows version "VoiceBubble STT v0.1.0"', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('VoiceBubble STT v0.1.0'), findsOneWidget);
    });

    testWidgets('shows app description text', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.text('Transcripción de voz a texto con Groq Whisper.'),
        findsOneWidget,
      );
    });

    testWidgets('TextField accepts text input', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'test_api_key_123');
      await tester.pumpAndSettle();

      expect(find.text('test_api_key_123'), findsOneWidget);
    });

    testWidgets('save button stores the API key in FlutterSecureStorage',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
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
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'groq_api_key'), isNull);
    });
  });

  group('SettingsScreen - Floating Bubble Toggle & Permissions', () {
    testWidgets('shows Floating Bubble switch tile', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Burbuja flotante'), findsOneWidget);
      expect(find.text('Activar burbuja flotante'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('toggling switch ON starts bubble when permission granted',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
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

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
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

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(bubbleLog.map((c) => c.method), contains('stopBubble'));
      expect(await storageService.loadFloatingBubbleEnabled(), isFalse);
    });
  });
}
