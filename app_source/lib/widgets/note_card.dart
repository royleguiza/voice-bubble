import 'package:flutter/material.dart';

import '../helpers/note_groups.dart';
import '../models/voice_note.dart';
import '../ui/design_tokens.dart';
import 'app_icons.dart';
import 'note_audio_row.dart';

/// Tarjeta de nota de la lista principal (capa de contenido: sin vidrio).
///
/// Título en una línea, dos líneas de texto, hora y pastilla de audio. Tocar
/// abre el editor; mantener abre el menú de acciones (copiar, borrar audio,
/// eliminar). Copiar también queda a un toque, porque es lo que más se usa.
class NoteCard extends StatelessWidget {
  final VoiceNote note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCopy;

  /// 1 → 0 al aparecer una nota recién dictada: anillo de acento que se
  /// desvanece. Null en las demás.
  final Animation<double>? highlight;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.onCopy,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final accent = isDark ? kAccentDark : kAccentLight;
    final untitled = note.titulo.trim().isEmpty;
    final radius = BorderRadius.circular(kBorderRadiusNoteCard);

    final card = Material(
      color: isDark ? kBgElevatedDark : kBgSecondaryLight,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        untitled ? 'Sin título' : note.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kTextBody.copyWith(
                          fontWeight:
                              untitled ? FontWeight.w500 : FontWeight.w600,
                          color: untitled ? secondary : primary,
                          height: 22 / 17,
                        ),
                      ),
                    ),
                  ),
                  if (onCopy != null)
                    IconButton(
                      key: ValueKey('noteCopy-${note.id}'),
                      tooltip: 'Copiar texto',
                      icon: Icon(Icons.copy_rounded,
                          size: AppIcons.small, color: secondary),
                      onPressed: onCopy,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  note.cuerpo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      kTextSubhead.copyWith(color: secondary, height: 20 / 15),
                ),
              ),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Text(
                      noteTimeLabel(note.updatedAt),
                      style: kTextFootnote.copyWith(
                        color: secondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (note.hasAudio) ...[
                      const SizedBox(width: 10),
                      NoteAudioRow(
                        key: ValueKey('audio_${note.id}'),
                        audioPath: note.audioPath!,
                        noteId: note.id,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final highlighted = highlight == null
        ? card
        : AnimatedBuilder(
            animation: highlight!,
            builder: (context, child) => DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: accent.withValues(alpha: highlight!.value),
                  width: 2,
                ),
              ),
              child: child,
            ),
            child: card,
          );

    return Semantics(
      container: true,
      label: 'Nota: ${untitled ? 'Sin título' : note.titulo}',
      hint: 'Mantené presionado para más acciones',
      child: highlighted,
    );
  }
}
