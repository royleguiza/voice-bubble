import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/ui/design_tokens.dart';
import 'package:voice_bubble_stt/widgets/record_button.dart';

Widget buildTestWidget({
  RecordButtonState state = RecordButtonState.idle,
  VoidCallback? onPressed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: RecordButton(
        key: const ValueKey('recordButton'),
        state: state,
        onPressed: onPressed ?? () {},
      ),
    ),
  );
}

void main() {
  group('RecordButton v2', () {
    testWidgets('estado idle muestra icono de microfono', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('estado recording muestra stop', (tester) async {
      await tester.pumpWidget(buildTestWidget(state: RecordButtonState.recording));
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });

    testWidgets('estado transcribing muestra el agujero pensando y no dispara acciones',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(buildTestWidget(
        state: RecordButtonState.transcribing,
        onPressed: () => pressed = true,
      ));
      await tester.pump();

      expect(find.byKey(const ValueKey('recordProcessing')), findsOneWidget);
      // Pensando = arco + renglones sobre el agujero (fase 1), no puntos.
      expect(find.byKey(const ValueKey('recordHorizon')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      expect(pressed, isFalse);
    });

    testWidgets('tap dispara onPressed en modo toque', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
          buildTestWidget(onPressed: () => pressed++));

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      expect(pressed, 1);
    });

    testWidgets('hold dispara onHoldStart y onHoldEnd', (tester) async {
      var started = 0;
      var ended = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordButton(
            key: const ValueKey('recordButton'),
            state: RecordButtonState.idle,
            onHoldStart: () => started++,
            onHoldEnd: () => ended++,
          ),
        ),
      ));

      final center = tester.getCenter(find.byKey(const ValueKey('recordButton')));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      expect(started, 1);

      await gesture.up();
      await tester.pump();
      expect(ended, 1);
    });

    testWidgets('grabando se estira en pastilla sin overflow amarillo',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(state: RecordButtonState.recording));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byKey(const ValueKey('recordButton')));
      expect(size.width, kRecordPillMaxWidth);
      expect(size.height, kRecordPillHeight);
      expect(find.byKey(const ValueKey('recordElapsed')), findsOneWidget);
    });

    testWidgets('la pastilla no desborda en pantallas angostas (320 dp)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTestWidget(state: RecordButtonState.recording));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey('recordButton'))).width,
          lessThanOrEqualTo(320));
    });

    testWidgets('en reposo es un círculo de kRecordButtonSize', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      final size = tester.getSize(find.byKey(const ValueKey('recordButton')));
      expect(size.width, kRecordButtonSize);
      expect(size.height, kRecordButtonSize);
    });

    testWidgets('✕ descarta sin detener (onCancel, no onPressed)',
        (tester) async {
      var cancelled = 0;
      var pressed = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordButton(
            key: const ValueKey('recordButton'),
            state: RecordButtonState.recording,
            onPressed: () => pressed++,
            onCancel: () => cancelled++,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('recordCancelButton')));
      expect(cancelled, 1);
      expect(pressed, 0);
    });

    testWidgets('modo mantener: sin ✕ ni ■ (el dedo está en la burbuja)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordButton(
            key: const ValueKey('recordButton'),
            state: RecordButtonState.recording,
            onHoldStart: () {},
            onHoldEnd: () {},
            onCancel: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('recordCancelButton')), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('la onda consulta el nivel real del micrófono mientras graba',
        (tester) async {
      var polls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordButton(
            key: const ValueKey('recordButton'),
            state: RecordButtonState.recording,
            onPressed: () {},
            levelSource: () async {
              polls++;
              return 0.6;
            },
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(polls, greaterThan(2));
      // Al salir de recording deja de consultar (sin timers colgados).
      await tester.pumpWidget(buildTestWidget());
      final before = polls;
      await tester.pump(const Duration(milliseconds: 500));
      expect(polls, before);
    });

    testWidgets('C-26: Semantics en modo idle hold tiene label Mantené para grabar y accion longPress',
        (tester) async {
      final handle = tester.ensureSemantics();
      var started = 0;
      var ended = 0;
      var pressed = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordButton(
            key: const ValueKey('recordButton'),
            state: RecordButtonState.idle,
            onHoldStart: () => started++,
            onHoldEnd: () => ended++,
            onPressed: () => pressed++,
          ),
        ),
      ));

      final semantics = tester.getSemantics(find.byKey(const ValueKey('recordButton')));
      expect(semantics.label, 'Mantené para grabar');
      expect(semantics.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
      expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });

    testWidgets('C-26: Semantics en modo recording hold tiene label Detener grabación',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordButton(
            key: const ValueKey('recordButton'),
            state: RecordButtonState.recording,
            onHoldStart: () {},
            onHoldEnd: () {},
            onPressed: () {},
          ),
        ),
      ));
      await tester.pump();

      final semantics = tester.getSemantics(find.byKey(const ValueKey('recordButton')));
      expect(semantics.label, 'Detener grabación');
      expect(semantics.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
      expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });

    HorizonScene sceneOf(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('recordHorizon')));
      return (paint.painter! as HorizonPainter).scene;
    }

    Widget recordingWith({
      required Future<double> Function() level,
      bool disableAnimations = false,
      RecordButtonState state = RecordButtonState.recording,
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: RecordButton(
              key: const ValueKey('recordButton'),
              state: state,
              onPressed: () {},
              levelSource: level,
            ),
          ),
        ),
      );
    }

    testWidgets('fase 1: reposo es el agujero (negro + anillo brasa)',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      final box = tester.widget<AnimatedContainer>(find.descendant(
          of: find.byKey(const ValueKey('recordButton')),
          matching: find.byType(AnimatedContainer)));
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, kHoleLight);
      expect((deco.border! as Border).top.color, kEmberLight);
      final icon = tester.widget<Icon>(find.byIcon(Icons.mic_rounded));
      expect(icon.color, kOnHole);
      // Sin lienzo animado en reposo.
      expect(find.byKey(const ValueKey('recordHorizon')), findsNothing);
    });

    testWidgets('fase 1: el volumen alto llena la pastilla, con tope de pool',
        (tester) async {
      await tester.pumpWidget(recordingWith(level: () async => 1.0));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scene = sceneOf(tester);
      expect(scene.vol, greaterThan(0.9));
      expect(scene.activeParticles, greaterThan(5));
      expect(scene.activeParticles,
          lessThanOrEqualTo(HorizonScene.maxParticles));
    });

    testWidgets('fase 1: en silencio queda solo un goteo', (tester) async {
      await tester.pumpWidget(recordingWith(level: () async => 0.0));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scene = sceneOf(tester);
      expect(scene.vol, lessThan(0.05));
      expect(scene.activeParticles, lessThanOrEqualTo(8));
    });

    testWidgets('fase 1: el ticker se detiene al volver a reposo',
        (tester) async {
      await tester.pumpWidget(recordingWith(level: () async => 0.5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      final state = tester.state(find.byKey(const ValueKey('recordButton')));
      // Mismo árbol, otro estado: el State sobrevive y debe parar su ticker.
      await tester.pumpWidget(recordingWith(
          level: () async => 0.5, state: RecordButtonState.idle));
      expect(tester.state(find.byKey(const ValueKey('recordButton'))),
          same(state));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Pensando vuelve a animar; al terminar, se detiene otra vez.
      await tester.pumpWidget(recordingWith(
          level: () async => 0.5, state: RecordButtonState.transcribing));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(recordingWith(
          level: () async => 0.5, state: RecordButtonState.idle));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('fase 1: reducir movimiento = anillo fijo sin partículas',
        (tester) async {
      await tester.pumpWidget(
          recordingWith(level: () async => 0.7, disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 300));
      final scene = sceneOf(tester);
      expect(scene.animated, isFalse);
      expect(scene.activeParticles, 0);
      // El grosor del anillo sigue el volumen real.
      expect(scene.vol, closeTo(0.7, 0.001));
      // Sin cuadros de animación pendientes (solo el sondeo del nivel).
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('fase 1: pensando no absorbe partículas, saca renglones',
        (tester) async {
      await tester.pumpWidget(recordingWith(
          level: () async => 1.0, state: RecordButtonState.transcribing));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scene = sceneOf(tester);
      expect(scene.phase, VoicePhase.thinking);
      expect(scene.vol, 0);
      expect(scene.activeParticles, greaterThan(0));
    });
  });
}
