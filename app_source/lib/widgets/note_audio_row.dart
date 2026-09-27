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
  bool _corrupt = false;

  bool get _fileExists {
    try {
      return File(widget.audioPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// C-45: cabecera mínima RIFF/WAVE antes de reproducir. Un notes_audio
  /// heredado dañado (hueco sin tapa de antes del fix) fallaba en silencio;
  /// ahora avisa "Audio dañado" en vez de no hacer nada.
  bool _hasValidHeader() {
    try {
      final file = File(widget.audioPath);
      if (!file.existsSync() || file.lengthSync() < 12) return false;
      final raf = file.openSync(mode: FileMode.read);
      try {
        final head = raf.readSync(12);
        if (head.length < 12) return false;
        return head[0] == 0x52 && // R
            head[1] == 0x49 && // I
            head[2] == 0x46 && // F
            head[3] == 0x46 && // F
            head[8] == 0x57 && // W
            head[9] == 0x41 && // A
            head[10] == 0x56 && // V
            head[11] == 0x45; // E
      } finally {
        try {
          raf.closeSync();
        } catch (_) {}
      }
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
    if (!_hasValidHeader()) {
      if (mounted) setState(() => _corrupt = true);
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
                : _corrupt
                    ? 'Audio dañado; borralo y grabalo de nuevo'
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
          TextButton(
            key: ValueKey('noteDeleteAudio-${widget.noteId}'),
            onPressed: widget.onDeleteAudio,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.padded,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              foregroundColor: secondary,
              textStyle: kTextCaption.copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
            child: const Text('Borrar audio'),
          ),
      ],
    );
  }
}
