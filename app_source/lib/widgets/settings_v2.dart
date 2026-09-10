import 'package:flutter/material.dart';

import '../ui/design_tokens.dart';

/// Kit visual Settings v2 (laboratorio_ui/settings-redesign-v2.html):
/// títulos de página/grupo, tarjetas agrupadas estilo iOS, filas con
/// pastilla de icono, píldoras de estado y sección expandible.
/// La conducta y las Keys viven en los tabs; aquí solo presentación.
class SettingsPageTitle extends StatelessWidget {
  final String text;

  const SettingsPageTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 24, 10, 16),
      child: Text(
        text,
        style: kSettingsPageTitle.copyWith(
          color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
        ),
      ),
    );
  }
}

/// Título de grupo semántico en mayúsculas (más aire arriba que abajo).
class SettingsGroupTitle extends StatelessWidget {
  final String text;

  const SettingsGroupTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: kSettingsGroupTitle.copyWith(
          color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
        ),
      ),
    );
  }
}

/// Tarjeta agrupada (radio 16) con divisores finos entre filas.
class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final divided = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      divided.add(children[i]);
      if (i < children.length - 1) {
        divided.add(
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 58,
            endIndent: 0,
            color: Theme.of(context).dividerColor,
          ),
        );
      }
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: divided,
      ),
    );
  }
}

/// Pastilla de icono 30x30 de fila (tinte sólido, glifo blanco 16).
class SettingIconTile extends StatelessWidget {
  final IconData icon;
  final Color background;

  const SettingIconTile({
    super.key,
    required this.icon,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kSettingIconSize,
      height: kSettingIconSize,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(kSettingIconRadius),
      ),
      child: Icon(icon, color: Colors.white, size: kSettingIconGlyph),
    );
  }
}

/// Píldora de estado en línea (punto con brillo + etiqueta).
class StatusPill extends StatelessWidget {
  final Color dotColor;
  final String label;

  const StatusPill({
    super.key,
    required this.dotColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? kBgSecondaryDark : kBgSecondaryLight,
        borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: dotColor, blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: kTextFootnote.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila táctil con icono, título y chevron (navegación / acción).
class SettingChevronRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const SettingChevronRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kSettingRowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SettingIconTile(icon: icon, background: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: kSettingRowTitle.copyWith(
                    color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? kLabelTertiaryDark : kLabelTertiaryLight,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sección expandible "Avanzado" con chevron animado.
/// Arranca abierta para que todo siga visible y testeable.
class ExpandableSettingsCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const ExpandableSettingsCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  @override
  State<ExpandableSettingsCard> createState() => _ExpandableSettingsCardState();
}

class _ExpandableSettingsCardState extends State<ExpandableSettingsCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(minHeight: kSettingRowMinHeight),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SettingIconTile(
                      icon: widget.icon,
                      background: widget.iconColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: kSettingRowTitle.copyWith(
                          color: isDark
                              ? kLabelPrimaryDark
                              : kLabelPrimaryLight,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0.0,
                      duration: reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark
                            ? kLabelTertiaryDark
                            : kLabelTertiaryLight,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open) ...[
            Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).dividerColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chips rápidos bajo un slider (atajos de valores discretos).
class SliderChips<T> extends StatelessWidget {
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const SliderChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: entry.key == selected,
            selectedColor: scheme.primary,
            labelStyle: kTextMeta.copyWith(
              fontWeight: FontWeight.w600,
              color: entry.key == selected
                  ? Colors.white
                  : (isDark ? kLabelSecondaryDark : kLabelSecondaryLight),
            ),
            backgroundColor:
                isDark ? kBgSecondaryDark : kBgSecondaryLight,
            onSelected: (_) => onSelected(entry.key),
          ),
      ],
    );
  }
}
