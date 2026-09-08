import 'package:flutter/material.dart';

/// Tab Burbuja de Ajustes (SPK-06, módulo 2 de N): sección independiente
/// de burbuja flotante, extraída de SettingsScreen sin cambiar conducta.
/// El árbol visible (Keys, textos) es idéntico: los tests existentes
/// lo verifican sin cambios.
class BurbujaTab extends StatelessWidget {
  final bool isBubbleEnabled;
  final ValueChanged<bool> onToggleBubble;
  final bool showBubbleHistory;
  final ValueChanged<bool> onToggleBubbleHistory;
  final VoidCallback onReviewOverlayPermission;

  const BurbujaTab({
    super.key,
    required this.isBubbleEnabled,
    required this.onToggleBubble,
    required this.showBubbleHistory,
    required this.onToggleBubbleHistory,
    required this.onReviewOverlayPermission,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variantColor = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'Burbuja flotante',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Sección independiente. Flota sobre otras apps para dictar.',
          style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activar burbuja flotante'),
          subtitle: const Text(
            'Flota sobre otras aplicaciones para transcribir y copiar texto al instante.',
          ),
          value: isBubbleEnabled,
          onChanged: onToggleBubble,
        ),
        SwitchListTile(
          key: const ValueKey('bubble-history-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Historial en la burbuja'),
          subtitle: const Text(
            'El toque largo sobre la burbuja abre el historial con morph inteligente. Apagado: el toque largo no hace nada.',
          ),
          value: showBubbleHistory,
          onChanged: onToggleBubbleHistory,
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Permiso de superposición',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Android exige permitir “mostrar sobre otras apps”. Sin esto la burbuja no puede flotar.',
          style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onReviewOverlayPermission,
          child: const Text('Revisar'),
        ),
        const SizedBox(height: 8),
        Text(
          'Guía rápida: arrastra la burbuja para moverla · tócala para grabar y vuelve a tocarla para transcribir.',
          style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
        ),
      ],
    );
  }
}
