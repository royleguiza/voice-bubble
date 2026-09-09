import 'package:flutter/material.dart';

import '../../ui/design_tokens.dart';

/// Tab Teclado de Ajustes (SPK-06, módulo 4 de N): estado IME + fila
/// terminal + altura + toolbar + spacebar + elevación + háptico,
/// extraído de SettingsScreen sin cambiar conducta.
class TecladoTab extends StatelessWidget {
  final String keyboardStatusText;
  final VoidCallback onLoadKeyboardStatus;
  final bool showTerminalRow;
  final ValueChanged<bool> onToggleTerminalRow;
  final bool showCodeKey;
  final ValueChanged<bool> onToggleCodeKey;
  final bool showLanguageKey;
  final ValueChanged<bool> onToggleLanguageKey;
  final bool clipboardImagesEnabled;
  final ValueChanged<bool> onToggleClipboardImages;
  final String heightProfile;
  final ValueChanged<String> onSaveHeightProfile;
  final String heightProfileHint;
  final bool invertToolbar;
  final ValueChanged<bool> onToggleInvertToolbar;
  final String spacebarAlignment;
  final ValueChanged<String> onSaveSpacebarAlignment;
  final String spacebarTrackpadMode;
  final ValueChanged<String> onSaveSpacebarTrackpadMode;
  final int bottomElevationDp;
  final ValueChanged<int> onSaveBottomElevation;
  final bool hapticsEnabled;
  final ValueChanged<bool> onToggleHaptics;
  final bool isKeyboardEnabled;
  final bool isKeyboardSelected;
  final VoidCallback onOpenKeyboardSettings;
  final VoidCallback onShowInputMethodPicker;
  final ValueChanged<int> onSelectTab;

  const TecladoTab({
    super.key,
    required this.keyboardStatusText,
    required this.onLoadKeyboardStatus,
    required this.showTerminalRow,
    required this.onToggleTerminalRow,
    required this.showCodeKey,
    required this.onToggleCodeKey,
    required this.showLanguageKey,
    required this.onToggleLanguageKey,
    required this.clipboardImagesEnabled,
    required this.onToggleClipboardImages,
    required this.heightProfile,
    required this.onSaveHeightProfile,
    required this.heightProfileHint,
    required this.invertToolbar,
    required this.onToggleInvertToolbar,
    required this.spacebarAlignment,
    required this.onSaveSpacebarAlignment,
    required this.spacebarTrackpadMode,
    required this.onSaveSpacebarTrackpadMode,
    required this.bottomElevationDp,
    required this.onSaveBottomElevation,
    required this.hapticsEnabled,
    required this.onToggleHaptics,
    required this.isKeyboardEnabled,
    required this.isKeyboardSelected,
    required this.onOpenKeyboardSettings,
    required this.onShowInputMethodPicker,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'Teclado VoiceBubble',
          style: Theme.of(context).textTheme.titleMedium,
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
                      Icons.keyboard,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        keyboardStatusText,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: onLoadKeyboardStatus,
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Usa VoiceBubble como teclado del sistema en cualquier app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fila terminal'),
                  subtitle: Text(
                    'TAB, ESC, CTRL, ALT y flechas sobre las letras. '
                    'Desactívala si usás Termux, que ya trae teclas propias.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  value: showTerminalRow,
                  onChanged: onToggleTerminalRow,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tecla de capa código'),
                  subtitle: Text(
                    'La tecla </> abre los símbolos de programación. '
                    'Desactívala para liberar espacio en la barra inferior.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  value: showCodeKey,
                  onChanged: onToggleCodeKey,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tecla de idioma'),
                  subtitle: Text(
                    'El botón ES/EN junto a la barra espaciadora. '
                    'Desactívala si dictás en un solo idioma.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  value: showLanguageKey,
                  onChanged: onToggleLanguageKey,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Imágenes en portapapeles'),
                  subtitle: Text(
                    'Experimental (texto primero): guarda imágenes del portapapeles. '
                    'Apagado por defecto para cuidar RAM y disco.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  value: clipboardImagesEnabled,
                  onChanged: onToggleClipboardImages,
                ),
                const SizedBox(height: 4),
                Text(
                  'Altura del teclado',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  key: const ValueKey('kb-height-profile-selector'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'baja', label: Text('Baja')),
                    ButtonSegment(value: 'media', label: Text('Media')),
                    ButtonSegment(value: 'alta', label: Text('Alta')),
                    ButtonSegment(value: 'muy_alta', label: Text('Muy alta')),
                  ],
                  selected: {heightProfile},
                  onSelectionChanged: (profiles) =>
                      onSaveHeightProfile(profiles.first),
                ),
                const SizedBox(height: 8),
                Text(
                  heightProfileHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Barra Interactiva Superior',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Invertir disposición (Zurdo/Diestro)'),
                  subtitle: Text(
                    'El micrófono pasa a la izquierda y el portapapeles a la derecha.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  value: invertToolbar,
                  onChanged: onToggleInvertToolbar,
                ),
                const SizedBox(height: 16),
                Text(
                  'Posición de la Barra Espaciadora',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                _SpacebarAlignmentCards(
                  current: spacebarAlignment,
                  onSelect: onSaveSpacebarAlignment,
                ),
                const SizedBox(height: 16),
                Text(
                  'Gesto en Barra Espaciadora (Cursor)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  key: const ValueKey('kb-spacebar-trackpad-mode-selector'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'ios_2d', label: Text('iOS 2D (Mantener)')),
                    ButtonSegment(value: 'gboard_horizontal', label: Text('Gboard (Deslizar)')),
                  ],
                  selected: {spacebarTrackpadMode},
                  onSelectionChanged: (s) => onSaveSpacebarTrackpadMode(s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  spacebarTrackpadMode == 'ios_2d'
                      ? 'Mantener presionado >300ms activa navegación 2D libre con borrado de teclas estilo iOS.'
                      : 'Deslizar sobre la barra mueve el cursor lateralmente estilo Gboard.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Elevación Inferior (Bottom Lift)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  key: const ValueKey('kb-bottom-elevation-selector'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('0dp')),
                    ButtonSegment(value: 12, label: Text('12dp')),
                    ButtonSegment(value: 24, label: Text('24dp')),
                    ButtonSegment(value: 36, label: Text('36dp')),
                    ButtonSegment(value: 48, label: Text('48dp')),
                  ],
                  selected: {bottomElevationDp},
                  onSelectionChanged: (dps) => onSaveBottomElevation(dps.first),
                ),
                const SizedBox(height: 8),
                Text(
                  'Despega el teclado del borde inferior de la pantalla. Ideal para dispositivos con barra de gestos o biseles delgados.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vibración'),
                  subtitle: Text(
                    'Feedback háptico al tocar cada tecla.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  value: hapticsEnabled,
                  onChanged: onToggleHaptics,
                ),
                const SizedBox(height: 12),
                if (!isKeyboardEnabled) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Abrir ajustes del sistema'),
                    onPressed: onOpenKeyboardSettings,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paso 1: Activa "VoiceBubble STT" en Administrar teclados de Android. Al volver, la app te permitirá seleccionarlo inmediatamente sin salir.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ] else if (!isKeyboardSelected) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.touch_app),
                    label: const Text('Seleccionar VoiceBubble como teclado'),
                    onPressed: onShowInputMethodPicker,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paso 2: Toca para abrir el selector modal y activar VoiceBubble STT directamente sin salir de la app.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Abrir ajustes del sistema'),
                    onPressed: onOpenKeyboardSettings,
                  ),
                ] else ...[
                  FilledButton.tonalIcon(
                    icon: Icon(Icons.check_circle, color: (Theme.of(context).brightness == Brightness.dark ? kSuccessDark : kSuccessLight)),
                    label: const Text('Teclado activo (toca para cambiar)'),
                    onPressed: onShowInputMethodPicker,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'VoiceBubble está activo. Toca el botón para alternar rápidamente entre teclados sin salir de la app.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Abrir ajustes del sistema'),
                    onPressed: onOpenKeyboardSettings,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Buscas el trackpad?',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ahora tiene su propia sección con puntero virtual y sensibilidad.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('teclado-go-trackpad'),
                  onPressed: () => onSelectTab(3),
                  child: const Text('Abrirlo en su propia sección →'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpacebarAlignmentCards extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;

  const _SpacebarAlignmentCards({
    required this.current,
    required this.onSelect,
  });

  static const Map<String, List<int>> miniKbSpaceFlex = {
    'left': [1, 3, 1, 1, 1],
    'center': [1, 1, 3, 1, 1],
    'right': [1, 1, 1, 3, 1],
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _miniKbCard(context, 'left', 'Zurdo')),
        const SizedBox(width: 8),
        Expanded(child: _miniKbCard(context, 'center', 'Centro')),
        const SizedBox(width: 8),
        Expanded(child: _miniKbCard(context, 'right', 'Diestro')),
      ],
    );
  }

  Widget _miniKbCard(BuildContext context, String id, String label) {
    final isSelected = current == id;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onSelect(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surface,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _miniKbRow(context, id, colorScheme),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniKbRow(
      BuildContext context, String layout, ColorScheme colorScheme) {
    Widget miniKey(int flex, {bool isSpace = false}) {
      return Expanded(
        flex: flex,
        child: Container(
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSpace
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }

    final flexes = miniKbSpaceFlex[layout] ?? miniKbSpaceFlex['center']!;
    return Row(
      children: [for (final flex in flexes) miniKey(flex, isSpace: flex == 3)],
    );
  }
}
