import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/models/transcription.dart';

void main() {
  final fixedTimestamp = DateTime(2025, 7, 15, 10, 30, 0);

  Transcription createSut({
    String text = 'Hello world',
    DateTime? timestamp,
  }) {
    return Transcription(
      text: text,
      timestamp: timestamp ?? fixedTimestamp,
    );
  }

  group('Constructor', () {
    test('creates a valid instance', () {
      final t = createSut();

      expect(t.text, 'Hello world');
      expect(t.timestamp, fixedTimestamp);
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
  });

  group('toJson', () {
    test('produces correct JSON map with ISO 8601 timestamp', () {
      final json = createSut().toJson();

      expect(json, {
        'text': 'Hello world',
        'timestamp': fixedTimestamp.toIso8601String(),
      });
    });
  });

  group('fromJson', () {
    test('deserializes correctly from JSON map', () {
      final t = Transcription.fromJson({
        'text': 'Deserialized text',
        'timestamp': '2025-03-20T14:00:00.000',
      });

      expect(t.text, 'Deserialized text');
      expect(t.timestamp, DateTime(2025, 3, 20, 14, 0, 0));
    });

    test('handles UTC timestamp with Z suffix', () {
      final t = Transcription.fromJson({
        'text': 'Text',
        'timestamp': '2025-12-31T23:59:59.999Z',
      });

      // El instante se conserva y se expresa en hora local (AT-C7).
      expect(
        t.timestamp,
        DateTime.utc(2025, 12, 31, 23, 59, 59, 999).toLocal(),
      );
      expect(t.timestamp.isUtc, isFalse);
    });

    test("timestamps con 'Z' y sin zona caen en hora local equivalente",
        () {
      final fromUtc = Transcription.fromJson(
          {'text': 'a', 'timestamp': '2026-08-23T10:00:00Z'});
      final fromNaive = Transcription.fromJson(
          {'text': 'b', 'timestamp': '2026-08-23T10:00:00.000'});

      // Ninguno queda en UTC: el historial muestra siempre hora local.
      expect(fromUtc.timestamp.isUtc, isFalse);
      expect(fromNaive.timestamp.isUtc, isFalse);

      // El instante del dictado del teclado (UTC) equivale a SU
      // representacion local; el naive de la app ya era local.
      expect(fromUtc.timestamp, DateTime.utc(2026, 8, 23, 10).toLocal());
      expect(fromNaive.timestamp, DateTime(2026, 8, 23, 10));
    });
  });

  group('Round-trip serialization', () {
    test('toJson then fromJson preserves data', () {
      final original = createSut();
      final restored = Transcription.fromJson(original.toJson());

      expect(restored, original);
    });

    test('round-trip with complex text', () {
      final original =
          createSut(text: 'Acentos: áéíóú ñ, emojis: 🎤, quotes: "hello"');
      final restored = Transcription.fromJson(original.toJson());

      expect(restored.text, original.text);
      expect(restored.timestamp, original.timestamp);
    });
  });

  group('Equality operator', () {
    test('two instances with identical data are equal', () {
      expect(createSut(), createSut());
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

    test('not equal to a non-Transcription object', () {
      final t = createSut();

      expect(t, isNot(equals('not a transcription')));
      expect(t, isNot(equals(42)));
      expect(t, isNotNull);
    });
  });

  group('hashCode', () {
    test('equal instances have the same hashCode (contrato equals/hash)', () {
      final t1 = createSut();
      final t2 = createSut();

      expect(t1 == t2, true);
      expect(t1.hashCode, t2.hashCode);
    });
  });

  group('toString', () {
    test('produces readable string representation', () {
      final dt = DateTime(2025, 7, 15, 10, 30, 0);
      final t = Transcription(text: 'Prueba', timestamp: dt);

      expect(t.toString(), 'Transcription(text: Prueba, timestamp: $dt)');
    });
  });

  group('Defensive JSON deserialization', () {
    test('handles missing or null fields gracefully', () {
      final t = Transcription.fromJson(<String, dynamic>{
        'text': null,
        'timestamp': null,
      });

      expect(t.text, '');
      expect(t.timestamp, isA<DateTime>());
    });
  });
}
