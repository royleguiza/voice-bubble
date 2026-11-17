import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

/// Atajo: `context.l10n.clave` en vez de `AppLocalizations.of(context).clave`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
