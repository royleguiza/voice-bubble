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
      return false;
    });
    messenger.setMockMethodCallHandler(keyboardChannel, (MethodCall call) async {
      return false;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(keyboardChannel, null);
  });

  Widget buildTestableWidget(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 6400);
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

  group('SettingsScreen - Trackpad y Puntero Virtual', () {
    testWidgets('muestra la sección Modo Trackpad en la pestaña Teclado',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      expect(find.text('Modo Trackpad y Puntero Virtual'), findsOneWidget);
      expect(find.text('Superficie Táctil Split Wings'), findsOneWidget);
      expect(find.text('Activar modo trackpad'), findsOneWidget);
    });

    testWidgets('cambiar selector de posición de scroll persiste en SharedPreferences',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      final scrollSelector = find.byKey(const ValueKey('kb-trackpad-scroll-position-selector'));
      expect(scrollSelector, findsOneWidget);

      // Tocar opción Izquierda
      await tester.tap(find.text('Izquierda'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_trackpad_scroll_position'), 'left');

      // Tocar opción Desactivada
      await tester.tap(find.text('Desactivada'));
      await tester.pumpAndSettle();

      expect(prefs.getString('kb_trackpad_scroll_position'), 'disabled');
    });

    testWidgets('cambiar selector de estilo de puntero persiste en SharedPreferences',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-teclado')));
      await tester.pumpAndSettle();

      final pointerSelector = find.byKey(const ValueKey('kb-trackpad-pointer-style-selector'));
      expect(pointerSelector, findsOneWidget);

      await tester.tap(find.text('Punto'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kb_trackpad_pointer_style'), 'dot');

      await tester.tap(find.text('Cruz'));
      await tester.pumpAndSettle();

      expect(prefs.getString('kb_trackpad_pointer_style'), 'cross');
    });
  });
}
