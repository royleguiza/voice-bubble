import 'package:flutter/material.dart';

/// Modo de tema vivo de la app (rediseño v2: Sistema/Claro/Oscuro desde
/// Acerca de). Vive aquí (no en main.dart) para evitar import circular
/// main → home → settings → main.
final ValueNotifier<ThemeMode> appThemeMode =
    ValueNotifier<ThemeMode>(ThemeMode.system);

ThemeMode themeModeFromStorage(String raw) {
  switch (raw) {
    case 'claro':
      return ThemeMode.light;
    case 'oscuro':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}
