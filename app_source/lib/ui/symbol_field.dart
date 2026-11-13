import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Campo de símbolos de Horizonte (maqueta "Pantalla vacía"): tres
/// renglones quietos de 0 1 { } [ ] < > · en mono, fg2 tenue.
///
/// Puramente decorativo: fuera del árbol de semántica, sin animación y sin
/// recibir toques. Va solo sobre el título y la ayuda de una lista vacía
/// ([kSymbolFieldOpacity]) o, más tenue, detrás del título grande de
/// Ajustes ([SymbolField.header], [kSymbolFieldHeaderOpacity]); nunca
/// detrás de contenido que haya que leer (design.md §15).
class SymbolField extends StatelessWidget {
  /// Opacidad del glifo sobre fg2.
  final double fieldOpacity;

  const SymbolField({super.key, this.fieldOpacity = kSymbolFieldOpacity});

  /// Variante muy tenue para el encabezado de Ajustes.
  const SymbolField.header({super.key})
      : fieldOpacity = kSymbolFieldHeaderOpacity;

  static const List<String> rows = [
    '1 0 { } 0 1',
    '· [ ] 1 · 0',
    '0 · < > 1 ·',
  ];

  /// Opacidad de las pantallas vacías (alias histórico del token).
  static const double opacity = kSymbolFieldOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = (isDark ? kLabelSecondaryDark : kLabelSecondaryLight)
        .withValues(alpha: fieldOpacity);
    final style = kTextMono.copyWith(
      fontSize: kSymbolFieldFontSize,
      height: 2,
      letterSpacing: 6,
      color: color,
    );
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Column(
          key: const ValueKey('symbolField'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              Text(row, textAlign: TextAlign.center, style: style),
          ],
        ),
      ),
    );
  }
}
