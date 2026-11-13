import 'package:flutter/material.dart';

import '../helpers/note_groups.dart';
import '../models/voice_note.dart';
import '../ui/design_tokens.dart';
import 'app_icons.dart';
import 'note_audio_row.dart';

/// Tarjeta de nota de la lista principal (Horizonte: superficie surf con
/// borde line de 1 px, radio 14, sin sombra).
///
/// Título en Sora, dos líneas de texto en fg2 y una fila meta con la hora
/// en mono, la pastilla de audio y copiar a la derecha. Tocar abre el
/// editor; mantener abre el menú de acciones (copiar, borrar audio,
/// eliminar). Copiar también queda a un toque, porque es lo que más se usa.
class NoteCard extends StatelessWidget {
  final VoiceNote note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCopy;

  /// 1 → 0 al aparecer una nota recién dictada: anillo de acento que se
  /// desvanece. Null en las demás.
  final Animation<double>? highlight;

  /// Hora o fecha corta ya formateada por la lista (memoizada junto con los
  /// grupos). Sin ella se calcula acá.
  final String? timeLabel;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.onCopy,
    this.highlight,
    this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final primary = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final accent = isDark ? kAccentDark : kAccentLight;
    final untitled = note.titulo.trim().isEmpty;
    final radius = BorderRadius.circular(kRadiusCard);
    final surface = highContrast
        ? (isDark ? kHighContrastSurfaceDark : kHighContrastSurfaceLight)
        : (isDark ? kBgElevatedDark : kBgElevatedLight);

    final card = Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: highContrast
              ? primary
              : (isDark ? kSeparatorDark : kSeparatorLight),
          width: highContrast
              ? kGlassBorderWidthAccessible
              : kSurfaceBorderWidth,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  untitled ? 'Sin título' : note.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kTextCardTitle.copyWith(
                    color: untitled ? secondary : primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 12),
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
                      timeLabel ?? noteTimeLabel(note.updatedAt),
                      style: kTextMono.copyWith(fontSize: 12, color: secondary),
                    ),
                    if (note.hasAudio) ...[
                      const SizedBox(width: 10),
                      NoteAudioRow(
                        key: ValueKey('audio_${note.id}'),
                        audioPath: note.audioPath!,
                        noteId: note.id,
                      ),
                    ],
                    const Spacer(),
                    if (onCopy != null)
                      IconButton(
                        key: ValueKey('noteCopy-${note.id}'),
                        tooltip: 'Copiar texto',
                        icon: Icon(Icons.copy_rounded,
                            size: AppIcons.small, color: secondary),
                        onPressed: onCopy,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
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
