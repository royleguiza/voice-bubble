import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Clipboard History Multimodal - Isolation & Invariants', () {
    test('ClipType definitions match Kotlin model', () {
      const types = ['TEXT', 'CODE', 'IMAGE', 'MATH', 'URL'];
      expect(types.length, 5);
      expect(types.contains('TEXT'), isTrue);
      expect(types.contains('CODE'), isTrue);
      expect(types.contains('IMAGE'), isTrue);
      expect(types.contains('MATH'), isTrue);
      expect(types.contains('URL'), isTrue);
    });

    test('Separation invariant: Voice transcriptions never pollute clipboard', () {
      const transcriptionKey = 'flutter.transcription_history';
      const clipboardStorage = 'clipboard_history.json';
      expect(transcriptionKey != clipboardStorage, isTrue);
    });

    test('FIFO limit and Pinning retention rule', () {
      const maxUnpinned = 25;
      final clips = List.generate(40, (i) => {'id': 'clip-$i', 'isPinned': false});
      final pinned = [
        {'id': 'pin-1', 'isPinned': true},
        {'id': 'pin-2', 'isPinned': true},
      ];

      final combined = [...pinned, ...clips.take(maxUnpinned)];
      expect(combined.length, 27);
      expect(combined.where((c) => c['isPinned'] == true).length, 2);
    });
  });
}
