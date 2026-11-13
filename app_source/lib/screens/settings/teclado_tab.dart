part of '../settings_screen.dart';

/// Páginas Teclado y Vibración y sonido. Arriba de Teclado va una vista
/// previa en vivo que refleja altura, separación, teclas visibles, posición
/// del micrófono y de la barra espaciadora.
extension _TecladoPages on _SettingsScreenState {
  Widget _buildTecladoPage(BuildContext context) {
    return _subpage(
      context,
      title: 'Teclado',
      sections: [
        KeyboardPreview(
          key: const ValueKey('kb-preview'),
          heightProfile: _heightProfile,
          keySpacing: _keySpacing,
          bottomElevationDp: _bottomElevationDp,
          showTerminalRow: _showTerminalRow,
          showCodeKey: _showCodeKey,
          showLanguageKey: _showLanguageKey,
          showCredentialsKey: _showCredentialsKey,
          showTrackpadKey: _trackpadToolbarVisible,
          invertToolbar: _invertToolbar,
          spacebarAlignment: _spacebarAlignment,
        ),
        _keyboardStatusSection(),
        SettingsSection(
          header: 'Tamaño',
          children: [
            SettingsMenuRow<String>(
              id: 'kb-height-profile-selector',
              title: 'Altura',
              value: _heightProfile,
              options: const [
                SettingsOption('baja', 'Baja'),
                SettingsOption('media', 'Media'),
                SettingsOption('alta', 'Alta'),
                SettingsOption('muy_alta', 'Muy alta'),
              ],
              onSelected: _saveHeightProfile,
            ),
            SettingsMenuRow<String>(
              id: 'kb-key-spacing-selector',
              title: 'Separación',
              value: _keySpacing,
              options: const [
                SettingsOption('compacto', 'Compacta'),
                SettingsOption('normal', 'Normal'),
                SettingsOption('amplio', 'Amplia'),
                SettingsOption('extra', 'Máxima'),
              ],
              onSelected: _saveKeySpacing,
            ),
            SettingsMenuRow<int>(
              id: 'kb-bottom-elevation-selector',
              title: 'Distancia al borde',
              value: _bottomElevationDp,
              options: const [
                SettingsOption(0, 'Ninguna'),
                SettingsOption(12, '12 dp'),
                SettingsOption(24, '24 dp'),
                SettingsOption(36, '36 dp'),
                SettingsOption(48, '48 dp'),
              ],
              onSelected: _saveBottomElevation,
            ),
          ],
        ),
        SettingsSection(
          header: 'Teclas',
          footer: 'Ocultá las que no uses y el teclado gana espacio.',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('kb-terminal-row-switch'),
              title: 'Fila de terminal',
              value: _showTerminalRow,
              onChanged: _toggleTerminalRow,
            ),
            SettingsSwitchRow(
              key: const ValueKey('kb-code-key-switch'),
              title: 'Tecla de código',
              value: _showCodeKey,
              onChanged: _toggleKeyboardCodeKey,
            ),
            SettingsSwitchRow(
              key: const ValueKey('kb-language-key-switch'),
              title: 'Tecla de idioma',
              value: _showLanguageKey,
              onChanged: _toggleKeyboardLanguageKey,
            ),
            SettingsSwitchRow(
              key: const ValueKey('credenciales-key-visible-switch'),
              title: 'Llave de claves',
              value: _showCredentialsKey,
              onChanged: _toggleKeyboardCredentialsKey,
            ),
          ],
        ),
        SettingsSection(
          header: 'Escritura',
          children: [
            SettingsMenuRow<String>(
              id: 'kb-spacebar-trackpad-mode-selector',
              title: 'Mover el cursor',
              value: _spacebarTrackpadMode,
              options: const [
                SettingsOption('ios_2d', 'Mantener', detail: 'en 2D'),
                SettingsOption(
                  'gboard_horizontal',
                  'Deslizar',
                  detail: 'lateral',
                ),
              ],
              onSelected: _saveSpacebarTrackpadMode,
            ),
            SettingsMenuRow<String>(
              id: 'kb-spacebar-alignment-selector',
              title: 'Barra espaciadora',
              value: _spacebarAlignment,
              options: const [
                SettingsOption('left', 'A la izquierda'),
                SettingsOption('center', 'Centrada'),
                SettingsOption('right', 'A la derecha'),
              ],
              onSelected: _saveSpacebarAlignment,
            ),
            SettingsSwitchRow(
              key: const ValueKey('kb-invert-toolbar-switch'),
              title: 'Micrófono a la izquierda',
              value: _invertToolbar,
              onChanged: _toggleInvertToolbar,
            ),
            SettingsSwitchRow(
              key: const ValueKey('kb-long-press-symbols-switch'),
              title: 'Símbolos al mantener',
              value: _longPressSymbolsEnabled,
              onChanged: _toggleLongPressSymbols,
            ),
            if (_longPressSymbolsEnabled)
              SettingsMenuRow<String>(
                id: 'kb-long-press-delay-selector',
                title: 'Espera',
                value: _longPressDelay,
                options: const [
                  SettingsOption('rapido', 'Corta', detail: '250 ms'),
                  SettingsOption('normal', 'Normal', detail: '350 ms'),
                  SettingsOption('relajado', 'Larga', detail: '450 ms'),
                ],
                onSelected: _saveLongPressDelay,
              ),
          ],
        ),
        SettingsSection(
          children: [
            SettingsNavRow(
              key: const ValueKey('nav-sonido'),
              icon: Icons.volume_up_outlined,
              title: 'Vibración y sonido',
              value: _hapticsEnabled ? 'Activados' : 'Sin vibración',
              valueActive: _hapticsEnabled,
              onTap: () => _go(SettingsPage.sonido),
            ),
          ],
        ),
        SettingsSection(
          header: 'Portapapeles',
          footer: 'Apagado guarda solo texto y ocupa menos memoria.',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('kb-clipboard-images-switch'),
              title: 'Guardar imágenes',
              badge: 'Beta',
              value: _clipboardImagesEnabled,
              onChanged: _toggleClipboardImages,
            ),
          ],
        ),
      ],
    );
  }

  /// Activo: confirmación + "Cambiar de teclado". Sin activar: los dos
  /// pasos (habilitar en Android y elegirlo).
  Widget _keyboardStatusSection() {
    if (_isKeyboardActive) {
      return SettingsSection(
        key: const ValueKey('kb-status-active'),
        children: [
          const SettingsStatusRow(
            title: 'VoiceBubble está activo',
            subtitle: 'Es tu teclado en todas las apps.',
          ),
          SettingsActionRow(
            key: const ValueKey('kb-picker-button'),
            title: 'Cambiar de teclado',
            onTap: _showInputMethodPicker,
          ),
        ],
      );
    }
    return SettingsSection(
      key: const ValueKey('kb-status-setup'),
      header: 'Activalo en dos pasos',
      footer: 'Al volver de Android, el selector se abre solo.',
      children: [
        if (_isKeyboardEnabled)
          const SettingsStatusRow(
            title: 'Activado en Android',
            subtitle: 'Falta elegirlo como teclado.',
          )
        else
          SettingsActionRow(
            key: const ValueKey('kb-open-settings-button'),
            title: '1. Activar en Android',
            onTap: _openKeyboardSettings,
          ),
        SettingsActionRow(
          key: const ValueKey('kb-picker-button'),
          title: '2. Elegir VoiceBubble',
          onTap: _isKeyboardEnabled ? _showInputMethodPicker : null,
        ),
      ],
    );
  }

  Widget _buildSonidoPage(BuildContext context) {
    const tones = [
      SettingsOption('1', 'Tono 1'),
      SettingsOption('2', 'Tono 2'),
      SettingsOption('3', 'Tono 3'),
      SettingsOption('4', 'Tono 4'),
    ];
    return _subpage(
      context,
      title: 'Vibración y sonido',
      sections: [
        SettingsSection(
          header: 'Al escribir',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('kb-haptics-switch'),
              title: 'Vibrar al tocar',
              value: _hapticsEnabled,
              onChanged: _toggleHaptics,
            ),
            if (_hapticsEnabled)
              SettingsMenuRow<String>(
                id: 'kb-haptic-style-selector',
                title: 'Intensidad',
                value: _hapticStyle,
                options: const [
                  SettingsOption('nitido', 'Nítida', detail: 'clic seco'),
                  SettingsOption('firme', 'Firme', detail: 'marcada'),
                  SettingsOption('suave', 'Suave', detail: 'leve'),
                ],
                onSelected: _saveHapticStyle,
              ),
          ],
        ),
        SettingsSection(
          header: 'Al dictar',
          footer: 'Funciona aparte de la vibración de las teclas.',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('kb-mic-haptics-enabled'),
              title: 'Vibración',
              value: _micHapticsEnabled,
              onChanged: _toggleMicHaptics,
            ),
            if (_micHapticsEnabled) ...[
              SettingsSwitchRow(
                key: const ValueKey('kb-mic-haptic-start'),
                title: 'Al empezar',
                value: _micHapticStart,
                onChanged: _toggleMicHapticStart,
              ),
              SettingsSwitchRow(
                key: const ValueKey('kb-mic-haptic-recording'),
                title: 'Mientras graba',
                value: _micHapticRecording,
                onChanged: _toggleMicHapticRecording,
              ),
              SettingsSwitchRow(
                key: const ValueKey('kb-mic-haptic-paste'),
                title: 'Al pegar',
                value: _micHapticPaste,
                onChanged: _toggleMicHapticPaste,
              ),
              SettingsSwitchRow(
                key: const ValueKey('kb-mic-haptic-cancel'),
                title: 'Al cancelar',
                value: _micHapticCancel,
                onChanged: _toggleMicHapticCancel,
              ),
            ],
          ],
        ),
        SettingsSection(
          header: 'Sonidos del micrófono',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('kb-mic-sounds-enabled'),
              title: 'Sonidos',
              value: _micSoundsEnabled,
              onChanged: _toggleMicSounds,
            ),
            if (_micSoundsEnabled) ...[
              SettingsMenuRow<String>(
                id: 'kb-mic-start-style',
                title: 'Al empezar',
                value: _micStartStyle,
                options: tones,
                onSelected: _saveMicStartStyle,
              ),
              SettingsMenuRow<String>(
                id: 'kb-mic-stop-style',
                title: 'Al terminar',
                value: _micStopStyle,
                options: tones,
                onSelected: _saveMicStopStyle,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Vista previa del teclado con los ajustes actuales. Decorativa para
/// lectores de pantalla (los valores ya se anuncian en cada fila).
class KeyboardPreview extends StatelessWidget {
  final String heightProfile;
  final String keySpacing;
  final int bottomElevationDp;
  final bool showTerminalRow;
  final bool showCodeKey;
  final bool showLanguageKey;
  final bool showCredentialsKey;
  final bool showTrackpadKey;
  final bool invertToolbar;
  final String spacebarAlignment;

  const KeyboardPreview({
    super.key,
    required this.heightProfile,
    required this.keySpacing,
    required this.bottomElevationDp,
    required this.showTerminalRow,
    required this.showCodeKey,
    required this.showLanguageKey,
    required this.showCredentialsKey,
    required this.showTrackpadKey,
    required this.invertToolbar,
    required this.spacebarAlignment,
  });

  static const _keyHeights = {
    'baja': 26.0,
    'media': 31.0,
    'alta': 36.0,
    'muy_alta': 41.0,
  };
  static const _rowGaps = {
    'compacto': 3.0,
    'normal': 5.0,
    'amplio': 7.0,
    'extra': 10.0,
  };
  static const _keyGaps = {
    'compacto': 3.0,
    'normal': 5.0,
    'amplio': 6.0,
    'extra': 8.0,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyColor = isDark ? kKbPreviewKeyDark : kKbPreviewKeyLight;
    final altColor = isDark ? kKbPreviewKeyAltDark : kKbPreviewKeyAltLight;
    final fg = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    final accent = isDark ? kAccentDark : kAccentLight;
    final keyH = _keyHeights[heightProfile] ?? 31.0;
    final rowGap = _rowGaps[keySpacing] ?? 5.0;
    final keyGap = _keyGaps[keySpacing] ?? 5.0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    _PreviewKey letter(String c) => _PreviewKey(c, 10, keyColor, fg, 15);
    _PreviewKey alt(String c, {int flex = 14, double fontSize = 15}) =>
        _PreviewKey(c, flex, altColor, fg, fontSize, bold: true);

    final rows = <List<_PreviewKey>>[
      if (showTerminalRow)
        [
          for (final c in const ['esc', 'tab', 'ctrl', 'alt'])
            alt(c, flex: 10, fontSize: 11),
          for (final i in const [
            Icons.arrow_back_rounded,
            Icons.arrow_upward_rounded,
            Icons.arrow_downward_rounded,
            Icons.arrow_forward_rounded,
          ])
            _PreviewKey('', 10, altColor, fg, 18, icon: i),
        ],
      [for (final c in 'qwertyuiop'.split('')) letter(c)],
      [for (final c in 'asdfghjklñ'.split('')) letter(c)],
      [
        _PreviewKey('', 14, altColor, fg, 18, icon: Icons.arrow_upward_rounded),
        for (final c in 'zxcvbnm'.split('')) letter(c),
        _PreviewKey('', 14, altColor, fg, 18, icon: Icons.backspace_outlined),
      ],
    ];
    final mods = <_PreviewKey>[
      alt('123', fontSize: 12),
      if (showCodeKey) alt('</>', flex: 11, fontSize: 11),
      if (showLanguageKey) alt('ES', flex: 11, fontSize: 11),
    ];
    final space = _PreviewKey('espacio', 50, keyColor, fg, 12);
    final enter = _PreviewKey(
      '',
      16,
      accent,
      kOnEmber,
      18,
      icon: Icons.keyboard_return_rounded,
    );
    rows.add(switch (spacebarAlignment) {
      'left' => [space, ...mods, enter],
      'right' => [...mods, enter, space],
      _ => [...mods, space, enter],
    });

    // Barra del teclado (fase 2): íconos sueltos en fg2, sin caja.
    final toolColor = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final tools = <Widget>[
      _tool(Icons.short_text_rounded, toolColor),
      if (showCredentialsKey) _tool(Icons.key_rounded, toolColor),
      if (showTrackpadKey) _tool(Icons.touch_app_rounded, toolColor),
    ];
    // Micrófono del teclado = el agujero con anillo de brasa (fase 2).
    final mic = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? kHoleDark : kHoleLight,
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.5),
      ),
      child: const Icon(Icons.mic_rounded, size: 18, color: kOnHole),
    );
    final clip = _tool(Icons.content_paste_rounded, toolColor);
    final toolbar = invertToolbar
        ? [mic, ...tools, clip]
        : [clip, ...tools, mic];

    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(5, 8, 5, 8 + bottomElevationDp / 2),
        decoration: BoxDecoration(
          color: isDark ? kKbPreviewSurfaceDark : kKbPreviewSurfaceLight,
          borderRadius: BorderRadius.circular(kSettingsGroupRadius),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 34,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: toolbar,
                ),
              ),
            ),
            for (final row in rows) ...[
              SizedBox(height: rowGap),
              Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) SizedBox(width: keyGap),
                    Expanded(
                      flex: row[i].flex,
                      child: AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        height: keyH,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: row[i].color,
                          borderRadius: BorderRadius.circular(kRadiusKey),
                          // Línea inferior de 1 dp como la tecla nativa
                          // (kb_key_shadow): en claro, kb_key_stroke; en
                          // oscuro la tecla va plana.
                          boxShadow: isDark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: kKeyStrokeLight,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: row[i].icon != null
                            ? Icon(
                                row[i].icon,
                                size: row[i].fontSize,
                                color: row[i].foreground,
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  row[i].label,
                                  style: kTextCaption.copyWith(
                                    fontSize: row[i].fontSize,
                                    fontWeight: row[i].bold
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: row[i].foreground,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tool(IconData icon, Color color) => SizedBox(
    width: 32,
    height: 32,
    child: Icon(icon, size: 18, color: color),
  );
}

class _PreviewKey {
  final String label;
  final int flex;
  final Color color;
  final Color foreground;
  final double fontSize;
  final bool bold;
  final IconData? icon;

  const _PreviewKey(
    this.label,
    this.flex,
    this.color,
    this.foreground,
    this.fontSize, {
    this.bold = false,
    this.icon,
  });
}
