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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: small ? kGlassBlurSmall : kGlassBlurLarge,
          sigmaY: small ? kGlassBlurSmall : kGlassBlurLarge,
        ),
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
