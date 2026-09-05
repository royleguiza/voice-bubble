import 'dart:ui';
import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Contenedor Liquid Glass reutilizable (design.md §7.1: nadie arma glass a mano).
///
/// Aplica blur + fill translúcido según brightness del tema, borde especular
/// 1px y sombra de profundidad. [small] selecciona la variante de elementos
/// chicos (blur 12 / sombra corta) vs grandes (blur 24 / sombra profunda).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool small;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = kBorderRadiusCard,
    this.small = true,
    this.padding,
  });

  /// Filtros compartidos: ImageFilter.blur crea un objeto nativo por
  /// construcción y GlassContainer se reconstruye en cada frame de
  /// animaciones y por cada carácter del form de snippets. Reutilizar dos
  /// instancias elimina ese costo GPU sin cambiar el efecto visual.
  static final ImageFilter _blurSmall = ImageFilter.blur(
    sigmaX: kGlassBlurSmall,
    sigmaY: kGlassBlurSmall,
  );
  static final ImageFilter _blurLarge = ImageFilter.blur(
    sigmaX: kGlassBlurLarge,
    sigmaY: kGlassBlurLarge,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: small ? _blurSmall : _blurLarge,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: kGlassOpacityDark)
                : Colors.white.withValues(alpha: kGlassOpacityLight),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark ? kGlassBorderDark : kGlassBorderLight,
            ),
            boxShadow: [
              small
                  ? (isDark ? kGlassShadowSmallDark : kGlassShadowSmallLight)
                  : (isDark ? kGlassShadowDark : kGlassShadowLight),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
