import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../ui/design_tokens.dart';
import 'app_icons.dart';

/// Pastilla de audio conservado en una nota: "▶ 0:38".
///
/// Reproduce el WAV original guardado en `notes_audio/` con un player
/// creado solo al tocar (perezoso: construir el widget no toca canales
/// nativos). Sin red: playback local de archivos propios. Borrar el audio
/// vive en el menú de la nota, no acá: la tarjeta queda liviana.
class NoteAudioRow extends StatefulWidget {
  final String audioPath;
  final String noteId;

  const NoteAudioRow({
    super.key,
    required this.audioPath,
    required this.noteId,
  });

  /// WAV PCM 16 bits mono a 16 kHz (TranscriptionService): 32000 B/s.
  static const int bytesPerSecond = 32000;

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

  /// Duración leída del tamaño del archivo (cabecera RIFF de 44 bytes).
  /// I/O sync a propósito: un stat() de microsegundos, y `await` de dart:io
  /// se cuelga bajo FakeAsync de los widget tests (AGENTS §9.2-10).
  String? get _durationLabel {
    try {
      final file = File(widget.audioPath);
      if (!file.existsSync()) return null;
      final secs = ((file.lengthSync() - 44) / NoteAudioRow.bytesPerSecond)
          .round()
          .clamp(0, 359999);
      return '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final accent = isDark ? kAccentDark : kAccentLight;
    if (_missing || _corrupt) {
      return Text(
        _missing
            ? 'Audio no encontrado'
            : 'Audio dañado; borralo y grabalo de nuevo',
        style: kTextCaption.copyWith(color: secondary),
      );
    }
    final duration = _durationLabel;
    return Semantics(
      button: true,
      label: _playing
          ? 'Detener audio'
          : 'Escuchar audio${duration == null ? '' : ', $duration'}',
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey('notePlayAudio-${widget.noteId}'),
        onTap: _toggle,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
        containedInkWell: true,
        // Pastilla de 28 dp dentro de un área táctil de 44 dp.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            height: 28,
            padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: AppIcons.small,
                  color: accent,
                ),
                const SizedBox(width: 4),
                Text(
                  duration ?? 'Audio',
                  style: kTextCaption.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
