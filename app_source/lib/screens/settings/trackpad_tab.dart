part of '../settings_screen.dart';

/// Página Trackpad: arriba el puntero en otras apps (complemento
/// VoiceBubble Puntero, lo abre la barra flotante) y el trackpad del
/// teclado; el ajuste fino solo aparece si alguno de los dos está en uso.
extension _TrackpadPage on _SettingsScreenState {
  Widget _buildTrackpadPage(BuildContext context) {
    final status = _pointerStatus;
    final statusLabel = switch (status) {
      FloatingTrackpadService.pointerReady => 'Activo',
      FloatingTrackpadService.pointerDisabled => 'Activar',
      _ => 'No instalado',
    };
    final statusFooter = switch (status) {
      FloatingTrackpadService.pointerReady =>
        'Los clics del puntero llegan a cualquier app. No lee la pantalla '
            'ni guarda nada.',
      FloatingTrackpadService.pointerDisabled =>
        'Activalo en Accesibilidad. Si Android dice «Ajuste restringido», '
            'tocá Permitir ajustes restringidos y volvé a intentar.',
      _ => 'Para hacer clic en otras apps hace falta el complemento '
          'VoiceBubble Puntero. Sin él, el puntero se mueve pero no hace clic.',
    };
    return _subpage(
      context,
      title: 'Trackpad',
      sections: [
        SettingsSection(
          header: 'Puntero en otras apps',
          footer: statusFooter,
          children: [
            SettingsNavRow(
              key: const ValueKey('pointer-companion-row'),
              title: 'VoiceBubble Puntero',
              value: statusLabel,
              valueActive: status == FloatingTrackpadService.pointerReady,
              valueColor: status == FloatingTrackpadService.pointerReady
                  ? null
                  : SettingsPalette.of(context).alert,
              onTap: _onPointerCompanionTap,
            ),
            if (status == FloatingTrackpadService.pointerDisabled)
              SettingsActionRow(
                key: const ValueKey('pointer-restricted-row'),
                title: 'Permitir ajustes restringidos',
                onTap: _floatingTrackpadService.openCompanionDetails,
              ),
          ],
        ),
        SettingsSection(
          footer: 'Se abre desde la barra flotante. Para cerrarlo, tocá la '
              'línea de arriba.',
          children: [
            SettingsMenuRow<String>(
              id: 'pointer-open-mode-selector',
              title: 'Se abre como',
              value: _pointerOpenMode,
              options: const [
                SettingsOption('panel', 'Panel abajo'),
                SettingsOption('window', 'Ventana flotante'),
              ],
              onSelected: _savePointerOpenMode,
            ),
            SettingsMenuRow<int>(
              id: 'kb-trackpad-auto-return-selector',
              title: 'Al soltar',
              value: _trackpadAutoReturn,
              options: const [
                SettingsOption(0, 'Queda abierto'),
                SettingsOption(5, 'Se cierra a los 5 s'),
                SettingsOption(15, 'Se cierra a los 15 s'),
                SettingsOption(30, 'Se cierra a los 30 s'),
              ],
              onSelected: _saveTrackpadAutoReturn,
            ),
          ],
        ),
        SettingsSection(
          header: 'En el teclado',
          footer: 'Un puntero dentro del teclado para mover el cursor con '
              'precisión.',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('kb-trackpad-enabled-switch'),
              title: 'Trackpad en el teclado',
              value: _trackpadEnabled,
              onChanged: _toggleTrackpadEnabled,
            ),
            SettingsSwitchRow(
              key: const ValueKey('kb-trackpad-toolbar-switch'),
              title: 'Acceso en la barra del teclado',
              value: _trackpadToolbarVisible,
              onChanged: _toggleTrackpadToolbarVisible,
            ),
          ],
        ),
        if (_trackpadEnabled || _dockToolPointer) ...[
          SettingsSection(
            header: 'Puntero',
            children: [
              TrackpadSensitivitySection(
                sensitivity: _trackpadSensitivity,
                onSensitivityChanged: _onTrackpadSensitivitySlider,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-accel-curve-selector',
                title: 'Aceleración',
                value: _trackpadAccelCurve,
                options: const [
                  SettingsOption('dynamic', 'Dinámica'),
                  SettingsOption('linear', 'Lineal'),
                  SettingsOption('precision', 'Precisión'),
                ],
                onSelected: _saveTrackpadAccelCurve,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-pointer-style-selector',
                title: 'Forma',
                value: _trackpadPointerStyle,
                options: const [
                  SettingsOption('arrow', 'Flecha'),
                  SettingsOption('dot', 'Punto'),
                  SettingsOption('cross', 'Cruz'),
                ],
                onSelected: _saveTrackpadPointerStyle,
              ),
            ],
          ),
          SettingsSection(
            header: 'Clic',
            children: [
              SettingsSwitchRow(
                key: const ValueKey('kb-trackpad-tap-to-click-switch'),
                title: 'Tocar para hacer clic',
                value: _trackpadTapToClick,
                onChanged: _toggleTrackpadTapToClick,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-secondary-click-selector',
                title: 'Clic secundario',
                value: _trackpadSecondaryClick,
                options: const [
                  SettingsOption('2fingers', 'Dos dedos'),
                  SettingsOption('button', 'Botón derecho'),
                  SettingsOption('hold', 'Mantener'),
                ],
                onSelected: _saveTrackpadSecondaryClick,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-button-layout-selector',
                title: 'Botones',
                value: _trackpadButtonLayout,
                options: const [
                  SettingsOption('top', 'Arriba'),
                  SettingsOption('wings', 'A los lados'),
                ],
                onSelected: _saveTrackpadButtonLayout,
              ),
            ],
          ),
          SettingsSection(
            header: 'Desplazamiento',
            children: [
              SettingsMenuRow<String>(
                id: 'kb-trackpad-scroll-position-selector',
                title: 'Barra de scroll',
                value: _trackpadScrollPosition,
                options: const [
                  SettingsOption('right', 'Derecha'),
                  SettingsOption('left', 'Izquierda'),
                  SettingsOption('disabled', 'Oculta'),
                ],
                onSelected: _saveTrackpadScrollPosition,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-scroll-direction-selector',
                title: 'Dirección',
                value: _trackpadScrollDirection,
                options: const [
                  SettingsOption('natural', 'Natural'),
                  SettingsOption('standard', 'Invertida'),
                ],
                onSelected: _saveTrackpadScrollDirection,
              ),
            ],
          ),
          SettingsSection(
            header: 'Otros',
            children: [
              SettingsMenuRow<String>(
                id: 'kb-trackpad-haptic-selector',
                title: 'Vibración',
                value: _trackpadHaptic,
                options: const [
                  SettingsOption('subtle', 'Sutil'),
                  SettingsOption('firm', 'Firme'),
                  SettingsOption('none', 'Ninguna'),
                ],
                onSelected: _saveTrackpadHaptic,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Fila de velocidad del puntero con estado propio (C-33): el thumb se
/// redibuja solo aquí y el guardado se difiere 150 ms con [Debouncer], sin
/// reconstruir toda la pantalla de Ajustes en cada tick.
class TrackpadSensitivitySection extends StatefulWidget {
  final double sensitivity;
  final ValueChanged<double> onSensitivityChanged;

  const TrackpadSensitivitySection({
    super.key,
    required this.sensitivity,
    required this.onSensitivityChanged,
  });

  @override
  State<TrackpadSensitivitySection> createState() =>
      _TrackpadSensitivitySectionState();
}

class _TrackpadSensitivitySectionState
    extends State<TrackpadSensitivitySection> {
  late double _current;
  late final Debouncer _debouncer;

  @override
  void initState() {
    super.initState();
    _current = widget.sensitivity;
    _debouncer = Debouncer(delay: const Duration(milliseconds: 150));
  }

  @override
  void didUpdateWidget(covariant TrackpadSensitivitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensitivity != widget.sensitivity) {
      _current = widget.sensitivity;
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _onChanged(double value) {
    setState(() => _current = value);
    _debouncer.run(() async {
      widget.onSensitivityChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final valueLabel = '${_current.toStringAsFixed(1)}×';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Velocidad',
                  style: kTextBody.copyWith(color: p.label),
                ),
              ),
              Text(
                valueLabel,
                style: kTextMono.copyWith(fontSize: 14, color: p.tintText),
              ),
            ],
          ),
          Row(
            children: [
              Text('Lenta', style: kTextFootnote.copyWith(color: p.secondary)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: p.tintFill,
                    inactiveTrackColor: p.switchOff,
                    thumbColor: kBgElevatedLight,
                    overlayColor: p.tintFill.withValues(alpha: 0.12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 14),
                    tickMarkShape: SliderTickMarkShape.noTickMark,
                  ),
                  child: Slider(
                    key: const ValueKey('kb-trackpad-sensitivity-slider'),
                    value: _current,
                    min: 0.5,
                    max: 2.5,
                    divisions: 20,
                    label: valueLabel,
                    semanticFormatterCallback: (v) =>
                        'Velocidad ${v.toStringAsFixed(1)}',
                    onChanged: _onChanged,
                  ),
                ),
              ),
              Text('Rápida', style: kTextFootnote.copyWith(color: p.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}
