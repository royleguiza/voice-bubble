import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

/// Arma Inicio recibiendo la clave del lienzo del botón de dictar.
typedef HoleHomeBuilder = Widget Function(GlobalKey holeKey);

/// Las tres reproducciones de la capa (design.md §15).
enum HorizonIntroKind {
  /// Arranque en frío: fase 1 larga ([kIntroSwallow]) y aterrizaje.
  cold,

  /// Al volver de Ajustes a Inicio: fase 1 corta ([kIntroSwallowReturn]).
  returning,

  /// Salida con «atrás»: la entrada invertida ([kIntroExit]) y cierre.
  exit,
}

/// Lo que Inicio puede pedirle al host de la animación.
abstract interface class HorizonIntroController {
  /// Reproduce la versión corta de la entrada (volver de Ajustes). No hace
  /// nada con reducir movimiento, TalkBack o si ya hay una capa.
  void playReturn();

  /// «Atrás» en Inicio que cerraría la app: reproduce la salida y cierra al
  /// terminar. Un segundo pedido (o un toque) durante la salida cierra ya.
  void requestExit();
}

/// Publica el [HorizonIntroController] del host a Inicio. Sin host (o con el
/// host apagado) [maybeOf] devuelve null y Inicio se comporta como siempre.
class HorizonIntroScope extends InheritedWidget {
  final HorizonIntroController? controller;

  const HorizonIntroScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static HorizonIntroController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HorizonIntroScope>()?.controller;

  @override
  bool updateShouldNotify(HorizonIntroScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Arranque Horizonte (design.md §15, maqueta `drawHole` y bloque
/// «arranque» de `laboratorio_ui/horizonte.html`).
///
/// Inicio se construye debajo desde el primer cuadro (su carga de datos no
/// espera a nada); encima va [HorizonIntro], que se desmonta al terminar.
/// El arranque en frío se muestra una sola vez por proceso y solo si
/// [enabled]: quien monta la app decide (en `main()` sí; en los tests, solo
/// cuando lo piden). El mismo host reproduce la versión corta al volver de
/// Ajustes y la salida con «atrás» (ver [HorizonIntroController]).
/// Con reducir movimiento o TalkBack no se muestra ninguna.
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
  static void debugResetColdStart() {
    _coldStartPending = true;
    homeLoading.value = false;
  }

  /// Inicio lo pone en true mientras carga sus notas al arrancar: el
  /// arranque en frío sigue girando hasta que vuelva a false.
  static final ValueNotifier<bool> homeLoading = ValueNotifier<bool>(false);

  @override
  State<HorizonIntroHost> createState() => _HorizonIntroHostState();
}

class _HorizonIntroHostState extends State<HorizonIntroHost>
    with WidgetsBindingObserver
    implements HorizonIntroController {
  final GlobalKey _holeKey = GlobalKey(debugLabel: 'recordHole');

  /// Instancia fija: reconstruir el host (fin del arranque, tema) no vuelve
  /// a construir Inicio desde arriba.
  late final Widget _home = widget.homeBuilder(_holeKey);

  /// Reproducción en curso (null = sin capa).
  HorizonIntroKind? _playing;

  /// Falso hasta decidir el arranque (primer didChangeDependencies).
  bool _decided = false;

  /// Ya se pidió cerrar la app: no se vuelve a pedir.
  bool _closeRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    // Se reclama aunque después no se muestre: si el arranque en frío fue
    // con reducir movimiento, no aparece más tarde en el mismo proceso.
    final claimed = widget.enabled && HorizonIntroHost._coldStartPending;
    if (claimed) HorizonIntroHost._coldStartPending = false;
    if (claimed && HorizonIntro.allowedIn(context)) {
      _playing = HorizonIntroKind.cold;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Si la app vuelve al primer plano con la capa de salida puesta (Android
  /// no destruyó la actividad), no puede quedar pegada: Inicio normal.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _closeRequested = false;
    if (_playing == HorizonIntroKind.exit && mounted) {
      setState(() => _playing = null);
    }
  }

  @override
  void playReturn() {
    if (!mounted || !widget.enabled || _playing != null) return;
    if (!HorizonIntro.allowedIn(context)) return;
    if (!(ModalRoute.isCurrentOf(context) ?? true)) return;
    setState(() => _playing = HorizonIntroKind.returning);
  }

  @override
  void requestExit() {
    if (!mounted) return;
    // Segundo «atrás», «atrás» durante una entrada o animaciones apagadas:
    // se cierra en el acto, como antes de la animación de salida.
    if (_playing != null ||
        !widget.enabled ||
        !HorizonIntro.allowedIn(context)) {
      _closeApp();
      return;
    }
    setState(() => _playing = HorizonIntroKind.exit);
  }

  /// Misma llamada que hace el framework cuando «atrás» no tiene nada que
  /// cerrar. La capa de salida queda puesta (tapa Inicio) hasta que se cierre
  /// la actividad o la app se reanude.
  void _closeApp() {
    if (_closeRequested) return;
    _closeRequested = true;
    unawaited(SystemNavigator.pop());
  }

  void _layerDone() {
    if (!mounted) return;
    if (_playing == HorizonIntroKind.exit) {
      _closeApp();
    } else if (_playing != null) {
      setState(() => _playing = null);
    }
  }

  void _layerCancelled() {
    if (!mounted || _playing == null) return;
    setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    final kind = _playing;
    return HorizonIntroScope(
      controller: widget.enabled ? this : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _home,
          if (kind != null)
            HorizonIntro(
              key: kind == HorizonIntroKind.exit
                  ? const ValueKey('horizonExit')
                  : const ValueKey('horizonIntro'),
              kind: kind,
              targetKey: _holeKey,
              onDone: _layerDone,
              onCancel: _layerCancelled,
              onTap: kind == HorizonIntroKind.exit ? _closeApp : null,
            ),
        ],
      ),
    );
  }
}

/// Capa de la animación: fase 1 ([kIntroSwallow] o [kIntroSwallowReturn]) el
/// agujero grande traga símbolos en espiral; fase 2 ([kIntroLand]) se achica
/// y aterriza sobre el agujero del botón de dictar ([targetKey]) mientras su
/// fondo se desvanece. La salida ([HorizonIntroKind.exit]) es la fase 2
/// invertida: el agujero crece desde el botón, los símbolos caen hacia él y
/// el fondo cubre Inicio.
///
/// Un toque en la fase 1 la saltea (fase 2 acelerada, [kIntroSkipLand]);
/// ese único toque no llega a Inicio. En la fase 2 la capa ya no recibe
/// toques. En la salida, un toque llama a [onTap] (cerrar ya). Si la ruta de
/// Inicio deja de estar al frente (se abrió otra pantalla) o se activa
/// reducir movimiento, termina en el acto ([onCancel]).
class HorizonIntro extends StatefulWidget {
  final HorizonIntroKind kind;
  final GlobalKey targetKey;

  /// La reproducción llegó a su último cuadro.
  final VoidCallback onDone;

  /// La reproducción se cortó antes de tiempo (otra ruta, reducir movimiento).
  final VoidCallback? onCancel;

  /// Solo en la salida: toque durante la animación.
  final VoidCallback? onTap;

  const HorizonIntro({
    super.key,
    this.kind = HorizonIntroKind.cold,
    required this.targetKey,
    required this.onDone,
    this.onCancel,
    this.onTap,
  });

  /// Reducir movimiento o lector de pantalla → sin animación.
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
  /// integra el tiempo con un paso acotado). Se detiene al terminar y se
  /// libera al desmontar.
  late final AnimationController _frames = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addListener(_onFrame);
  Duration _lastFrame = Duration.zero;

  late final HorizonIntroScene _scene = HorizonIntroScene.forKind(widget.kind);
  bool _landing = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _scene.targetProbe = _measureTarget;
    if (widget.kind == HorizonIntroKind.cold) {
      _scene.holdWhile = () => HorizonIntroHost.homeLoading.value;
    }
    HorizonIntro.debugLastScene = _scene;
    _frames.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onTop = ModalRoute.isCurrentOf(context) ?? true;
    if (!onTop || !HorizonIntro.allowedIn(context)) _cancelAfterFrame();
  }

  void _onFrame() {
    if (_finished) return;
    // El cuadro con el agujero ya en su sitio se pintó: fin.
    if (_scene.done) {
      _finish();
      return;
    }
    final elapsed = _frames.lastElapsedDuration ?? Duration.zero;
    final dt = (elapsed - _lastFrame).inMicroseconds / 1e6;
    _lastFrame = elapsed;
    _scene.step(dt);
    if (_scene.landing != _landing) setState(() => _landing = _scene.landing);
  }

  /// Rect real del lienzo del botón de dictar, en coordenadas de la capa.
  /// Lo pide el pintor en cada cuadro en que el destino importa (el botón
  /// real no se mueve, pero así el primer cuadro ya sale alineado).
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

  void _onPointerDown() {
    if (widget.kind == HorizonIntroKind.exit) {
      widget.onTap?.call();
      return;
    }
    _scene.skip();
    if (_scene.landing != _landing) setState(() => _landing = true);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _frames.stop();
    widget.onDone();
  }

  /// Corte desde un build (dependencias): el host no puede reconstruirse en
  /// medio de la construcción de un descendiente.
  void _cancelAfterFrame() {
    if (_finished) return;
    _finished = true;
    _frames.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) (widget.onCancel ?? widget.onDone)();
    });
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
          onPointerDown: (_) => _onPointerDown(),
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

/// Simulación de la animación (port de `drawHole`): pool fijo de partículas
/// en coordenadas polares sobre un disco inclinado, sin asignaciones por
/// cuadro. El tiempo avanza con un paso acotado ([maxStep]): un primer
/// cuadro lento no produce un salto.
///
/// Entrada: [swallow] de fase 1 y [land] de aterrizaje. Salida ([reverse]):
/// solo la fase 2, recorrida al revés (`landProgress` baja de 1 a 0).
class HorizonIntroScene extends ChangeNotifier {
  HorizonIntroScene({
    math.Random? random,
    Duration swallow = kIntroSwallow,
    Duration land = kIntroLand,
    this.reverse = false,
  })  : _rng = random ?? math.Random(),
        swallowSeconds = reverse ? 0 : swallow.inMicroseconds / 1e6,
        _baseSwallow = reverse ? 0 : swallow.inMicroseconds / 1e6,
        landSeconds = land.inMicroseconds / 1e6;

  factory HorizonIntroScene.forKind(HorizonIntroKind kind,
          {math.Random? random}) =>
      switch (kind) {
        HorizonIntroKind.cold => HorizonIntroScene(random: random),
        HorizonIntroKind.returning =>
          HorizonIntroScene(random: random, swallow: kIntroSwallowReturn),
        HorizonIntroKind.exit =>
          HorizonIntroScene(random: random, land: kIntroExit, reverse: true),
      };

  /// Tope del pool (design.md §15).
  static const int maxParticles = kIntroMaxParticles;

  /// Textos fijos (nunca contenido del usuario). En [glyphs] van en este
  /// orden: símbolos, código, tiras binarias y palabras.
  static const List<String> symbols = [
    '0', '1', '{', '}', '[', ']', '<', '>', '/', ';', '(', ')', '=', '*', //
    '#',
  ];
  static const List<String> code = [
    'const', 'let', 'if (x) {', '} else {', '=>', '</>', '{}', '[]', 'fn()',
    'return', 'for (i = 0; i < n; i++)', 'PI = 3.14159;', 'while (true)',
    'async', 'await', 'null', '===', 'import', '// nota', '0x1F',
  ];
  static const List<String> words = [
    'voz', 'nota', 'texto', 'dev', 'hola', 'ssh', 'tmux',
  ];

  /// Tiras binarias: pool fijo (semilla fija) para que la hoja de glifos
  /// sea finita.
  static final List<String> binary = () {
    final rng = math.Random(11);
    return List<String>.generate(24, (_) {
      final length = 4 + rng.nextInt(9);
      final b = StringBuffer();
      for (var j = 0; j < length; j++) {
        b.write(rng.nextBool() ? '1' : '0');
        if (j == 3 && length > 6) b.write(' ');
      }
      return b.toString();
    }, growable: false);
  }();

  static final List<String> glyphs =
      List.unmodifiable([...symbols, ...code, ...binary, ...words]);

  static int get _codeStart => symbols.length;
  static int get _binaryStart => _codeStart + code.length;
  static int get _wordStart => _binaryStart + binary.length;

  /// Parte de las partículas que son código o tiras binarias (artifact: 60 %).
  static const double codeShare = 0.6;

  /// Inclinación del disco y aplastamiento de la órbita (artifact: 0,22).
  static const double tilt = -0.32;
  static const double flatten = 0.22;

  /// Tope de la espera por Inicio: aunque no termine de cargar, el agujero
  /// aterriza después de este tiempo extra.
  static const double maxHoldSeconds = 4;

  /// Radio del agujero respecto del radio del disco (R × 0,9).
  static const double holeOfDisc = 0.9;

  /// Paso máximo por cuadro, en segundos.
  static const double maxStep = 0.05;

  /// Aceleración de la simulación respecto de la maqueta: en menos de dos
  /// segundos tiene que verse la espiral.
  static const double simSpeed = 2.4;

  /// Lo que se traga reaparece dentro de este tramo del alcance (fracción de
  /// [orbitReach]) y entra con un fundido: mientras dura la fase 1 siguen
  /// llegando símbolos, la escena nunca se vacía.
  static const double respawnNear = 0.12;
  static const double respawnFar = 0.5;

  /// Segundos que tarda un símbolo recién nacido en llegar a su opacidad.
  static const double fadeInSeconds = 0.3;

  /// En la salida los símbolos nacen más cerca: en medio segundo tienen que
  /// alcanzar a caer.
  static const double exitReach = 0.55;

  final bool reverse;

  /// Fase 1: se estira mientras [holdWhile] diga que Inicio sigue cargando.
  double swallowSeconds;
  final double _baseSwallow;

  /// Mientras devuelva true, la fase 1 sigue girando (hasta
  /// [maxHoldSeconds] extra). Solo en el arranque en frío.
  bool Function()? holdWhile;
  bool _skipped = false;
  final double landSeconds;
  static final double skipSeconds = kIntroSkipLand.inMicroseconds / 1e6;

  final math.Random _rng;
  final Float64List _r = Float64List(maxParticles);
  final Float64List _th = Float64List(maxParticles);
  final Float64List _k = Float64List(maxParticles);
  final Float64List _age = Float64List(maxParticles);
  final Int8List _glyph = Int8List(maxParticles)
    ..fillRange(0, maxParticles, -1);

  /// Reloj de la animación (s) y su escala (> 1 tras saltear).
  double clock = 0;
  double _timeScale = 1;

  Size size = Size.zero;

  /// Rect del botón de dictar en coordenadas del lienzo.
  Rect? target;

  /// Quien mide el botón de dictar; el pintor lo consulta en cada cuadro en
  /// que el destino cuenta ([wantsTarget]).
  Rect? Function()? targetProbe;

  Offset _start = Offset.zero;
  double _startHole = 0;

  /// Centro y radio exterior del agujero en el cuadro actual.
  Offset holeCenter = Offset.zero;
  double holeRadius = 0;

  /// Radio del disco (R de la maqueta) y alcance de las órbitas.
  double get discRadius => holeRadius / holeOfDisc;
  double get orbitReach => math.max(size.width, size.height) * 0.6;

  /// Fase 2 de la entrada en curso (nunca en la salida).
  bool get landing => !reverse && clock >= swallowSeconds;

  /// El agujero está (o va) hacia el botón: hay que medirlo.
  bool get wantsTarget => reverse || landing;

  bool get done => clock >= swallowSeconds + landSeconds;

  /// 0..1 dentro de la fase 2; en la salida va de 1 (agujero sobre el botón,
  /// fondo transparente) a 0 (agujero arriba, fondo cubriendo todo).
  double get landProgress {
    final p = ((clock - swallowSeconds) / landSeconds).clamp(0.0, 1.0);
    return reverse ? 1 - p : p;
  }

  /// Curva del viaje y del achique.
  static double landEase(double p) => Curves.easeInOutCubic.transform(p);

  int get activeParticles {
    var n = 0;
    for (var i = 0; i < maxParticles; i++) {
      if (_glyph[i] >= 0) n++;
    }
    return n;
  }

  /// Partículas a menos de [fraction] × [orbitReach] del borde del disco
  /// (solo tests y métricas: cuántas se ven cerca del agujero).
  int countNear(double fraction) {
    var n = 0;
    final limit = discRadius + orbitReach * fraction;
    for (var i = 0; i < maxParticles; i++) {
      if (_glyph[i] >= 0 && _r[i] <= limit) n++;
    }
    return n;
  }

  /// Destino si todavía no hay medida: abajo al centro, tamaño del botón.
  Rect get _fallbackTarget => Rect.fromCircle(
        center: Offset(size.width / 2,
            size.height - kRecordDockBottomGap - kRecordButtonSize / 2),
        radius: kRecordButtonSize / 2,
      );

  /// Lo llama el pintor antes de dibujar: mide el botón y reubica el
  /// agujero (sin notificar).
  void syncTarget() {
    final probe = targetProbe;
    if (probe == null || !wantsTarget || size.isEmpty) return;
    final measured = probe();
    if (measured == null || measured == target) return;
    target = measured;
    _updateHole();
  }

  /// Lo llama el pintor con el tamaño del lienzo (sin notificar).
  void resize(Size next) {
    if (next == size || next.isEmpty) return;
    final first = size.isEmpty;
    size = next;
    // Centro de la pantalla: mismo lugar que el agujero del arranque nativo.
    _start = Offset(next.width * 0.5, next.height * 0.5);
    _startHole = math.min(next.width, next.height) * 0.13 * holeOfDisc;
    _updateHole();
    if (first) _seed();
  }

  void _seed() {
    final reach = orbitReach * (reverse ? exitReach : 1.0);
    final r0 = discRadius;
    for (var i = 0; i < maxParticles; i++) {
      _r[i] = r0 * 1.2 + _rng.nextDouble() * reach;
      _th[i] = _rng.nextDouble() * math.pi * 2;
      _k[i] = 0.6 + _rng.nextDouble() * 0.8;
      _glyph[i] = _pick();
      _age[i] = fadeInSeconds;
    }
  }

  int _pick() {
    final x = _rng.nextDouble();
    if (x < codeShare * 0.62) return _codeStart + _rng.nextInt(code.length);
    if (x < codeShare) return _binaryStart + _rng.nextInt(binary.length);
    if (x < codeShare + 0.06) return _wordStart + _rng.nextInt(words.length);
    // 0 y 1 salen el doble que el resto.
    final i = _rng.nextInt(symbols.length + 2);
    return i >= symbols.length ? i - symbols.length : i;
  }

  /// Tocar para saltear: la fase 2 empieza ya y dura [kIntroSkipLand].
  void skip() {
    if (reverse || done) return;
    _skipped = true;
    if (!landing) clock = swallowSeconds;
    final remaining = swallowSeconds + landSeconds - clock;
    _timeScale = math.max(_timeScale, remaining / skipSeconds);
  }

  void step(double dt) {
    final d = dt.clamp(0.0, maxStep) * _timeScale;
    clock += d;
    // Inicio todavía carga: el agujero sigue girando en vez de aterrizar.
    if (!reverse &&
        !_skipped &&
        clock + maxStep >= swallowSeconds &&
        clock < _baseSwallow + maxHoldSeconds &&
        (holdWhile?.call() ?? false)) {
      // Un paso por delante del reloj: la fase 2 no arranca mientras espera.
      swallowSeconds = clock + maxStep;
    }
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
    // En la salida los símbolos caen con la fuerza de la mitad del aterrizaje.
    final p = reverse ? 0.5 : landProgress;
    final landingNow = landing;
    final big = discRadius;
    final reach = orbitReach;
    final spin = dt * simSpeed * (1 + 3 * p);
    final fall = dt * simSpeed * (1 + 9 * p);
    for (var i = 0; i < maxParticles; i++) {
      if (_glyph[i] < 0) continue;
      _age[i] += dt;
      final f = big / _r[i];
      _th[i] += spin * (0.25 + 2.6 * f * math.sqrt(f)) * _k[i];
      _r[i] -= fall * (14 + 70 * f) * _k[i];
      if (_r[i] < big * 1.02) {
        if (landingNow) {
          // Fase 2: lo que cae ya no vuelve a salir.
          _glyph[i] = -1;
        } else {
          final span = reverse ? exitReach : respawnFar;
          _r[i] = big +
              reach * (respawnNear + _rng.nextDouble() * (span - respawnNear));
          _th[i] = _rng.nextDouble() * math.pi * 2;
          _age[i] = 0;
        }
      }
    }
  }
}

/// Pintor del arranque sobre [HorizonIntroScene] (propuesta aprobada en el
/// artifact «Agujero Horizonte», 2026-11-14): fondo, halo, mitad trasera del
/// disco de acreción y de las partículas, anillo de fotones, agujero con su
/// anillo (destello → brasa), micrófono y mitad delantera.
///
/// Las partículas son texto (símbolos, código, tiras binarias, palabras) que
/// sigue la órbita, con estela y profundidad (detrás del agujero más chico).
/// Todo el texto sale de una hoja de glifos precalculada y se dibuja con un
/// único `drawRawAtlas` por mitad: cientos de partículas sin un TextPainter
/// por cuadro. Sin `saveLayer` ni blur.
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

  /// Tope de TextPainter por modo: un glifo por texto de la hoja + micrófono.
  static int get textPainterCapacity => _IntroResources.capacity;

  static const double _cosTilt = 0.9492354180824408; // cos(tilt)
  static const double _sinTilt = -0.3145665606161178; // sin(tilt)

  @override
  void paint(Canvas canvas, Size size) {
    scene.resize(size);
    scene.syncTarget();
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
      res.fill.color = res.bgSolid.withValues(alpha: bgAlpha);
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
    // Disco, halo y anillo de fotones se apagan mientras aterriza.
    final diskA = highContrast ? 0.0 : 1 - e;

    if (diskA > 0.01) {
      res.halo.color = Color.fromRGBO(0, 0, 0, diskA);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(HorizonIntroScene.tilt);
      final sx = big * 3.4;
      canvas.scale(sx, sx * math.max(0.45, HorizonIntroScene.flatten * 1.5));
      canvas.drawCircle(Offset.zero, 1, res.halo);
      canvas.restore();
    }
    _disk(canvas, res, c, big, diskA, back: true);
    _particles(canvas, res, w, h, big, fade, back: true);
    if (diskA > 0.01) _photonRing(canvas, res, c, hr, diskA);

    res.fill.color = res.hole;
    canvas.drawCircle(c, hr, res.fill);
    // Anillo: destello fino → brasa de 2 dp del botón (por dentro del borde,
    // como Border.all).
    final hotAlpha = highContrast ? 0.0 : 0.95 * (1 - e);
    if (hotAlpha > 0.01) {
      res.stroke
        ..blendMode = BlendMode.srcOver
        ..color = kHot.withValues(alpha: hotAlpha)
        ..strokeWidth = 1.5;
      canvas.drawCircle(c, hr - 0.75, res.stroke);
    }
    final emberAlpha = highContrast ? 1.0 : e;
    if (emberAlpha > 0.01) {
      final sw = 1.5 + 0.5 * e;
      res.stroke
        ..blendMode = BlendMode.srcOver
        ..color = res.emberColor.withValues(alpha: emberAlpha)
        ..strokeWidth = sw;
      canvas.drawCircle(c, hr - sw / 2, res.stroke);
    }
    final micAlpha = ((p - 0.5) / 0.5).clamp(0.0, 1.0);
    if (micAlpha > 0) {
      final tp = res.mic(micAlpha);
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    _disk(canvas, res, c, big, diskA, back: false);
    _particles(canvas, res, w, h, big, fade, back: false);
  }

  /// Bandas finas del disco de acreción, discontinuas, que giran más rápido
  /// cuanto más cerca del agujero. [back]: mitad de atrás (arriba).
  void _disk(Canvas canvas, _IntroResources res, Offset c, double big,
      double diskA,
      {required bool back}) {
    if (diskA <= 0.01) return;
    const flat = HorizonIntroScene.flatten;
    final a0 = back ? math.pi : 0.0;
    final p = scene.landProgress;
    final path = res.path;
    final paint = res.band;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(HorizonIntroScene.tilt);
    for (final band in _IntroResources.bands) {
      final rr = big * (1.05 + band.t * band.t * 2.6);
      final near = 1 - band.t;
      final alpha = ((0.08 + 0.5 * math.pow(near, 1.6)) *
              diskA *
              res.diskBrightness *
              (back ? 0.8 : 1.0))
          .clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;
      final total = band.dash[0] + band.dash[1] + band.dash[2] + band.dash[3];
      final offset = band.offset -
          scene.clock * 260 * math.pow(big / rr, 1.5) * (1 + 3 * p);
      final rect = Rect.fromCenter(
          center: Offset.zero, width: rr * 2, height: rr * 2 * flat);
      final length = math.pi * rr;
      path.reset();
      for (var s = -(offset % total); s < length; s += total) {
        _dash(path, rect, rr, a0, length, s, band.dash[0]);
        _dash(path, rect, rr, a0, length, s + band.dash[0] + band.dash[1],
            band.dash[2]);
      }
      paint
        ..color = Color(_withAlpha(
            _mix(res.emberArgb, kHot.toARGB32(), math.pow(near, 2.2).toDouble()),
            alpha))
        ..strokeWidth = band.width * (1 + near);
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  static void _dash(Path path, Rect rect, double rr, double a0, double length,
      double from, double len) {
    final s0 = math.max(0.0, from);
    final s1 = math.min(length, from + len);
    if (s1 - s0 < 0.5) return;
    path.addArc(rect, a0 + s0 / rr, (s1 - s0) / rr);
  }

  /// Anillo de fotones: la parte trasera del disco curvada sobre el agujero.
  void _photonRing(
      Canvas canvas, _IntroResources res, Offset c, double hr, double diskA) {
    final paint = res.band;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(HorizonIntroScene.tilt);
    for (final ring in _IntroResources.photonRings) {
      final rr = hr * ring.radius;
      paint
        ..color = Color(_withAlpha(
            ring.argb(res), (ring.alpha * diskA * res.diskBrightness).clamp(0.0, 1.0)))
        ..strokeWidth = ring.width;
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: rr * 2, height: rr * 1.84),
        math.pi * 1.04,
        math.pi * 0.92,
        false,
        paint,
      );
    }
    canvas.restore();
  }

  void _particles(Canvas canvas, _IntroResources res, double w, double h,
      double big, double fade,
      {required bool back}) {
    if (fade <= 0.02) return;
    final c = scene.holeCenter;
    final reach = scene.orbitReach;
    const tilt = HorizonIntroScene.tilt;
    const flat = HorizonIntroScene.flatten;
    const ca = _cosTilt;
    const sa = _sinTilt;
    final xforms = res.xforms;
    final rects = res.rects;
    final colors = res.colors;
    final sprites = res.sprites;
    final trail = res.trail;
    var n = 0;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    for (var i = 0; i < HorizonIntroScene.maxParticles; i++) {
      final g = scene._glyph[i];
      if (g < 0) continue;
      final th = scene._th[i];
      final sinT = math.sin(th);
      if (back != (sinT < 0)) continue;
      final cosT = math.cos(th);
      final r = scene._r[i];
      final u = (r - big) / reach;
      var a = ((r - big * 1.02) / (big * 0.35)).clamp(0.0, 1.0) *
          math.min(1.0, (1 - u) * 2.6);
      a *= (u > 0.45 ? 0.6 : 1.0) * fade * (back ? 0.85 : 1.0);
      final age = scene._age[i];
      if (age < HorizonIntroScene.fadeInSeconds) {
        a *= age / HorizonIntroScene.fadeInSeconds;
      }
      // Profundidad: detrás del agujero (arriba) más chico y tenue.
      final depth = 1 + 0.34 * sinT;
      a *= 0.72 + 0.28 * (depth - 0.66) / 0.68;
      if (a <= 0.02) continue;
      final ox = r * cosT;
      final oy = r * sinT * flat;
      final x = c.dx + ox * ca - oy * sa;
      final y = c.dy + ox * sa + oy * ca;
      if (x < -120 || x > w + 120 || y < -60 || y > h + 60) continue;
      final rgb = res.particleArgb(u);
      // Estela: arco corto detrás, más largo cerca del horizonte.
      final sweep = 0.05 + 0.32 * math.pow(big / r, 1.4);
      trail
        ..color = Color(_withAlpha(rgb, a * (u < 0.2 ? 0.9 : 0.35)))
        ..strokeWidth = (u < 0.14 ? 1.6 : 1.0) * depth;
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2 * flat),
        th - sweep,
        sweep,
        false,
        trail,
      );
      if (u < 0.14 || sprites == null) continue; // pegado al horizonte: estela
      // Dirección del giro en pantalla, siempre legible (nunca cabeza abajo).
      // En los costados la órbita va casi vertical: el texto se apaga y
      // queda la estela; nunca se para.
      final tx = -r * sinT;
      final ty = r * cosT * flat;
      var dev = math.atan2(tx * sa + ty * ca, tx * ca - ty * sa) - tilt;
      while (dev > math.pi / 2) {
        dev -= math.pi;
      }
      while (dev <= -math.pi / 2) {
        dev += math.pi;
      }
      final textA =
          a * (1 - ((math.sin(dev).abs() - 0.4) / 0.35).clamp(0.0, 1.0));
      if (textA <= 0.03) continue;
      final ang = tilt + dev.clamp(-0.5, 0.5);
      final long = HorizonIntroScene.glyphs[g].length > 2;
      final sz = math.max(5.5,
          (long ? 9.5 : 12.0) * (0.55 + u * 1.35) * scene._k[i] * depth);
      final scale = sz / _IntroResources.atlasFont;
      final scos = scale * math.cos(ang);
      final ssin = scale * math.sin(ang);
      final ax = sprites[g * 4 + 2] / 2 - sprites[g * 4] / 2;
      final ay = sprites[g * 4 + 3] / 2 - sprites[g * 4 + 1] / 2;
      final o = n * 4;
      xforms[o] = scos;
      xforms[o + 1] = ssin;
      xforms[o + 2] = x - scos * ax + ssin * ay;
      xforms[o + 3] = y - ssin * ax - scos * ay;
      rects[o] = sprites[g * 4];
      rects[o + 1] = sprites[g * 4 + 1];
      rects[o + 2] = sprites[g * 4 + 2];
      rects[o + 3] = sprites[g * 4 + 3];
      colors[n] = _withAlpha(rgb, textA);
      n++;
    }
    canvas.restore();
    final image = res.atlas;
    if (n > 0 && image != null) {
      canvas.drawRawAtlas(
        image,
        Float32List.sublistView(xforms, 0, n * 4),
        Float32List.sublistView(rects, 0, n * 4),
        Int32List.sublistView(colors, 0, n),
        BlendMode.modulate,
        null,
        res.atlasPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HorizonIntroPainter old) =>
      old.scene != scene ||
      old.isDark != isDark ||
      old.highContrast != highContrast;
}

/// Mezcla dos colores ARGB opacos (t = 0 → [a]).
int _mix(int a, int b, double t) {
  final k = t.clamp(0.0, 1.0);
  int ch(int shift) {
    final x = (a >> shift) & 0xFF;
    final y = (b >> shift) & 0xFF;
    return (x + (y - x) * k).round() & 0xFF;
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// [argb] con la opacidad [alpha] (0..1).
int _withAlpha(int argb, double alpha) =>
    ((alpha.clamp(0.0, 1.0) * 255).round() << 24) | (argb & 0x00FFFFFF);

/// Banda del disco: radio relativo, patrón de trazos (px), grosor y fase.
class _Band {
  final double t;
  final List<double> dash;
  final double width;
  final double offset;
  const _Band(this.t, this.dash, this.width, this.offset);
}

/// Arco del anillo de fotones: radio (× agujero), grosor, color y opacidad.
class _PhotonRing {
  final double radius;
  final double width;
  final int color; // 0 brasa, 1 dorado, 2 texto
  final double alpha;
  const _PhotonRing(this.radius, this.width, this.color, this.alpha);

  int argb(_IntroResources res) => switch (color) {
        0 => res.emberArgb,
        1 => kHot.toARGB32(),
        _ => res.fgArgb,
      };
}

/// Pinceles, colores, halo, hoja de glifos y buffers del arranque: uno por
/// modo y por proceso. Los TextPainter (uno por texto de la hoja y los
/// niveles del micrófono) se arman una sola vez cada uno.
class _IntroResources {
  _IntroResources._(bool isDark)
      : hole = isDark ? kHoleDark : kHoleLight,
        bgSolid = isDark ? kHzBgDark : kHzBgLight,
        emberColor = isDark ? kEmberDark : kEmberLight,
        diskBrightness = isDark ? 2.0 : 1.1,
        _coolArgb = isDark ? 0xFFAEBBDA : kHzFg2Light.toARGB32(),
        fgArgb = (isDark ? kHzFgDark : kHzFgLight).toARGB32(),
        _hotArgb = isDark ? kHot.toARGB32() : kEmberLight.toARGB32() {
    emberArgb = emberColor.toARGB32();
    // En oscuro la luz se suma (como el render); en claro se pinta encima.
    final blend = isDark ? BlendMode.plus : BlendMode.srcOver;
    band.blendMode = blend;
    trail.blendMode = blend;
    halo.blendMode = blend;
    atlasPaint.blendMode = blend;
    final scale = isDark ? 1.0 : 0.5;
    halo.shader = ui.Gradient.radial(
      Offset.zero,
      1,
      [
        emberColor.withValues(alpha: 1.0 * scale),
        emberColor.withValues(alpha: 0.64 * scale),
        emberColor.withValues(alpha: 0.16 * scale),
        emberColor.withValues(alpha: 0),
      ],
      const [0, 0.3, 0.6, 1],
    );
    _buildAtlas();
  }

  static final Map<bool, _IntroResources> _cache = {};

  static _IntroResources of(bool isDark) =>
      _cache.putIfAbsent(isDark, () => _IntroResources._(isDark));

  /// Tamaño de letra de la hoja de glifos (se escala al dibujar).
  static const double atlasFont = 40;
  static const int _micLevels = 8;

  static int get capacity => HorizonIntroScene.glyphs.length + _micLevels;

  static int created = 0;

  /// Bandas del disco: fijas por proceso (semilla fija).
  static final List<_Band> bands = () {
    final rng = math.Random(7);
    return List<_Band>.generate(30, (i) {
      return _Band(
        i / 29,
        [
          6 + rng.nextDouble() * 40,
          3 + rng.nextDouble() * 18,
          2 + rng.nextDouble() * 14,
          4 + rng.nextDouble() * 22,
        ],
        0.6 + rng.nextDouble() * 1.6,
        rng.nextDouble() * 200,
      );
    }, growable: false);
  }();

  static const List<_PhotonRing> photonRings = [
    _PhotonRing(1.32, 9, 0, 0.10),
    _PhotonRing(1.22, 5, 0, 0.22),
    _PhotonRing(1.14, 2.4, 1, 0.55),
    _PhotonRing(1.10, 1.1, 2, 0.50),
  ];

  final Color hole;
  final Color bgSolid;
  final Color emberColor;
  final double diskBrightness;
  late final int emberArgb;
  final int fgArgb;
  final int _coolArgb;
  final int _hotArgb;

  /// Color de una partícula según su distancia relativa al disco: frío
  /// lejos, brasa en el medio, dorado cerca.
  int particleArgb(double u) {
    if (u > 0.42) return _mix(_coolArgb, fgArgb, (0.7 - u) / 0.28);
    if (u > 0.2) return _mix(emberArgb, fgArgb, (u - 0.2) / 0.22 * 0.55);
    return _mix(_hotArgb, emberArgb, u / 0.2);
  }

  final Paint fill = Paint()..style = PaintingStyle.fill;
  final Paint stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint band = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint trail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint halo = Paint()..style = PaintingStyle.fill;
  final Paint atlasPaint = Paint()..filterQuality = FilterQuality.low;
  final Path path = Path();

  /// Hoja de glifos en blanco (se tiñe con el color de cada partícula) y el
  /// rect de cada texto: [l, t, r, b] por índice de `HorizonIntroScene.glyphs`.
  ui.Image? atlas;
  Float32List? sprites;

  /// Buffers del `drawRawAtlas`, reutilizados en cada cuadro.
  final Float32List xforms = Float32List(HorizonIntroScene.maxParticles * 4);
  final Float32List rects = Float32List(HorizonIntroScene.maxParticles * 4);
  final Int32List colors = Int32List(HorizonIntroScene.maxParticles);

  void _buildAtlas() {
    const maxWidth = 2048.0;
    const pad = 3.0;
    final glyphs = HorizonIntroScene.glyphs;
    final painters = [
      for (final g in glyphs)
        _layout(TextSpan(
          text: g,
          style: kTextMono.copyWith(
            fontSize: atlasFont,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFFFFFF),
          ),
        )),
    ];
    final out = Float32List(glyphs.length * 4);
    final offsets = <Offset>[];
    var x = pad;
    var y = pad;
    var row = 0.0;
    var width = 0.0;
    for (var i = 0; i < painters.length; i++) {
      final tp = painters[i];
      if (x + tp.width + pad > maxWidth) {
        x = pad;
        y += row + pad;
        row = 0;
      }
      offsets.add(Offset(x, y));
      out[i * 4] = x;
      out[i * 4 + 1] = y;
      out[i * 4 + 2] = x + tp.width;
      out[i * 4 + 3] = y + tp.height;
      x += tp.width + pad;
      width = math.max(width, x);
      row = math.max(row, tp.height);
    }
    final height = y + row + pad;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (var i = 0; i < painters.length; i++) {
        painters[i].paint(canvas, offsets[i]);
      }
      final picture = recorder.endRecording();
      atlas = picture.toImageSync(width.ceil(), height.ceil());
      picture.dispose();
      sprites = out;
    } catch (_) {
      // Sin hoja de glifos: quedan disco, estelas y agujero.
      atlas = null;
      sprites = null;
    }
    for (final tp in painters) {
      tp.dispose();
    }
  }

  final List<TextPainter?> _mics = List<TextPainter?>.filled(_micLevels, null);

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
