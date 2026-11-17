import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
import '../helpers/note_groups.dart';

/// Atajo: `context.l10n.clave` en vez de `AppLocalizations.of(context).clave`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Palabras de fecha del idioma activo para `helpers/note_groups.dart`.
NoteDateWords noteDateWordsOf(AppLocalizations l10n) => NoteDateWords(
      today: l10n.dateToday,
      yesterday: l10n.dateYesterday,
      thisWeek: l10n.dateThisWeek,
      months: l10n.dateMonths.split(','),
      monthsShort: l10n.dateMonthsShort.split(','),
      shortDate: (d, m) => l10n.dateShort('$d', m),
      shortDateYear: (d, m, y) => l10n.dateShortYear('$d', m, '$y'),
      monthYear: (m, y) => l10n.dateMonthYear(m, '$y'),
    );
