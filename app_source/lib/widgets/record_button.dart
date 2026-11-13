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
    final motionSafe = !MediaQuery.disableAnimationsOf(context);
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
      // Primera lectura ya, sin esperar el primer período: el anillo y el
      // goteo arrancan con el nivel real lo antes posible.
      scheduleMicrotask(() => unawaited(_onTick()));
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
    final motionSafe = !MediaQuery.disableAnimationsOf(context);
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
                // Grabando se ve desde el primer cuadro (la pastilla que se
                // abre ya es la transición); el resto entra desde cero.
                begin: _isRecording ? 0.5 : 0,
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
                // Mismo tamaño que el lienzo: el ■ va al centro exacto del
                // agujero y el tiempo y el ✕ fijan las zonas sin partículas
                // (HoleGeometry es la única fuente de centro y radio).
                CustomMultiChildLayout(
                  delegate: _PillLayout(scene),
                  children: [
                    if (showControls)
                      LayoutId(
                        id: _PillLayout.stop,
                        child: const Icon(Icons.stop_rounded,
                            size: AppIcons.medium, color: kOnHole),
                      ),
                    // Tiempo en mono, centrado en la pastilla. Su "mini
                    // píldora" difuminada la pinta el lienzo (HorizonPainter)
                    // con la geometría que fija el layout.
                    LayoutId(
                      id: _PillLayout.timer,
                      child: Text(
                        elapsed,
                        key: const ValueKey('recordElapsed'),
                        maxLines: 1,
                        softWrap: false,
                        style: kTextMono.copyWith(
                          fontSize: HoleGeometry.timerFontSize,
                          fontWeight: FontWeight.w500,
                          color: kOnHole,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (showControls && onCancel != null)
                      LayoutId(
                        id: _PillLayout.cancel,
                        child: Semantics(
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

/// Coloca ■, tiempo y ✕ sobre el lienzo con la geometría de [HoleGeometry]
/// y le pasa a la escena el rectángulo de la mini píldora del tiempo y el
/// del ✕ (el pintor y la simulación leen de ahí).
class _PillLayout extends MultiChildLayoutDelegate {
  final HorizonScene scene;

  _PillLayout(this.scene);

  static const String stop = 'stop';
  static const String timer = 'timer';
  static const String cancel = 'cancel';

  @override
  void performLayout(Size size) {
    final g = HoleGeometry.of(size);
    final loose = BoxConstraints.loose(size);
    if (hasChild(stop)) {
      final s = layoutChild(stop, loose);
      positionChild(stop, g.center - Offset(s.width / 2, s.height / 2));
    }
    Rect? cancelRect;
    if (hasChild(cancel)) {
      final s = layoutChild(cancel, loose);
      cancelRect = g.cancelRect(size, s);
      positionChild(cancel, cancelRect.topLeft);
    }
    Rect? capsule;
    if (hasChild(timer)) {
      final (left, right) = g.timerLimits(size, cancelRect);
      final s = layoutChild(
        timer,
        BoxConstraints(
          maxWidth: math.max(0.0, right - left - 2 * HoleGeometry.timerPadH),
          maxHeight: size.height,
        ),
      );
      capsule = g.timerCapsule(size, s, cancelRect);
      positionChild(timer, capsule.center - Offset(s.width / 2, s.height / 2));
    }
    scene.setZones(size, timer: capsule, cancel: cancelRect);
  }

  @override
  bool shouldRelayout(covariant _PillLayout old) => old.scene != scene;
}

/// Geometría del agujero de la pastilla: única fuente de centro y radio
/// para el pintor (anillo, halo, partículas) y para el layout (■ centrado,
/// tiempo fuera del halo).
@immutable
class HoleGeometry {
  final Offset center;
  final double radius;

  const HoleGeometry._(this.center, this.radius);

  /// Agujero a la izquierda del lienzo de alto h: centro (h/2 + 1, h/2),
  /// radio 0.3 h (maqueta `drawA`).
  factory HoleGeometry.of(Size size) {
    final h = size.height;
    return HoleGeometry._(Offset(h * 0.5 + 1, h * 0.5), h * 0.3);
  }

  /// Grosor del anillo para el volumen k (0..1).
  static double strokeFor(double k) => 1.2 + 2.2 * k;

  /// Halo para el volumen k: radio exterior del degradado.
  double haloFor(double k) => radius * (1.6 + 1.6 * k);

  /// Alcance máximo del anillo: el mayor entre el halo con volumen 1 y el
  /// anillo con su grosor máximo.
  double get outerExtent => math.max(haloFor(1), radius + strokeFor(1) / 2);

  /// Separación mínima entre el borde exterior del anillo y el tiempo.
  static const double timerGap = 8;

  /// Margen entre la mini píldora del tiempo y lo que tiene a los lados.
  static const double zonePad = 4;

  /// Tamaño de letra del tiempo (mono).
  static const double timerFontSize = 13.5;

  /// Holgura de la mini píldora alrededor del texto.
  static const double timerPadH = 8;
  static const double timerPadV = 3;

  /// Ancho del borde difuminado de la mini píldora (hacia afuera).
  static const double timerFade = 5;

  /// Margen del ✕ al borde derecho del contenido.
  static const double cancelEdge = 10;

  /// Radio del halo circular (color del agujero, opaco al centro y
  /// transparente en el borde) centrado en el ✕. Las partículas nacen en
  /// su centro y el tiempo no lo invade.
  static const double cancelHalo = 20;

  /// Borde izquierdo del tiempo (fuera del halo máximo).
  double get timerLeft => center.dx + outerExtent + timerGap;

  /// Área del ✕ (de tamaño [child]) pegada al borde derecho.
  Rect cancelRect(Size size, Size child) =>
      Offset(
        size.width - cancelEdge - child.width,
        center.dy - child.height / 2,
      ) &
      child;

  /// Franja [izq, der] donde puede ir la mini píldora del tiempo.
  (double, double) timerLimits(Size size, Rect? cancel) => (
        timerLeft,
        cancel == null
            ? size.width - cancelEdge
            : cancel.center.dx - cancelHalo - zonePad,
      );

  /// Mini píldora del tiempo: el texto [text] más su holgura, centrada en
  /// la pastilla; si así chocara con el agujero o el ✕, centrada en el
  /// espacio libre entre ambos.
  Rect timerCapsule(Size size, Size text, Rect? cancel) {
    final w = text.width + 2 * timerPadH;
    final h = text.height + 2 * timerPadV;
    final (left, right) = timerLimits(size, cancel);
    var x = size.width / 2 - w / 2;
    if (x < left || x + w > right) x = (left + right) / 2 - w / 2;
    return Rect.fromLTWH(x, center.dy - h / 2, w, h);
  }
}

/// Fundido de entrada corto para el contenido de cada estado.
class _FadeIn extends StatelessWidget {
  final bool enabled;
  final double begin;
  final Widget child;

  const _FadeIn({
    super.key,
    required this.enabled,
    this.begin = 0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: 1),
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

  /// Tamaño del lienzo (lo fijan el layout de la pastilla y el pintor).
  Size size = Size.zero;

  /// Mini píldora del tiempo (texto + holgura) y área del ✕, en coordenadas
  /// del lienzo. Las fija el layout de la pastilla; las partículas se
  /// atenúan cerca de la primera y nacen antes del degradado del ✕.
  Rect? timerRect;
  Rect? cancelRect;

  /// Borde derecho del recorrido: las partículas entran desde acá (donde
  /// empieza el degradado del ✕ si lo hay). Null = ancho del lienzo.
  double? _right;

  /// Al empezar a grabar se siembra un goteo ya visible en el primer
  /// cuadro, sin esperar el primer nivel ni el recorrido desde el borde.
  bool _seedPending = false;

  /// Partículas sembradas al empezar a grabar.
  static const int seedCount = 3;

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
    // Grabando: la primera gota entra en el primer paso con tiempo.
    _acc = next == VoicePhase.recording ? 1 : 0;
    _seedPending = next == VoicePhase.recording && animated;
    if (next != VoicePhase.recording) {
      timerRect = null;
      cancelRect = null;
      _right = null;
    }
    // Corte limpio: fuera de grabando no sobrevive ninguna partícula de la
    // grabación (al pasar a pensando arrancan solo los renglones).
    if (next != VoicePhase.recording || !animated) {
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

  /// Zonas reservadas del layout de la pastilla (coordenadas del lienzo).
  void setZones(Size size, {Rect? timer, Rect? cancel}) {
    this.size = size;
    timerRect = timer;
    cancelRect = cancel;
    _right = cancel?.center.dx;
    if (_seedPending) _seed();
  }

  /// Extremo derecho del recorrido: el centro del ✕ (o el borde sin ✕).
  double get right => _right ?? size.width;

  void _seed() {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0 || phase != VoicePhase.recording || !animated) return;
    _seedPending = false;
    final g = HoleGeometry.of(size);
    final from = timerRect == null
        ? g.timerLeft
        : timerRect!.right + HoleGeometry.timerFade;
    final to = right - 6;
    // Una en el halo (cae enseguida) y el resto entre el tiempo y el borde.
    final xs = [
      g.center.dx + g.radius + (g.timerLeft - g.center.dx - g.radius) * 0.6,
      if (to > from) from + (to - from) * 0.3,
      if (to > from) from + (to - from) * 0.75,
    ];
    for (var n = 0; n < xs.length && n < seedCount; n++) {
      final i = _freeSlot();
      if (i < 0) break;
      _x[i] = xs[n];
      _y[i] = g.center.dy + (_rng.nextDouble() - 0.5) * h * 0.4;
      _s[i] = 0.55 + _rng.nextDouble() * 0.9;
      _kind[i] = n == 1 ? _glyph0 + _rng.nextInt(_glyphs.length) : _dot;
    }
  }

  void step(double dt) {
    clock += dt;
    vol += (_target - vol) * math.min(1.0, dt * 14);
    final w = size.width;
    final h = size.height;
    if (w > 0 && h > 0) {
      if (_seedPending) _seed();
      _advance(dt, w, h);
    }
    notifyListeners();
  }

  void _advance(double dt, double w, double h) {
    final g = HoleGeometry.of(size);
    final r = g.radius;
    final cx = g.center.dx;
    final cy = g.center.dy;
    final right = this.right;
    if (phase == VoicePhase.recording) {
      _acc += dt * (5 + 90 * vol);
      while (_acc > 1) {
        _acc -= 1;
        final i = _freeSlot();
        if (i < 0) break;
        _x[i] = right;
        _y[i] = h * (0.2 + _rng.nextDouble() * 0.6);
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
            math.max(0.25, 1 - (_x[i] - cx) / (right * 0.9));
        if (_lineAlpha(i, cx, r, right) <= 0 && _x[i] >= cx + r + 16) {
          _kind[i] = _inactive;
        }
      } else {
        final d = (_x[i] - cx) / (right - cx);
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
      ((w - _x[i]) / 24).clamp(0.0, 1.0);

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
    final g = HoleGeometry.of(size);
    final r = g.radius;
    final cx = g.center.dx;
    final cy = g.center.dy;
    final right = scene.right;
    final live = scene.animated;

    if (live) {
      for (var i = 0; i < HorizonScene.maxParticles; i++) {
        final kind = scene._kind[i];
        if (kind == HorizonScene._inactive) continue;
        final x = scene._x[i];
        final y = scene._y[i];
        if (kind == HorizonScene._line) {
          final a = scene._lineAlpha(i, cx, r, right).clamp(0.0, 1.0);
          res.stroke
            ..color = res.tint(0, a)
            ..strokeWidth = 2;
          canvas.drawLine(
              Offset(x, y), Offset(x + scene._len[i], y), res.stroke);
          continue;
        }
        final d = ((x - cx) / (right - cx)).clamp(0.0, 1.0);
        var a = math.min(1.0, 0.25 + d * 0.9) *
            ((right - x) / HoleGeometry.cancelHalo).clamp(0.0, 1.0);
        if (a <= 0.02) continue;
        final colorIdx = d < 0.18 ? 2 : (d < 0.45 ? 1 : 0);
        final k = 0.45 + 0.55 * d;
        final isGlyph = kind != HorizonScene._dot && kind != HorizonScene._dash;
        final fontSize = h * 0.2 * k + 3;
        final scale = fontSize / _glyphBase;
        TextPainter? tp;
        // Extensión de la partícula: se atenúa al acercarse a la mini
        // píldora del tiempo (alfa por distancia) y no se pinta sobre ella.
        final double x0;
        final double x1;
        final double y0;
        final double y1;
        if (kind == HorizonScene._dot) {
          x0 = x - 1.5 * k;
          x1 = x + 1.5 * k;
          y0 = y - 1.5 * k;
          y1 = y + 1.5 * k;
        } else if (kind == HorizonScene._dash) {
          x0 = x;
          x1 = x + 8 * k;
          y0 = y - 0.8 * k;
          y1 = y + 0.8 * k;
        } else {
          tp = res.glyph(kind - HorizonScene._glyph0, colorIdx, a);
          x0 = x;
          x1 = x + tp.width * scale;
          y0 = y + 3 - tp.height * 0.8 * scale;
          y1 = y0 + tp.height * scale;
        }
        final timer = scene.timerRect;
        if (timer != null) a *= _rectFade(x0, y0, x1, y1, timer);
        if (a <= 0.02) continue;
        if (!isGlyph) {
          res.fill.color = res.tint(colorIdx, a);
          if (kind == HorizonScene._dot) {
            canvas.drawCircle(Offset(x, y), 1.5 * k, res.fill);
          } else {
            canvas.drawRect(
                Rect.fromLTRB(x, y - 0.8 * k, x + 8 * k, y + 0.8 * k),
                res.fill);
          }
        } else {
          tp = res.glyph(kind - HorizonScene._glyph0, colorIdx, a);
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
    final timer = scene.timerRect;
    if (live && timer != null) _timerPill(canvas, res, timer);
    final cancel = scene.cancelRect;
    if (cancel != null) _cancelHalo(canvas, res, cancel, size);
    _ringGlow(canvas, res, g, k);
    if (scene.phase == VoicePhase.thinking) {
      _spinArc(canvas, res, cx, cy, r, live ? scene.clock : 0);
    }
  }

  /// 0 sobre [r]; sube a 1 a [HoleGeometry.timerFade] de distancia.
  static double _rectFade(double x0, double y0, double x1, double y1, Rect r) {
    final dx = math.max(math.max(r.left - x1, x0 - r.right), 0.0);
    final dy = math.max(math.max(r.top - y1, y0 - r.bottom), 0.0);
    return (math.sqrt(dx * dx + dy * dy) / HoleGeometry.timerFade)
        .clamp(0.0, 1.0);
  }

  // Anillos de la mini píldora (se rearman solo si cambia el rectángulo).
  Rect? _ringsFor;
  final List<RRect> _rings = [];

  /// Mini píldora del tiempo: cápsula del color del agujero cuyo borde se
  /// desvanece hacia afuera. Sin blur ni capas: [_PainterResources.pillSteps]
  /// cápsulas concéntricas con alfa precalculado que se acumula.
  void _timerPill(Canvas canvas, _PainterResources res, Rect core) {
    if (_ringsFor != core) {
      _ringsFor = core;
      _rings.clear();
      const n = _PainterResources.pillSteps;
      for (var i = 0; i <= n; i++) {
        final r = core.inflate(HoleGeometry.timerFade * (1 - i / n));
        _rings.add(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)));
      }
    }
    for (var i = 0; i < _rings.length; i++) {
      res.fill.color = res.pillFill[i];
      canvas.drawRRect(_rings[i], res.fill);
    }
  }

  // Halo circular del ✕ (shader unitario; se rearma solo si cambia el color)
  // y recorte interior que lo mantiene dentro de la pastilla.
  bool? _haloDark;
  final Paint _haloPaint = Paint()..style = PaintingStyle.fill;
  Size? _clipFor;
  RRect? _clipRRect;

  /// Halo del color del agujero centrado en el ✕: opaco al centro y
  /// transparente en el borde. Va recortado al lienzo (redondeado), de
  /// modo que nunca cubre el borde de brasa.
  void _cancelHalo(
      Canvas canvas, _PainterResources res, Rect cancel, Size size) {
    if (_haloDark != isDark) {
      _haloDark = isDark;
      _haloPaint.shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          res.hole,
          res.hole,
          res.hole.withValues(alpha: 0.4),
          res.hole.withValues(alpha: 0),
        ],
        const [0, 0.5, 0.78, 1],
      );
    }
    if (_clipFor != size) {
      _clipFor = size;
      _clipRRect = RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(size.height / 2));
    }
    final c = cancel.center;
    // Con pastillas bajas el halo no excede la mitad del alto.
    final rad = math.min(HoleGeometry.cancelHalo, size.height / 2);
    canvas.save();
    canvas.clipRRect(_clipRRect!);
    canvas.translate(c.dx, c.dy);
    canvas.scale(rad);
    canvas.drawCircle(Offset.zero, 1, _haloPaint);
    canvas.restore();
  }

  void _ringGlow(
      Canvas canvas, _PainterResources res, HoleGeometry g, double k) {
    final x = g.center.dx;
    final y = g.center.dy;
    final r = g.radius;
    final kk = k.clamp(0.0, 1.0);
    final outer = g.haloFor(kk);
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
      ..strokeWidth = HoleGeometry.strokeFor(kk);
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

  /// Cápsulas de la mini píldora del tiempo: n + 1 rellenos del color del
  /// agujero cuyo alfa acumulado sube suave (smoothstep) de 0 a 1.
  static const int pillSteps = 8;
  late final List<Color> pillFill = () {
    double cum(int i) {
      final t = (i + 1) / (pillSteps + 1);
      return t * t * (3 - 2 * t);
    }

    return [
      for (var i = 0; i <= pillSteps; i++)
        hole.withValues(
            alpha: i == 0 ? cum(0) : 1 - (1 - cum(i)) / (1 - cum(i - 1))),
    ];
  }();

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
