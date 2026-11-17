import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/floating_trackpad_service.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';

import '../helpers/settings_harness.dart';
import '../helpers/test_app.dart';
import '../helpers/l10n_app.dart';

/// Fase 2B: forma «Isla» y pantalla «Ajustar isla» (maqueta + controles al
/// píxel, aplicados EN VIVO). El arnés monta una vista de 1600 x 6400 px a
/// 2x: la isla por defecto mide 224 x 60 px, centro en 800 y borde en 6.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = SettingsHarness();

  setUp(() => h.setUp());
  tearDown(h.tearDown);

  /// Abre Ajustes › Barra flotante con el complemento en [status].
  Future<void> openBar(
    WidgetTester tester, {
    String status = FloatingTrackpadService.pointerReady,
    Map<String, Object> prefs = const {},
  }) async {
    h.setUp(prefs: prefs);
    h.pointerStatus = status;
    await h.pump(tester);
    await openPage(tester, 'burbuja');
  }

  /// Abre la pantalla Ajustar isla (con la forma Isla ya elegida).
  Future<void> openIsland(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    String status = FloatingTrackpadService.pointerReady,
  }) async {
    await openBar(tester,
        status: status, prefs: {'dock_form': 'island', ...prefs});
    await tapKey(tester, 'island-adjust-row');
  }

  String valueOf(WidgetTester tester, String id) =>
      tester.widget<Text>(byKey('$id-value')).data!;

  int pxOf(WidgetTester tester, String id) =>
      int.parse(valueOf(tester, id).replaceAll(' px', ''));

  int reloads() => h.bubbleMethods.where((m) => m == 'reloadDock').length;

  Rect pill(WidgetTester tester) => tester.getRect(byKey('island-mockup-pill'));
  Rect frame(WidgetTester tester) => tester.getRect(byKey('island-mockup'));

  group('Forma «Isla» en Barra flotante', () {
    testWidgets('con el complemento activo se puede elegir y avisa a la barra',
        (tester) async {
      await openBar(tester);
      expect(byKey('island-adjust-row'), findsNothing);
      expect(byKey('island-companion-section'), findsNothing);

      await pickOption(tester, 'dock-form-selector', 'island');

      expect(await h.storage.getDockForm(), 'island');
      expect(rowShows('dock-form-selector', 'Isla'), isTrue);
      expect(h.bubbleMethods, contains('reloadDock'));
      expect(byKey('island-adjust-row'), findsOneWidget);
    });

    for (final status in [
      FloatingTrackpadService.pointerMissing,
      FloatingTrackpadService.pointerDisabled,
    ]) {
      testWidgets(
          'con el complemento "$status" Isla está deshabilitada y se explica',
          (tester) async {
        await openBar(tester, status: status);

        expect(byKey('island-companion-section'), findsOneWidget);
        await tapKey(tester, 'dock-form-selector');
        final option =
            tester.widget<MenuItemButton>(byKey('dock-form-selector-island'));
        expect(option.onPressed, isNull);
        await tester.tap(byKey('dock-form-selector-island'));
        await tester.pumpAndSettle();

        expect(await h.storage.getDockForm(), 'edge');
        expect(h.bubbleMethods, isNot(contains('reloadDock')));
        expect(byKey('island-adjust-row'), findsNothing);
      });
    }

    testWidgets('sin instalar: el acceso explica cómo conseguir el complemento',
        (tester) async {
      await openBar(tester, status: FloatingTrackpadService.pointerMissing);
      expect(rowShows('pointer-companion-row', 'No instalado'), isTrue);

      await tapKey(tester, 'pointer-companion-row');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tapKey(tester, 'pointer-missing-ok');
      expect(h.trackpadMethods, isNot(contains('openAccessibilitySettings')));
    });

    testWidgets(
        'instalado y apagado: el mismo acceso que Trackpad lleva a Accesibilidad',
        (tester) async {
      await openBar(tester, status: FloatingTrackpadService.pointerDisabled);
      expect(rowShows('pointer-companion-row', 'Activar'), isTrue);

      await tapKey(tester, 'pointer-companion-row');
      expect(h.trackpadMethods, contains('openAccessibilitySettings'));
      await tapKey(tester, 'pointer-restricted-row');
      expect(h.trackpadMethods, contains('openCompanionDetails'));
    });

    testWidgets(
        'al volver de Accesibilidad con el complemento activo se habilita Isla',
        (tester) async {
      await openBar(tester, status: FloatingTrackpadService.pointerDisabled);
      expect(byKey('island-companion-section'), findsOneWidget);

      h.pointerStatus = FloatingTrackpadService.pointerReady;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(byKey('island-companion-section'), findsNothing);
      await pickOption(tester, 'dock-form-selector', 'island');
      expect(await h.storage.getDockForm(), 'island');
    });

    testWidgets('muestra la forma que dejó guardada y la fila para ajustarla',
        (tester) async {
      await openBar(tester, prefs: {'dock_form': 'island'});
      expect(rowShows('dock-form-selector', 'Isla'), isTrue);
      expect(byKey('island-adjust-row'), findsOneWidget);
    });

    testWidgets('con la burbuja o la barra no hay fila de ajuste',
        (tester) async {
      await openBar(tester, prefs: {'dock_form': 'bubble'});
      expect(byKey('island-adjust-row'), findsNothing);
    });

    testWidgets(
        'si la isla quedó elegida y el complemento se fue, igual se puede cambiar',
        (tester) async {
      await openBar(tester,
          status: FloatingTrackpadService.pointerMissing,
          prefs: {'dock_form': 'island'});
      expect(byKey('island-companion-section'), findsOneWidget);
      await pickOption(tester, 'dock-form-selector', 'edge');
      expect(await h.storage.getDockForm(), 'edge');
    });

    testWidgets('«Ajustar isla» abre la subpágina y Volver regresa a la barra',
        (tester) async {
      await openIsland(tester);
      expect(byKey('island-mockup'), findsOneWidget);
      expect(byKey('island-x-slider'), findsOneWidget);

      await goBack(tester);
      expect(byKey('dock-form-selector'), findsOneWidget);
      expect(byKey('island-mockup'), findsNothing);
    });
  });

  group('Ajustar isla: valores', () {
    testWidgets(
        'por defecto muestra los px reales de la isla (112 x 30 dp, centrada)',
        (tester) async {
      await openIsland(tester);

      expect(valueOf(tester, 'island-x'), '800 px');
      expect(valueOf(tester, 'island-y'), '6 px');
      expect(valueOf(tester, 'island-w'), '224 px');
      expect(valueOf(tester, 'island-h'), '60 px');
      expect(rowShows('island-side-selector', 'Izquierda'), isTrue);
      // Abrir la página no guarda nada ni toca la barra.
      expect(reloads(), 0);
    });

    testWidgets('muestra lo guardado', (tester) async {
      await openIsland(tester, prefs: {
        'dock_island_x': 300,
        'dock_island_y': 40,
        'dock_island_w': 300,
        'dock_island_h': 80,
        'dock_island_side': 'right',
      });

      expect(valueOf(tester, 'island-x'), '300 px');
      expect(valueOf(tester, 'island-y'), '40 px');
      expect(valueOf(tester, 'island-w'), '300 px');
      expect(valueOf(tester, 'island-h'), '80 px');
      expect(rowShows('island-side-selector', 'Derecha'), isTrue);
    });

    testWidgets('los rangos son los de la especificación, en px de la vista',
        (tester) async {
      await openIsland(tester);

      Slider slider(String id) => tester.widget<Slider>(byKey('$id-slider'));
      // X: de medio ancho (más su margen) a ancho - medio ancho.
      expect(slider('island-x').min, 8 + 112);
      expect(slider('island-x').max, 1600 - 224 - 8 + 112);
      // Y: de 0 a un tercio del alto.
      expect(slider('island-y').min, 0);
      expect(slider('island-y').max, 6400 ~/ 3);
      // Ancho 72–180 dp y alto 22–48 dp, a 2x.
      expect(slider('island-w').min, 144);
      expect(slider('island-w').max, 360);
      expect(slider('island-h').min, 44);
      expect(slider('island-h').max, 96);
      // Todos de un paso (1 px).
      for (final id in ['island-x', 'island-y', 'island-w', 'island-h']) {
        final s = slider(id);
        expect(s.divisions, (s.max - s.min).round(), reason: id);
      }
    });

    testWidgets('un valor fuera de rango guardado se muestra ya acotado',
        (tester) async {
      await openIsland(tester, prefs: {
        'dock_island_w': 5000,
        'dock_island_h': 3,
        'dock_island_x': 1,
      });
      expect(valueOf(tester, 'island-w'), '360 px');
      expect(valueOf(tester, 'island-h'), '44 px');
      expect(valueOf(tester, 'island-x'), '${8 + 180} px');
    });
  });

  group('Ajustar isla: en vivo', () {
    testWidgets('+ y − de 1 px guardan y piden recargar la barra',
        (tester) async {
      await openIsland(tester);

      await tapKey(tester, 'island-x-plus');
      expect(valueOf(tester, 'island-x'), '801 px');
      expect(await h.storage.getDockIslandX(), 801);
      expect(reloads(), 1);

      await tapKey(tester, 'island-x-minus');
      await tapKey(tester, 'island-x-minus');
      expect(valueOf(tester, 'island-x'), '799 px');
      expect(await h.storage.getDockIslandX(), 799);
      expect(reloads(), 3);

      await tapKey(tester, 'island-y-plus');
      expect(await h.storage.getDockIslandY(), 7);
      await tapKey(tester, 'island-w-plus');
      expect(await h.storage.getDockIslandW(), 225);
      await tapKey(tester, 'island-h-minus');
      expect(await h.storage.getDockIslandH(), 59);
      expect(reloads(), 6);
    });

    testWidgets('solo se guarda lo que se tocó: el resto sigue por defecto',
        (tester) async {
      await openIsland(tester);
      await tapKey(tester, 'island-w-plus');

      expect(await h.storage.getDockIslandW(), 225);
      expect(await h.storage.getDockIslandX(), -1);
      expect(await h.storage.getDockIslandY(), -1);
      expect(await h.storage.getDockIslandH(), -1);
    });

    testWidgets('el deslizador guarda el valor final al soltar',
        (tester) async {
      await openIsland(tester);

      await tester.drag(byKey('island-w-slider'), const Offset(60, 0));
      await tester.pumpAndSettle();

      final shown = pxOf(tester, 'island-w');
      expect(shown, greaterThan(224));
      expect(await h.storage.getDockIslandW(), shown);
      expect(reloads(), greaterThanOrEqualTo(1));
    });

    testWidgets('un arrastre largo no inunda al nativo y el último valor llega',
        (tester) async {
      await openIsland(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(byKey('island-x-slider')));
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(3, 0));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final shown = pxOf(tester, 'island-x');
      expect(shown, greaterThan(800));
      expect(await h.storage.getDockIslandX(), shown,
          reason: 'el valor final siempre se guarda');
      // 40 movimientos sin pasar el tiempo: salen la primera y la final.
      expect(reloads(), lessThanOrEqualTo(3));
      expect(reloads(), greaterThanOrEqualTo(1));
    });

    testWidgets('mantener apretado + repite y guarda el valor final al soltar',
        (tester) async {
      await openIsland(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(byKey('island-h-plus')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      final shown = pxOf(tester, 'island-h');
      expect(shown, greaterThan(64));
      expect(await h.storage.getDockIslandH(), shown);
    });

    testWidgets('en el tope el botón no pasa del límite', (tester) async {
      await openIsland(tester, prefs: {'dock_island_w': 360});

      await tapKey(tester, 'island-w-plus');

      expect(valueOf(tester, 'island-w'), '360 px');
      expect(await h.storage.getDockIslandW(), 360);
      expect(reloads(), 0);
    });

    testWidgets('lado del micrófono: guarda, recarga y la maqueta lo refleja',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openIsland(tester);
      expect(find.bySemanticsLabel(RegExp('Micrófono a la izquierda')),
          findsOneWidget);

      await pickOption(tester, 'island-side-selector', 'right');

      expect(await h.storage.getDockIslandSide(), 'right');
      expect(rowShows('island-side-selector', 'Derecha'), isTrue);
      expect(reloads(), 1);
      expect(find.bySemanticsLabel(RegExp('Micrófono a la derecha')),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets(
        '«Centrar arriba»: x al centro y y por defecto; ancho y alto quedan',
        (tester) async {
      await openIsland(tester, prefs: {
        'dock_island_x': 300,
        'dock_island_y': 120,
        'dock_island_w': 300,
        'dock_island_h': 80,
        'dock_island_side': 'right',
      });

      await tapKey(tester, 'island-center-button');

      expect(await h.storage.getDockIslandX(), -1);
      expect(await h.storage.getDockIslandY(), -1);
      expect(await h.storage.getDockIslandW(), 300);
      expect(await h.storage.getDockIslandH(), 80);
      expect(await h.storage.getDockIslandSide(), 'right');
      expect(valueOf(tester, 'island-x'), '800 px');
      expect(valueOf(tester, 'island-y'), '6 px');
      expect(reloads(), 1);
    });

    testWidgets('«Restablecer» vuelve todo a los valores por defecto',
        (tester) async {
      await openIsland(tester, prefs: {
        'dock_island_x': 300,
        'dock_island_y': 120,
        'dock_island_w': 300,
        'dock_island_h': 80,
        'dock_island_side': 'right',
      });

      await tapKey(tester, 'island-reset-button');

      expect(await h.storage.getDockIslandX(), -1);
      expect(await h.storage.getDockIslandY(), -1);
      expect(await h.storage.getDockIslandW(), -1);
      expect(await h.storage.getDockIslandH(), -1);
      expect(await h.storage.getDockIslandSide(), 'left');
      expect(valueOf(tester, 'island-w'), '224 px');
      expect(valueOf(tester, 'island-h'), '60 px');
      expect(rowShows('island-side-selector', 'Izquierda'), isTrue);
      expect(reloads(), 1);
    });

    testWidgets(
        'salir de la página a mitad de un gesto no pierde el último valor',
        (tester) async {
      await openIsland(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(byKey('island-y-slider')));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      final shown = pxOf(tester, 'island-y');
      await goBack(tester);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(await h.storage.getDockIslandY(), shown);
    });
  });

  group('Ajustar isla: maqueta', () {
    testWidgets('refleja los valores: posición y tamaño a escala real',
        (tester) async {
      await openIsland(tester, prefs: {
        'dock_island_x': 400,
        'dock_island_y': 100,
        'dock_island_w': 300,
        'dock_island_h': 80,
      });

      // Vista de 1600 px de ancho; maqueta de 280 dp.
      final scale = frame(tester).width / 1600;
      final p = pill(tester);
      expect(p.width, closeTo(300 * scale, 0.01));
      expect(p.height, closeTo(80 * scale, 0.01));
      expect(p.center.dx - frame(tester).left, closeTo(400 * scale, 0.01));
      expect(p.top - frame(tester).top, closeTo(100 * scale, 0.01));
    });

    testWidgets('se mueve con los botones: 1 px de x = 1 px a escala',
        (tester) async {
      await openIsland(tester);
      final before = pill(tester).center.dx;
      final scale = frame(tester).width / 1600;

      await tapKey(tester, 'island-x-plus');

      expect(pill(tester).center.dx - before, closeTo(scale, 0.0001));
    });

    testWidgets('crece con el ancho y el alto', (tester) async {
      await openIsland(tester);
      final before = pill(tester);

      await tapKey(tester, 'island-w-plus');
      await tapKey(tester, 'island-h-plus');

      expect(pill(tester).width, greaterThan(before.width));
      expect(pill(tester).height, greaterThan(before.height));
    });

    testWidgets('queda fija arriba mientras la lista de controles se desplaza',
        (tester) async {
      await openIsland(tester);
      final before = frame(tester);

      await tester.drag(byKey('island-x-slider'), const Offset(0, -300),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(frame(tester), before);
    });

    testWidgets('se dibuja sin errores en tema oscuro', (tester) async {
      h.setUp(prefs: {'dock_form': 'island'});
      h.pointerStatus = FloatingTrackpadService.pointerReady;
      configureTestViewSize(tester);
      await tester.pumpWidget(esMaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: SettingsScreen(
          storageService: h.storage,
          floatingBubbleService: FloatingBubbleService(),
          keyboardService:
              KeyboardService(channel: SettingsHarness.keyboardChannel),
        ),
      ));
      await tester.pumpAndSettle();
      await openPage(tester, 'burbuja');
      await tapKey(tester, 'island-adjust-row');
      expect(byKey('island-mockup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Ajustar isla: avisos y accesibilidad', () {
    testWidgets('sin la barra encendida avisa que no se verá', (tester) async {
      await openIsland(tester);
      // El arnés no tiene la burbuja corriendo.
      expect(find.textContaining('Encendé la barra flotante'), findsOneWidget);
    });

    testWidgets('sin el complemento avisa que se ve como burbuja',
        (tester) async {
      await openIsland(tester, status: FloatingTrackpadService.pointerMissing);
      expect(find.textContaining('VoiceBubble Puntero activo'), findsOneWidget);
    });

    testWidgets('cada control tiene etiqueta en español y 48 dp de target',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openIsland(tester);

      for (final label in [
        'Un píxel a la izquierda',
        'Un píxel a la derecha',
        'Un píxel hacia arriba',
        'Un píxel hacia abajo',
        'Un píxel más angosta',
        'Un píxel más ancha',
        'Un píxel más baja',
        'Un píxel más alta',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      for (final id in ['island-x', 'island-y', 'island-w', 'island-h']) {
        for (final k in ['minus', 'plus']) {
          final size = tester.getSize(byKey('$id-$k'));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        // El deslizador anuncia título y valor en píxeles.
        expect(sliderSpokenValue(tester, byKey('$id-slider')),
            contains('píxeles'));
      }
      handle.dispose();
    });
  });
}
