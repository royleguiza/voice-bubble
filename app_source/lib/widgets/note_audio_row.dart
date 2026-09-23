import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../ui/design_tokens.dart';

/// Fila de audio conservado en una nota (texto + audio).
///
/// Reproduce el WAV original guardado en `notes_audio/` con un player
/// creado solo al tocar (perezoso: construir el widget no toca canales
/// nativos). Sin red: playback local de archivos propios.
class NoteAudioRow extends StatefulWidget {
  final String audioPath;
  final String noteId;
  final VoidCallback? onDeleteAudio;

  const NoteAudioRow({
    super.key,
    required this.audioPath,
    required this.noteId,
    this.onDeleteAudio,
  });

  @override
  State<NoteAudioRow> createState() => _NoteAudioRowState();
}

class _NoteAudioRowState extends State<NoteAudioRow> {
  AudioPlayer? _player;
  StreamSubscription<void>? _doneSub;
  bool _playing = false;
  bool _missing = false;

  bool get _fileExists {
    try {
      return File(widget.audioPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      try {
        await _player?.stop();
      } catch (_) {}
      if (mounted) setState(() => _playing = false);
      return;
    }
    if (!_fileExists) {
      if (mounted) setState(() => _missing = true);
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
      await player.play(DeviceFileSource(widget.audioPath));
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  void dispose() {
    unawaited(_doneSub?.cancel());
    unawaited(_player?.stop());
    unawaited(_player?.dispose());
    _player = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    return Row(
      children: [
        Icon(
          Icons.audiotrack_rounded,
          size: 18,
          color: secondary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _missing
                ? 'Audio no encontrado'
                : 'Audio original conservado',
            style: kTextCaption.copyWith(color: secondary),
          ),
        ),
        if (!_missing)
          IconButton(
            key: ValueKey('notePlayAudio-${widget.noteId}'),
            tooltip: _playing ? 'Detener' : 'Escuchar audio',
            icon: Icon(
              _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 18,
              color: secondary,
            ),
            onPressed: _toggle,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        if (widget.onDeleteAudio != null)
          InkWell(
            key: ValueKey('noteDeleteAudio-${widget.noteId}'),
            onTap: widget.onDeleteAudio,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Borrar audio',
                style: kTextCaption.copyWith(
                  color: secondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
