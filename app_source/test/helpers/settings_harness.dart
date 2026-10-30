import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

import 'test_app.dart';

/// Arnés de Ajustes 2026: canales nativos simulados, montaje de la pantalla
/// y atajos para navegar (filas `nav-*`), elegir opciones de menú
/// (`<id>-<valor>`) y leer interruptores. Todo por Key, nunca por copy.
class SettingsHarness {
  static const bubbleChannel = MethodChannel(FloatingBubbleService.channelName);
  static const keyboardChannel = MethodChannel(KeyboardService.channelName);

  final List<MethodCall> bubbleLog = <MethodCall>[];
  final List<MethodCall> keyboardLog = <MethodCall>[];

  bool keyboardEnabled = false;
  bool keyboardSelected = false;
  bool canDrawOverlays = true;
  bool bubbleStarts = true;

  StorageService storage = StorageService();

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Estado inicial reproducible: bóveda y prefs (claves sin `flutter.`).
  void setUp({
    Map<String, String> secure = const {},
    Map<String, Object> prefs = const {},
  }) {
    FlutterSecureStorage.setMockInitialValues(Map.of(secure));
    SharedPreferences.setMockInitialValues(Map.of(prefs));
    storage = StorageService();
    keyboardEnabled = false;
    keyboardSelected = false;
    canDrawOverlays = true;
    bubbleStarts = true;
    bubbleLog.clear();
    keyboardLog.clear();
    _messenger.setMockMethodCallHandler(bubbleChannel, (call) async {
      bubbleLog.add(call);
      switch (call.method) {
        case 'canDrawOverlays':
          return canDrawOverlays;
        case 'startBubble':
          return bubbleStarts;
        case 'isBubbleRunning':
          return false;
        default:
          return true;
      }
    });
    _messenger.setMockMethodCallHandler(keyboardChannel, (call) async {
      keyboardLog.add(call);
      switch (call.method) {
        case 'isKeyboardEnabled':
          return keyboardEnabled;
        case 'isKeyboardSelected':
          return keyboardSelected;
        default:
          return true;
      }
    });
  }

  void tearDown() {
    _messenger.setMockMethodCallHandler(bubbleChannel, null);
    _messenger.setMockMethodCallHandler(keyboardChannel, null);
  }

  /// Monta Ajustes con el helper común (superficie alta 800x3200 lógicos
  /// para que las páginas largas queden construidas sin scroll).
  Future<void> pump(WidgetTester tester, {StorageService? storageService}) async {
    await tester.pumpWidget(buildTestableSettingsScreen(
      tester,
      storageService: storageService ?? storage,
      bubbleService: FloatingBubbleService(),
      keyboardService: KeyboardService(channel: keyboardChannel),
    ));
    await tester.pumpAndSettle();
  }
}

Finder byKey(String key) => find.byKey(ValueKey(key));

/// Toca el widget con esa Key (lo trae a la vista si hace falta).
Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Entra a una página desde la raíz (`nav-<page>`).
Future<void> openPage(WidgetTester tester, String page) =>
    tapKey(tester, 'nav-$page');

/// Vuelve un nivel con el botón de la barra.
Future<void> goBack(WidgetTester tester) =>
    tapKey(tester, 'settings-back-button');

/// Abre el menú `id` y elige la opción `value`.
Future<void> pickOption(WidgetTester tester, String id, Object value) async {
  await tapKey(tester, id);
  await tester.tap(byKey('$id-$value'));
  await tester.pumpAndSettle();
}

/// Texto mostrado como valor actual de un menú o fila.
bool rowShows(String key, String text) => find
    .descendant(of: byKey(key), matching: find.text(text))
    .evaluate()
    .isNotEmpty;

/// Valor del interruptor de la fila `key`.
bool switchValue(WidgetTester tester, String key) => tester
    .widget<CupertinoSwitch>(
      find.descendant(of: byKey(key), matching: find.byType(CupertinoSwitch)),
    )
    .value;

Future<SharedPreferences> prefs() => SharedPreferences.getInstance();
