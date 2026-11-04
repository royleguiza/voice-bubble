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
    testWidgets('pastilla con reproducir y la duración del WAV',
        (tester) async {
      // 16 kHz mono 16 bits = 32000 B/s: 44 B de cabecera + 38 s.
      final dir = Directory.systemTemp.createTempSync('note_audio_len_');
      final path = '${dir.path}/x.wav';
      File(path).writeAsBytesSync(
          List<int>.filled(44 + 38 * NoteAudioRow.bytesPerSecond, 0));
      await tester.pumpWidget(wrap(NoteAudioRow(audioPath: path, noteId: 'n1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notePlayAudio-n1')), findsOneWidget);
      expect(find.text('0:38'), findsOneWidget);
      // Borrar el audio vive en el menú de la nota, no en la tarjeta.
      expect(find.byKey(const ValueKey('noteDeleteAudio-n1')), findsNothing);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    testWidgets('el área táctil mide al menos 44 dp de alto', (tester) async {
      await tester.pumpWidget(wrap(const NoteAudioRow(
        audioPath: '/tmp/notes_audio/x.wav',
        noteId: 'n2',
      )));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byKey(const ValueKey('notePlayAudio-n2')));
      expect(size.height, greaterThanOrEqualTo(44));
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
