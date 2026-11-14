import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Cargas de la IA y sus íconos, idénticos a los del widget (design.md §14):
/// título = «Letras en órbita», resumen = «Bits que caen». Misma geometría
/// que `docs/gen_widget_ai_loaders.py` (lienzo de 48 con el agujero en el
/// centro, órbita inclinada −0,32 rad) y los mismos colores en claro y oscuro.
enum AiLoaderKind { title, summary }

/// Animación de carga en bucle mientras la IA trabaja. [size] es el lado del
/// lienzo (el botón que la contiene).
class AiLoader extends StatefulWidget {
  final AiLoaderKind kind;
  final double size;

  const AiLoader({super.key, required this.kind, this.size = 44});

  @override
  State<AiLoader> createState() => _AiLoaderState();
}

class _AiLoaderState extends State<AiLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _AiLoaderPainter(
          kind: widget.kind,
          clock: _clock,
          colors: _AiColors.of(isDark),
        ),
      ),
    );
  }
}

class _AiColors {
  final Color fg2;
  final Color emberText;
  final Color ember;
  final Color hole;

  const _AiColors(this.fg2, this.emberText, this.ember, this.hole);

  static _AiColors of(bool isDark) => isDark
      ? const _AiColors(kHzFg2Dark, kEmberTextDark, kEmberDark, kHoleDark)
      : const _AiColors(kHzFg2Light, kEmberTextLight, kEmberLight, kHoleLight);
}

class _AiLoaderPainter extends CustomPainter {
  final AiLoaderKind kind;
  final AnimationController clock;
  final _AiColors colors;

  _AiLoaderPainter({
    required this.kind,
    required this.clock,
    required this.colors,
  }) : super(repaint: clock);

  static const double _tilt = -0.32;
  static final double _ct = math.cos(_tilt);
  static final double _st = math.sin(_tilt);

  /// TextPainter por (texto, color): se arman una vez por proceso.
  static final Map<String, TextPainter> _glyphs = {};

  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  static Offset _orbit(double r, double th, double flat) {
    final ox = r * math.cos(th);
    final oy = r * math.sin(th) * flat;
    return Offset(24 + ox * _ct - oy * _st, 24 + ox * _st + oy * _ct);
  }

  static double _clamp(double v) => v.clamp(0.0, 1.0);

  TextPainter _glyph(String text, Color color) {
    final key = '$text${color.toARGB32()}';
    return _glyphs[key] ??= TextPainter(
      text: TextSpan(
        text: text,
        style: kTextMono.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _glowAndHole(Canvas canvas, double glowR, double glowA, double holeR) {
    _fill.shader = RadialGradient(
      colors: [
        colors.ember.withValues(alpha: glowA),
        colors.ember.withValues(alpha: 0),
      ],
      stops: const [0.4, 1],
    ).createShader(Rect.fromCircle(center: const Offset(24, 24), radius: glowR));
    canvas.drawCircle(const Offset(24, 24), glowR, _fill);
    _fill.shader = null;
  }

  void _hole(Canvas canvas, double r) {
    _fill.color = colors.hole;
    canvas.drawCircle(const Offset(24, 24), r, _fill);
    _stroke
      ..color = colors.ember
      ..strokeWidth = 1.3;
    canvas.drawCircle(const Offset(24, 24), r - 0.65, _stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = (clock.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6;
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    if (kind == AiLoaderKind.title) {
      _title(canvas, t);
    } else {
      _summary(canvas, t);
    }
    canvas.restore();
  }

  /// «Letras en órbita»: A, a y T caen en espiral al agujero.
  void _title(Canvas canvas, double t) {
    const holeR = 5.2;
    _glowAndHole(canvas, 13, 0.22, holeR);
    const letters = ['A', 'a', 'T'];
    final items = <(String, double, double, double)>[];
    for (var i = 0; i < 3; i++) {
      final p = ((t / 2.1) + i / 3) % 1;
      final r = 5.5 + 12 * (1 - p);
      final th = p * 3.2 * math.pi + i * 2.1;
      items.add((letters[i], p, r, th));
    }
    void draw((String, double, double, double) it) {
      final (l, p, r, th) = it;
      final pos = _orbit(r, th, 0.42);
      final a = _clamp(p / 0.1) * _clamp((r - 5.8) / 2.5);
      if (a <= 0.02) return;
      final tp = _glyph(l, p > 0.55 ? colors.emberText : colors.fg2);
      final s = 0.75 * (1 - p * 0.45);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.scale(s);
      _fill.color = Colors.white.withValues(alpha: a);
      canvas.saveLayer(null, _fill);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      canvas.restore();
    }

    for (final it in items) {
      if (math.sin(it.$4) < 0) draw(it);
    }
    _stroke
      ..color = colors.ember.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;
    canvas.save();
    canvas.translate(24, 24);
    canvas.rotate(_tilt);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 22, height: 8.8), _stroke);
    canvas.restore();
    _hole(canvas, holeR);
    for (final it in items) {
      if (math.sin(it.$4) >= 0) draw(it);
    }
  }

  /// «Bits que caen»: puntos, 0 y 1 en espiral, grises lejos y brasa cerca.
  void _summary(Canvas canvas, double t) {
    const holeR = 6.0;
    const n = 9;
    _glowAndHole(canvas, 13, 0.24, holeR);
    final items = <(int, double, double, double)>[];
    for (var i = 0; i < n; i++) {
      final p = ((t / 1.8) + i / n) % 1;
      final r = 6 + 13 * (1 - p);
      final th = p * 2.8 * math.pi + i * 1.7;
      items.add((i, p, r, th));
    }
    void draw((int, double, double, double) it) {
      final (i, p, r, th) = it;
      final pos = _orbit(r, th, 0.55);
      final a = _clamp(p / 0.1) * _clamp((r - 6.2) / 2.5);
      if (a <= 0.02) return;
      final color = p > 0.5 ? colors.emberText : colors.fg2;
      if (i % 3 == 0) {
        final tp = _glyph(i.isOdd ? '1' : '0', color);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.scale(0.65);
        _fill.color = Colors.white.withValues(alpha: a);
        canvas.saveLayer(null, _fill);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
        canvas.restore();
      } else {
        _fill.color = color.withValues(alpha: a);
        canvas.drawCircle(pos, 1.1 + 0.5 * (1 - p), _fill);
      }
    }

    for (final it in items) {
      if (math.sin(it.$4) < 0) draw(it);
    }
    _hole(canvas, holeR);
    for (final it in items) {
      if (math.sin(it.$4) >= 0) draw(it);
    }
  }

  @override
  bool shouldRepaint(covariant _AiLoaderPainter old) =>
      old.kind != kind || old.colors != colors || old.clock != clock;
}

/// Íconos de la IA con el trazo del widget (`widget_ic_title`,
/// `widget_ic_restructure`): estrella de cuatro puntas centrada y tres
/// renglones. Lienzo de 24, trazo 2,2 redondeado.
enum AiGlyph { star, lines }

class AiIcon extends StatelessWidget {
  final AiGlyph glyph;
  final double size;
  final Color color;

  const AiIcon(
      {super.key, required this.glyph, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _AiIconPainter(glyph, color),
    );
  }
}

class _AiIconPainter extends CustomPainter {
  final AiGlyph glyph;
  final Color color;

  _AiIconPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final path = Path();
    if (glyph == AiGlyph.star) {
      path
        ..moveTo(12, 5)
        ..lineTo(13.8, 10.2)
        ..lineTo(19, 12)
        ..lineTo(13.8, 13.8)
        ..lineTo(12, 19)
        ..lineTo(10.2, 13.8)
        ..lineTo(5, 12)
        ..lineTo(10.2, 10.2)
        ..close();
    } else {
      path
        ..moveTo(5, 7)
        ..lineTo(19, 7)
        ..moveTo(5, 12)
        ..lineTo(19, 12)
        ..moveTo(5, 17)
        ..lineTo(13, 17);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AiIconPainter old) =>
      old.glyph != glyph || old.color != color;
}
