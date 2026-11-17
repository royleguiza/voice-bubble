import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/helpers/island_geometry.dart';
import 'package:voice_bubble_stt/ui/design_tokens.dart';
import 'package:voice_bubble_stt/widgets/island_mockup.dart';
import '../helpers/l10n_app.dart';
import 'package:voice_bubble_stt/l10n/app_localizations_es.dart';

/// Maqueta de Ajustes › Ajustar isla: escala fiel a los píxeles reales.
void main() {
  // Pantalla de 1080 x 2400 px a 3x; la maqueta mide 280 dp de ancho.
  const screen = Size(1080, 2400);
  const density = 3.0;
  const geo = IslandGeometry(screen: screen, density: density);
  const scale = kIslandMockupMaxWidth / 1080;

  Widget app(
    Widget child, {
    Brightness brightness = Brightness.light,
    bool highContrast = false,
  }) =>
      esMaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(highContrast: highContrast),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  IslandMockup mockup({
    int x = -1,
    int y = -1,
    int w = -1,
    int h = -1,
    bool micOnLeft = true,
  }) =>
      IslandMockup(
        screenPx: screen,
        density: density,
        x: x,
        y: y,
        w: w,
        h: h,
        micOnLeft: micOnLeft,
      );

  Rect frameRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('island-mockup')));
  Rect pillRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('island-mockup-pill')));

  group('IslandMockup - escala', () {
    testWidgets('el marco guarda la proporción de la pantalla real',
        (tester) async {
      await tester.pumpWidget(app(mockup()));
      final frame = frameRect(tester);
      expect(frame.width, kIslandMockupMaxWidth);
      // Muestra la parte de arriba (la fracción fija) de la pantalla.
      expect(frame.height,
          closeTo(2400 * kIslandMockupVisibleFraction * scale, 0.01));
    });

    testWidgets('por defecto: 112 x 30 dp centrada y a 3 dp de arriba',
        (tester) async {
      await tester.pumpWidget(app(mockup()));
      final pill = pillRect(tester);
      expect(pill.width, closeTo(336 * scale, 0.01));
      expect(pill.height, closeTo(90 * scale, 0.01));
      // Centrada en el marco (el borde se pinta encima, sin restar ancho).
      expect(pill.center.dx, closeTo(frameRect(tester).center.dx, 0.01));
      expect(pill.top - frameRect(tester).top, closeTo(9 * scale, 0.01));
    });

    testWidgets('posición y tamaño en px reales se escalan con un solo factor',
        (tester) async {
      await tester.pumpWidget(app(mockup(x: 300, y: 120, w: 400, h: 100)));
      final frame = frameRect(tester);
      final pill = pillRect(tester);
      expect(pill.width, closeTo(400 * scale, 0.01));
      expect(pill.height, closeTo(100 * scale, 0.01));
      // x = centro, y = borde superior.
      expect(pill.center.dx - frame.left, closeTo(300 * scale, 0.01));
      expect(pill.top - frame.top, closeTo(120 * scale, 0.01));
    });

    testWidgets('cada píxel de x mueve la píldora exactamente `escala`',
        (tester) async {
      await tester.pumpWidget(app(mockup(x: 400)));
      final a = pillRect(tester).center.dx;
      await tester.pumpWidget(app(mockup(x: 401)));
      final b = pillRect(tester).center.dx;
      expect(b - a, closeTo(scale, 0.0001));
    });

    testWidgets('se recorta a la pantalla igual que el complemento',
        (tester) async {
      await tester.pumpWidget(app(mockup(x: 0, w: 9000, h: 9000)));
      final expected = geo.pill(x: 0, y: -1, w: 9000, h: 9000);
      final pill = pillRect(tester);
      expect(pill.width, closeTo(expected.width * scale, 0.01));
      expect(pill.height, closeTo(expected.height * scale, 0.01));
      expect(pill.left - frameRect(tester).left,
          closeTo(expected.left * scale, 0.01));
    });

    testWidgets('en un ancho menor la maqueta se achica y sigue a escala',
        (tester) async {
      await tester.pumpWidget(app(SizedBox(width: 200, child: mockup(x: 300))));
      final frame = frameRect(tester);
      expect(frame.width, 200);
      final s = 200 / 1080;
      expect(pillRect(tester).width, closeTo(336 * s, 0.01));
    });
  });

  group('IslandMockup - contenido y tema', () {
    testWidgets('no usa desenfoque ni filtros', (tester) async {
      await tester.pumpWidget(app(mockup()));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    for (final brightness in Brightness.values) {
      testWidgets('se dibuja en tema ${brightness.name} (la isla es negra)',
          (tester) async {
        await tester.pumpWidget(app(mockup(), brightness: brightness));
        expect(
            find.byKey(const ValueKey('island-mockup-pill')), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(kIslandBg, const Color(0xFF000000));
      });
    }

    testWidgets('con alto contraste también se dibuja', (tester) async {
      await tester.pumpWidget(app(mockup(), highContrast: true));
      expect(tester.takeException(), isNull);
    });

    testWidgets('repinta con el lado del micrófono', (tester) async {
      await tester.pumpWidget(app(mockup(micOnLeft: true)));
      await tester.pumpWidget(app(mockup(micOnLeft: false)));
      expect(tester.takeException(), isNull);
    });
  });

  group('IslandMockup - accesibilidad', () {
    testWidgets('anuncia la posición, el tamaño y el lado en español',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(mockup(x: 600, y: 24, w: 340, h: 90)));
      expect(
        find.bySemanticsLabel(RegExp(
            r'Maqueta de la isla: centro a 600 píxeles del borde izquierdo, '
            r'borde superior a 24 píxeles, 340 de ancho por 90 de alto\. '
            r'Micrófono a la izquierda\.')),
        findsOneWidget,
      );
      await tester.pumpWidget(app(mockup(x: 600, micOnLeft: false)));
      expect(find.bySemanticsLabel(RegExp('Micrófono a la derecha')),
          findsOneWidget);
      handle.dispose();
    });

    test('describe la isla con los píxeles reales ya acotados', () {
      final pill = geo.pill(x: -1, y: -1, w: -1, h: -1);
      expect(
          IslandMockup.describe(AppLocalizationsEs(), pill, true), contains('centro a 540 píxeles'));
      expect(IslandMockup.describe(AppLocalizationsEs(), pill, true), contains('336 de ancho'));
    });
  });
}
