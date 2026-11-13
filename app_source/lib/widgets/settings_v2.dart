import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/design_tokens.dart';
import '../ui/symbol_field.dart';

/// Kit visual de Ajustes (Horizonte, maqueta "Ajustes" de
/// laboratorio_ui/horizonte.html).
///
/// Un solo lenguaje para toda la sección: grupos como lista sólida (surf +
/// borde line, radio 14) con separadores line, encabezados en mono
/// mayúsculas, íconos de línea en fg2 sin pastilla y el valor de cada fila
/// en mono (ember-t si está encendido/activo, fg2 si no). Tipos de fila:
/// - [SettingsNavRow]: entra a otra página (chevron).
/// - [SettingsSwitchRow]: sí / no (interruptor en brasa).
/// - [SettingsMenuRow]: elegir una opción (menú desplegable con check).
/// - [SettingsActionRow]: ejecutar algo (texto ember-t o danger).
/// - [SettingsValueRow]: dato de solo lectura.
/// La conducta y el estado viven en las páginas; aquí solo presentación.

/// Colores de la sección resueltos según el brillo del tema y el alto
/// contraste del sistema (design.md §9: superficie pura y borde fg de 2 px).
class SettingsPalette {
  final bool isDark;
  final bool highContrast;

  const SettingsPalette._(this.isDark, this.highContrast);

  factory SettingsPalette.of(BuildContext context) => SettingsPalette._(
        Theme.of(context).brightness == Brightness.dark,
        MediaQuery.highContrastOf(context),
      );

  Color get background => isDark ? kBgBaseDark : kBgBaseLight;
  Color get card => highContrast
      ? (isDark ? kHighContrastSurfaceDark : kHighContrastSurfaceLight)
      : (isDark ? kBgElevatedDark : kBgElevatedLight);
  Color get label => isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
  Color get secondary =>
      isDark ? kSettingsSecondaryDark : kSettingsSecondaryLight;
  Color get chevron => isDark ? kSettingsChevronDark : kSettingsChevronLight;
  Color get separator =>
      isDark ? kSettingsSeparatorDark : kSettingsSeparatorLight;

  /// Borde de grupos, campos y botones: line (fg con alto contraste).
  Color get border => highContrast ? label : separator;
  double get borderWidth =>
      highContrast ? kGlassBorderWidthAccessible : kSurfaceBorderWidth;

  /// Ícono de línea de una fila: fg2 (fg con alto contraste).
  Color get icon => highContrast ? label : secondary;
  Color get field => isDark ? kFillDark : kFillLight;
  Color get switchOff => isDark ? kSwitchOffDark : kSwitchOffLight;
  Color get tintText => isDark ? kTintTextDark : kTintTextLight;
  Color get tintFill => isDark ? kAccentDark : kAccentLight;
  Color get alert => isDark ? kSettingsAlertDark : kSettingsAlertLight;
  Color get success => isDark ? kSuccessDark : kSuccessLight;
  Color get danger => isDark ? kDangerDark : kDangerLight;
  Color get glass => card;
  Color get glassBorder => border;
  Color get menu => isDark ? kSettingsMenuDark : kSettingsMenuLight;
  Color get sheet => background;
  Color get sheetCard => card;
}

/// Título grande de la raíz ("Ajustes"). Detrás, a la derecha y muy tenue,
/// el campo de símbolos quieto (design.md §15): solo en este encabezado,
/// nunca detrás de los grupos de la lista.
class SettingsLargeTitle extends StatelessWidget {
  final String text;

  const SettingsLargeTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          right: 0,
          bottom: 6,
          child: SymbolField.header(key: ValueKey('settingsHeaderSymbols')),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 56, 2, 12),
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: kSettingsLargeTitle.copyWith(
                color: SettingsPalette.of(context).label,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Etiqueta de grupo: mono en mayúsculas, fg2. El lector de pantalla lee
/// el texto original (sin mayúsculas forzadas).
class SettingsGroupLabel extends StatelessWidget {
  final String text;

  const SettingsGroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        semanticsLabel: text,
        style: kSettingsSectionHeader.copyWith(
          color: SettingsPalette.of(context).secondary,
        ),
      ),
    );
  }
}

/// Grupo de filas: encabezado opcional, lista sólida (surf + line) con
/// separadores line y una línea de pie opcional.
class SettingsSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  /// Pie en mono (contadores, "9 de 50 · …").
  final bool monoFooter;

  const SettingsSection({
    super.key,
    this.header,
    this.footer,
    this.monoFooter = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Container(height: kSurfaceBorderWidth, color: p.separator));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: SettingsGroupLabel(header!),
          ),
        Material(
          color: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kSettingsGroupRadius),
            side: BorderSide(color: p.border, width: p.borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
            child: Text(
              footer!,
              style: monoFooter
                  ? kTextMono.copyWith(
                      fontSize: 12, color: p.secondary, height: 1.4)
                  : kTextFootnote.copyWith(color: p.secondary, height: 1.35),
            ),
          ),
      ],
    );
  }
}

/// Ícono de línea de una fila: un solo color (fg2), sin pastilla.
class _RowIcon extends StatelessWidget {
  final IconData icon;

  const _RowIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kSettingIconSize,
      child: Icon(icon, size: 22, color: SettingsPalette.of(context).icon),
    );
  }
}

/// Valor de una fila, en mono a la derecha: ember-t si está encendido o
/// activo, fg2 si está apagado o es neutro.
class _RowValue extends StatelessWidget {
  final String text;
  final Color color;

  const _RowValue(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: kTextMono.copyWith(fontSize: 14, color: color),
    );
  }
}

/// Esqueleto común de fila: [leading] opcional, título (y subtítulo) y
/// [trailing]. Toda la fila es táctil cuando hay [onTap].
class _RowShell extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _RowShell({
    this.leading,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kSettingRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: kTextBody.copyWith(color: titleColor ?? p.label),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kTextSubhead.copyWith(color: p.secondary),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

Widget? _icon(IconData? icon) => icon == null ? null : _RowIcon(icon);

/// Entra a otra página: valor actual en mono + chevron.
class SettingsNavRow extends StatelessWidget {
  final String title;
  final String? value;
  final Color? valueColor;

  /// Valor encendido/activo: se pinta en ember-t (si no, fg2).
  final bool valueActive;
  final IconData? icon;
  final VoidCallback onTap;

  const SettingsNavRow({
    super.key,
    required this.title,
    this.value,
    this.valueColor,
    this.valueActive = false,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final hasValue = value != null && value!.isNotEmpty;
    return Semantics(
      button: true,
      label: hasValue ? '$title, $value' : title,
      excludeSemantics: true,
      child: _RowShell(
        leading: _icon(icon),
        title: title,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasValue)
              _RowValue(
                value!,
                color: valueColor ??
                    (valueActive ? p.tintText : p.secondary),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 22, color: p.chevron),
          ],
        ),
      ),
    );
  }
}

/// Sí / no: toda la fila alterna el interruptor.
class SettingsSwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? badge;
  final IconData? icon;

  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.badge,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: _RowShell(
        leading: _icon(icon),
        title: title,
        onTap: onChanged == null ? null : () => onChanged(!value),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null) ...[
              SettingsBadge(badge!),
              const SizedBox(width: 8),
            ],
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: p.tintFill,
              inactiveTrackColor: p.switchOff,
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta chica en mono sobre relleno surf2 ("Beta").
class SettingsBadge extends StatelessWidget {
  final String text;

  const SettingsBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
      ),
      child: Text(
        text,
        style: kTextMono.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: p.secondary,
        ),
      ),
    );
  }
}

/// Opción de un [SettingsMenuRow].
class SettingsOption<T> {
  final T value;
  final String label;

  /// Aclaración corta a la derecha dentro del menú ("250 ms").
  final String? detail;

  const SettingsOption(this.value, this.label, {this.detail});
}

/// Elegir una opción: valor actual + flechas; al tocar abre un menú
/// flotante con check en la opción elegida.
///
/// Keys: la fila lleva `ValueKey(id)` y cada opción `ValueKey('$id-$value')`
/// para localizarlas en tests sin depender del texto visible.
class SettingsMenuRow<T> extends StatelessWidget {
  final String id;
  final String title;
  final T value;
  final List<SettingsOption<T>> options;
  final ValueChanged<T> onSelected;
  final IconData? icon;

  SettingsMenuRow({
    required this.id,
    required this.title,
    required this.value,
    required this.options,
    required this.onSelected,
    this.icon,
  }) : super(key: ValueKey(id));

  String get _currentLabel {
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return options.first.label;
  }

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        backgroundColor: WidgetStatePropertyAll(p.menu),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        // Horizonte: menú plano (surf + line), sin sombra.
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusCard),
            side: BorderSide(color: p.border, width: p.borderWidth),
          ),
        ),
      ),
      menuChildren: [
        for (final o in options)
          MenuItemButton(
            key: ValueKey('$id-${o.value}'),
            onPressed: () => onSelected(o.value),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(220, 44)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusField),
                ),
              ),
            ),
            leadingIcon: SizedBox(
              width: 20,
              child: o.value == value
                  ? Icon(Icons.check_rounded, size: 18, color: p.label)
                  : null,
            ),
            trailingIcon: o.detail == null
                ? null
                : Text(
                    o.detail!,
                    style: kTextMono.copyWith(color: p.secondary),
                  ),
            child: Semantics(
              selected: o.value == value,
              child: Text(o.label, style: kTextBody.copyWith(color: p.label)),
            ),
          ),
      ],
      builder: (context, controller, _) => Semantics(
        button: true,
        label: '$title, $_currentLabel',
        excludeSemantics: true,
        child: _RowShell(
          leading: _icon(icon),
          title: title,
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RowValue(_currentLabel, color: p.secondary),
              const SizedBox(width: 4),
              Icon(Icons.unfold_more_rounded, size: 18, color: p.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ejecuta algo: texto ember-t (danger si es destructivo), sin chevron.
class SettingsActionRow extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final bool destructive;

  const SettingsActionRow({
    super.key,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final color = destructive ? p.danger : p.tintText;
    return Semantics(
      button: true,
      child: _RowShell(
        title: title,
        titleColor: onTap == null ? p.secondary : color,
        onTap: onTap,
      ),
    );
  }
}

/// Dato de solo lectura (versión, permiso concedido).
class SettingsValueRow extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const SettingsValueRow({
    super.key,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return MergeSemantics(
      child: _RowShell(
        title: title,
        trailing: _RowValue(value, color: valueColor ?? p.secondary),
      ),
    );
  }
}

/// Estado confirmado (check de línea en ok + título + aclaración).
class SettingsStatusRow extends StatelessWidget {
  final String title;
  final String subtitle;

  const SettingsStatusRow({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return MergeSemantics(
      child: _RowShell(
        leading: SizedBox(
          width: kSettingIconSize,
          child: Icon(Icons.check_circle_outline_rounded,
              size: 22, color: p.success),
        ),
        title: title,
        subtitle: subtitle,
        titleColor: p.label,
      ),
    );
  }
}

/// Botón de ícono circular sólido (volver, agregar, cerrar y guardar de
/// la hoja): surf + borde line, sin sombra.
class SettingsGlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Relleno brasa con glifo on-ember (acción principal, p. ej. Guardar).
  /// Sin [onPressed] queda atenuado en surf2.
  final bool prominent;

  const SettingsGlassButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final enabled = onPressed != null;
    final Color fill;
    final Color glyph;
    if (prominent) {
      fill = enabled ? p.tintFill : p.field;
      glyph = enabled ? kOnEmber : p.chevron;
    } else {
      fill = p.glass;
      glyph = p.label;
    }
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: fill,
          shape: CircleBorder(
            side: prominent
                ? BorderSide.none
                : BorderSide(color: p.glassBorder, width: p.borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: kSettingsNavButtonSize,
              height: kSettingsNavButtonSize,
              child: Icon(icon, size: 22, color: glyph),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de identidad de la app en la raíz (abre Acerca de): agujero chico
/// + "VoiceBubble" + subtítulo en mono, como lista sólida.
class SettingsAppCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsAppCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kSettingsGroupRadius),
          side: BorderSide(color: p.border, width: p.borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                const SettingsAppIcon(dimension: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: kTextCardTitle.copyWith(color: p.label),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kTextMono.copyWith(
                            fontSize: 12, color: p.secondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 22, color: p.chevron),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ícono de la app: el agujero (hole) con anillo de brasa y micrófono
/// on-hole (design.md §3). Decorativo: la fila ya se anuncia.
class SettingsAppIcon extends StatelessWidget {
  final double dimension;

  const SettingsAppIcon({super.key, required this.dimension});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: isDark ? kHoleDark : kHoleLight,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? kEmberDark : kEmberLight,
          width: dimension >= 64 ? 2.5 : 2,
        ),
      ),
      child: Icon(
        Icons.mic_rounded,
        color: kOnHole,
        size: dimension * 0.46,
      ),
    );
  }
}

/// Estado vacío de una lista de Ajustes (sin claves, sin snippets): campo
/// de símbolos quieto, título, ayuda y botón primario en brasa.
class SettingsEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final Key? actionKey;
  final VoidCallback onAction;

  const SettingsEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.actionKey,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          const SymbolField(),
          const SizedBox(height: kSymbolFieldGap),
          Text(
            title,
            textAlign: TextAlign.center,
            style: kTextTitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: p.label,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: kTextSubhead.copyWith(color: p.secondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: actionKey,
            style: FilledButton.styleFrom(
              backgroundColor: p.tintFill,
              foregroundColor: kOnEmber,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: const StadiumBorder(),
              textStyle: kTextBody.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Hoja inferior sólida (Horizonte): fondo bg, radio superior 22, borde
/// line, agarradera line, barra con cerrar / título / guardar en brasa y
/// el contenido debajo. Sin sombra: el velo (scrim) ya la separa.
class SettingsSheetFrame extends StatelessWidget {
  final String title;
  final Key? closeKey;
  final VoidCallback onClose;
  final Key? saveKey;
  final VoidCallback? onSave;

  /// Hay botón de guardar aunque [onSave] sea null (queda atenuado, p. ej.
  /// mientras se guarda).
  final bool showSave;
  final List<Widget> children;

  const SettingsSheetFrame({
    super.key,
    required this.title,
    this.closeKey,
    required this.onClose,
    this.saveKey,
    this.onSave,
    this.showSave = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Material(
      color: p.sheet,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kRadiusSheet),
        ),
        side: BorderSide(color: p.border, width: p.borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: p.separator,
                  borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SettingsGlassButton(
                  key: closeKey,
                  icon: Icons.close_rounded,
                  tooltip: 'Cancelar',
                  onPressed: onClose,
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: kSettingsNavTitle.copyWith(color: p.label),
                  ),
                ),
                if (onSave != null || showSave)
                  SettingsGlassButton(
                    key: saveKey,
                    icon: Icons.check_rounded,
                    tooltip: 'Guardar',
                    prominent: true,
                    onPressed: onSave,
                  )
                else
                  const SizedBox(width: kSettingsNavButtonSize),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Campo de la hoja (maqueta `.fld`): caja surf + line con la etiqueta en
/// mono mayúsculas arriba y el valor abajo. [mono] escribe el valor en
/// monoespaciada (texto de un snippet, contraseña).
class SettingsSheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final bool mono;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool autofocus;

  const SettingsSheetField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.mono = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final valueStyle = mono || obscure
        ? kTextMono.copyWith(fontSize: 15, color: p.label, height: 1.4)
        : kTextBody.copyWith(color: p.label);
    // La etiqueta flotante se dibuja al 75 %: 16 → 12 sp visibles.
    final labelStyle = kTextGroupLabel.copyWith(
      fontSize: 16,
      letterSpacing: 2,
      color: p.secondary,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(kRadiusField),
        border: Border.all(color: p.border, width: p.borderWidth),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autocorrect: !obscure,
        enableSuggestions: !obscure,
        autofocus: autofocus,
        minLines: obscure ? 1 : minLines,
        maxLines: obscure ? 1 : maxLines,
        keyboardType: maxLines > 1 ? TextInputType.multiline : null,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        cursorColor: p.tintText,
        style: valueStyle,
        decoration: InputDecoration(
          label: Text(label.toUpperCase(), semanticsLabel: label),
          hintText: hint,
          errorText: errorText,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: labelStyle,
          floatingLabelStyle: labelStyle,
          hintStyle: valueStyle.copyWith(color: p.chevron),
          errorStyle: kTextFootnote.copyWith(color: p.danger),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          filled: false,
        ),
      ),
    );
  }
}

/// Columna de campos de la hoja, separados por un respiro (cada campo ya
/// es su propia caja). Una acción suelta (p. ej. "Eliminar snippet") se
/// lee como texto danger, sin caja.
class SettingsSheetCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsSheetCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
