import 'package:flutter/material.dart';
import '../services/pending_note_queue.dart';
import '../ui/design_tokens.dart';

/// Fila de un audio pendiente de transcripción cloud en Notas.
/// Acciones explícitas del usuario: transcribir o descartar.
class PendingNoteTile extends StatelessWidget {
  final PendingNote item;
  final bool busy;
  final VoidCallback onTranscribe;
  final VoidCallback onDiscard;

  const PendingNoteTile({
    super.key,
    required this.item,
    required this.busy,
    required this.onTranscribe,
    required this.onDiscard,
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
      label: 'Audio sin transcribir, ${_format(item.createdAt)}',
      child: Material(
        color: isDark ? kBgSecondaryDark : kBgSecondaryLight,
        borderRadius: BorderRadius.circular(kBorderRadiusCard),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kBorderRadiusCard),
            border: Border.all(
              color: isDark ? kSeparatorDark : kSeparatorLight,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 18,
                    color: secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Audio sin transcribir',
                      style: kTextSubhead.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? kLabelPrimaryDark
                            : kLabelPrimaryLight,
                      ),
                    ),
                  ),
                  Text(
                    _format(item.createdAt),
                    style: kTextCaption.copyWith(color: secondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: ValueKey('transcribeCloudButton-${item.id}'),
                      onPressed: busy ? null : onTranscribe,
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Text('Transcribir con nube'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: ValueKey('discardPendingButton-${item.id}'),
                    tooltip: 'Descartar audio',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: secondary,
                    ),
                    onPressed: busy ? null : onDiscard,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
