import 'package:flutter/material.dart';
import 'package:voice_bubble_stt/l10n/app_localizations.dart';

/// `MaterialApp` de tests con los delegados de idioma y `locale: es`:
/// los textos de la UI salen de `app_es.arb`, igual que en la app real.
MaterialApp esMaterialApp({
  Key? key,
  Widget? home,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
  TransitionBuilder? builder,
}) {
  return MaterialApp(
    key: key,
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    darkTheme: darkTheme,
    themeMode: themeMode,
    builder: builder,
    home: home,
  );
}
