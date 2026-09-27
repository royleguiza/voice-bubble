import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/pending_note_queue.dart';
import '../ui/design_tokens.dart';

/// Fila de un audio pendiente de transcripción cloud en Notas.
/// Acciones explícitas del usuario: escuchar, transcribir o descartar.
///
/// C-45: el pendiente ahora se puede reproducir en la app (play local sin
/// red, player perezoso). Si el WAV heredado está dañado se avisa en vez
/// de fallar en silencio.
class PendingNoteTile extends StatefulWidget {
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

  @override
  State<PendingNoteTile> createState() => _PendingNoteTileState();
}

class _PendingNoteTileState extends State<PendingNoteTile> {
  AudioPlayer? _player;
  StreamSubscription<void>? _doneSub;
  bool _playing = false;
  bool _unplayable = false;

  @override
  void dispose() {
    unawaited(_doneSub?.cancel());
    unawaited(_player?.stop());
    unawaited(_player?.dispose());
    _player = null;
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      try {
        await _player?.stop();
      } catch (_) {}
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      if (!File(widget.item.audioPath).existsSync()) {
        if (mounted) setState(() => _unplayable = true);
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _unplayable = true);
      return;
    }
    try {
      await _player?.dispose();
    } catch (_) {}
    final player = AudioPlayer();
    _player = player;
    try {
      await _doneSub?.cancel();
    } catch (_) {}
    _doneSub = player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    try {
      await player.play(DeviceFileSource(widget.item.audioPath));
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) setState(() => _unplayable = true);
    }
  }

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
      container: true,
      label: 'Audio sin transcribir, ${_format(widget.item.createdAt)}',
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
                    _format(widget.item.createdAt),
                    style: kTextCaption.copyWith(color: secondary),
                  ),
                ],
              ),
              if (_unplayable)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No se pudo reproducir este audio',
                    style: kTextCaption.copyWith(color: secondary),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: ValueKey('transcribeCloudButton-${widget.item.id}'),
                      onPressed: widget.busy ? null : widget.onTranscribe,
                      child: widget.busy
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
                    key: ValueKey('playPendingButton-${widget.item.id}'),
                    tooltip: _playing ? 'Detener' : 'Escuchar audio',
                    icon: Icon(
                      _playing
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 18,
                      color: secondary,
                    ),
                    onPressed: widget.busy ? null : _togglePlay,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  IconButton(
                    key: ValueKey('discardPendingButton-${widget.item.id}'),
                    tooltip: 'Descartar audio',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: secondary,
                    ),
                    onPressed: widget.busy ? null : widget.onDiscard,
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
