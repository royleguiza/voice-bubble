import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/helpers/note_groups.dart';

void main() {
  final now = DateTime(2026, 11, 4, 15, 30);

  group('noteGroupLabel', () {
    test('hoy, ayer y esta semana por día calendario', () {
      expect(noteGroupLabel(DateTime(2026, 11, 4, 0, 5), now: now), 'Hoy');
      expect(noteGroupLabel(DateTime(2026, 11, 3, 23, 59), now: now), 'Ayer');
      expect(noteGroupLabel(DateTime(2026, 10, 29), now: now), 'Esta semana');
    });

    test('más viejo: mes, con año solo si no es el actual', () {
      expect(noteGroupLabel(DateTime(2026, 10, 28), now: now), 'Octubre');
      expect(noteGroupLabel(DateTime(2025, 12, 1), now: now), 'Diciembre 2025');
    });

    test('una fecha futura (reloj corrido) cuenta como hoy', () {
      expect(noteGroupLabel(DateTime(2026, 11, 5), now: now), 'Hoy');
    });
  });

  group('noteTimeLabel', () {
    test('hoy y ayer muestran la hora en 24 h', () {
      expect(noteTimeLabel(DateTime(2026, 11, 4, 9, 7), now: now), '09:07');
      expect(noteTimeLabel(DateTime(2026, 11, 3, 18, 40), now: now), '18:40');
    });

    test('más viejo muestra fecha corta', () {
      expect(noteTimeLabel(DateTime(2026, 10, 28), now: now), '28 oct');
      expect(noteTimeLabel(DateTime(2025, 3, 2), now: now), '2 mar 2025');
    });
  });
}
