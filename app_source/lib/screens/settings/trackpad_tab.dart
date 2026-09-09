import 'package:flutter/material.dart';

/// Tab Trackpad de Ajustes (SPK-06, módulo 5 de N): superficie split wings
/// + sensibilidad + curvas + botones, extraído de SettingsScreen
/// sin cambiar conducta.
class TrackpadTab extends StatelessWidget {
  final bool trackpadEnabled;
  final ValueChanged<bool> onToggleTrackpadEnabled;
  final bool trackpadToolbarVisible;
  final ValueChanged<bool> onToggleTrackpadToolbarVisible;
  final String trackpadButtonLayout;
  final ValueChanged<String> onSaveTrackpadButtonLayout;
  final String trackpadScrollPosition;
  final ValueChanged<String> onSaveTrackpadScrollPosition;
  final double trackpadSensitivity;
  final ValueChanged<double> onTrackpadSensitivitySlider;
  final String trackpadAccelCurve;
  final ValueChanged<String> onSaveTrackpadAccelCurve;
  final bool trackpadTapToClick;
  final ValueChanged<bool> onToggleTrackpadTapToClick;
  final String trackpadSecondaryClick;
  final ValueChanged<String> onSaveTrackpadSecondaryClick;
  final String trackpadScrollDirection;
  final ValueChanged<String> onSaveTrackpadScrollDirection;
  final String trackpadPointerStyle;
  final ValueChanged<String> onSaveTrackpadPointerStyle;
  final String trackpadHaptic;
  final ValueChanged<String> onSaveTrackpadHaptic;
  final int trackpadAutoReturn;
  final ValueChanged<int> onSaveTrackpadAutoReturn;

  const TrackpadTab({
    super.key,
    required this.trackpadEnabled,
    required this.onToggleTrackpadEnabled,
    required this.trackpadToolbarVisible,
    required this.onToggleTrackpadToolbarVisible,
    required this.trackpadButtonLayout,
    required this.onSaveTrackpadButtonLayout,
    required this.trackpadScrollPosition,
    required this.onSaveTrackpadScrollPosition,
    required this.trackpadSensitivity,
    required this.onTrackpadSensitivitySlider,
    required this.trackpadAccelCurve,
    required this.onSaveTrackpadAccelCurve,
    required this.trackpadTapToClick,
    required this.onToggleTrackpadTapToClick,
    required this.trackpadSecondaryClick,
    required this.onSaveTrackpadSecondaryClick,
    required this.trackpadScrollDirection,
    required this.onSaveTrackpadScrollDirection,
    required this.trackpadPointerStyle,
    required this.onSaveTrackpadPointerStyle,
    required this.trackpadHaptic,
    required this.onSaveTrackpadHaptic,
    required this.trackpadAutoReturn,
    required this.onSaveTrackpadAutoReturn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variantColor = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'Trackpad',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Sección propia y separada del teclado.',
          style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Modo Trackpad y Puntero Virtual',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.near_me,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Superficie Táctil Split Wings',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Controla un puntero virtual en pantalla con aceleración cinemática y botones dedicados para pulgares.',
                  style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Puntero local: no hace clic fuera de su ventana sin accesibilidad (dormida).',
                  style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activar modo trackpad'),
                  subtitle: Text(
                    'Habilita la capa de trackpad con puntero de mouse en el teclado.',
                    style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
                  ),
                  value: trackpadEnabled,
                  onChanged: onToggleTrackpadEnabled,
                ),
                if (trackpadEnabled) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Botón en barra superior'),
                    subtitle: Text(
                      'Muestra el acceso rápido al trackpad en la barra interactiva del teclado.',
                      style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
                    ),
                    value: trackpadToolbarVisible,
                    onChanged: onToggleTrackpadToolbarVisible,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Distribución de Botones de Clic',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    key: const ValueKey('kb-trackpad-button-layout-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'top', label: Text('Superiores 50/50')),
                      ButtonSegment(value: 'wings', label: Text('Laterales (Alas)')),
                    ],
                    selected: {trackpadButtonLayout},
                    onSelectionChanged: (s) => onSaveTrackpadButtonLayout(s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trackpadButtonLayout == 'top'
                        ? 'Botones L y R divididos al 50% arriba con iconos limpios sin texto.'
                        : 'Botones ergonómicos en columnas laterales para acceso rápido con pulgares.',
                    style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Posición de la Barra de Scroll',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    key: const ValueKey('kb-trackpad-scroll-position-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'right', label: Text('Derecha')),
                      ButtonSegment(value: 'left', label: Text('Izquierda')),
                      ButtonSegment(value: 'disabled', label: Text('Desactivada')),
                    ],
                    selected: {trackpadScrollPosition},
                    onSelectionChanged: (s) => onSaveTrackpadScrollPosition(s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Auto-expansión al 100%: cuando el scroll está en un ala o apagado, los botones de clic ocupan toda la altura (200dp).',
                    style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sensibilidad del puntero',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '${trackpadSensitivity.toStringAsFixed(1)}x',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    key: const ValueKey('kb-trackpad-sensitivity-slider'),
                    value: trackpadSensitivity,
                    min: 0.5,
                    max: 2.5,
                    divisions: 20,
                    label: '${trackpadSensitivity.toStringAsFixed(1)}x',
                    onChanged: onTrackpadSensitivitySlider,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Curva de Aceleración',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    key: const ValueKey('kb-trackpad-accel-curve-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'dynamic', label: Text('Dinámica')),
                      ButtonSegment(value: 'linear', label: Text('Lineal')),
                      ButtonSegment(value: 'precision', label: Text('Precisión')),
                    ],
                    selected: {trackpadAccelCurve},
                    onSelectionChanged: (s) => onSaveTrackpadAccelCurve(s.first),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tocar para hacer clic (Tap-to-Click)'),
                    subtitle: Text(
                      'Un toque rápido en la superficie táctil dispara un clic izquierdo.',
                      style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
                    ),
                    value: trackpadTapToClick,
                    onChanged: onToggleTrackpadTapToClick,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Clic Secundario (Menú contextual)',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    key: const ValueKey('kb-trackpad-secondary-click-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: '2fingers', label: Text('2 Dedos')),
                      ButtonSegment(value: 'button', label: Text('Botón R')),
                      ButtonSegment(value: 'hold', label: Text('Mantener')),
                    ],
                    selected: {trackpadSecondaryClick},
                    onSelectionChanged: (s) => onSaveTrackpadSecondaryClick(s.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dirección de Scroll',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    key: const ValueKey('kb-trackpad-scroll-direction-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'natural', label: Text('Natural (iOS)')),
                      ButtonSegment(value: 'standard', label: Text('Estándar (PC)')),
                    ],
                    selected: {trackpadScrollDirection},
                    onSelectionChanged: (s) => onSaveTrackpadScrollDirection(s.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Estilo Visual del Puntero',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    key: const ValueKey('kb-trackpad-pointer-style-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'arrow', label: Text('Flecha')),
                      ButtonSegment(value: 'dot', label: Text('Punto')),
                      ButtonSegment(value: 'cross', label: Text('Cruz')),
                    ],
                    selected: {trackpadPointerStyle},
                    onSelectionChanged: (s) => onSaveTrackpadPointerStyle(s.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vibración Háptica del Trackpad',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    key: const ValueKey('kb-trackpad-haptic-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'subtle', label: Text('Sutil')),
                      ButtonSegment(value: 'firm', label: Text('Firme')),
                      ButtonSegment(value: 'none', label: Text('Ninguna')),
                    ],
                    selected: {trackpadHaptic},
                    onSelectionChanged: (s) => onSaveTrackpadHaptic(s.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Auto-retorno al Teclado por Inactividad',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    key: const ValueKey('kb-trackpad-auto-return-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Off')),
                      ButtonSegment(value: 5, label: Text('5s')),
                      ButtonSegment(value: 15, label: Text('15s')),
                      ButtonSegment(value: 30, label: Text('30s')),
                    ],
                    selected: {trackpadAutoReturn},
                    onSelectionChanged: (s) => onSaveTrackpadAutoReturn(s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vuelve a la capa alfabética automáticamente si no se detectan toques tras el tiempo elegido.',
                    style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
