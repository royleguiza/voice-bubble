import 'package:flutter/material.dart';

/// Tabla única de iconos (SPK-15): una familia (rounded), 3 tamaños.
///
/// - `kIconSmall` (18): acciones en línea (copiar, nube en listas).
/// - `kIconMedium` (22): tabs, botones de barra, estados.
/// - `kIconLarge` (28): headers de sheets, estados vacíos.
///
/// Prohibido `Icon(..., size: <otro>)` fuera de esta tabla ni mezclar
/// outlined/plain sin justificación (guard CI "Tokens UI").
// ignore: avoid_classes_with_only_static_members
class AppIcons {
  static const double small = 18;
  static const double medium = 22;
  static const double large = 28;
}
