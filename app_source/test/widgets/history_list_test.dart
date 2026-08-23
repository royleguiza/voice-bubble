import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/widgets/history_list.dart';
import 'package:voice_bubble_stt/models/transcription.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Backend en memoria para Clipboard (sin mock, Clipboard.setData lanza
  // MissingPluginException y el SnackBar nunca aparece).
  String? clipboardStore;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboardStore = (call.arguments as Map)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return <String, String?>{'text': clipboardStore};
        default:
          return null;
      }
    },
  );

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 600, child: child),
      ),
    );
  }

  Transcription makeT(String text, {int minutesAgo = 0}) {
    return Transcription(
      text: text,
      timestamp: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    );
  }

  group('HistoryList', () {
    testWidgets('shows empty message when list is empty', (tester) async {
      await tester.pumpWidget(wrap(const HistoryList(transcriptions: [])));
      expect(find.text('No hay transcripciones aun'), findsOneWidget);
    });

    testWidgets('renders items when list has items', (tester) async {
      await tester.pumpWidget(wrap(HistoryList(transcriptions: [makeT('hola')])));
      expect(find.text('hola'), findsOneWidget);
    });

    testWidgets('renders correct number of items', (tester) async {
      final items = List.generate(5, (i) => makeT('text $i'));
      await tester.pumpWidget(wrap(HistoryList(transcriptions: items)));
      for (var i = 0; i < 5; i++) {
        expect(find.text('text $i'), findsOneWidget);
      }
    });

    testWidgets('shows the cloud icon for every transcription', (tester) async {
      await tester.pumpWidget(wrap(HistoryList(
        transcriptions: [makeT('cloud text')],
      )));
      // Motor Cloud unico: un solo icono, sin rama local (AT-C5).
      expect(find.byIcon(Icons.cloud), findsOneWidget);
      expect(find.byIcon(Icons.phone_android), findsNothing);
    });

    testWidgets('shows transcription text in each item', (tester) async {
      await tester.pumpWidget(wrap(HistoryList(
        transcriptions: [makeT('hello world')],
      )));
      expect(find.text('hello world'), findsOneWidget);
    });

    testWidgets('shows formatted timestamp', (tester) async {
      final dt = DateTime(2026, 8, 21, 14, 30);
      final t = Transcription(text: 'ts', timestamp: dt);
      await tester.pumpWidget(wrap(HistoryList(transcriptions: [t])));
      expect(find.text('21/08/2026 14:30'), findsOneWidget);
    });

    testWidgets('shows copy button in each item', (tester) async {
      await tester.pumpWidget(wrap(HistoryList(
        transcriptions: [makeT('copy test')],
      )));
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('copy button shows snackbar when tapped', (tester) async {
      await tester.pumpWidget(wrap(HistoryList(
        transcriptions: [makeT('tap test')],
      )));
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Texto copiado'), findsOneWidget);
    });

    testWidgets('handles single item list', (tester) async {
      await tester.pumpWidget(wrap(HistoryList(
        transcriptions: [makeT('only')],
      )));
      expect(find.text('only'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('handles maximum items (20)', (tester) async {
      final items = List.generate(20, (i) => makeT('item $i'));
      await tester.pumpWidget(wrap(HistoryList(transcriptions: items)));
      expect(find.text('item 0'), findsOneWidget);
      // ListView es lazy: los ítems fuera del viewport no se construyen,
      // hay que hacer scroll hasta el último.
      await tester.dragUntilVisible(
        find.text('item 19'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pump();
      expect(find.text('item 19'), findsOneWidget);
    });

    testWidgets('list is scrollable', (tester) async {
      final items = List.generate(20, (i) => makeT('scroll $i'));
      await tester.pumpWidget(wrap(HistoryList(transcriptions: items)));
      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);
    });

    testWidgets('shows one cloud icon per item in a mixed list', (tester) async {
      final items = [
        makeT('first 1'),
        makeT('second 1'),
        makeT('third 2'),
      ];
      await tester.pumpWidget(wrap(HistoryList(transcriptions: items)));
      expect(find.byIcon(Icons.cloud), findsNWidgets(3));
      expect(find.byIcon(Icons.phone_android), findsNothing);
    });
  });
}
