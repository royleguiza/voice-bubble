import 'package:flutter/material.dart';
import '../models/voice_note.dart';
import '../ui/design_tokens.dart';
import 'note_audio_row.dart';

class NoteCard extends StatelessWidget {
  final VoiceNote note;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onDeleteAudio;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onDelete,
    this.onCopy,
    this.onDeleteAudio,
  });

  String _format(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    return Semantics(
      button: true,
      label: 'Abrir nota ${note.titulo.isEmpty ? 'Sin título' : note.titulo}',
      child: Material(
        color: isDark ? kBgSecondaryDark : kBgSecondaryLight,
        borderRadius: BorderRadius.circular(kBorderRadiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(kBorderRadiusCard),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kBorderRadiusCard),
              border: Border.all(
                color: isDark ? kSeparatorDark : kSeparatorLight,
                width: 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.titulo.isEmpty ? 'Sin título' : note.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kTextSubhead.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
                          fontStyle: note.titulo.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note.cuerpo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: kTextFootnote.copyWith(color: secondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _format(note.updatedAt),
                        style: kTextCaption.copyWith(color: secondary),
                      ),
                      if (note.hasAudio) ...[
                        const SizedBox(height: 6),
                        NoteAudioRow(
                          audioPath: note.audioPath!,
                          noteId: note.id,
                          onDeleteAudio: onDeleteAudio,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onCopy != null)
                  IconButton(
                    tooltip: 'Copiar contenido',
                    icon: Icon(Icons.copy_rounded, size: 18, color: secondary),
                    onPressed: onCopy,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Borrar',
                    icon: Icon(Icons.close_rounded, size: 18, color: secondary),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  )
                else if (onCopy == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: secondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
