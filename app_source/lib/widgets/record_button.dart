import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';
import 'app_icons.dart';

/// Burbuja de dictado de la pantalla principal (capa funcional, vidrio).
///
/// Es un solo objeto que cambia de forma, la misma idea que la burbuja que
/// flota sobre otras apps:
/// - idle: círculo de vidrio Ø76 con el micrófono en acento.
/// - recording: se estira en pastilla con ✕ (cancelar, solo modo toque),
///   punto rojo, tiempo, onda con el nivel REAL del micrófono y ■ detener.
/// - transcribing: vuelve a círculo con tres puntos en ola; deshabilitado.
///
/// El rojo queda solo en lo semántico de grabar (punto y ■), nunca en el
/// vidrio: así el morph no interpola decoraciones rojas (artefacto que tenía
/// el botón anterior al salir de recording).
enum RecordButtonState { idle, recording, transcribing }

class RecordButton extends StatefulWidget {
  final RecordButtonState state;
  final VoidCallback? onPressed;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  /// Descarta la grabación en curso sin transcribir (✕). Solo modo toque:
  /// en modo mantener el dedo está sobre la burbuja.
  final VoidCallback? onCancel;

  /// Nivel de entrada 0..1. Se consulta mientras se graba para dibujar la
  /// onda; sin fuente, la onda queda plana (no se inventa movimiento).
  final Future<double> Function()? levelSource;

  const RecordButton({
    super.key,
    required this.state,
    this.onPressed,
    this.onHoldStart,
    this.onHoldEnd,
    this.onCancel,
    this.levelSource,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  static const int _bars = 28;
  static const Duration _tick = Duration(milliseconds: 90);

  /// Pulso del punto rojo y ola de los puntos de "transcribiendo".
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _pulseActive = false;

  final List<double> _levels = List<double>.filled(_bars, 0, growable: true);

  /// Hora de inicio de la grabación en curso (para el tiempo M:SS).
  DateTime? _startedAt;
  Timer? _ticker;
  bool _polling = false;

  bool get _isRecording => widget.state == RecordButtonState.recording;
  bool get _isTranscribing => widget.state == RecordButtonState.transcribing;
  bool get _isHoldMode => widget.onHoldStart != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant RecordButton old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _syncAnimations();
  }

  void _syncAnimations() {
    final motionSafe = !MediaQuery.of(context).disableAnimations;
    final animate = motionSafe && (_isRecording || _isTranscribing);
    if (animate && !_pulseActive) {
      _pulse.repeat();
      _pulseActive = true;
    } else if (!animate && _pulseActive) {
      _pulse.stop();
      _pulse.value = 0;
      _pulseActive = false;
    }

    if (_isRecording && _ticker == null) {
      _levels.fillRange(0, _bars, 0);
      _startedAt = DateTime.now();
      _ticker = Timer.periodic(_tick, (_) => _onTick());
    } else if (!_isRecording && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
      _startedAt = null;
    }
  }

  Future<void> _onTick() async {
    if (!mounted) return;
    double level = 0;
    final source = widget.levelSource;
    if (source != null && !_polling) {
      _polling = true;
      try {
        level = await source();
      } catch (_) {
        level = 0;
      } finally {
        _polling = false;
      }
    }
    if (!mounted || !_isRecording) return;
    setState(() {
      _levels
        ..removeAt(0)
        ..add(level.clamp(0.0, 1.0));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  bool get _enabled =>
      !_isTranscribing &&
      (widget.onPressed != null ||
          widget.onHoldStart != null ||
          widget.onHoldEnd != null);

  String get _elapsed {
    final started = _startedAt;
    final s =
        started == null ? 0 : DateTime.now().difference(started).inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionSafe = !MediaQuery.of(context).disableAnimations;
    final semanticLabel = _isRecording
        ? 'Detener grabación'
        : _isTranscribing
            ? 'Transcribiendo'
            : (_isHoldMode ? 'Mantené para grabar' : 'Iniciar grabación');

    // Semantics en la raíz: TalkBack lee el nodo de la burbuja misma.
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: _enabled ? widget.onPressed : null,
      onLongPress: (_enabled && _isHoldMode)
          ? (_isRecording ? widget.onHoldEnd : widget.onHoldStart)
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = math.min(kRecordPillMaxWidth, constraints.maxWidth);
          final width = _isRecording ? pillWidth : kRecordButtonSize;
          final height = _isRecording ? kRecordPillHeight : kRecordButtonSize;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enabled ? widget.onPressed : null,
            onLongPressStart: (_enabled && widget.onHoldStart != null)
                ? (_) => widget.onHoldStart!()
                : null,
            onLongPressEnd: (_enabled && widget.onHoldEnd != null)
                ? (_) => widget.onHoldEnd!()
                : null,
            onLongPressCancel: (_enabled && widget.onHoldEnd != null)
                ? () => widget.onHoldEnd!()
                : null,
            child: AnimatedContainer(
              duration: motionSafe ? kAnimMorph : Duration.zero,
              // Al abrirse, rebote suave; al cerrarse, sin overshoot.
              curve: _isRecording ? kCurveEnter : kCurveExit,
              width: width,
              height: height,
              // Crystal: borde y brillo visibles también sobre el negro del
              // modo oscuro (el vidrio regular se perdía contra el fondo).
              child: GlassContainer(
                borderRadius: kBorderRadiusCapsule,
                crystal: true,
                // Cambio instantáneo + fundido de entrada del contenido nuevo:
                // nunca conviven dos estados (ni el micrófono bajo la pastilla).
                child: _FadeIn(
                  key: ValueKey(widget.state),
                  enabled: motionSafe,
                  child: _isRecording
                      ? _RecordingContent(
                          key: const ValueKey('recordPill'),
                          targetWidth: pillWidth,
                          isDark: isDark,
                          elapsed: _elapsed,
                          levels: _levels,
                          pulse: _pulse,
                          showControls: !_isHoldMode,
                          onCancel: widget.onCancel,
                        )
                      : _isTranscribing
                          ? _ProcessingDots(
                              key: const ValueKey('recordProcessing'),
                              pulse: _pulse,
                              color: isDark ? kAccentDark : kAccentLight,
                            )
                          : Center(
                              key: const ValueKey('recordIdle'),
                              child: Icon(
                                Icons.mic_rounded,
                                size: kRecordIconSize,
                                color: isDark ? kAccentDark : kAccentLight,
                              ),
                            ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecordingContent extends StatelessWidget {
  final bool isDark;
  final String elapsed;
  final List<double> levels;
  final Animation<double> pulse;
  final bool showControls;
  final VoidCallback? onCancel;

  /// Ancho final de la pastilla: el contenido se arma a ese ancho desde el
  /// primer cuadro y la animación solo lo va destapando.
  final double targetWidth;

  const _RecordingContent({
    super.key,
    required this.targetWidth,
    required this.isDark,
    required this.elapsed,
    required this.levels,
    required this.pulse,
    required this.showControls,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final red = isDark ? kRecordingDark : kRecording;
    final primary = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    // Mientras la pastilla se abre, el contenido se recorta desde el CENTRO:
    // bajo el dedo queda la onda (tocar = terminar) y el ✕ aparece recién
    // en el borde cuando la pastilla ya se estiró. Anclado a la izquierda,
    // un segundo toque rápido caía sobre el ✕ y descartaba la grabación.
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: targetWidth,
        maxWidth: targetWidth,
        child: Builder(
          builder: (context) {
            return SizedBox(
              width: targetWidth,
              child: Padding(
                padding: EdgeInsets.only(
                  left: showControls && onCancel != null ? 6 : 22,
                  right: showControls ? 10 : 22,
                ),
                child: Row(
                  children: [
                    if (showControls && onCancel != null)
                      Semantics(
                        button: true,
                        label: 'Descartar grabación',
                        child: InkResponse(
                          key: const ValueKey('recordCancelButton'),
                          onTap: onCancel,
                          radius: 22,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.close_rounded,
                                size: AppIcons.medium, color: secondary),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    AnimatedBuilder(
                      animation: pulse,
                      // Coseno: el ciclo se repite sin salto al volver a 0.
                      builder: (context, child) => Opacity(
                        opacity:
                            0.675 + 0.325 * math.cos(2 * math.pi * pulse.value),
                        child: child,
                      ),
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration:
                            BoxDecoration(color: red, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      elapsed,
                      key: const ValueKey('recordElapsed'),
                      style: kTextCallout.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          size: const Size.fromHeight(30),
                          painter: _WavePainter(
                            levels: List<double>.of(levels),
                            color: primary.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ),
                    if (showControls) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: red.withValues(alpha: 0.30),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.stop_rounded,
                            size: AppIcons.large, color: kOnEmber),
                      ),
                    ] else
                      const SizedBox(width: 4),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Fundido de entrada corto para el contenido de cada estado.
class _FadeIn extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _FadeIn({super.key, required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: kCurveFade,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}

/// Onda que corre de derecha a izquierda: cada barra es una muestra real.
class _WavePainter extends CustomPainter {
  final List<double> levels;
  final Color color;

  _WavePainter({required this.levels, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    const barWidth = 3.0;
    const gap = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final fit = ((size.width + gap) / (barWidth + gap)).floor();
    final count = math.min(fit, levels.length);
    final start = levels.length - count;
    final mid = size.height / 2;
    for (var i = 0; i < count; i++) {
      final v = levels[start + i];
      final h = math.max(barWidth, v * size.height);
      final x =
          size.width - (count - i) * (barWidth + gap) + barWidth / 2 + gap;
      canvas.drawLine(Offset(x, mid - h / 2 + barWidth / 2),
          Offset(x, mid + h / 2 - barWidth / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.color != color || !_sameLevels(old.levels, levels);

  static bool _sameLevels(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Tres puntos en ola (mismo lenguaje que la tecla mic del teclado, M4).
class _ProcessingDots extends StatelessWidget {
  final Animation<double> pulse;
  final Color color;

  const _ProcessingDots({super.key, required this.pulse, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (pulse.value - i * 0.15) % 1.0;
              final wave = t < 0.35 ? math.sin(t / 0.35 * math.pi) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Transform.translate(
                  offset: Offset(0, -7 * wave),
                  child: Opacity(
                    opacity: 0.45 + 0.55 * wave,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
