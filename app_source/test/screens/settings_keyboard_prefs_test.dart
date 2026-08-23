import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
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

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();

    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
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
    messenger.setMockMethodCallHandler(keyboardChannel,
        (MethodCall call) async {
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

  Widget buildTestableWidget(WidgetTester tester) {
    // Superficie alta (800x2400 logicos): la pagina de Settings crece con
    // las preferencias nuevas de altura/vibracion y el ListView lazy no
    // construye lo que queda fuera del viewport (9.1-17 / 9.1-21).
    tester.view.physicalSize = const Size(1600, 4800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    return MaterialApp(
      home: SettingsScreen(
        storageService: storageService,
        floatingBubbleService: FloatingBubbleService(),
        keyboardService: KeyboardService(channel: keyboardChannel),
      ),
    );
  }

  Finder heightSelector() =>
      find.byKey(const ValueKey('kb-height-profile-selector'));

  Set<String> selectedHeightProfile(WidgetTester tester) =>
      tester.widget<SegmentedButton<String>>(heightSelector()).selected;

  Finder hapticsSwitch() => find.descendant(
        of: find.ancestor(
          of: find.text('Vibración'),
          matching: find.byType(SwitchListTile),
        ),
        matching: find.byType(Switch),
      );

  group('SettingsScreen - Altura del teclado', () {
    testWidgets('muestra Media seleccionada por defecto', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Altura del teclado'), findsOneWidget);
      expect(find.text('Baja'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);
      expect(find.text('Alta'), findsOneWidget);
      expect(selectedHeightProfile(tester), {'media'});
    });

    testWidgets('cambiar a Alta persiste en SharedPreferences',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alta'));
      await tester.pumpAndSettle();

      expect(selectedHeightProfile(tester), {'alta'});
      // Persistencia verificada desde otra instancia del servicio.
      expect(await StorageService().getHeightProfile(), 'alta');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_height_profile'), 'alta');
    });

    testWidgets('valor corrupto en prefs cae a Media sin crash',
        (tester) async {
      SharedPreferences.setMockInitialValues({'kb_height_profile': 'xxx'});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(selectedHeightProfile(tester), {'media'});
      expect(await StorageService().getHeightProfile(), 'media');
    });
  });

  group('SettingsScreen - Vibración del teclado', () {
    testWidgets('muestra el switch encendido por defecto', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Vibración'), findsOneWidget);
      expect(hapticsSwitch(), findsOneWidget);
      expect(tester.widget<Switch>(hapticsSwitch()).value, isTrue);
    });

    testWidgets('apagar la vibración persiste en SharedPreferences',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(hapticsSwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(hapticsSwitch()).value, isFalse);
      // Persistencia verificada desde otra instancia del servicio.
      expect(await StorageService().getHapticsEnabled(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kb_haptics_enabled'), isFalse);
    });

    testWidgets('refleja el valor previamente guardado', (tester) async {
      SharedPreferences.setMockInitialValues({'kb_haptics_enabled': false});
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(hapticsSwitch()).value, isFalse);
    });
  });
}
