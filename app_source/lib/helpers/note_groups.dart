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
