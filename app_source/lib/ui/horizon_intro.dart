import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Arma Inicio recibiendo la clave del lienzo del botón de dictar.
typedef HoleHomeBuilder = Widget Function(GlobalKey holeKey);

/// Arranque Horizonte (design.md §15, maqueta `drawHole` y bloque
/// «arranque» de `laboratorio_ui/horizonte.html`).
///
/// Inicio se construye debajo desde el primer cuadro (su carga de datos no
/// espera a nada); encima va [HorizonIntro], que se desmonta al terminar.
/// Se muestra una sola vez por proceso y solo si [enabled]: quien monta la
/// app decide (en `main()` sí; en los tests, solo cuando lo piden).
/// Con reducir movimiento o TalkBack no se muestra.
class HorizonIntroHost extends StatefulWidget {
  final HoleHomeBuilder homeBuilder;
  final bool enabled;

  const HorizonIntroHost({
    super.key,
    required this.homeBuilder,
    this.enabled = true,
  });

  static bool _coldStartPending = true;

  /// true hasta que un host habilitado reclama el arranque de este proceso.
  static bool get coldStartPending => _coldStartPending;

  /// Vuelve a habilitar el arranque (solo tests: simula un proceso nuevo).
  @visibleForTesting
  static void debugResetColdStart() => _coldStartPending = true;

  @override
  State<HorizonIntroHost> createState() => _HorizonIntroHostState();
}

class _HorizonIntroHostState extends State<HorizonIntroHost> {
  final GlobalKey _holeKey = GlobalKey(debugLabel: 'recordHole');

  /// Instancia fija: reconstruir el host (fin del arranque, tema) no vuelve
  /// a construir Inicio desde arriba.
  late final Widget _home = widget.homeBuilder(_holeKey);

  /// null hasta decidir (primer didChangeDependencies, antes del 1er cuadro).
  bool? _show;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_show != null) return;
    // Se reclama aunque después no se muestre: si el arranque en frío fue
    // con reducir movimiento, no aparece más tarde en el mismo proceso.
    final claimed = widget.enabled && HorizonIntroHost._coldStartPending;
    if (claimed) HorizonIntroHost._coldStartPending = false;
    _show = claimed && HorizonIntro.allowedIn(context);
  }

  void _finish() {
    if (!mounted || _show != true) return;
    setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _home,
        if (_show == true)
          HorizonIntro(
            key: const ValueKey('horizonIntro'),
            targetKey: _holeKey,
            onDone: _finish,
          ),
      ],
    );
  }
}

/// Capa del arranque: fase 1 ([kIntroSwallow]) el agujero grande traga
/// símbolos en espiral; fase 2 ([kIntroLand]) se achica y aterriza sobre el
/// agujero del botón de dictar ([targetKey]) mientras su fondo se desvanece.
///
/// Un toque en la fase 1 la saltea (fase 2 acelerada, [kIntroSkipLand]);
/// ese único toque no llega a Inicio. En la fase 2 la capa ya no recibe
/// toques. Si la ruta de Inicio deja de estar al frente (se abrió otra
/// pantalla) o se activa reducir movimiento, termina en el acto.
class HorizonIntro extends StatefulWidget {
  final GlobalKey targetKey;
  final VoidCallback onDone;

  const HorizonIntro({
    super.key,
    required this.targetKey,
    required this.onDone,
  });

  /// Reducir movimiento o lector de pantalla → sin arranque.
  static bool allowedIn(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context) &&
      !MediaQuery.accessibleNavigationOf(context);

  /// Última escena creada (solo tests: geometría y presupuesto).
  @visibleForTesting
  static HorizonIntroScene? debugLastScene;

  @override
  State<HorizonIntro> createState() => _HorizonIntroState();
}

class _HorizonIntroState extends State<HorizonIntro>
    with SingleTickerProviderStateMixin {
  /// Único ticker: solo marca los cuadros (el valor no importa, la escena
  /// integra el tiempo con un paso acotado). Se libera al desmontar.
  late final AnimationController _frames = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addListener(_onFrame);
  Duration _lastFrame = Duration.zero;

  final HorizonIntroScene _scene = HorizonIntroScene();
  bool _landing = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    HorizonIntro.debugLastScene = _scene;
    _frames.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onTop = ModalRoute.isCurrentOf(context) ?? true;
    if (!onTop || !HorizonIntro.allowedIn(context)) _finishAfterFrame();
  }

  void _onFrame() {
    if (_finished) return;
    // El cuadro con el agujero ya sobre el botón se pintó: fuera la capa.
    if (_scene.done) {
      _finish();
      return;
    }
    final elapsed = _frames.lastElapsedDuration ?? Duration.zero;
    final dt = (elapsed - _lastFrame).inMicroseconds / 1e6;
    _lastFrame = elapsed;
    if (_scene.landing) _scene.target = _measureTarget();
    _scene.step(dt);
    if (_scene.landing != _landing) setState(() => _landing = _scene.landing);
  }

  /// Rect real del lienzo del botón de dictar, en coordenadas de la capa.
  Rect? _measureTarget() {
    final target = widget.targetKey.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    if (target is! RenderBox ||
        self is! RenderBox ||
        !target.attached ||
        !target.hasSize ||
        !self.hasSize) {
      return null;
    }
    final topLeft = self.globalToLocal(target.localToGlobal(Offset.zero));
    return topLeft & target.size;
  }

  void _skip() {
    _scene.skip();
    if (_scene.landing != _landing) setState(() => _landing = true);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _frames.stop();
    widget.onDone();
  }

  /// Fin desde un build (dependencias): el host no puede reconstruirse en
  /// medio de la construcción de un descendiente.
  void _finishAfterFrame() {
    if (_finished) return;
    _finished = true;
    _frames.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
  }

  @override
  void dispose() {
    _frames.dispose();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        ignoring: _landing,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _skip(),
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('horizonIntroCanvas'),
              size: Size.infinite,
              painter: HorizonIntroPainter(
                scene: _scene,
                isDark: isDark,
                highContrast: highContrast,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simulación del arranque (port de `drawHole`): pool fijo de partículas en
/// coordenadas polares sobre un disco inclinado, sin asignaciones por
/// cuadro. El tiempo avanza con un paso acotado ([maxStep]): un primer
/// cuadro lento no produce un salto.
class HorizonIntroScene extends ChangeNotifier {
  HorizonIntroScene({math.Random? random}) : _rng = random ?? math.Random();

  /// Tope del pool (design.md §15: ≤ 120).
  static const int maxParticles = kIntroMaxParticles;

  /// Glifos fijos (nunca contenido del usuario): símbolos y palabras cortas.
  static const List<String> glyphs = [
    '0', '1', '{', '}', '[', ']', '<', '>', '/', ';', //
    'voz', 'nota', 'texto', 'ssh', 'tmux', 'dev', 'hola',
  ];

  /// Primer índice de [glyphs] que es palabra.
  static const int wordStart = 10;

  /// 0 y 1 salen el doble que el resto (maqueta).
  static const List<int> _symbolPick = [0, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  /// Probabilidad de que una partícula sea palabra.
  static const double wordChance = 0.08;

  /// Inclinación del disco y aplastamiento de la órbita (maqueta).
  static const double tilt = -0.32;
  static const double flatten = 0.4;

  /// Radio del agujero respecto del radio del disco (R × 0,9).
  static const double holeOfDisc = 0.9;

  /// Paso máximo por cuadro, en segundos.
  static const double maxStep = 0.05;

  /// Aceleración de la simulación respecto de la maqueta: en 0,7 s tiene
  /// que verse la espiral.
  static const double simSpeed = 2.4;

  static final double swallowSeconds = kIntroSwallow.inMicroseconds / 1e6;
  static final double landSeconds = kIntroLand.inMicroseconds / 1e6;
  static final double skipSeconds = kIntroSkipLand.inMicroseconds / 1e6;

  final math.Random _rng;
  final Float64List _r = Float64List(maxParticles);
  final Float64List _th = Float64List(maxParticles);
  final Float64List _k = Float64List(maxParticles);
  final Int8List _glyph = Int8List(maxParticles)..fillRange(0, maxParticles, -1);

  /// Reloj de la animación (s) y su escala (> 1 tras saltear).
  double clock = 0;
  double _timeScale = 1;

  Size size = Size.zero;

  /// Rect del botón de dictar en coordenadas del lienzo (fase 2).
  Rect? target;

  Offset _start = Offset.zero;
  double _startHole = 0;

  /// Centro y radio exterior del agujero en el cuadro actual.
  Offset holeCenter = Offset.zero;
  double holeRadius = 0;

  /// Radio del disco (R de la maqueta) y alcance de las órbitas.
  double get discRadius => holeRadius / holeOfDisc;
  double get orbitReach => math.max(size.width, size.height) * 0.6;

  bool get landing => clock >= swallowSeconds;
  bool get done => clock >= swallowSeconds + landSeconds;

  /// 0..1 dentro de la fase 2.
  double get landProgress =>
      ((clock - swallowSeconds) / landSeconds).clamp(0.0, 1.0);

  /// Curva del viaje y del achique.
  static double landEase(double p) => Curves.easeInOutCubic.transform(p);

  int get activeParticles {
    var n = 0;
    for (var i = 0; i < maxParticles; i++) {
      if (_glyph[i] >= 0) n++;
    }
    return n;
  }

  /// Destino si todavía no hay medida: abajo al centro, tamaño del botón.
  Rect get _fallbackTarget => Rect.fromCircle(
        center: Offset(size.width / 2,
            size.height - kRecordDockBottomGap - kRecordButtonSize / 2),
        radius: kRecordButtonSize / 2,
      );

  /// Lo llama el pintor con el tamaño del lienzo (sin notificar).
  void resize(Size next) {
    if (next == size || next.isEmpty) return;
    final first = size.isEmpty;
    size = next;
    _start = Offset(next.width * 0.5, next.height * 0.40);
    _startHole = math.min(next.width, next.height) * 0.13 * holeOfDisc;
    _updateHole();
    if (first) _seed();
  }

  void _seed() {
    final reach = orbitReach;
    final r0 = discRadius;
    for (var i = 0; i < maxParticles; i++) {
      _r[i] = r0 * 1.2 + _rng.nextDouble() * reach;
      _th[i] = _rng.nextDouble() * math.pi * 2;
      _k[i] = 0.6 + _rng.nextDouble() * 0.8;
      _glyph[i] = _pick();
    }
  }

  int _pick() => _rng.nextDouble() < wordChance
      ? wordStart + _rng.nextInt(glyphs.length - wordStart)
      : _symbolPick[_rng.nextInt(_symbolPick.length)];

  /// Tocar para saltear: la fase 2 empieza ya y dura [kIntroSkipLand].
  void skip() {
    if (done) return;
    if (!landing) clock = swallowSeconds;
    final remaining = swallowSeconds + landSeconds - clock;
    _timeScale = math.max(_timeScale, remaining / skipSeconds);
  }

  void step(double dt) {
    final d = dt.clamp(0.0, maxStep) * _timeScale;
    clock += d;
    _updateHole();
    if (!size.isEmpty) _advance(d);
    notifyListeners();
  }

  void _updateHole() {
    if (size.isEmpty) return;
    final e = landEase(landProgress);
    final t = target ?? _fallbackTarget;
    if (e <= 0) {
      holeCenter = _start;
      holeRadius = _startHole;
    } else if (e >= 1) {
      holeCenter = t.center;
      holeRadius = t.shortestSide / 2;
    } else {
      holeCenter = Offset.lerp(_start, t.center, e)!;
      holeRadius = _startHole + (t.shortestSide / 2 - _startHole) * e;
    }
  }

  void _advance(double dt) {
    final p = landProgress;
    final landingNow = landing;
    final big = discRadius;
    final reach = orbitReach;
    final spin = dt * simSpeed * (1 + 3 * p);
    final fall = dt * simSpeed * (1 + 9 * p);
    for (var i = 0; i < maxParticles; i++) {
      if (_glyph[i] < 0) continue;
      final f = big / _r[i];
      _th[i] += spin * (0.25 + 2.6 * f * math.sqrt(f)) * _k[i];
      _r[i] -= fall * (14 + 70 * f) * _k[i];
      if (_r[i] < big * 1.02) {
        if (landingNow) {
          // Fase 2: lo que cae ya no vuelve a salir.
          _glyph[i] = -1;
        } else {
          _r[i] = reach * (0.7 + _rng.nextDouble() * 0.3);
          _th[i] = _rng.nextDouble() * math.pi * 2;
        }
      }
    }
  }
}

/// Pintor del arranque sobre [HorizonIntroScene]: fondo, mitad trasera del
/// disco, halo elíptico, agujero con anillo (destello → brasa), micrófono y
/// mitad delantera. Sin `saveLayer` ni blur; pinceles, colores y glifos
/// cacheados una vez por proceso y modo.
class HorizonIntroPainter extends CustomPainter {
  final HorizonIntroScene scene;
  final bool isDark;
  final bool highContrast;

  HorizonIntroPainter({
    required this.scene,
    required this.isDark,
    required this.highContrast,
  }) : super(repaint: scene);

  /// TextPainter creados en total por el arranque (instrumentación: la
  /// cantidad está acotada por [textPainterCapacity], no crece por cuadro).
  static int get debugTextPainterCount => _IntroResources.created;

  /// Tope de TextPainter por modo: glifos × 2 colores × niveles + micrófono.
  static const int textPainterCapacity = _IntroResources.capacity;

  static const double _glyphBase = 16;

  @override
  void paint(Canvas canvas, Size size) {
    scene.resize(size);
    final w = size.width;
    final h = size.height;
    if (w < 8 || h < 8) return;
    final res = _IntroResources.of(isDark);
    final p = scene.landProgress;
    final e = HorizonIntroScene.landEase(p);
    final c = scene.holeCenter;
    final hr = scene.holeRadius;
    final big = scene.discRadius;

    // Fondo = fondo de la app (empalma con el arranque nativo).
    final bgAlpha = 1 - Curves.easeInOut.transform(p);
    if (bgAlpha > 0) {
      res.fill.color = res.tint(_IntroResources.bg, bgAlpha);
      canvas.drawRect(Offset.zero & size, res.fill);
    }
    // Mientras el agujero viaja, el botón real que asoma debajo queda
    // tapado: nunca se ven dos agujeros.
    final target = scene.target;
    if (p > 0 && target != null) {
      res.fill.color = res.bgSolid;
      canvas.drawCircle(target.center, target.shortestSide / 2 + 0.5, res.fill);
    }

    final fade = 1 - Curves.easeIn.transform(p);
    _particles(canvas, res, w, h, big, fade, back: true);

    if (!highContrast) {
      final haloAlpha = 1 - e;
      if (haloAlpha > 0.01) {
        res.glow.color = res.tint(_IntroResources.black, haloAlpha);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(HorizonIntroScene.tilt);
        canvas.scale(big * 2.3, big * 2.3 * 0.62);
        canvas.drawCircle(Offset.zero, 1, res.glow);
        canvas.restore();
      }
    }

    res.fill.color = res.hole;
    canvas.drawCircle(c, hr, res.fill);
    // Anillo: destello fino de la maqueta → brasa de 2 dp del botón (por
    // dentro del borde, como Border.all).
    final hotAlpha = highContrast ? 0.0 : 0.9 * (1 - e);
    if (hotAlpha > 0.01) {
      res.stroke
        ..color = res.tint(_IntroResources.hot, hotAlpha)
        ..strokeWidth = 1.5;
      canvas.drawCircle(c, hr - 0.75, res.stroke);
    }
    final emberAlpha = highContrast ? 1.0 : e;
    if (emberAlpha > 0.01) {
      final sw = 1.5 + 0.5 * e;
      res.stroke
        ..color = res.tint(_IntroResources.ember, emberAlpha)
        ..strokeWidth = sw;
      canvas.drawCircle(c, hr - sw / 2, res.stroke);
    }
    final micAlpha = ((p - 0.5) / 0.5).clamp(0.0, 1.0);
    if (micAlpha > 0) {
      final tp = res.mic(micAlpha);
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    _particles(canvas, res, w, h, big, fade, back: false);
  }

  void _particles(Canvas canvas, _IntroResources res, double w, double h,
      double big, double fade,
      {required bool back}) {
    if (fade <= 0.02) return;
    final c = scene.holeCenter;
    final reach = scene.orbitReach;
    const ca = 0.9492354180824408; // cos(tilt)
    const sa = -0.3145665606161178; // sin(tilt)
    const flatten = HorizonIntroScene.flatten;
    for (var i = 0; i < HorizonIntroScene.maxParticles; i++) {
      final g = scene._glyph[i];
      if (g < 0) continue;
      final th = scene._th[i];
      final sinTh = math.sin(th);
      if (back != (sinTh < 0)) continue;
      final r = scene._r[i];
      final u = (r - big) / reach;
      var a = ((r - big * 1.02) / (big * 0.5)).clamp(0.0, 1.0) *
          math.min(1.0, (1 - u) * 3);
      a *= (u > 0.4 ? 0.55 : 0.95) * fade;
      if (a <= 0.02) continue;
      final ox = r * math.cos(th);
      final oy = r * sinTh * flatten;
      final x = c.dx + ox * ca - oy * sa;
      final y = c.dy + ox * sa + oy * ca;
      if (x < -80 || x > w + 80 || y < -50 || y > h + 50) continue;
      if (u > 0.16) {
        // Lejos: glifo que crece al alejarse, fg; más cerca, brasa.
        final word = g >= HorizonIntroScene.wordStart;
        final sz = math.max(7.0,
            (word ? 10.0 : 12.0) * (0.5 + u * 1.6) * scene._k[i]);
        final tp = res.glyph(
            g, u < 0.3 ? _IntroResources.ember : _IntroResources.fg, a);
        final scale = sz / _glyphBase;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(HorizonIntroScene.tilt + sinTh * 0.35);
        canvas.scale(scale);
        tp.paint(canvas, Offset(0, -tp.height * 0.8));
        canvas.restore();
      } else {
        // Cerca del horizonte: trazo corto en la dirección de la órbita.
        final th2 = th - 0.09 * (1 + big / r);
        final ox2 = r * math.cos(th2);
        final oy2 = r * math.sin(th2) * flatten;
        res.stroke
          ..color = res.tint(
              u < 0.1 ? _IntroResources.hot : _IntroResources.ember, a)
          ..strokeWidth = 1.4;
        canvas.drawLine(
          Offset(c.dx + ox2 * ca - oy2 * sa, c.dy + ox2 * sa + oy2 * ca),
          Offset(x, y),
          res.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant HorizonIntroPainter old) =>
      old.scene != scene ||
      old.isDark != isDark ||
      old.highContrast != highContrast;
}

/// Pinceles, colores con opacidad cuantizada, halo y glifos del arranque:
/// uno por modo y por proceso. Los TextPainter se arman a demanda una sola
/// vez cada uno (como mucho [capacity]) y se reutilizan en cada cuadro.
class _IntroResources {
  _IntroResources._(bool isDark)
      : hole = isDark ? kHoleDark : kHoleLight,
        bgSolid = isDark ? kHzBgDark : kHzBgLight,
        _bases = [
          isDark ? kHzFgDark : kHzFgLight,
          isDark ? kEmberDark : kEmberLight,
          kHot,
          isDark ? kHzBgDark : kHzBgLight,
          kHoleDark,
        ] {
    for (var c = 0; c < _bases.length; c++) {
      for (var l = 0; l <= _alphaSteps; l++) {
        _tints[c * (_alphaSteps + 1) + l] =
            _bases[c].withValues(alpha: l / _alphaSteps);
      }
    }
    final emberColor = _bases[ember];
    // Halo de la maqueta: brasa desde el borde del agujero (0,9 R de
    // 2,3 R), brasa al 40 % al 35 % del tramo y transparente al final.
    const inner = 0.9 / 2.3;
    glow.shader = ui.Gradient.radial(
      Offset.zero,
      1,
      [
        emberColor,
        emberColor,
        emberColor.withValues(alpha: 0.4),
        emberColor.withValues(alpha: 0),
      ],
      const [0, inner, inner + 0.35 * (1 - inner), 1],
    );
  }

  static final Map<bool, _IntroResources> _cache = {};

  static _IntroResources of(bool isDark) =>
      _cache.putIfAbsent(isDark, () => _IntroResources._(isDark));

  static const int fg = 0;
  static const int ember = 1;
  static const int hot = 2;
  static const int bg = 3;
  static const int black = 4;

  static const int _alphaSteps = 32;
  static const int _glyphLevels = 4;
  static const int _micLevels = 8;

  /// Glifos × {fg, brasa} × niveles de opacidad.
  static const int _glyphSlots = _glyphCount * 2 * _glyphLevels;

  /// = `HorizonIntroScene.glyphs.length` (lo verifica el test).
  static const int _glyphCount = 17;

  /// TextPainter que puede llegar a crear un modo (claro u oscuro).
  static const int capacity = _glyphSlots + _micLevels;

  static int created = 0;

  final Color hole;
  final Color bgSolid;
  final List<Color> _bases;
  final List<Color> _tints =
      List<Color>.filled(5 * (_alphaSteps + 1), Colors.transparent);

  Color tint(int colorIdx, double alpha) => _tints[colorIdx * (_alphaSteps + 1) +
      (alpha.clamp(0.0, 1.0) * _alphaSteps).round()];

  final Paint fill = Paint()..style = PaintingStyle.fill;
  final Paint stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint glow = Paint()..style = PaintingStyle.fill;

  final List<TextPainter?> _glyphs =
      List<TextPainter?>.filled(_glyphSlots, null);
  final List<TextPainter?> _mics = List<TextPainter?>.filled(_micLevels, null);

  TextPainter glyph(int glyph, int colorIdx, double alpha) {
    final level = (alpha * _glyphLevels).ceil().clamp(1, _glyphLevels);
    final key = (glyph * 2 + (colorIdx == ember ? 1 : 0)) * _glyphLevels +
        (level - 1);
    return _glyphs[key] ??= _layout(TextSpan(
      text: HorizonIntroScene.glyphs[glyph],
      style: kTextMono.copyWith(
        fontSize: HorizonIntroPainter._glyphBase,
        fontWeight: FontWeight.w500,
        color: _bases[colorIdx].withValues(alpha: level / _glyphLevels),
      ),
    ));
  }

  /// Glifo del micrófono idéntico al `Icon` del botón en reposo.
  TextPainter mic(double alpha) {
    final level = (alpha * _micLevels).ceil().clamp(1, _micLevels);
    const icon = Icons.mic_rounded;
    return _mics[level - 1] ??= _layout(TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: kRecordIconGlyph.copyWith(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: kOnHole.withValues(alpha: level / _micLevels),
      ),
    ));
  }

  static TextPainter _layout(TextSpan span) {
    created++;
    return TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
  }
}
