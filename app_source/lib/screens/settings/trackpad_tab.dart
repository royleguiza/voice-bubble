import 'package:flutter/material.dart';

import '../../ui/design_tokens.dart';
import '../../widgets/settings_v2.dart';

/// Tab Trackpad de Ajustes (rediseño v2): superficie + sensibilidad con
/// chips + interacción + apariencia expandible. Misma conducta, mismos
/// textos y Keys que v1.
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

  static const _sensitivityChips = <double, String>{
    0.5: '0.5x',
    1.0: '1.0x',
    1.5: '1.5x',
    2.0: '2.0x',
  };

  double get _snappedSensitivity {
    var best = _sensitivityChips.keys.first;
    for (final v in _sensitivityChips.keys) {
      if ((trackpadSensitivity - v).abs() <
          (trackpadSensitivity - best).abs()) {
        best = v;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variantColor = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        const SettingsPageTitle('Trackpad'),
        Text(
          'Modo Trackpad y Puntero Virtual',
          style: kSettingRowTitle.copyWith(
            color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Modo Trackpad y Puntero Virtual',
          style: kSettingRowTitle.copyWith(
            color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const SettingIconTile(
                    icon: Icons.near_me_rounded,
                    background: kTilePink,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Superficie Táctil Split Wings',
                      style: kSettingRowTitle.copyWith(
                        color: isDark
                            ? kLabelPrimaryDark
                            : kLabelPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Controla un puntero virtual en pantalla con aceleración cinemática y botones dedicados para pulgares.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: variantColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Puntero local: no hace clic fuera de su ventana sin accesibilidad (dormida).',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: variantColor),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Activar modo trackpad'),
              subtitle: Text(
                'Habilita la capa de trackpad con puntero de mouse en el teclado.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: variantColor),
              ),
              value: trackpadEnabled,
              onChanged: onToggleTrackpadEnabled,
            ),
            if (trackpadEnabled) ...[
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('Botón en barra superior'),
                subtitle: Text(
                  'Muestra el acceso rápido al trackpad en la barra interactiva del teclado.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: variantColor),
                ),
                value: trackpadToolbarVisible,
                onChanged: onToggleTrackpadToolbarVisible,
              ),
            ],
          ],
        ),
        if (trackpadEnabled) ...[
          const SettingsGroupTitle('Sensibilidad y Control'),
          SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Velocidad del puntero',
                          style: kSettingRowTitle.copyWith(
                            color: isDark
                                ? kLabelPrimaryDark
                                : kLabelPrimaryLight,
                          ),
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
                    const SizedBox(height: 4),
                    Center(
                      child: SliderChips<double>(
                        options: _sensitivityChips,
                        selected: _snappedSensitivity,
                        onSelected: onTrackpadSensitivitySlider,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Curva de Aceleración',
                      style: kSettingRowTitle.copyWith(
                        color: isDark
                            ? kLabelPrimaryDark
                            : kLabelPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      key: const ValueKey(
                          'kb-trackpad-accel-curve-selector'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: 'dynamic', label: Text('Dinámica')),
                        ButtonSegment(
                            value: 'linear', label: Text('Lineal')),
                        ButtonSegment(
                            value: 'precision', label: Text('Precisión')),
                      ],
                      selected: {trackpadAccelCurve},
                      onSelectionChanged: (s) =>
                          onSaveTrackpadAccelCurve(s.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SettingsGroupTitle('Interacción'),
          SettingsCard(
            children: [
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('Tocar para hacer clic (Tap-to-Click)'),
                subtitle: Text(
                  'Un toque rápido en la superficie táctil dispara un clic izquierdo.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: variantColor),
                ),
                value: trackpadTapToClick,
                onChanged: onToggleTrackpadTapToClick,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clic Secundario (Menú contextual)',
                      style: kSettingRowTitle.copyWith(
                        color: isDark
                            ? kLabelPrimaryDark
                            : kLabelPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      key: const ValueKey(
                          'kb-trackpad-secondary-click-selector'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: '2fingers', label: Text('2 Dedos')),
                        ButtonSegment(
                            value: 'button', label: Text('Botón R')),
                        ButtonSegment(
                            value: 'hold', label: Text('Mantener')),
                      ],
                      selected: {trackpadSecondaryClick},
                      onSelectionChanged: (s) =>
                          onSaveTrackpadSecondaryClick(s.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ExpandableSettingsCard(
            icon: Icons.tune_rounded,
            iconColor: kTileGray,
            title: 'Apariencia y Layout',
            children: [
              _TrackpadSegmentedBlock(
                label: 'Distribución de Botones de Clic',
                selectorKey: 'kb-trackpad-button-layout-selector',
                options: const {
                  'top': 'Superiores 50/50',
                  'wings': 'Laterales (Alas)',
                },
                selected: trackpadButtonLayout,
                onSelected: onSaveTrackpadButtonLayout,
                hint: trackpadButtonLayout == 'top'
                    ? 'Botones L y R divididos al 50% arriba con iconos limpios sin texto.'
                    : 'Botones ergonómicos en columnas laterales para acceso rápido con pulgares.',
              ),
              const SizedBox(height: 12),
              _TrackpadSegmentedBlock(
                label: 'Posición de la Barra de Scroll',
                selectorKey: 'kb-trackpad-scroll-position-selector',
                options: const {
                  'right': 'Derecha',
                  'left': 'Izquierda',
                  'disabled': 'Desactivada',
                },
                selected: trackpadScrollPosition,
                onSelected: onSaveTrackpadScrollPosition,
                hint:
                    'Auto-expansión al 100%: cuando el scroll está en un ala o apagado, los botones de clic ocupan toda la altura (200dp).',
              ),
              const SizedBox(height: 12),
              _TrackpadSegmentedBlock(
                label: 'Dirección de Scroll',
                selectorKey: 'kb-trackpad-scroll-direction-selector',
                options: const {
                  'natural': 'Natural (iOS)',
                  'standard': 'Estándar (PC)',
                },
                selected: trackpadScrollDirection,
                onSelected: onSaveTrackpadScrollDirection,
              ),
              const SizedBox(height: 12),
              _TrackpadSegmentedBlock(
                label: 'Estilo Visual del Puntero',
                selectorKey: 'kb-trackpad-pointer-style-selector',
                options: const {
                  'arrow': 'Flecha',
                  'dot': 'Punto',
                  'cross': 'Cruz',
                },
                selected: trackpadPointerStyle,
                onSelected: onSaveTrackpadPointerStyle,
              ),
              const SizedBox(height: 12),
              _TrackpadSegmentedBlock(
                label: 'Vibración Háptica del Trackpad',
                selectorKey: 'kb-trackpad-haptic-selector',
                options: const {
                  'subtle': 'Sutil',
                  'firm': 'Firme',
                  'none': 'Ninguna',
                },
                selected: trackpadHaptic,
                onSelected: onSaveTrackpadHaptic,
              ),
              const SizedBox(height: 12),
              Text(
                'Auto-retorno al Teclado por Inactividad',
                style: kSettingRowTitle.copyWith(
                  color:
                      isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
                ),
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
                onSelectionChanged: (s) =>
                    onSaveTrackpadAutoReturn(s.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Vuelve a la capa alfabética automáticamente si no se detectan toques tras el tiempo elegido.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: variantColor),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Bloque segmented + hint para el expandible del trackpad.
class _TrackpadSegmentedBlock extends StatelessWidget {
  final String label;
  final String selectorKey;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final String? hint;

  const _TrackpadSegmentedBlock({
    required this.label,
    required this.selectorKey,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: kSettingRowTitle.copyWith(
            color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          key: ValueKey(selectorKey),
          showSelectedIcon: false,
          segments: [
            for (final entry in options.entries)
              ButtonSegment(value: entry.key, label: Text(entry.value)),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onSelected(s.first),
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
