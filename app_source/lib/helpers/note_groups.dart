/// Etiquetas de fecha de la lista de notas: secciones (Hoy, Ayer, Esta
/// semana, Octubre…) y la hora o fecha corta que muestra cada tarjeta. El
/// Historial agrupa por día (Hoy, Ayer, 6 nov) y cada fila lleva la hora.
///
/// Funciones puras con `now` inyectable para testearlas sin reloj real.
library;

const List<String> _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Días calendario entre [t] y [now] (0 = hoy). Fechas futuras cuentan como hoy.
int _daysAgo(DateTime t, DateTime now) {
  final diff = _day(now).difference(_day(t)).inHours;
  // inHours/24 redondeado: absorbe el día de 23/25 h del cambio de horario.
  return diff <= 0 ? 0 : (diff / 24).round();
}

/// Título de sección para una nota editada en [t].
String noteGroupLabel(DateTime t, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final days = _daysAgo(t, ref);
  if (days == 0) return 'Hoy';
  if (days == 1) return 'Ayer';
  if (days < 7) return 'Esta semana';
  final month = _months[t.month - 1];
  final label = '${month[0].toUpperCase()}${month.substring(1)}';
  return t.year == ref.year ? label : '$label ${t.year}';
}

String _hourMinute(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

String _shortDate(DateTime t, DateTime ref) {
  final short = '${t.day} ${_months[t.month - 1].substring(0, 3)}';
  return t.year == ref.year ? short : '$short ${t.year}';
}

/// Hora (hoy y ayer) o fecha corta "28 oct" (más viejo) de una tarjeta.
String noteTimeLabel(DateTime t, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  if (_daysAgo(t, ref) <= 1) return _hourMinute(t);
  return _shortDate(t, ref);
}

/// Grupo de un día del Historial: "Hoy", "Ayer" o la fecha corta "6 nov"
/// (con el año si no es el actual).
String historyDayLabel(DateTime t, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final days = _daysAgo(t, ref);
  if (days == 0) return 'Hoy';
  if (days == 1) return 'Ayer';
  return _shortDate(t, ref);
}

/// Hora sola "16:49" de una fila del Historial (el día lo da el grupo).
String historyTimeLabel(DateTime t) => _hourMinute(t);

// ---------------------------------------------------------------------------
// Filas planas para listas perezosas (Notas e Historial de Inicio)
// ---------------------------------------------------------------------------

/// Fila de una lista agrupada por fecha, en índice plano: un solo sliver
/// perezoso arma encabezados, ítems y espacios sin listas anidadas.
sealed class GroupedRow<T> {
  const GroupedRow();
}

/// Encabezado de grupo ("Hoy", "Ayer", "Octubre"…).
final class GroupHeaderRow<T> extends GroupedRow<T> {
  final String label;
  const GroupHeaderRow(this.label);
}

/// Ítem con su etiqueta de hora ya formateada (se calcula una vez, no en
/// cada build de la fila).
final class GroupItemRow<T> extends GroupedRow<T> {
  final T item;
  final String timeLabel;
  const GroupItemRow(this.item, this.timeLabel);
}

/// Separación entre dos ítems seguidos del mismo grupo.
final class GroupGapRow<T> extends GroupedRow<T> {
  const GroupGapRow();
}

/// Agrupa [items] (ya ordenados) por corridas de [groupOf]: cada cambio de
/// etiqueta abre un encabezado y entre ítems del mismo grupo va un espacio.
List<GroupedRow<T>> groupRows<T>(
  Iterable<T> items, {
  required String Function(T item) groupOf,
  required String Function(T item) timeOf,
}) {
  final rows = <GroupedRow<T>>[];
  String? group;
  for (final item in items) {
    final g = groupOf(item);
    if (g != group) {
      rows.add(GroupHeaderRow<T>(g));
      group = g;
    } else {
      rows.add(GroupGapRow<T>());
    }
    rows.add(GroupItemRow<T>(item, timeOf(item)));
  }
  return rows;
}

/// Memo de [groupRows]: recalcula solo cuando cambian los datos (otra
/// lista o algún elemento distinto por identidad: los modelos son
/// inmutables), la búsqueda o el día (las etiquetas dependen de la fecha).
/// Desplazar o reconstruir la pantalla por otra causa reutiliza las filas.
class GroupedRowsMemo<T> {
  final Object Function(T item) idOf;

  GroupedRowsMemo({required this.idOf});

  List<T> _source = const [];
  String? _key;
  List<GroupedRow<T>> _rows = const [];
  Map<Object, int> _index = const {};

  /// Veces que se recalcularon las filas (para tests).
  int computeCount = 0;

  List<GroupedRow<T>> get rows => _rows;

  /// Fila de cada ítem por su id (para `findChildIndexCallback`).
  int? indexOf(Object id) => _index[id];

  /// Filas de [source] con la búsqueda [query]; [build] filtra y agrupa.
  List<GroupedRow<T>> resolve(
    List<T> source,
    String query, {
    required List<GroupedRow<T>> Function() build,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final key = '${ref.year}-${ref.month}-${ref.day}|$query';
    if (key == _key && _sameItems(source)) return _rows;
    computeCount++;
    _key = key;
    _source = List<T>.of(source, growable: false);
    _rows = build();
    final index = <Object, int>{};
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row is GroupItemRow<T>) index[idOf(row.item)] = i;
    }
    _index = index;
    return _rows;
  }

  bool _sameItems(List<T> source) {
    if (source.length != _source.length) return false;
    for (var i = 0; i < source.length; i++) {
      if (!identical(source[i], _source[i])) return false;
    }
    return true;
  }
}
