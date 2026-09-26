import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

/// Configura la superficie de test para permitir ver vistas largas sin cortes de viewport
/// (lecciones 9.1-17 / 9.1-21).
void configureTestViewSize(
  WidgetTester tester, {
  Size physicalSize = const Size(1600, 6400),
  double devicePixelRatio = 2.0,
}) {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
}

/// Envuelve un widget para pruebas con MaterialApp y opcionalmente configura la superficie.
Widget buildTestApp({
  Widget? home,
  ThemeData? theme,
  WidgetTester? tester,
  Size physicalSize = const Size(1600, 6400),
}) {
  if (tester != null) {
    configureTestViewSize(tester, physicalSize: physicalSize);
  }
  return MaterialApp(
    theme: theme,
    home: home,
  );
}

/// Envuelve SettingsScreen con servicios inyectados y superficie alta para pruebas.
Widget buildTestableSettingsScreen(
  WidgetTester tester, {
  StorageService? storageService,
  FloatingBubbleService? bubbleService,
  KeyboardService? keyboardService,
  Size physicalSize = const Size(1600, 6400),
}) {
  configureTestViewSize(tester, physicalSize: physicalSize);
  return MaterialApp(
    home: SettingsScreen(
      storageService: storageService ?? StorageService(),
      floatingBubbleService: bubbleService ?? FloatingBubbleService(),
      keyboardService: keyboardService ?? KeyboardService(),
    ),
  );
}
