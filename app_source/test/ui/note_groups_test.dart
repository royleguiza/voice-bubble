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

  group('historyDayLabel / historyTimeLabel', () {
    test('agrupa por día: hoy, ayer y fecha corta', () {
      expect(historyDayLabel(DateTime(2026, 11, 4, 0, 5), now: now), 'Hoy');
      expect(historyDayLabel(DateTime(2026, 11, 3, 23, 59), now: now), 'Ayer');
      expect(historyDayLabel(DateTime(2026, 10, 30, 8), now: now), '30 oct');
      expect(historyDayLabel(DateTime(2025, 3, 2), now: now), '2 mar 2025');
    });

    test('la fila lleva solo la hora en 24 h', () {
      expect(historyTimeLabel(DateTime(2026, 10, 30, 8, 5)), '08:05');
      expect(historyTimeLabel(DateTime(2026, 11, 4, 16, 49)), '16:49');
    });
  });

  group('groupRows / GroupedRowsMemo', () {
    List<GroupedRow<DateTime>> build(List<DateTime> items) => groupRows(
          items,
          groupOf: (t) => noteGroupLabel(t, now: now),
          timeOf: (t) => noteTimeLabel(t, now: now),
        );

    test('índices planos: encabezado por grupo y espacio entre ítems', () {
      final rows = build([
        DateTime(2026, 11, 4, 10),
        DateTime(2026, 11, 4, 9),
        DateTime(2026, 11, 3, 8),
      ]);
      expect(rows.map((r) => r.runtimeType.toString().split('<').first), [
        'GroupHeaderRow',
        'GroupItemRow',
        'GroupGapRow',
        'GroupItemRow',
        'GroupHeaderRow',
        'GroupItemRow',
      ]);
      expect((rows[0] as GroupHeaderRow).label, 'Hoy');
      expect((rows[1] as GroupItemRow).timeLabel, '10:00');
      expect((rows[4] as GroupHeaderRow).label, 'Ayer');
    });

    test('memo: recalcula solo si cambian datos, búsqueda o día', () {
      final memo = GroupedRowsMemo<DateTime>(idOf: (t) => t);
      final a = DateTime(2026, 11, 4, 10);
      final b = DateTime(2026, 11, 3, 8);
      final data = [a, b];
      List<GroupedRow<DateTime>> resolve(List<DateTime> src, String q,
              [DateTime? day]) =>
          memo.resolve(src, q, now: day ?? now, build: () => build(src));

      final first = resolve(data, '');
      expect(memo.computeCount, 1);
      // Otra lista con los mismos elementos (copia): reutiliza.
      expect(identical(resolve(List.of(data), ''), first), isTrue);
      expect(memo.computeCount, 1);
      expect(memo.indexOf(a), 1);
      expect(memo.indexOf(b), 3);
      // Búsqueda distinta, elemento distinto, otro largo u otro día.
      resolve(data, 'x');
      expect(memo.computeCount, 2);
      resolve([DateTime(2026, 11, 4, 10), b], 'x');
      expect(memo.computeCount, 3);
      resolve([a], 'x');
      expect(memo.computeCount, 4);
      resolve([a], 'x', DateTime(2026, 11, 5, 0, 1));
      expect(memo.computeCount, 5);
    });
  });
}
