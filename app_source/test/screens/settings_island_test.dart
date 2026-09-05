import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const bubbleChannel = MethodChannel(FloatingBubbleService.channelName);
  const keyboardChannel = MethodChannel(KeyboardService.channelName);

  late StorageService storage;

  setUp(() {
    messenger.setMockMethodCallHandler(bubbleChannel, (MethodCall call) async {
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
          return true;
        default:
          return null;
      }
    });

    messenger.setMockMethodCallHandler(keyboardChannel, (MethodCall call) async {
      switch (call.method) {
        case 'isKeyboardEnabled':
          return false;
        case 'isKeyboardSelected':
          return false;
        default:
          return null;
      }
    });

    SharedPreferences.setMockInitialValues({
      'floating_bubble_enabled': true,
      'bubble_docking_mode': 'dynamic_island',
      'island_pos_x': 0,
      'island_pos_y': 12,
      'island_width': 184,
      'island_height': 36,
      'island_slot_order': 'trackpad_camera_mic',
      'island_theme': 'glass',
      'island_waveform_enabled': true,
    });
    storage = StorageService();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(bubbleChannel, null);
    messenger.setMockMethodCallHandler(keyboardChannel, null);
  });

  Widget createTestWidget(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 6400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    return MaterialApp(
      home: SettingsScreen(
        storageService: storage,
        floatingBubbleService: FloatingBubbleService(),
        keyboardService: KeyboardService(channel: keyboardChannel),
      ),
    );
  }

  group('SettingsScreen - Sección Píldora e Isla Dinámica', () {
    testWidgets('Renderiza título de sección y tarjeta de pastilla flotante', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Píldora e Isla Dinámica'), findsOneWidget);
      expect(find.text('Pastilla Flotante Inteligente'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('island-coords-badge')),
          matching: find.text('X: 0px | Y: 12px'),
        ),
        findsOneWidget,
      );
      expect(find.text('Activar burbuja flotante'), findsOneWidget);
    });

    testWidgets('Muestra opciones de hardware y calibración en modo dynamic_island', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Presets de Hardware (Cámara y Notch)'), findsOneWidget);
      expect(find.text('Cámara Central'), findsOneWidget);
      expect(find.text('Perforada Izquierda'), findsOneWidget);
      expect(find.text('Notch Superior'), findsOneWidget);
      expect(find.text('Restablecer'), findsOneWidget);

      expect(find.text('Calibración Píxel por Píxel'), findsOneWidget);
      expect(find.byKey(const ValueKey('island-slider-x')), findsOneWidget);
      expect(find.byKey(const ValueKey('island-slider-y')), findsOneWidget);
      expect(find.byKey(const ValueKey('island-slider-w')), findsOneWidget);
      expect(find.byKey(const ValueKey('island-slider-h')), findsOneWidget);
    });

    testWidgets('Preset Perforada Izquierda actualiza coordenadas a X: -108, Y: 12', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perforada Izquierda'));
      await tester.pumpAndSettle();

      expect(await storage.getIslandPosX(), -108);
      expect(await storage.getIslandPosY(), 12);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('island-coords-badge')),
          matching: find.text('X: -108px | Y: 12px'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Steppers de Eje X incrementan y decrementan la posición', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // Tap +5 px stepper
      await tester.tap(find.text('+5 px').first);
      await tester.pumpAndSettle();
      expect(await storage.getIslandPosX(), 5);

      // Tap -1 px stepper
      await tester.tap(find.text('-1 px').first);
      await tester.pumpAndSettle();
      expect(await storage.getIslandPosX(), 4);
    });

    testWidgets('Inversión de ranuras de acceso rápido', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('Izquierda: Trackpad | Centro: Cámara | Derecha: Mic'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('island-swap-slots-btn')));
      await tester.pumpAndSettle();

      expect(await storage.getIslandSlotOrder(), 'mic_camera_trackpad');
      expect(find.text('Izquierda: Mic | Centro: Cámara | Derecha: Trackpad'), findsOneWidget);
    });

    testWidgets('Cambio de tema visual y onda reactiva', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // Cambiar a Oscuro
      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();
      expect(await storage.getIslandTheme(), 'dark');

      // Cambiar a Claro
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(await storage.getIslandTheme(), 'light');

      // Alternar onda de voz
      await tester.tap(find.byKey(const ValueKey('island-waveform-switch')));
      await tester.pumpAndSettle();
      expect(await storage.getIslandWaveformEnabled(), false);
    });
  });
}
