import 'dart:ui';
import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Contenedor Liquid Glass reutilizable (design.md §7.1: nadie arma glass a mano).
///
/// Aplica blur + fill translúcido según brightness del tema, borde especular
/// 1px y sombra de profundidad. [small] selecciona la variante de elementos
/// chicos (blur 12 / sombra corta) vs grandes (blur 24 / sombra profunda).
///
/// Accesibilidad (C-31 / design.md §9): se adapta a las preferencias del sistema
/// de reducción de transparencia (`accessibleNavigationOf`) y alto contraste
/// (`highContrastOf`). Cuando alguna de ellas está activa, el fill se vuelve
/// opaco, el blur se reduce a 2px y el borde se refuerza a 2px.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool small;

  /// Variante "Crystal" (settings-redesign-v2): blur 10, fill vivo,
  /// borde 1.5px y highlight diagonal. Rige tab bar y sheets.
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

  /// Filtros compartidos: ImageFilter.blur crea un objeto nativo por
  /// construcción y GlassContainer se reconstruye en cada frame de
  /// animaciones y por cada carácter del form de snippets. Reutilizar
  /// instancias elimina ese costo GPU sin cambiar el efecto visual.
  static final ImageFilter _blurSmall = ImageFilter.blur(
    sigmaX: kGlassBlurSmall,
    sigmaY: kGlassBlurSmall,
  );
  static final ImageFilter _blurLarge = ImageFilter.blur(
    sigmaX: kGlassBlurLarge,
    sigmaY: kGlassBlurLarge,
  );
  static final ImageFilter _blurCrystal = ImageFilter.blur(
    sigmaX: kGlassBlurCrystal,
    sigmaY: kGlassBlurCrystal,
  );
  static final ImageFilter _blurReduced = ImageFilter.blur(
    sigmaX: kGlassBlurReduced,
    sigmaY: kGlassBlurReduced,
  );

  ImageFilter get _filter =>
      crystal ? _blurCrystal : (small ? _blurSmall : _blurLarge);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHighContrast =
        highContrast ?? MediaQuery.highContrastOf(context);
    final isReduceTransparency =
        reduceTransparency ?? MediaQuery.accessibleNavigationOf(context);
    final bool isAccessible = isHighContrast || isReduceTransparency;

    final ImageFilter filter = isAccessible ? _blurReduced : _filter;

    final Color fill;
    final Color borderColor;
    final double borderWidth;
    final BoxShadow shadow;
    if (isHighContrast) {
      fill = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      borderColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
      borderWidth = kGlassBorderWidthAccessible;
      shadow = small
          ? (isDark ? kGlassShadowSmallDark : kGlassShadowSmallLight)
          : (isDark ? kGlassShadowDark : kGlassShadowLight);
    } else if (isReduceTransparency) {
      fill = isDark ? kBgElevatedDark : kBgElevatedLight;
      borderColor =
          isDark ? kGlassBorderCrystalDark : kGlassBorderCrystalLight;
      borderWidth = kGlassBorderWidthAccessible;
      shadow = small
          ? (isDark ? kGlassShadowSmallDark : kGlassShadowSmallLight)
          : (isDark ? kGlassShadowDark : kGlassShadowLight);
    } else if (crystal) {
      fill = isDark ? kGlassFillCrystalDark : kGlassFillCrystalLight;
      borderColor =
          isDark ? kGlassBorderCrystalDark : kGlassBorderCrystalLight;
      borderWidth = 1.5;
      shadow = isDark ? kGlassShadowCrystalDark : kGlassShadowCrystalLight;
    } else {
      fill = isDark
          ? Colors.black.withValues(alpha: kGlassOpacityDark)
          : Colors.white.withValues(alpha: kGlassOpacityLight);
      borderColor = isDark ? kGlassBorderDark : kGlassBorderLight;
      borderWidth = 1.0;
      shadow = small
          ? (isDark ? kGlassShadowSmallDark : kGlassShadowSmallLight)
          : (isDark ? kGlassShadowDark : kGlassShadowLight);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: filter,
        child: Container(
          padding: padding,
          foregroundDecoration: (crystal && !isAccessible)
              ? BoxDecoration(
                  // Highlight superior simétrico (no diagonal): la misma
                  // luz en todo el ancho para que el dock se vea parejo
                  // de izquierda a derecha en claro y oscuro.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      isDark ? kGlassHighlightDark : kGlassHighlightLight,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35],
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                )
              : null,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: [shadow],
          ),
          child: child,
        ),
      ),
    );
  }
}
