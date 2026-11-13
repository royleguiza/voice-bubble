import 'package:flutter/material.dart';

import '../ui/design_tokens.dart';
import '../ui/symbol_field.dart';
import 'app_icons.dart';

/// Piezas visuales de la pantalla principal (Notas + Historial): selector
/// de pestañas, buscador, encabezados de sección, estado vacío y menú de
/// acciones de una nota. Sin lógica: la pantalla decide qué hacer.

/// Pestañas de texto "Notas | Historial" (Horizonte): sin caja; la activa
/// va en fg con subrayado de brasa y la otra en fg2. El contador va en mono.
class HomeSegmented extends StatelessWidget {
  final int index;
  final int notesCount;
  final int historyCount;
  final ValueChanged<int> onChanged;

  const HomeSegmented({
    super.key,
    required this.index,
    required this.notesCount,
    required this.historyCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionSafe = !MediaQuery.of(context).disableAnimations;
    final duration =
        motionSafe ? const Duration(milliseconds: 200) : Duration.zero;
    final primary = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final ember = isDark ? kEmberDark : kEmberLight;
    final line = isDark ? kSeparatorDark : kSeparatorLight;

    Widget tab(int i, String label, int count, String key) {
      final selected = i == index;
      final color = selected ? primary : secondary;
      return Semantics(
        selected: selected,
        button: true,
        label: '$label, $count',
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey(key),
          onTap: selected ? null : () => onChanged(i),
          child: AnimatedContainer(
            duration: duration,
            curve: kCurveFade,
            height: kHomeTabHeight,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? ember : ember.withValues(alpha: 0),
                  width: kHomeTabUnderline,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: label,
                  style: kTextSubhead.copyWith(
                    fontFamily: kFontDisplay,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: '  $count',
                  style: kTextMono.copyWith(fontSize: 12, color: color),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: line, width: kSurfaceBorderWidth),
        ),
      ),
      child: Row(
        children: [
          tab(0, 'Notas', notesCount, 'home-tab-notas'),
          const SizedBox(width: 22),
          tab(1, 'Historial', historyCount, 'home-tab-historial'),
        ],
      ),
    );
  }
}

/// Buscador de la pantalla principal (filtra la pestaña visible).
class HomeSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const HomeSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final fill = isDark ? kFillDark : kFillLight;
    return SizedBox(
      height: 44,
      child: TextField(
        key: const ValueKey('homeSearchField'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: kTextBody.copyWith(
          color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: kTextBody.copyWith(color: secondary),
          prefixIcon: Icon(Icons.search_rounded,
              size: AppIcons.small, color: secondary),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: Icon(Icons.cancel_rounded,
                        size: AppIcons.small, color: secondary),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          filled: true,
          fillColor: fill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusField),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusField),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusField),
            borderSide: BorderSide(
              color: isDark ? kAccentDark : kAccentLight,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado de grupo de la lista ("HOY", "AYER", "OCTUBRE"…): mono en
/// mayúsculas con tracking, fg2 (maqueta `.grp`).
class HomeSectionHeader extends StatelessWidget {
  final String label;

  const HomeSectionHeader(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text(
          label.toUpperCase(),
          style: kTextGroupLabel.copyWith(
            color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
          ),
        ),
      ),
    );
  }
}

/// Estado vacío o mensaje centrado de la lista. Con [showGlyph] (lista
/// realmente vacía) lleva el campo de símbolos encima; los avisos (sin
/// resultados, cargando) van sin él.
class HomeEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final bool showGlyph;

  const HomeEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.showGlyph = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
      child: Column(
        children: [
          if (showGlyph) ...[
            const SymbolField(),
            const SizedBox(height: 14),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: kTextTitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: kTextSubhead.copyWith(
              height: 1.4,
              color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Acciones del menú de una nota.
enum NoteAction { open, copy, deleteAudio, delete }

/// Menú de acciones de una nota: hoja sólida desde abajo (surf, radio
/// superior 22, agarradera line). Borrar va en danger; el resto, neutro.
Future<NoteAction?> showNoteActions(
  BuildContext context, {
  required String heading,
  required bool hasAudio,
}) {
  return showModalBottomSheet<NoteAction>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: kScrimColor,
    useSafeArea: true,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final primary = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
      final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
      final danger = isDark ? kDangerDark : kDangerLight;
      final line = isDark ? kSeparatorDark : kSeparatorLight;
      final highContrast = MediaQuery.highContrastOf(sheetContext);
      final surface = highContrast
          ? (isDark ? kHighContrastSurfaceDark : kHighContrastSurfaceLight)
          : (isDark ? kBgElevatedDark : kBgElevatedLight);
      final border = highContrast ? primary : line;

      Widget action(NoteAction a, IconData icon, String label,
          {bool destructive = false}) {
        return InkWell(
          key: ValueKey('noteAction-${a.name}'),
          borderRadius: BorderRadius.circular(kRadiusCard),
          onTap: () => Navigator.of(sheetContext).pop(a),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(icon,
                    size: AppIcons.medium,
                    color: destructive ? danger : secondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: kTextBody.copyWith(
                        color: destructive ? danger : primary),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(kRadiusSheet),
          ),
          border: Border(
            top: BorderSide(
              color: border,
              width: highContrast
                  ? kGlassBorderWidthAccessible
                  : kSurfaceBorderWidth,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            8,
            8,
            8 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 2, bottom: 12),
                decoration: BoxDecoration(
                  color: line,
                  borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kTextFootnote.copyWith(color: secondary),
                ),
              ),
              action(
                  NoteAction.open, Icons.edit_note_rounded, 'Abrir y editar'),
              action(NoteAction.copy, Icons.copy_rounded, 'Copiar texto'),
              if (hasAudio)
                action(NoteAction.deleteAudio, Icons.music_off_rounded,
                    'Borrar audio, conservar texto',
                    destructive: true),
              action(NoteAction.delete, Icons.delete_outline_rounded,
                  'Eliminar nota',
                  destructive: true),
            ],
          ),
        ),
      );
    },
  );
}
