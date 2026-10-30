import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/services/floating_trackpad_service.dart';

import '../helpers/settings_harness.dart';

/// Barra flotante (prototipo "Burbuja de puntero", 2026-10-30): forma,
/// herramientas y el complemento VoiceBubble Puntero en Ajustes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = SettingsHarness();

  setUp(() => h.setUp());
  tearDown(h.tearDown);

  Future<void> openBar(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
    h.setUp(prefs: prefs);
    await h.pump(tester);
    await openPage(tester, 'burbuja');
  }

  group('Barra flotante', () {
    testWidgets('por defecto: barra en el borde, solo micrófono',
        (tester) async {
      await openBar(tester);

      expect(rowShows('dock-form-selector', 'Barra en el borde'), isTrue);
      expect(switchValue(tester, 'dock-tool-mic-switch'), isTrue);
      expect(switchValue(tester, 'dock-tool-pointer-switch'), isFalse);
    });

    testWidgets('elegir Burbuja persiste y avisa a la barra viva',
        (tester) async {
      await openBar(tester);

      await pickOption(tester, 'dock-form-selector', 'bubble');

      expect(await h.storage.getDockForm(), 'bubble');
      expect(rowShows('dock-form-selector', 'Burbuja'), isTrue);
      expect(h.bubbleMethods, contains('reloadDock'));
    });

    testWidgets('muestra la forma que dejó el usuario con el dedo',
        (tester) async {
      await openBar(tester, prefs: {'dock_form': 'bubble'});
      expect(rowShows('dock-form-selector', 'Burbuja'), isTrue);
    });

    testWidgets('una forma inválida guardada cae a la barra', (tester) async {
      await openBar(tester, prefs: {'dock_form': 'cometa'});
      expect(rowShows('dock-form-selector', 'Barra en el borde'), isTrue);
    });

    testWidgets('sumar el puntero persiste, recarga y avisa si falta el complemento',
        (tester) async {
      await openBar(tester);

      await tapKey(tester, 'dock-tool-pointer-switch');

      expect(switchValue(tester, 'dock-tool-pointer-switch'), isTrue);
      expect(await h.storage.getDockToolPointer(), isTrue);
      expect(h.bubbleMethods, contains('reloadDock'));
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('con el complemento activo no hay aviso al sumar el puntero',
        (tester) async {
      h.setUp();
      h.pointerStatus = FloatingTrackpadService.pointerReady;
      await h.pump(tester);
      await openPage(tester, 'burbuja');

      await tapKey(tester, 'dock-tool-pointer-switch');

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('no se puede apagar la única herramienta', (tester) async {
      await openBar(tester);

      await tapKey(tester, 'dock-tool-mic-switch');

      expect(switchValue(tester, 'dock-tool-mic-switch'), isTrue);
      expect(await h.storage.getDockToolMic(), isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(h.bubbleMethods, isNot(contains('reloadDock')));
    });

    testWidgets('con el puntero encendido el micrófono se puede apagar',
        (tester) async {
      await openBar(tester, prefs: {'dock_tool_pointer': true});

      await tapKey(tester, 'dock-tool-mic-switch');

      expect(switchValue(tester, 'dock-tool-mic-switch'), isFalse);
      expect(await h.storage.getDockToolMic(), isFalse);
    });

    testWidgets('el historial sigue en la página de la barra', (tester) async {
      await openBar(tester);
      await tapKey(tester, 'bubble-history-switch');
      expect(await h.storage.loadBubbleHistoryEnabled(), isFalse);
    });
  });

  group('Trackpad: complemento VoiceBubble Puntero', () {
    Future<void> openTrackpad(WidgetTester tester, String status,
        {Map<String, Object> prefs = const {}}) async {
      h.setUp(prefs: prefs);
      h.pointerStatus = status;
      await h.pump(tester);
      await openPage(tester, 'trackpad');
    }

    testWidgets('sin instalar: lo dice y explica cómo conseguirlo',
        (tester) async {
      await openTrackpad(tester, FloatingTrackpadService.pointerMissing);

      expect(rowShows('pointer-companion-row', 'No instalado'), isTrue);
      expect(byKey('pointer-restricted-row'), findsNothing);

      await tapKey(tester, 'pointer-companion-row');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tapKey(tester, 'pointer-missing-ok');
      expect(find.byType(AlertDialog), findsNothing);
      expect(h.trackpadMethods, isNot(contains('openAccessibilitySettings')));
    });

    testWidgets('instalado y apagado: lleva a Accesibilidad y a ajustes restringidos',
        (tester) async {
      await openTrackpad(tester, FloatingTrackpadService.pointerDisabled);

      expect(rowShows('pointer-companion-row', 'Activar'), isTrue);

      await tapKey(tester, 'pointer-companion-row');
      expect(h.trackpadMethods, contains('openAccessibilitySettings'));

      await tapKey(tester, 'pointer-restricted-row');
      expect(h.trackpadMethods, contains('openCompanionDetails'));
    });

    testWidgets('activo: lo muestra sin pasos extra', (tester) async {
      await openTrackpad(tester, FloatingTrackpadService.pointerReady);

      expect(rowShows('pointer-companion-row', 'Activo'), isTrue);
      expect(byKey('pointer-restricted-row'), findsNothing);
    });

    testWidgets('al volver a la app se relee el estado del complemento',
        (tester) async {
      await openTrackpad(tester, FloatingTrackpadService.pointerDisabled);
      expect(rowShows('pointer-companion-row', 'Activar'), isTrue);

      h.pointerStatus = FloatingTrackpadService.pointerReady;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(rowShows('pointer-companion-row', 'Activo'), isTrue);
    });

    testWidgets('"Se abre como" persiste', (tester) async {
      await openTrackpad(tester, FloatingTrackpadService.pointerReady);

      expect(rowShows('pointer-open-mode-selector', 'Panel abajo'), isTrue);
      await pickOption(tester, 'pointer-open-mode-selector', 'window');

      expect(await h.storage.getPointerOpenMode(), 'window');
      expect(rowShows('pointer-open-mode-selector', 'Ventana flotante'), isTrue);
    });

    testWidgets('"Al soltar" se ve aunque el trackpad del teclado esté apagado',
        (tester) async {
      await openTrackpad(tester, FloatingTrackpadService.pointerReady);

      await pickOption(tester, 'kb-trackpad-auto-return-selector', 5);
      expect(await h.storage.getTrackpadAutoReturn(), 5);
    });

    testWidgets('con el puntero en la barra aparece el ajuste fino',
        (tester) async {
      await openTrackpad(tester, FloatingTrackpadService.pointerReady,
          prefs: {'dock_tool_pointer': true});

      expect(switchValue(tester, 'kb-trackpad-enabled-switch'), isFalse);
      expect(byKey('kb-trackpad-sensitivity-slider'), findsOneWidget);
      expect(byKey('kb-trackpad-pointer-style-selector'), findsOneWidget);
    });

    testWidgets('el trackpad del teclado ya no abre ventanas flotantes',
        (tester) async {
      await openTrackpad(tester, FloatingTrackpadService.pointerReady);

      await tapKey(tester, 'kb-trackpad-enabled-switch');

      expect(await h.storage.getTrackpadEnabled(), isTrue);
      expect(h.trackpadMethods, isNot(contains('startTrackpadBubble')));
    });

    testWidgets('la raíz muestra el trackpad activado si el puntero está en la barra',
        (tester) async {
      h.setUp(prefs: {'dock_tool_pointer': true});
      await h.pump(tester);
      expect(rowShows('nav-trackpad', 'Activado'), isTrue);
    });
  });
}
