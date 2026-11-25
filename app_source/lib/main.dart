import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_info.dart';
import 'l10n/app_localizations.dart';
import 'services/pro_service.dart';
import 'services/storage_service.dart';
import 'ui/app_locale.dart';
import 'ui/design_tokens.dart';
import 'ui/horizon_intro.dart';
import 'ui/theme_mode.dart';
import 'screens/home_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Historial persistente FIFO-20: sin purga al arrancar.
  try {
    final prefs = await SharedPreferences.getInstance();
    appThemeMode.value =
        themeModeFromStorage(prefs.getString('theme_mode') ?? 'sistema');
    appLocale.value = localeFromStorage(
        prefs.getString(StorageService.appLocaleKey) ?? 'sistema');
  } catch (_) {}
  // Android 13+: el idioma pudo cambiarse desde Ajustes del sistema.
  unawaited(_syncAppLocaleFromSystem());
  // T15: la prueba de 30 días arranca con el primer uso; las compras de
  // Play se escuchan desde el arranque (también las pendientes).
  unawaited(ProGate.ensureTrialStarted());
  unawaited(ProService.instance.init());
  // Arranque en frío del proceso: con la animación Horizonte (una vez).
  runApp(const VoiceBubbleApp(showIntro: true));
}

Future<void> _syncAppLocaleFromSystem() async {
  final code = await AppLocaleChannel.current();
  if (code == null || !StorageService.appLocales.contains(code)) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(StorageService.appLocaleKey) != code) {
      await prefs.setString(StorageService.appLocaleKey, code);
    }
  } catch (_) {}
  appLocale.value = localeFromStorage(code);
}

class VoiceBubbleApp extends StatelessWidget {
  /// Animación de arranque sobre Inicio (design.md §15). Apagada por
  /// defecto: solo `main()` la pide; un test la enciende explícitamente.
  /// Igual se muestra una sola vez por proceso.
  final bool showIntro;

  const VoiceBubbleApp({super.key, this.showIntro = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (_, mode, __) => ValueListenableBuilder<Locale?>(
        valueListenable: appLocale,
        builder: (_, locale, __) => MaterialApp(
          title: AppInfo.name,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          home: showIntro
              ? const HorizonIntroHost(homeBuilder: _homeWithHoleKey)
              : const HomeScreen(),
        ),
      ),
    );
  }
}

Widget _homeWithHoleKey(GlobalKey holeKey) =>
    HomeScreen(holeKey: holeKey, showOnboarding: true);
