import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/widgets/note_audio_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(NoteAudioRow row) {
    return MaterialApp(home: Scaffold(body: row));
  }

  group('NoteAudioRow', () {
    testWidgets('muestra reproducir y borrar audio', (tester) async {
      var deleted = false;
      await tester.pumpWidget(wrap(NoteAudioRow(
        audioPath: '/tmp/notes_audio/x.wav',
        noteId: 'n1',
        onDeleteAudio: () => deleted = true,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Audio original conservado'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notePlayAudio-n1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('noteDeleteAudio-n1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('noteDeleteAudio-n1')));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('sin callback no muestra borrar audio', (tester) async {
      await tester.pumpWidget(wrap(const NoteAudioRow(
        audioPath: '/tmp/notes_audio/x.wav',
        noteId: 'n2',
      )));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('notePlayAudio-n2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('noteDeleteAudio-n2')),
        findsNothing,
      );
    });

    testWidgets('archivo inexistente avisa sin crashear', (tester) async {
      await tester.pumpWidget(wrap(const NoteAudioRow(
        audioPath: '/tmp/notes_audio/no-existe.wav',
        noteId: 'n3',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('notePlayAudio-n3')));
      await tester.pumpAndSettle();

      expect(find.text('Audio no encontrado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('C-45: cabecera dañada avisa sin crashear', (tester) async {
      // IO síncrona: los futures de dart:io se cuelgan bajo FakeAsync
      // en widget tests (§9.2-10).
      final dir = Directory.systemTemp.createTempSync('note_audio_corrupt_');
      final path = '${dir.path}/roto.wav';
      File(path).writeAsBytesSync(List<int>.filled(9000, 0));
      await tester.pumpWidget(wrap(NoteAudioRow(
        audioPath: path,
        noteId: 'n4',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('notePlayAudio-n4')));
      await tester.pumpAndSettle();

      expect(
        find.text('Audio dañado; borralo y grabalo de nuevo'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  });
}
