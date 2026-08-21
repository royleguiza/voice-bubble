import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/widgets/record_button.dart';

Widget buildTestWidget({
  bool isRecording = false,
  bool isTranscribing = false,
  VoidCallback? onPressed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: RecordButton(
        isRecording: isRecording,
        isTranscribing: isTranscribing,
        onPressed: onPressed ?? () {},
      ),
    ),
  );
}

void main() {
  group('RecordButton', () {
    testWidgets('renders FloatingActionButton.large', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      final FloatingActionButton widget = tester.widget<FloatingActionButton>(fab);
      expect(widget.shape, isA<StadiumBorder>());
    });

    testWidgets('shows mic icon when not recording', (tester) async {
      await tester.pumpWidget(buildTestWidget(isRecording: false));

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('shows stop icon when recording', (tester) async {
      await tester.pumpWidget(buildTestWidget(isRecording: true));

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });

    testWidgets('shows CircularProgressIndicator when transcribing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isTranscribing: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('calls onPressed when tapped and not recording', (tester) async {
      var called = false;
      await tester.pumpWidget(buildTestWidget(
        isRecording: false,
        onPressed: () => called = true,
      ));

      await tester.tap(find.byType(FloatingActionButton));
      expect(called, isTrue);
    });

    testWidgets('calls onPressed when tapped while recording', (tester) async {
      var called = false;
      await tester.pumpWidget(buildTestWidget(
        isRecording: true,
        onPressed: () => called = true,
      ));

      await tester.tap(find.byType(FloatingActionButton));
      expect(called, isTrue);
    });

    testWidgets('does not call onPressed when transcribing', (tester) async {
      var called = false;
      await tester.pumpWidget(buildTestWidget(
        isTranscribing: true,
        onPressed: () => called = true,
      ));

      await tester.tap(find.byType(FloatingActionButton));
      expect(called, isFalse);
    });

    testWidgets('background color is kRecording when recording', (tester) async {
      await tester.pumpWidget(buildTestWidget(isRecording: true));

      final widget = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(widget.backgroundColor, const Color(0xFFFF3B30));
    });

    testWidgets('background color is primary when not recording', (tester) async {
      await tester.pumpWidget(buildTestWidget(isRecording: false));

      final widget = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(widget.backgroundColor, isNotNull);
    });

    testWidgets('button is 80x80 size', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 80);
      expect(sizedBox.height, 80);
    });

    testWidgets('widget tree is correct', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('has correct SizedBox dimensions when transcribing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isTranscribing: true));

      final innerSizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 32 && widget.height == 32,
        ),
      );
      expect(innerSizedBox.width, 32);
      expect(innerSizedBox.height, 32);
    });

    testWidgets('CircularProgressIndicator has correct strokeWidth', (tester) async {
      await tester.pumpWidget(buildTestWidget(isTranscribing: true));

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.strokeWidth, 3);
    });

    testWidgets('onPressed is null when transcribing (disabled)', (tester) async {
      await tester.pumpWidget(buildTestWidget(isTranscribing: true));

      final widget = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(widget.onPressed, isNull);
    });

    testWidgets('Icon is not disabled when not recording', (tester) async {
      await tester.pumpWidget(buildTestWidget(isRecording: false));

      final widget = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(widget.onPressed, isNotNull);
    });
  });
}
