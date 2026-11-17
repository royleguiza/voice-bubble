part of '../settings_screen.dart';

/// Página Trackpad: arriba el puntero en otras apps (complemento
/// VoiceBubble Puntero, lo abre la barra flotante) y el trackpad del
/// teclado; el ajuste fino solo aparece si alguno de los dos está en uso.
extension _TrackpadPage on _SettingsScreenState {
  /// Filas del complemento VoiceBubble Puntero (estado + «Permitir ajustes
  /// restringidos»). Las usan Trackpad y Barra flotante (la isla las
  /// necesita): mismo acceso en los dos lados.
  List<Widget> _pointerCompanionRows() {
    final status = _pointerStatus;
    final ready = status == FloatingTrackpadService.pointerReady;
    final statusLabel = switch (status) {
      FloatingTrackpadService.pointerReady => context.l10n.trackpadPointerActive,
      FloatingTrackpadService.pointerDisabled => context.l10n.trackpadPointerEnable,
      _ => context.l10n.trackpadPointerNotInstalled,
    };
    return [
      SettingsNavRow(
        key: const ValueKey('pointer-companion-row'),
        title: context.l10n.settingsPointerCompanionTitle,
        value: statusLabel,
        valueActive: ready,
        valueColor: ready ? null : SettingsPalette.of(context).alert,
        onTap: _onPointerCompanionTap,
      ),
      if (status == FloatingTrackpadService.pointerDisabled)
        SettingsActionRow(
          key: const ValueKey('pointer-restricted-row'),
          title: context.l10n.trackpadRestrictedRow,
          onTap: _floatingTrackpadService.openCompanionDetails,
        ),
    ];
  }

  Widget _buildTrackpadPage(BuildContext context) {
    final status = _pointerStatus;
    final statusFooter = switch (status) {
      FloatingTrackpadService.pointerReady =>
        context.l10n.trackpadFooterReady,
      FloatingTrackpadService.pointerDisabled =>
        context.l10n.trackpadFooterDisabled,
      _ => context.l10n.trackpadFooterMissing,
    };
    return _subpage(
      context,
      title: context.l10n.settingsNavTrackpad,
      sections: [
        SettingsSection(
          header: context.l10n.trackpadOtherAppsHeader,
          footer: statusFooter,
          children: _pointerCompanionRows(),
        ),
        SettingsSection(
          footer: context.l10n.trackpadOpenFooter,
          children: [
            SettingsMenuRow<String>(
              id: 'pointer-open-mode-selector',
              title: context.l10n.trackpadOpenAs,
              value: _pointerOpenMode,
              options: [
                SettingsOption('panel', context.l10n.trackpadOpenPanel),
                SettingsOption('window', context.l10n.trackpadOpenWindow),
              ],
              onSelected: _savePointerOpenMode,
            ),
            SettingsMenuRow<int>(
              id: 'kb-trackpad-auto-return-selector',
              title: context.l10n.trackpadAutoReturn,
              value: _trackpadAutoReturn,
              options: [
                SettingsOption(0, context.l10n.trackpadStaysOpen),
                SettingsOption(5, context.l10n.trackpadClosesIn5),
                SettingsOption(15, context.l10n.trackpadClosesIn15),
                SettingsOption(30, context.l10n.trackpadClosesIn30),
              ],
              onSelected: _saveTrackpadAutoReturn,
            ),
          ],
        ),
        SettingsSection(
          header: context.l10n.trackpadKeyboardHeader,
          footer: context.l10n.trackpadKeyboardFooter,
          children: [
            SettingsSwitchRow(
              key: const ValueKey('kb-trackpad-enabled-switch'),
              title: context.l10n.trackpadKeyboardSwitch,
              value: _trackpadEnabled,
              onChanged: _toggleTrackpadEnabled,
            ),
            SettingsSwitchRow(
              key: const ValueKey('kb-trackpad-toolbar-switch'),
              title: context.l10n.trackpadToolbarSwitch,
              value: _trackpadToolbarVisible,
              onChanged: _toggleTrackpadToolbarVisible,
            ),
          ],
        ),
        if (_trackpadEnabled || _dockToolPointer) ...[
          SettingsSection(
            header: context.l10n.settingsToolPointer,
            children: [
              TrackpadSensitivitySection(
                sensitivity: _trackpadSensitivity,
                onSensitivityChanged: _onTrackpadSensitivitySlider,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-accel-curve-selector',
                title: context.l10n.trackpadAcceleration,
                value: _trackpadAccelCurve,
                options: [
                  SettingsOption('dynamic', context.l10n.trackpadAccelDynamic),
                  SettingsOption('linear', context.l10n.trackpadAccelLinear),
                  SettingsOption('precision', context.l10n.trackpadAccelPrecision),
                ],
                onSelected: _saveTrackpadAccelCurve,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-pointer-style-selector',
                title: context.l10n.settingsDockForm,
                value: _trackpadPointerStyle,
                options: [
                  SettingsOption('arrow', context.l10n.trackpadShapeArrow),
                  SettingsOption('dot', context.l10n.trackpadShapeDot),
                  SettingsOption('cross', context.l10n.trackpadShapeCross),
                ],
                onSelected: _saveTrackpadPointerStyle,
              ),
            ],
          ),
          SettingsSection(
            header: context.l10n.trackpadClickHeader,
            children: [
              SettingsSwitchRow(
                key: const ValueKey('kb-trackpad-tap-to-click-switch'),
                title: context.l10n.trackpadTapToClick,
                value: _trackpadTapToClick,
                onChanged: _toggleTrackpadTapToClick,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-secondary-click-selector',
                title: context.l10n.trackpadSecondaryClick,
                value: _trackpadSecondaryClick,
                options: [
                  SettingsOption('2fingers', context.l10n.trackpadTwoFingers),
                  SettingsOption('button', context.l10n.trackpadRightButton),
                  SettingsOption('hold', context.l10n.settingsRecordHold),
                ],
                onSelected: _saveTrackpadSecondaryClick,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-button-layout-selector',
                title: context.l10n.trackpadButtons,
                value: _trackpadButtonLayout,
                options: [
                  SettingsOption('top', context.l10n.trackpadButtonsTop),
                  SettingsOption('wings', context.l10n.trackpadButtonsSides),
                ],
                onSelected: _saveTrackpadButtonLayout,
              ),
            ],
          ),
          SettingsSection(
            header: context.l10n.trackpadScrollHeader,
            children: [
              SettingsMenuRow<String>(
                id: 'kb-trackpad-scroll-position-selector',
                title: context.l10n.trackpadScrollBar,
                value: _trackpadScrollPosition,
                options: [
                  SettingsOption('right', context.l10n.trackpadScrollRight),
                  SettingsOption('left', context.l10n.trackpadScrollLeft),
                  SettingsOption('disabled', context.l10n.trackpadScrollHidden),
                ],
                onSelected: _saveTrackpadScrollPosition,
              ),
              SettingsMenuRow<String>(
                id: 'kb-trackpad-scroll-direction-selector',
                title: context.l10n.trackpadScrollDirection,
                value: _trackpadScrollDirection,
                options: [
                  SettingsOption('natural', context.l10n.trackpadScrollNatural),
                  SettingsOption('standard', context.l10n.trackpadScrollInverted),
                ],
                onSelected: _saveTrackpadScrollDirection,
              ),
            ],
          ),
          SettingsSection(
            header: context.l10n.trackpadOtherHeader,
            children: [
              SettingsMenuRow<String>(
                id: 'kb-trackpad-haptic-selector',
                title: context.l10n.trackpadHaptics,
                value: _trackpadHaptic,
                options: [
                  SettingsOption('subtle', context.l10n.trackpadHapticSubtle),
                  SettingsOption('firm', context.l10n.keyboardIntensityFirm),
                  SettingsOption('none', context.l10n.keyboardBottomNone),
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
                  context.l10n.trackpadSpeed,
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
              Text(context.l10n.trackpadSlow, style: kTextFootnote.copyWith(color: p.secondary)),
              Expanded(
                child: SliderTheme(
                  data: settingsSliderTheme(context),
                  child: Slider(
                    key: const ValueKey('kb-trackpad-sensitivity-slider'),
                    value: _current,
                    min: 0.5,
                    max: 2.5,
                    divisions: 20,
                    label: valueLabel,
                    semanticFormatterCallback: (v) =>
                        context.l10n.trackpadSpeedSemantics(v.toStringAsFixed(1)),
                    onChanged: _onChanged,
                  ),
                ),
              ),
              Text(context.l10n.trackpadFast, style: kTextFootnote.copyWith(color: p.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}
