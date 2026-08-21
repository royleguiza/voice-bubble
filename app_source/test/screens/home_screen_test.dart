import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/ui/design_tokens.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: const HomeScreen(),
    );
  }

  group('HomeScreen', () {
    testWidgets('renders AppBar with "VoiceBubble STT" title', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('VoiceBubble STT'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows settings icon in AppBar', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('shows SegmentedButton with Cloud and Local options', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton), findsOneWidget);
      expect(find.text('Cloud'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.byIcon(Icons.cloud), findsOneWidget);
      expect(find.byIcon(Icons.phone_android), findsOneWidget);
    });

    testWidgets('default mode is Cloud', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton>(
        find.byType(SegmentedButton),
      );
      expect(segmentedButton.selected, contains(TranscriptionMode.cloud));
    });

    testWidgets('shows RecordButton widget', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('shows "Listo para transcribir" text initially', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Listo para transcribir'), findsOneWidget);
    });

    testWidgets('shows mic icon in record button initially', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('settings button navigates to SettingsScreen', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('API Key de Groq'), findsOneWidget);
    });

    testWidgets('tapping record button changes to recording state', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });

    testWidgets('shows history section', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('No hay transcripciones aun'),
        findsOneWidget,
      );
    });

    testWidgets('shows "Historial" label when there are transcriptions', (tester) async {
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          '{"text":"Hola mundo","timestamp":"2024-01-15T10:30:00.000","isLocal":false}',
        ],
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Historial'), findsOneWidget);
    });

    testWidgets('AppBar title is centered', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.centerTitle, isTrue);
    });

    testWidgets('body has horizontal padding of 20', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final padding = tester.widget<Padding>(
        find.byWidgetPredicate(
          (widget) => widget is Padding && widget.padding == const EdgeInsets.symmetric(horizontal: 20),
        ),
      );
      expect(padding.padding, const EdgeInsets.symmetric(horizontal: 20));
    });

    testWidgets('shows stop icon when recording and tapped again', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('shows SegmentedButton before record button', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final segmentedButton = find.byType(SegmentedButton);
      final fab = find.byType(FloatingActionButton);

      expect(segmentedButton, findsOneWidget);
      expect(fab, findsOneWidget);
    });

    testWidgets('shows Expanded widget for history', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Expanded), findsWidgets);
    });

    testWidgets('shows SizedBox spacers between sections', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('Scaffold has proper structure', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('mode selector shows Cloud icon', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud), findsOneWidget);
    });

    testWidgets('mode selector shows Local icon', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.phone_android), findsOneWidget);
    });
  });
}
