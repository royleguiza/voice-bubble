import 'package:flutter/material.dart';

import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';
import 'app_icons.dart';

/// Piezas visuales de la pantalla principal (Notas + Historial): selector
/// de pestañas, buscador, encabezados de sección, estado vacío y menú de
/// acciones de una nota. Sin lógica: la pantalla decide qué hacer.

/// Selector segmentado "Notas | Historial" (capa de contenido).
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
    final track = isDark ? kFillDark : kFillLight;
    final thumb = isDark ? kSegmentThumbDark : kBgElevatedLight;
    final primary = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;

    Widget segment(int i, String label, int count, String key) {
      final selected = i == index;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: '$label, $count',
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey(key),
            borderRadius: BorderRadius.circular(kBorderRadiusSmall),
            onTap: selected ? null : () => onChanged(i),
            child: Center(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: label,
                    style: kTextFootnote.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  TextSpan(
                    text: '  $count',
                    style: kTextFootnote.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: secondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration:
                motionSafe ? const Duration(milliseconds: 320) : Duration.zero,
            curve: kCurveEnter,
            alignment:
                index == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: thumb,
                  borderRadius: BorderRadius.circular(kBorderRadiusSmall),
                  boxShadow: const [kSegmentThumbShadow],
                ),
              ),
            ),
          ),
          Row(
            children: [
              segment(0, 'Notas', notesCount, 'home-tab-notas'),
              segment(1, 'Historial', historyCount, 'home-tab-historial'),
            ],
          ),
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
      height: 40,
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
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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

/// Encabezado de sección de la lista ("HOY", "AYER", "OCTUBRE"…).
class HomeSectionHeader extends StatelessWidget {
  final String label;

  const HomeSectionHeader(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(
          label.toUpperCase(),
          style: kTextFootnote.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
          ),
        ),
      ),
    );
  }
}

/// Estado vacío o mensaje centrado de la lista.
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
    final accent = isDark ? kTintTextDark : kTintTextLight;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
      child: Column(
        children: [
          if (showGlyph) ...[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.graphic_eq_rounded,
                  size: AppIcons.large, color: accent),
            ),
            const SizedBox(height: 18),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: kTextTitle.copyWith(
              color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: kTextSubhead.copyWith(
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

/// Menú de acciones de una nota: hoja de vidrio desde abajo.
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
      final accent = isDark ? kTintTextDark : kTintTextLight;

      Widget action(NoteAction a, IconData icon, String label,
          {bool muted = false}) {
        return InkWell(
          key: ValueKey('noteAction-${a.name}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(sheetContext).pop(a),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(icon,
                    size: AppIcons.medium, color: muted ? secondary : accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style:
                        kTextBody.copyWith(color: muted ? secondary : primary),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: GlassContainer(
          borderRadius: kBorderRadiusSheetLarge,
          small: false,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 2, bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? kLabelTertiaryDark : kLabelTertiaryLight,
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
                    muted: true),
              action(NoteAction.delete, Icons.delete_outline_rounded,
                  'Eliminar nota',
                  muted: true),
            ],
          ),
        ),
      );
    },
  );
}
