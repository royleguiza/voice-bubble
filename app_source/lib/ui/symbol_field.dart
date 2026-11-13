import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Campo de símbolos de las pantallas vacías (Horizonte, maqueta "Pantalla
/// vacía"): tres renglones quietos de 0 1 { } [ ] < > · en mono, fg2 tenue.
///
/// Puramente decorativo: fuera del árbol de semántica y sin animación. Va
/// solo sobre el título y la ayuda de una lista vacía, nunca detrás de
/// contenido que haya que leer.
class SymbolField extends StatelessWidget {
  const SymbolField({super.key});

  static const List<String> rows = [
    '1 0 { } 0 1',
    '· [ ] 1 · 0',
    '0 · < > 1 ·',
  ];

  /// Opacidad del glifo sobre fg2: presente pero en segundo plano.
  static const double opacity = 0.5;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = (isDark ? kLabelSecondaryDark : kLabelSecondaryLight)
        .withValues(alpha: opacity);
    final style = kTextMono.copyWith(
      fontSize: 13,
      height: 2,
      letterSpacing: 6,
      color: color,
    );
    return ExcludeSemantics(
      child: Column(
        key: const ValueKey('symbolField'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Text(row, textAlign: TextAlign.center, style: style),
        ],
      ),
    );
  }
}
