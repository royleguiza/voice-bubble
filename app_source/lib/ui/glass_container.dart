import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Superficie sólida reutilizable (Horizonte, design.md §7).
///
/// Conserva el nombre y la API del antiguo contenedor de vidrio para no
/// tocar los call sites, pero ya no desenfoca: Horizonte prohíbe el blur en
/// la app. Pinta superficie (surf) + borde de línea (line) de 1 px.
/// [small] y [crystal] se aceptan por compatibilidad y no cambian el
/// aspecto: todas las superficies son iguales.
///
/// Accesibilidad (C-31 / design.md §9): con alto contraste
/// (`highContrastOf`) el fondo pasa a blanco/negro puro y el borde a
/// fg con 2 px; con transparencia reducida (`accessibleNavigationOf`) el
/// borde se refuerza a 2 px. La superficie ya es opaca en todos los casos.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  /// Compatibilidad: variante chica/grande del vidrio retirado.
  final bool small;

  /// Compatibilidad: variante "Crystal" del vidrio retirado.
  final bool crystal;
  final EdgeInsetsGeometry? padding;

  /// Preferencia explícita de reducción de transparencia. Si es null,
  /// consulta [MediaQuery.accessibleNavigationOf].
  final bool? reduceTransparency;

  /// Preferencia explícita de alto contraste. Si es null,
  /// consulta [MediaQuery.highContrastOf].
  final bool? highContrast;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = kBorderRadiusCard,
    this.small = true,
    this.crystal = false,
    this.padding,
    this.reduceTransparency,
    this.highContrast,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHighContrast = highContrast ?? MediaQuery.highContrastOf(context);
    final isReduceTransparency =
        reduceTransparency ?? MediaQuery.accessibleNavigationOf(context);
    final bool isAccessible = isHighContrast || isReduceTransparency;

    final Color fill;
    final Color borderColor;
    if (isHighContrast) {
      fill = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      borderColor = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    } else {
      fill = isDark ? kBgElevatedDark : kBgElevatedLight;
      borderColor = isDark ? kGlassBorderDark : kGlassBorderLight;
    }
    final double borderWidth =
        isAccessible ? kGlassBorderWidthAccessible : kSurfaceBorderWidth;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: child,
      ),
    );
  }
}
