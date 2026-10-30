import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/design_tokens.dart';

/// Kit visual de Ajustes 2026 (prototipo "VoiceBubble · Ajustes 2026").
///
/// Un solo lenguaje para toda la sección, estilo Ajustes de iOS 26:
/// grupos con esquinas de 26, filas de 52 dp y solo cinco tipos de fila:
/// - [SettingsNavRow]: entra a otra página (chevron).
/// - [SettingsSwitchRow]: sí / no (interruptor).
/// - [SettingsMenuRow]: elegir una opción (menú desplegable con check).
/// - [SettingsActionRow]: ejecutar algo (texto azul o rojo).
/// - [SettingsValueRow]: dato de solo lectura.
/// La conducta y el estado viven en las páginas; aquí solo presentación.

/// Colores de la sección resueltos según el brillo del tema.
class SettingsPalette {
  final bool isDark;

  const SettingsPalette._(this.isDark);

  factory SettingsPalette.of(BuildContext context) =>
      SettingsPalette._(Theme.of(context).brightness == Brightness.dark);

  Color get background => isDark ? kBgBaseDark : kBgBaseLight;
  Color get card => isDark ? kBgElevatedDark : kBgElevatedLight;
  Color get label => isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
  Color get secondary =>
      isDark ? kSettingsSecondaryDark : kSettingsSecondaryLight;
  Color get chevron => isDark ? kSettingsChevronDark : kSettingsChevronLight;
  Color get separator =>
      isDark ? kSettingsSeparatorDark : kSettingsSeparatorLight;
  Color get switchOff => isDark ? kSwitchOffDark : kSwitchOffLight;
  Color get tintText => isDark ? kTintTextDark : kTintTextLight;
  Color get tintFill => isDark ? kAccentDark : kAccentLight;
  Color get alert => isDark ? kSettingsAlertDark : kSettingsAlertLight;
  Color get success => isDark ? kSuccessDark : kSuccessLight;
  Color get glass => isDark ? kSettingsGlassDark : kSettingsGlassLight;
  Color get glassBorder =>
      isDark ? kSettingsGlassBorderDark : kSettingsGlassBorderLight;
  Color get menu => isDark ? kSettingsMenuDark : kSettingsMenuLight;
  Color get sheet => isDark ? kBgElevatedDark : kBgBaseLight;
  Color get sheetCard => isDark ? kBgSecondaryDark : kBgElevatedLight;
}

/// Título grande de la raíz ("Ajustes").
class SettingsLargeTitle extends StatelessWidget {
  final String text;

  const SettingsLargeTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 56, 4, 12),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: kSettingsLargeTitle.copyWith(
            color: SettingsPalette.of(context).label,
          ),
        ),
      ),
    );
  }
}

/// Grupo de filas: encabezado opcional, tarjeta redondeada con separadores
/// finos y una línea de pie opcional.
class SettingsSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  /// Sangría del separador: 60 cuando las filas llevan pastilla de icono
  /// (el separador arranca en el texto, como iOS), 16 si no.
  final bool iconInset;

  const SettingsSection({
    super.key,
    this.header,
    this.footer,
    this.iconInset = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: iconInset ? 60 : 16),
          child: Container(height: 0.5, color: p.separator),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                header!,
                style: kSettingsSectionHeader.copyWith(color: p.label),
              ),
            ),
          ),
        Material(
          color: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kSettingsGroupRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              footer!,
              style: kTextFootnote.copyWith(color: p.secondary, height: 1.35),
            ),
          ),
      ],
    );
  }
}

/// Pastilla de icono 30x30 de fila (tinte sólido, glifo blanco).
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
    final highContrast = MediaQuery.highContrastOf(context);
    final border = highContrast
        ? Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            width: 1.5,
          )
        : null;

    return Container(
      width: kSettingIconSize,
      height: kSettingIconSize,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(kSettingIconRadius),
        border: border,
      ),
      child: Icon(icon, color: kLabelPrimaryDark, size: 18),
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
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
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

Widget? _tile(IconData? icon, Color? tile) =>
    icon == null ? null : SettingIconTile(icon: icon, background: tile!);

/// Entra a otra página: valor actual en gris + chevron.
class SettingsNavRow extends StatelessWidget {
  final String title;
  final String? value;
  final Color? valueColor;
  final IconData? icon;
  final Color? tile;
  final VoidCallback onTap;

  const SettingsNavRow({
    super.key,
    required this.title,
    this.value,
    this.valueColor,
    this.icon,
    this.tile,
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
        leading: _tile(icon, tile),
        title: title,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasValue)
              Text(
                value!,
                style: kTextBody.copyWith(color: valueColor ?? p.secondary),
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
  final Color? tile;

  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.badge,
    this.icon,
    this.tile,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: _RowShell(
        leading: _tile(icon, tile),
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
              activeTrackColor: kSwitchOn,
              inactiveTrackColor: p.switchOff,
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta chica gris ("Beta").
class SettingsBadge extends StatelessWidget {
  final String text;

  const SettingsBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.switchOff,
        borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
      ),
      child: Text(
        text,
        style: kTextCaption.copyWith(
          fontWeight: FontWeight.w600,
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
  final Color? tile;

  SettingsMenuRow({
    required this.id,
    required this.title,
    required this.value,
    required this.options,
    required this.onSelected,
    this.icon,
    this.tile,
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
        elevation: const WidgetStatePropertyAll(12),
        shadowColor: const WidgetStatePropertyAll(Color(0x55000000)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: p.glassBorder, width: 0.5),
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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    style: kTextSubhead.copyWith(color: p.secondary),
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
          leading: _tile(icon, tile),
          title: title,
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_currentLabel, style: kTextBody.copyWith(color: p.secondary)),
              const SizedBox(width: 4),
              Icon(Icons.unfold_more_rounded, size: 18, color: p.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ejecuta algo: texto azul (o rojo si es destructivo), sin chevron.
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
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : p.tintText;
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
        trailing: Text(
          value,
          style: kTextBody.copyWith(color: valueColor ?? p.secondary),
        ),
      ),
    );
  }
}

/// Estado confirmado (check verde + título + aclaración).
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
        leading: Container(
          width: kSettingIconSize,
          height: kSettingIconSize,
          decoration: const BoxDecoration(
            color: kTileGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 18,
            color: kLabelPrimaryDark,
          ),
        ),
        title: title,
        subtitle: subtitle,
        titleColor: p.label,
      ),
    );
  }
}

/// Botón circular de vidrio (volver, agregar, cerrar y guardar del sheet).
class SettingsGlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Relleno azul con glifo blanco (acción principal, p. ej. Guardar).
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
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: prominent ? p.tintFill : p.glass,
          shape: CircleBorder(
            side: prominent
                ? BorderSide.none
                : BorderSide(color: p.glassBorder, width: 0.5),
          ),
          elevation: prominent ? 0 : 2,
          shadowColor: const Color(0x33000000),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: kSettingsNavButtonSize,
              height: kSettingsNavButtonSize,
              child: Icon(
                icon,
                size: 22,
                color: prominent ? kLabelPrimaryDark : p.label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de identidad de la app en la raíz (abre Acerca de).
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
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const SettingsAppIcon(dimension: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: kTextTitle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          color: p.label,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: kTextSubhead.copyWith(color: p.secondary),
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

/// Icono de la app (cuadrado redondeado azul con micrófono).
class SettingsAppIcon extends StatelessWidget {
  final double dimension;

  const SettingsAppIcon({super.key, required this.dimension});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: kTileBlue,
        borderRadius: BorderRadius.circular(dimension * 0.26),
      ),
      child: Icon(
        Icons.mic_rounded,
        color: kLabelPrimaryDark,
        size: dimension * 0.5,
      ),
    );
  }
}

/// Estado vacío dentro de un grupo (icono, título, texto y botón).
class SettingsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Key? actionKey;
  final VoidCallback onAction;

  const SettingsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.actionKey,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(kSettingsGroupRadius),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: p.secondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: kTextTitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: p.label,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: kTextSubhead.copyWith(color: p.secondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: actionKey,
            style: FilledButton.styleFrom(
              backgroundColor: p.tintFill,
              foregroundColor: kLabelPrimaryDark,
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

/// Hoja inferior flotante (iOS 26): asa, barra con cerrar / título /
/// guardar, contenido y acción destructiva opcional al pie.
class SettingsSheetFrame extends StatelessWidget {
  final String title;
  final Key? closeKey;
  final VoidCallback onClose;
  final Key? saveKey;
  final VoidCallback? onSave;
  final List<Widget> children;

  const SettingsSheetFrame({
    super.key,
    required this.title,
    this.closeKey,
    required this.onClose,
    this.saveKey,
    this.onSave,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Material(
      color: p.sheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(40),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 16,
      shadowColor: const Color(0x55000000),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: p.chevron,
                  borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
                ),
              ),
            ),
            const SizedBox(height: 6),
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
                if (onSave != null)
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
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Campo de texto dentro de una tarjeta del sheet (etiqueta chica arriba).
class SettingsSheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
        style: kTextBody.copyWith(color: p.label),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: kTextFootnote.copyWith(color: p.secondary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          filled: false,
        ),
      ),
    );
  }
}

/// Tarjeta que agrupa campos del sheet con separadores.
class SettingsSheetCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsSheetCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Container(height: 0.5, color: p.separator),
        ));
      }
    }
    return Material(
      color: p.sheetCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}
