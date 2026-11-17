/// Etiquetas de fecha de la lista de notas: secciones (Hoy, Ayer, Esta
/// semana, Octubre…) y la hora o fecha corta que muestra cada tarjeta. El
/// Historial agrupa por día (Hoy, Ayer, 6 nov) y cada fila lleva la hora.
///
/// Funciones puras con `now` inyectable para testearlas sin reloj real.
library;

/// Palabras y formatos de fecha de un idioma. Las funciones de abajo
/// reciben uno; por defecto, español (el de la app antes de los idiomas).
/// La UI arma el del idioma activo con `noteDateWordsOf(context.l10n)`.
class NoteDateWords {
  final String today;
  final String yesterday;
  final String thisWeek;

  /// 12 nombres de mes en minúscula (enero…diciembre).
  final List<String> months;

  /// 12 abreviaturas (ene…dic).
  final List<String> monthsShort;

  /// Arma "28 oct" / "Oct 28".
  final String Function(int day, String month) shortDate;

  /// Arma "2 mar 2025" / "Mar 2, 2025".
  final String Function(int day, String month, int year) shortDateYear;

  /// Arma "Diciembre 2025".
  final String Function(String month, int year) monthYear;

  const NoteDateWords({
    required this.today,
    required this.yesterday,
    required this.thisWeek,
    required this.months,
    required this.monthsShort,
    required this.shortDate,
    required this.shortDateYear,
    required this.monthYear,
  });

  /// Si [label] es "Hoy" o "Ayer" (o su equivalente en este idioma).
  bool isRecent(String label) => label == today || label == yesterday;
}

String _esShort(int d, String m) => '$d $m';
String _esShortYear(int d, String m, int y) => '$d $m $y';
String _esMonthYear(String m, int y) => '$m $y';

const NoteDateWords kNoteDateWordsEs = NoteDateWords(
  today: 'Hoy',
  yesterday: 'Ayer',
  thisWeek: 'Esta semana',
  months: [
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
  ],
  monthsShort: [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ],
  shortDate: _esShort,
  shortDateYear: _esShortYear,
  monthYear: _esMonthYear,
);

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Días calendario entre [t] y [now] (0 = hoy). Fechas futuras cuentan como hoy.
int _daysAgo(DateTime t, DateTime now) {
  final diff = _day(now).difference(_day(t)).inHours;
  // inHours/24 redondeado: absorbe el día de 23/25 h del cambio de horario.
  return diff <= 0 ? 0 : (diff / 24).round();
}

/// Título de sección para una nota editada en [t].
String noteGroupLabel(DateTime t,
    {DateTime? now, NoteDateWords words = kNoteDateWordsEs}) {
  final ref = now ?? DateTime.now();
  final days = _daysAgo(t, ref);
  if (days == 0) return words.today;
  if (days == 1) return words.yesterday;
  if (days < 7) return words.thisWeek;
  final month = words.months[t.month - 1];
  final label = '${month[0].toUpperCase()}${month.substring(1)}';
  return t.year == ref.year ? label : words.monthYear(label, t.year);
}

String _hourMinute(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

String _shortDate(DateTime t, DateTime ref, NoteDateWords words) {
  final month = words.monthsShort[t.month - 1];
  return t.year == ref.year
      ? words.shortDate(t.day, month)
      : words.shortDateYear(t.day, month, t.year);
}

/// Hora (hoy y ayer) o fecha corta "28 oct" (más viejo) de una tarjeta.
String noteTimeLabel(DateTime t,
    {DateTime? now, NoteDateWords words = kNoteDateWordsEs}) {
  final ref = now ?? DateTime.now();
  if (_daysAgo(t, ref) <= 1) return _hourMinute(t);
  return _shortDate(t, ref, words);
}

/// Grupo de un día del Historial: "Hoy", "Ayer" o la fecha corta "6 nov"
/// (con el año si no es el actual).
String historyDayLabel(DateTime t,
    {DateTime? now, NoteDateWords words = kNoteDateWordsEs}) {
  final ref = now ?? DateTime.now();
  final days = _daysAgo(t, ref);
  if (days == 0) return words.today;
  if (days == 1) return words.yesterday;
  return _shortDate(t, ref, words);
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
  /// [locale] entra en la clave: cambiar de idioma rehace las etiquetas.
  List<GroupedRow<T>> resolve(
    List<T> source,
    String query, {
    required List<GroupedRow<T>> Function() build,
    DateTime? now,
    String locale = '',
  }) {
    final ref = now ?? DateTime.now();
    final key = '${ref.year}-${ref.month}-${ref.day}|$locale|$query';
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
