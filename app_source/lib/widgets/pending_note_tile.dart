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
  StreamSubscription<Duration>? _posSub;
  bool _open = false;
  bool _playing = false;
  bool _unplayable = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void dispose() {
    unawaited(_doneSub?.cancel());
    unawaited(_posSub?.cancel());
    unawaited(_player?.stop());
    unawaited(_player?.dispose());
    _player = null;
    super.dispose();
  }

  String _fmt(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  /// Duración estimada por tamaño (PCM16 mono 16kHz propio). Sincrónica y
  /// barata (un stat); el valor real lo corrige el player al sonar.
  Duration _estimateTotal() {
    try {
      final len = File(widget.item.audioPath).lengthSync();
      if (len <= 44) return Duration.zero;
      final secs = (len - 44) ~/ 32000;
      return Duration(seconds: secs < 1 ? 1 : secs);
    } catch (_) {
      return Duration.zero;
    }
  }

  Future<void> _toggleMain() async {
    if (!_open) {
      setState(() {
        _open = true;
        _unplayable = false;
        _position = Duration.zero;
        _total = _estimateTotal();
      });
      bool exists;
      try { exists = File(widget.item.audioPath).existsSync(); } catch (_) { exists = false; }
      if (!exists) {
        setState(() => _unplayable = true);
        return;
      }
      try { await _startPlayer(); } catch (_) { setState(() => _unplayable = true); }
      return;
    }
    if (_playing) {
      try { await _player?.pause(); } catch (_) {}
      setState(() => _playing = false);
      return;
    }
    if (_unplayable) return;
    try {
      await _player?.resume();
      setState(() => _playing = true);
    } catch (_) {}
  }
  Future<void> _startPlayer() async {
    try { await _player?.dispose(); } catch (_) {}
    AudioPlayer? player;
    try {
      player = AudioPlayer();
      _player = player;
    } catch (_) {
      setState(() => _unplayable = true);
      return;
    }
    try {
      await _doneSub?.cancel();
      await _posSub?.cancel();
    } catch (_) {}
    _doneSub = player.onPlayerComplete.listen((_) {
      setState(() {
        _playing = false;
        _open = false;
        _position = Duration.zero;
      });
    });
    _posSub = player.onPositionChanged.listen((pos) {
      if (pos.inSeconds != _position.inSeconds) {
        setState(() => _position = pos);
      }
    });
    try {
      await player.play(DeviceFileSource(widget.item.audioPath));
      final real = await player.getDuration();
      setState(() {
        _playing = true;
        if (real != null && real.inMilliseconds > 0) _total = real;
      });
    } catch (_) {
      setState(() => _unplayable = true);
      try { await player.stop(); } catch (_) {}
    }
  }
  Future<void> _closePlayer() async {
    try { await _player?.stop(); } catch (_) {}
    setState(() {
      _playing = false;
      _open = false;
      _unplayable = false;
      _position = Duration.zero;
    });
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
              // C-46: reproductor expandible con tiempos reales. Play
              // centrado que se abre en dos burbujas (pausa izq, X der)
              // con transcurrido / total en el medio, sin barra.
              _PlayerStage(
                open: _open,
                playing: _playing,
                enabled: !widget.busy,
                clock: '${_fmt(_position)} / ${_fmt(_total)}',
                mainKey: ValueKey('playPendingButton-${widget.item.id}'),
                closeKey: ValueKey('closePendingPlayer-${widget.item.id}'),
                clockKey: ValueKey('pendingPlayerClock-${widget.item.id}'),
                onMain: _toggleMain,
                onClose: _closePlayer,
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

/// Escenario del reproductor expandible (C-46).
///
/// Play centrado que se abre en dos burbujas: pausa a la izquierda y X a
/// la derecha, con `clock` (transcurrido / total) en el medio. Sin barra.
/// La apertura y el cierre animan en espejo con [AnimatedPositioned].
class _PlayerStage extends StatelessWidget {
  final bool open;
  final bool playing;
  final bool enabled;
  final String clock;
  final ValueKey<String> mainKey;
  final ValueKey<String> closeKey;
  final ValueKey<String> clockKey;
  final VoidCallback onMain;
  final VoidCallback onClose;

  const _PlayerStage({
    required this.open,
    required this.playing,
    required this.enabled,
    required this.clock,
    required this.mainKey,
    required this.closeKey,
    required this.clockKey,
    required this.onMain,
    required this.onClose,
  });

  static const double _buttonSize = 48;
  static const Duration _anim = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final center = maxWidth / 2;
        final double gap = (maxWidth * 0.30).clamp(96.0, 150.0).toDouble();
        // Ambas burbujas en el centro cuando están colapsadas;
        // la X usa IgnorePointer para no bloquear el play.
        final buttonLeft = center - _buttonSize / 2;
        final mainLeft = open ? center - gap - _buttonSize / 2 : buttonLeft;
        final closeLeft = open ? center + gap - _buttonSize / 2 : buttonLeft;
        return SizedBox(
          height: 64,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AnimatedOpacity(
                  duration: _anim,
                  opacity: open ? 1 : 0,
                  child: Text(
                    clock,
                    key: clockKey,
                    style: kTextSubhead.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
               AnimatedPositioned(
                duration: _anim,
                curve: Curves.easeOut,
                left: mainLeft,
                top: 8,
                child: _RoundButton(
                  key: mainKey,
                  tooltip: playing ? 'Pausar' : 'Escuchar audio',
                  icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  enabled: enabled,
                  onPressed: onMain,
                ),
              ),
              AnimatedPositioned(
                duration: _anim,
                curve: Curves.easeOut,
                left: closeLeft,
                top: 8,
                child: IgnorePointer(
                  ignoring: !open,
                  child: AnimatedOpacity(
                    duration: _anim,
                    opacity: open ? 1 : 0,
                    child: AnimatedScale(
                      duration: _anim,
                      scale: open ? 1 : 0.6,
                      child: _RoundButton(
                        key: closeKey,
                        tooltip: 'Cerrar reproductor',
                        icon: Icons.close_rounded,
                        enabled: enabled && open,
                        onPressed: open ? onClose : () {},
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _RoundButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 22, color: secondary),
        onPressed: enabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    );
  }
}
