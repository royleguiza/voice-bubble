import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/models/transcription.dart';

void main() {
  final fixedTimestamp = DateTime(2025, 7, 15, 10, 30, 0);

  Transcription createSut({
    String text = 'Hello world',
    DateTime? timestamp,
    bool isLocal = true,
  }) {
    return Transcription(
      text: text,
      timestamp: timestamp ?? fixedTimestamp,
      isLocal: isLocal,
    );
  }

  group('Constructor', () {
    test('creates a valid instance with all required parameters', () {
      final t = createSut();

      expect(t.text, 'Hello world');
      expect(t.timestamp, fixedTimestamp);
      expect(t.isLocal, true);
    });

    test('creates instance with isLocal false', () {
      final t = createSut(isLocal: false);

      expect(t.isLocal, false);
    });
  });

  group('Field accessors', () {
    test('text field is properly stored and retrieved', () {
      final t = createSut(text: 'Test transcription');

      expect(t.text, 'Test transcription');
    });

    test('timestamp field is properly stored and retrieved', () {
      final dt = DateTime(2024, 1, 1, 12, 0, 0);
      final t = createSut(timestamp: dt);

      expect(t.timestamp, dt);
    });

    test('isLocal field is properly stored and retrieved', () {
      final t1 = createSut(isLocal: true);
      final t2 = createSut(isLocal: false);

      expect(t1.isLocal, true);
      expect(t2.isLocal, false);
    });
  });

  group('toJson', () {
    test('produces correct JSON map', () {
      final t = createSut();
      final json = t.toJson();

      expect(json, {
        'text': 'Hello world',
        'timestamp': fixedTimestamp.toIso8601String(),
        'isLocal': true,
      });
    });

    test('serializes isLocal false correctly', () {
      final t = createSut(isLocal: false);
      final json = t.toJson();

      expect(json['isLocal'], false);
    });

    test('serializes timestamp as ISO 8601 string', () {
      final t = createSut();
      final json = t.toJson();

      expect(json['timestamp'], isA<String>());
      expect(json['timestamp'], fixedTimestamp.toIso8601String());
    });
  });

  group('fromJson', () {
    test('deserializes correctly from JSON map', () {
      final json = {
        'text': 'Deserialized text',
        'timestamp': '2025-03-20T14:00:00.000',
        'isLocal': true,
      };

      final t = Transcription.fromJson(json);

      expect(t.text, 'Deserialized text');
      expect(t.timestamp, DateTime(2025, 3, 20, 14, 0, 0));
      expect(t.isLocal, true);
    });

    test('deserializes isLocal false correctly', () {
      final json = {
        'text': 'Text',
        'timestamp': '2025-01-01T00:00:00.000',
        'isLocal': false,
      };

      final t = Transcription.fromJson(json);

      expect(t.isLocal, false);
    });

    test('handles various ISO 8601 timestamp formats', () {
      final json = {
        'text': 'Text',
        'timestamp': '2025-12-31T23:59:59.999Z',
        'isLocal': true,
      };

      final t = Transcription.fromJson(json);

      expect(t.timestamp.year, 2025);
      expect(t.timestamp.month, 12);
      expect(t.timestamp.day, 31);
    });
  });

  group('Round-trip serialization', () {
    test('toJson then fromJson preserves data', () {
      final original = createSut();
      final restored = Transcription.fromJson(original.toJson());

      expect(restored.text, original.text);
      expect(restored.timestamp, original.timestamp);
      expect(restored.isLocal, original.isLocal);
    });

    test('round-trip preserves isLocal false', () {
      final original = createSut(isLocal: false, text: 'Round trip test');
      final restored = Transcription.fromJson(original.toJson());

      expect(restored, original);
    });

    test('round-trip with complex text', () {
      final original = createSut(text: 'Acentos: áéíóú ñ, emojis: 🎤, quotes: "hello"');
      final restored = Transcription.fromJson(original.toJson());

      expect(restored.text, original.text);
    });
  });

  group('Equality operator', () {
    test('two instances with identical data are equal', () {
      final t1 = createSut();
      final t2 = createSut();

      expect(t1 == t2, true);
    });

    test('same instance is equal to itself', () {
      final t1 = createSut();

      expect(t1 == t1, true);
    });

    test('instances with different text are not equal', () {
      final t1 = createSut(text: 'Text A');
      final t2 = createSut(text: 'Text B');

      expect(t1 == t2, false);
    });

    test('instances with different timestamps are not equal', () {
      final t1 = createSut(timestamp: DateTime(2025, 1, 1));
      final t2 = createSut(timestamp: DateTime(2025, 6, 15));

      expect(t1 == t2, false);
    });

    test('instances with different isLocal are not equal', () {
      final t1 = createSut(isLocal: true);
      final t2 = createSut(isLocal: false);

      expect(t1 == t2, false);
    });

    test('not equal to a non-Transcription object', () {
      final t = createSut();

      expect(t, isNot(equals('not a transcription')));
      expect(t, isNot(equals(42)));
      expect(t, isNotNull);
    });

    test('not equal when only text differs', () {
      final t1 = createSut(text: 'Same');
      final t2 = createSut(text: 'Different');

      expect(t1 == t2, false);
    });

    test('not equal when only timestamp differs', () {
      final t1 = createSut(timestamp: DateTime(2025, 1, 1));
      final t2 = createSut(timestamp: DateTime(2025, 1, 2));

      expect(t1 == t2, false);
    });

    test('not equal when only isLocal differs', () {
      final t1 = createSut(isLocal: true);
      final t2 = createSut(isLocal: false);

      expect(t1 == t2, false);
    });
  });

  group('hashCode', () {
    test('consistent for equal instances', () {
      final t1 = createSut();
      final t2 = createSut();

      expect(t1.hashCode, t2.hashCode);
    });

    test('different instances with same data have same hashCode', () {
      final t1 = createSut(text: 'Same text', timestamp: DateTime(2025, 5, 5), isLocal: true);
      final t2 = createSut(text: 'Same text', timestamp: DateTime(2025, 5, 5), isLocal: true);

      expect(t1.hashCode, t2.hashCode);
    });

    test('hashes differ when text differs', () {
      final t1 = createSut(text: 'A');
      final t2 = createSut(text: 'B');

      expect(t1.hashCode, isNot(t2.hashCode));
    });

    test('hashes differ when timestamp differs', () {
      final t1 = createSut(timestamp: DateTime(2025, 1, 1));
      final t2 = createSut(timestamp: DateTime(2025, 12, 31));

      expect(t1.hashCode, isNot(t2.hashCode));
    });

    test('hashes differ when isLocal differs', () {
      final t1 = createSut(isLocal: true);
      final t2 = createSut(isLocal: false);

      expect(t1.hashCode, isNot(t2.hashCode));
    });
  });

  group('toString', () {
    test('produces readable string representation', () {
      final dt = DateTime(2025, 7, 15, 10, 30, 0);
      final t = Transcription(text: 'Prueba', timestamp: dt, isLocal: true);

      expect(t.toString(), 'Transcription(text: Prueba, timestamp: $dt, isLocal: true)');
    });
  });

  group('Defensive JSON deserialization', () {
    test('handles missing or null fields gracefully', () {
      final json = <String, dynamic>{};
      final t = Transcription.fromJson(json);

      expect(t.text, '');
      expect(t.isLocal, false);
      expect(t.timestamp, isA<DateTime>());
    });

    test('handles null values for nullable keys in map', () {
      final json = <String, dynamic>{
        'text': null,
        'timestamp': null,
        'isLocal': null,
      };
      final t = Transcription.fromJson(json);

      expect(t.text, '');
      expect(t.isLocal, false);
      expect(t.timestamp, isA<DateTime>());
    });
  });
}
