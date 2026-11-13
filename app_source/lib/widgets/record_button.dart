import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ui/design_tokens.dart';
import 'app_icons.dart';

/// Burbuja de dictado de la pantalla principal: el micrófono "agujero
/// negro" de Horizonte (design.md §3 y §8 "Voz").
///
/// Es un solo objeto que cambia de forma:
/// - idle: agujero Ø76 (negro también en claro) con anillo de brasa y el
///   micrófono en on-hole.
/// - recording: se estira en pastilla negra con la animación A
///   (Acreción): partículas que entran por la derecha y caen al agujero al
///   ritmo del nivel REAL del micrófono; tiempo en mono, ■ dentro del
///   agujero y ✕ (cancelar) en el borde, solo en modo toque.
/// - transcribing: la misma pastilla en modo pensando (arco que gira sobre
///   el anillo y renglones que salen hacia la derecha); deshabilitado.
///
/// Con "reducir movimiento" no hay partículas ni arco: queda un anillo fijo
/// cuyo grosor sigue el volumen.
enum RecordButtonState { idle, recording, transcribing }

class RecordButton extends StatefulWidget {
  final RecordButtonState state;
  final VoidCallback? onPressed;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  /// Descarta la grabación en curso sin transcribir (✕). Solo modo toque:
  /// en modo mantener el dedo está sobre la burbuja.
  final VoidCallback? onCancel;

  /// Nivel de entrada 0..1. Se consulta mientras se graba para animar el
  /// agujero; sin fuente, el nivel queda en 0 (no se inventa movimiento).
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
  static const Duration _tick = Duration(milliseconds: 90);

  /// Cuadros de la animación: corre solo en grabando/pensando con
  /// animaciones habilitadas (TickerMode la silencia fuera de pantalla).
  /// El valor no importa: se usa el tiempo transcurrido para el paso.
  late final AnimationController _frames = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addListener(_onFrame);
  Duration _lastFrame = Duration.zero;

  final HorizonScene _scene = HorizonScene();

  /// Hora de inicio de la grabación en curso (para el tiempo M:SS).
  DateTime? _startedAt;
  String _elapsedText = '0:00';
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
    final phase = _isRecording
        ? VoicePhase.recording
        : _isTranscribing
            ? VoicePhase.thinking
            : VoicePhase.idle;
    _scene.setPhase(phase, animated: motionSafe);

    final animate = motionSafe && phase != VoicePhase.idle;
    if (animate && !_frames.isAnimating) {
      _lastFrame = Duration.zero;
      _frames.repeat();
    } else if (!animate && _frames.isAnimating) {
      _frames.stop();
    }

    if (_isRecording && _ticker == null) {
      _startedAt = DateTime.now();
      _elapsedText = '0:00';
      _ticker = Timer.periodic(_tick, (_) => _onTick());
    } else if (!_isRecording && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
      _startedAt = null;
    }
  }

  void _onFrame() {
    final elapsed = _frames.lastElapsedDuration ?? Duration.zero;
    final dt = _lastFrame == Duration.zero
        ? 0.0
        : (elapsed - _lastFrame).inMicroseconds / 1e6;
    _lastFrame = elapsed;
    _scene.step(dt.clamp(0.0, 0.05));
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
    // El nivel va directo a la escena (repinta solo el lienzo); el árbol
    // se reconstruye únicamente cuando cambia el texto del tiempo.
    _scene.setLevel(level);
    final text = _elapsed;
    if (text != _elapsedText) setState(() => _elapsedText = text);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _frames.dispose();
    _scene.dispose();
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
    final isPill = _isRecording || _isTranscribing;
    final ember = isDark ? kEmberDark : kEmberLight;

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
          final width = isPill ? pillWidth : kRecordButtonSize;
          final height = isPill ? kRecordPillHeight : kRecordButtonSize;
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
              curve: isPill ? kCurveEnter : kCurveExit,
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              // Agujero: negro también en modo claro, anillo de brasa.
              decoration: BoxDecoration(
                color: isDark ? kHoleDark : kHoleLight,
                borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
                border: Border.all(color: ember, width: 2),
              ),
              // Cambio instantáneo + fundido de entrada del contenido nuevo:
              // nunca conviven dos estados (ni el micrófono bajo la pastilla).
              child: _FadeIn(
                key: ValueKey(widget.state),
                enabled: motionSafe,
                child: isPill
                    ? _PillContent(
                        key: ValueKey(
                            _isRecording ? 'recordPill' : 'recordProcessing'),
                        targetWidth: pillWidth,
                        isDark: isDark,
                        scene: _scene,
                        recording: _isRecording,
                        elapsed: _elapsedText,
                        showControls: _isRecording && !_isHoldMode,
                        onCancel: widget.onCancel,
                      )
                    : const Center(
                        key: ValueKey('recordIdle'),
                        child: Icon(
                          Icons.mic_rounded,
                          size: kRecordIconSize,
                          color: kOnHole,
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

/// Pastilla grabando / pensando: lienzo A + tiempo + controles.
class _PillContent extends StatelessWidget {
  final bool isDark;
  final HorizonScene scene;
  final bool recording;
  final String elapsed;
  final bool showControls;
  final VoidCallback? onCancel;

  /// Ancho final de la pastilla: el contenido se arma a ese ancho desde el
  /// primer cuadro y la animación solo lo va destapando.
  final double targetWidth;

  const _PillContent({
    super.key,
    required this.targetWidth,
    required this.isDark,
    required this.scene,
    required this.recording,
    required this.elapsed,
    required this.showControls,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final hole = isDark ? kHoleDark : kHoleLight;
    // El agujero ocupa la izquierda (centro en h/2 + 1, radio 0.3 h).
    const holeBox = kRecordPillHeight;
    // Mientras la pastilla se abre, el contenido se recorta desde el CENTRO:
    // bajo el dedo quedan las partículas (tocar = terminar) y el ✕ aparece
    // recién en el borde cuando la pastilla ya se estiró.
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: targetWidth,
        maxWidth: targetWidth,
        child: SizedBox(
          width: targetWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey('recordHorizon'),
                    painter: HorizonPainter(scene: scene, isDark: isDark),
                  ),
                ),
              ),
              if (recording)
                Row(
                  children: [
                    SizedBox(
                      width: holeBox,
                      child: showControls
                          ? const Icon(Icons.stop_rounded,
                              size: AppIcons.medium, color: kOnHole)
                          : null,
                    ),
                    // Tiempo en mono sobre su propio fondo negro: las
                    // partículas pasan por detrás sin taparlo.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: hole,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        child: Text(
                          elapsed,
                          key: const ValueKey('recordElapsed'),
                          style: kTextMono.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: kOnHole,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
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
                                size: AppIcons.medium,
                                color: kOnHole.withValues(alpha: 0.8)),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                  ],
                ),
            ],
          ),
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

/// Estado de la voz que dibuja el agujero.
enum VoicePhase { idle, recording, thinking }

/// Simulación de la animación A (Acreción, maqueta `drawA` de
/// `laboratorio_ui/horizonte.html`): pool fijo de partículas, sin
/// asignaciones por cuadro. Notifica a su pintor en cada paso.
class HorizonScene extends ChangeNotifier {
  /// Tope de partículas en la pastilla (pool fijo).
  static const int maxParticles = 60;

  static const int _dot = 0;
  static const int _dash = 1;
  static const int _line = 2;
  static const int _glyph0 = 3;
  static const int _inactive = -1;

  final math.Random _rng = math.Random();
  final Float64List _x = Float64List(maxParticles);
  final Float64List _y = Float64List(maxParticles);
  final Float64List _s = Float64List(maxParticles);
  final Float64List _len = Float64List(maxParticles);
  final Int8List _kind = Int8List(maxParticles)
    ..fillRange(0, maxParticles, _inactive);

  VoicePhase phase = VoicePhase.idle;

  /// false con "reducir movimiento": sin partículas ni arco.
  bool animated = true;

  double _target = 0;
  double _acc = 0;

  /// Nivel mostrado (suavizado por cuadro hacia el último leído).
  double vol = 0;

  /// Reloj de la animación en segundos.
  double clock = 0;

  /// Tamaño del lienzo (lo fija el pintor).
  Size size = Size.zero;

  int get activeParticles {
    var n = 0;
    for (var i = 0; i < maxParticles; i++) {
      if (_kind[i] != _inactive) n++;
    }
    return n;
  }

  void setPhase(VoicePhase next, {required bool animated}) {
    if (next == phase && animated == this.animated) return;
    phase = next;
    this.animated = animated;
    _acc = 0;
    if (next == VoicePhase.idle || !animated) {
      _kind.fillRange(0, maxParticles, _inactive);
    }
    if (next != VoicePhase.recording) _target = 0;
    if (!animated) vol = next == VoicePhase.recording ? _target : 0;
    notifyListeners();
  }

  /// Último nivel leído del micrófono (0..1).
  void setLevel(double level) {
    _target = phase == VoicePhase.recording ? level.clamp(0.0, 1.0) : 0;
    if (!animated) {
      // Anillo fijo: solo cambia su grosor con el volumen.
      vol = _target;
      notifyListeners();
    }
  }

  void step(double dt) {
    clock += dt;
    vol += (_target - vol) * math.min(1.0, dt * 14);
    final w = size.width;
    final h = size.height;
    if (w > 0 && h > 0) _advance(dt, w, h);
    notifyListeners();
  }

  void _advance(double dt, double w, double h) {
    final r = h * 0.3;
    final cx = h * 0.5 + 1;
    final cy = h * 0.5;
    if (phase == VoicePhase.recording) {
      _acc += dt * (5 + 90 * vol);
      while (_acc > 1) {
        _acc -= 1;
        final i = _freeSlot();
        if (i < 0) break;
        _x[i] = w + 4;
        _y[i] = h * (0.12 + _rng.nextDouble() * 0.76);
        _s[i] = 0.55 + _rng.nextDouble() * 0.9;
        _kind[i] = _rng.nextDouble() < 0.45
            ? _glyph0 + _rng.nextInt(_glyphs.length)
            : (_rng.nextDouble() < 0.5 ? _dash : _dot);
      }
    } else if (phase == VoicePhase.thinking) {
      _acc += dt * 9;
      while (_acc > 1) {
        _acc -= 1;
        final i = _freeSlot();
        if (i < 0) break;
        _x[i] = cx + r + 2;
        _y[i] = cy + (_rng.nextDouble() - 0.5) * h * 0.36;
        _s[i] = 0.6 + _rng.nextDouble() * 0.6;
        _len[i] = 5 + _rng.nextDouble() * 16;
        _kind[i] = _line;
      }
    }
    for (var i = 0; i < maxParticles; i++) {
      final kind = _kind[i];
      if (kind == _inactive) continue;
      if (kind == _line) {
        _x[i] += dt *
            (26 + 70 * _s[i]) *
            math.max(0.25, 1 - (_x[i] - cx) / (w * 0.9));
        if (_lineAlpha(i, cx, r, w) <= 0 && _x[i] >= cx + r + 16) {
          _kind[i] = _inactive;
        }
      } else {
        final d = (_x[i] - cx) / (w - cx);
        _x[i] -= dt * (50 + 330 * vol) * _s[i] * (0.55 + 0.45 * d);
        final near = 1 - d;
        _y[i] += (cy - _y[i]) * math.min(1.0, dt * (1.2 + 6 * near * near));
        final dx = _x[i] - cx;
        final dy = _y[i] - cy;
        if (dx * dx + dy * dy < r * r) _kind[i] = _inactive;
      }
    }
  }

  int _freeSlot() {
    for (var i = 0; i < maxParticles; i++) {
      if (_kind[i] == _inactive) return i;
    }
    return -1;
  }

  double _lineAlpha(int i, double cx, double r, double w) =>
      math.min(1.0, (_x[i] - cx - r) / 14) *
      math.max(0.0, 1 - (_x[i] - cx) / (w * 0.86));

  static const List<String> _glyphs = ['0', '1', '{', '}'];
}

/// Pintor de la animación A sobre [HorizonScene]. Los pinceles, el halo y
/// los glifos se crean una vez y se reutilizan en cada cuadro.
class HorizonPainter extends CustomPainter {
  final HorizonScene scene;
  final bool isDark;

  HorizonPainter({required this.scene, required this.isDark})
      : super(repaint: scene);

  static const double _glyphBase = 16;

  @override
  void paint(Canvas canvas, Size size) {
    scene.size = size;
    final w = size.width;
    final h = size.height;
    if (w < 4 || h < 4) return;
    final res = _PainterResources.of(isDark);
    final r = h * 0.3;
    final cx = h * 0.5 + 1;
    final cy = h * 0.5;
    final live = scene.animated;

    if (live) {
      for (var i = 0; i < HorizonScene.maxParticles; i++) {
        final kind = scene._kind[i];
        if (kind == HorizonScene._inactive) continue;
        final x = scene._x[i];
        final y = scene._y[i];
        if (kind == HorizonScene._line) {
          final a = scene._lineAlpha(i, cx, r, w).clamp(0.0, 1.0);
          res.stroke
            ..color = res.tint(0, a)
            ..strokeWidth = 2;
          canvas.drawLine(Offset(x, y), Offset(x + scene._len[i], y), res.stroke);
          continue;
        }
        final d = ((x - cx) / (w - cx)).clamp(0.0, 1.0);
        final a = math.min(1.0, 0.25 + d * 0.9) *
            ((w - x) / 20 + 0.2).clamp(0.0, 1.0);
        if (a <= 0.02) continue;
        final colorIdx = d < 0.18 ? 2 : (d < 0.45 ? 1 : 0);
        final k = 0.45 + 0.55 * d;
        if (kind == HorizonScene._dot || kind == HorizonScene._dash) {
          res.fill.color = res.tint(colorIdx, a);
          if (kind == HorizonScene._dot) {
            canvas.drawCircle(Offset(x, y), 1.5 * k, res.fill);
          } else {
            canvas.drawRect(
                Rect.fromLTRB(x, y - 0.8 * k, x + 8 * k, y + 0.8 * k), res.fill);
          }
        } else {
          final fontSize = h * 0.2 * k + 3;
          final tp = res.glyph(kind - HorizonScene._glyph0, colorIdx, a);
          final scale = fontSize / _glyphBase;
          canvas.save();
          canvas.translate(x, y + 3 - tp.height * 0.8 * scale);
          canvas.scale(scale);
          tp.paint(canvas, Offset.zero);
          canvas.restore();
        }
      }
    }

    final k = switch (scene.phase) {
      VoicePhase.recording => scene.vol,
      VoicePhase.thinking => 0.25,
      VoicePhase.idle => 0.0,
    };
    _ringGlow(canvas, res, cx, cy, r, k);
    if (scene.phase == VoicePhase.thinking) {
      _spinArc(canvas, res, cx, cy, r, live ? scene.clock : 0);
    }
  }

  void _ringGlow(Canvas canvas, _PainterResources res, double x, double y,
      double r, double k) {
    final kk = k.clamp(0.0, 1.0);
    final outer = r * (1.6 + kk * 1.6);
    res.glow.color = res.tint(_PainterResources.black, 0.35 + 0.5 * kk);
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(outer);
    canvas.drawCircle(Offset.zero, 1, res.glow);
    canvas.restore();
    res.fill.color = res.hole;
    canvas.drawCircle(Offset(x, y), r, res.fill);
    res.stroke
      ..color = kk > 0.5 ? kHot : res.palette[1]
      ..strokeWidth = 1.2 + 2.2 * kk;
    canvas.drawCircle(Offset(x, y), r, res.stroke);
  }

  void _spinArc(Canvas canvas, _PainterResources res, double x, double y,
      double r, double t) {
    final rect = Rect.fromCircle(center: Offset(x, y), radius: r + 4);
    res.stroke.strokeWidth = 3;
    for (var i = 0; i < 22; i++) {
      final a = t * 5 - i * 0.13;
      res.stroke.color = res.tint(i < 6 ? 2 : 1, (1 - i / 22) * 0.95);
      canvas.drawArc(rect, a, 0.14, false, res.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant HorizonPainter old) =>
      old.scene != scene || old.isDark != isDark;
}

/// Pinceles y glifos compartidos (uno por modo claro/oscuro), creados una
/// sola vez: el pintor no asigna Paint, Shader ni TextPainter por cuadro.
class _PainterResources {
  _PainterResources._(this.isDark)
      : hole = isDark ? kHoleDark : kHoleLight,
        palette = [kOnHole, isDark ? kEmberDark : kEmberLight, kHot] {
    // Negro opaco = máscara de opacidad del halo (mismo valor que hole).
    final bases = [...palette, kHoleDark];
    for (var c = 0; c < bases.length; c++) {
      for (var l = 0; l <= _alphaSteps; l++) {
        _tints[c * (_alphaSteps + 1) + l] =
            bases[c].withValues(alpha: l / _alphaSteps);
      }
    }
    final ember = palette[1];
    glow.shader = ui.Gradient.radial(
      Offset.zero,
      1,
      [ember, ember, ember.withValues(alpha: 0)],
      const [0, 0.28, 1],
    );
  }

  static final Map<bool, _PainterResources> _cache = {};

  static _PainterResources of(bool isDark) =>
      _cache.putIfAbsent(isDark, () => _PainterResources._(isDark));

  final bool isDark;
  final Color hole;

  /// fg lejos → brasa → destello cerca del agujero.
  final List<Color> palette;

  /// Índice del negro (solo como opacidad del halo con shader).
  static const int black = 3;
  static const int _alphaSteps = 16;

  /// Colores de la paleta con opacidad cuantizada, precalculados.
  final List<Color> _tints =
      List<Color>.filled(4 * (_alphaSteps + 1), Colors.transparent);

  Color tint(int colorIdx, double alpha) =>
      _tints[colorIdx * (_alphaSteps + 1) +
          (alpha.clamp(0.0, 1.0) * _alphaSteps).round()];

  final Paint fill = Paint()..style = PaintingStyle.fill;
  final Paint stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint glow = Paint()..style = PaintingStyle.fill;

  /// 4 glifos × 3 colores × 4 niveles de opacidad, armados a demanda.
  final List<TextPainter?> _glyphs = List<TextPainter?>.filled(48, null);

  TextPainter glyph(int glyph, int colorIdx, double alpha) {
    final level = (alpha * 4).ceil().clamp(1, 4);
    final key = glyph * 12 + colorIdx * 4 + (level - 1);
    return _glyphs[key] ??= TextPainter(
      text: TextSpan(
        text: HorizonScene._glyphs[glyph],
        style: kTextMono.copyWith(
          fontSize: HorizonPainter._glyphBase,
          fontWeight: FontWeight.w500,
          color: palette[colorIdx].withValues(alpha: level / 4),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}
