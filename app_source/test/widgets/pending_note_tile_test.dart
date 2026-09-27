import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/services/pending_note_queue.dart';
import 'package:voice_bubble_stt/widgets/pending_note_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PendingNote item(String id) => PendingNote(
        id: id,
        audioPath: '/tmp/pending_notes/$id.wav',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );

  Widget wrap(PendingNoteTile tile) {
    return MaterialApp(home: Scaffold(body: tile));
  }

  group('PendingNoteTile (C-45)', () {
    testWidgets('muestra transcribir, escuchar y descartar', (tester) async {
      const id = '11111111-1111-4111-8111-111111111111';
      await tester.pumpWidget(wrap(PendingNoteTile(
        item: item(id),
        busy: false,
        onTranscribe: () {},
        onDiscard: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Audio sin transcribir'), findsOneWidget);
      expect(
        find.byKey(ValueKey('transcribeCloudButton-$id')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('playPendingButton-$id')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('discardPendingButton-$id')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('audio inexistente avisa sin crashear', (tester) async {
      const id = '22222222-2222-4222-8222-222222222222';
      await tester.pumpWidget(wrap(PendingNoteTile(
        item: item(id),
        busy: false,
        onTranscribe: () {},
        onDiscard: () {},
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('playPendingButton-$id')));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo reproducir este audio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('busy deshabilita las tres acciones', (tester) async {
      const id = '33333333-3333-4333-8333-333333333333';
      var transcribed = false;
      var discarded = false;
      await tester.pumpWidget(wrap(PendingNoteTile(
        item: item(id),
        busy: true,
        onTranscribe: () => transcribed = true,
        onDiscard: () => discarded = true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(ValueKey('transcribeCloudButton-$id')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(ValueKey('discardPendingButton-$id')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(transcribed, isFalse);
      expect(discarded, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
