import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('estado transcribing muestra spinner y no dispara acciones',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(buildTestWidget(
        state: RecordButtonState.transcribing,
        onPressed: () => pressed = true,
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

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

    testWidgets('estado recording no desborda el boton (sin overflow amarillo)',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(state: RecordButtonState.recording));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byKey(const ValueKey('recordButton')));
      expect(size.width, 104.0);
      expect(size.height, 104.0);
    });

    testWidgets('tamano del boton es kRecordButtonSize (104)', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      // El gesto de pulsos puede programar frames; pumpAndSettle acotado.
      await tester.pump(const Duration(milliseconds: 100));

      final size = tester.getSize(find.byKey(const ValueKey('recordButton')));
      expect(size.width, 104.0);
      expect(size.height, 104.0);
    });
  });
}
