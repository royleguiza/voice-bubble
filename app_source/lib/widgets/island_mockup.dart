import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../helpers/island_geometry.dart';
import '../ui/design_tokens.dart';
import 'settings_v2.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';

/// Maqueta de Ajustes › Ajustar isla: la parte de arriba de la pantalla del
/// teléfono con la isla en reposo, a ESCALA REAL.
///
/// Un solo factor `escala = ancho de la maqueta / ancho de la pantalla en px`
/// pasa a la maqueta la posición, el tamaño y hasta el relleno de la isla, de
/// modo que cada píxel que se ajusta equivale a `escala` puntos acá. La
/// píldora se calcula con [IslandGeometry] —espejo de `IslandGeometry.kt`—,
/// o sea con las mismas cuentas con las que el complemento la dibuja de
/// verdad (recortada a la pantalla, con su margen).
///
/// La isla es negra siempre (design.md §14); la maqueta sigue el tema de
/// Ajustes. Sin desenfoque ni animaciones: cada cambio se ve de inmediato.
class IslandMockup extends StatelessWidget {
  /// Pantalla completa en px y densidad de la vista real.
  final Size screenPx;
  final double density;

  /// Valores pedidos tal como se guardan (−1 = por defecto).
  final int x;
  final int y;
  final int w;
  final int h;

  /// Lado del micrófono (el agujero); el puntero va del otro.
  final bool micOnLeft;

  const IslandMockup({
    super.key,
    required this.screenPx,
    required this.density,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.micOnLeft,
  });

  /// Alto de la barra de estado simulada, en dp (la real mide ~24–36).
  static const double statusBarDp = 28;

  static const BorderRadius _frameRadius = BorderRadius.vertical(
    top: Radius.circular(kRadiusSheet),
  );

  /// Qué decir en voz alta de la maqueta (la leen los lectores de pantalla).
  static String describe(AppLocalizations l10n, Rect pill, bool micOnLeft) {
    final cx = (pill.left + pill.width / 2).round();
    return l10n.islandMockupDescription(
      cx.toString(),
      pill.top.round().toString(),
      pill.width.round().toString(),
      pill.height.round().toString(),
      micOnLeft ? l10n.islandMicLeft : l10n.islandMicRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final geo = IslandGeometry(screen: screenPx, density: density);
    final pill = geo.pill(x: x, y: y, w: w, h: h);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? math.min(constraints.maxWidth, kIslandMockupMaxWidth)
            : kIslandMockupMaxWidth;
        final scale = width / screenPx.width;
        final height = screenPx.height * kIslandMockupVisibleFraction * scale;
        final bar = statusBarDp * density * scale;
        final dpScale = density * scale;
        final caption = math.min(12.0, math.max(6.0, 11 * dpScale));
        return Center(
          child: Semantics(
            container: true,
            image: true,
            label: describe(context.l10n, pill, micOnLeft),
            child: ExcludeSemantics(
              child: Container(
                key: const ValueKey('island-mockup'),
                width: width,
                height: height,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.field,
                  borderRadius: _frameRadius,
                ),
                // El borde va por encima y no resta ancho: así el contenido
                // mide justo lo que la pantalla y la escala no se desvía.
                foregroundDecoration: BoxDecoration(
                  borderRadius: _frameRadius,
                  border: Border.all(color: p.border, width: p.borderWidth),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Tarjetas de «apps» detrás, como la maqueta de isla.html.
                    for (final top in const [64.0, 120.0, 176.0])
                      Positioned(
                        left: 16 * dpScale,
                        right: 16 * dpScale,
                        top: top * dpScale + bar,
                        height: 44 * dpScale,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius:
                                BorderRadius.circular(kRadiusCard * dpScale),
                          ),
                        ),
                      ),
                    // Guía del centro de la pantalla (para cámaras centradas).
                    Positioned(
                      left: width / 2 - 0.5,
                      top: 0,
                      width: 1,
                      height: bar,
                      child: ColoredBox(color: p.separator),
                    ),
                    // Barra de estado: hora a la izquierda, íconos a la derecha.
                    Positioned(
                      left: 18 * dpScale,
                      top: 0,
                      height: bar,
                      child: Center(
                        child: Text(
                          '9:41',
                          style: kTextMono.copyWith(
                            fontSize: caption,
                            color: p.label,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18 * dpScale,
                      top: 0,
                      height: bar,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final iconW in const [14.0, 14.0, 20.0]) ...[
                            Container(
                              width: iconW * dpScale,
                              height: 9 * dpScale,
                              decoration: BoxDecoration(
                                color: p.icon,
                                borderRadius:
                                    BorderRadius.circular(2 * dpScale),
                              ),
                            ),
                            SizedBox(width: 5 * dpScale),
                          ],
                        ],
                      ),
                    ),
                    // La isla en reposo: misma posición y medida que la real.
                    Positioned(
                      key: const ValueKey('island-mockup-pill'),
                      left: pill.left * scale,
                      top: pill.top * scale,
                      width: pill.width * scale,
                      height: pill.height * scale,
                      child: CustomPaint(
                        painter: _IdleIslandPainter(
                          geo: geo,
                          micOnLeft: micOnLeft,
                          scale: scale,
                          pillWidth: pill.width,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dibuja la píldora negra con su borde, el agujero (anillo de brasa) y el
/// glifo del puntero (fg al 55 %), todo a [scale] del tamaño real en px.
class _IdleIslandPainter extends CustomPainter {
  final IslandGeometry geo;
  final bool micOnLeft;
  final double scale;
  final double pillWidth;

  const _IdleIslandPainter({
    required this.geo,
    required this.micOnLeft,
    required this.scale,
    required this.pillWidth,
  });

  /// Flecha del puntero (viewBox 24 de la maqueta isla.html).
  static Path _pointer() => Path()
    ..moveTo(6, 3)
    ..lineTo(6, 18.5)
    ..lineTo(10.1, 14.8)
    ..lineTo(13, 21.4)
    ..lineTo(15.5, 20.3)
    ..lineTo(12.7, 13.9)
    ..lineTo(18, 13.9)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final d = geo.density;
    final pill = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(pill, Paint()..color = kIslandBg);
    // Borde de 1 dp (a escala, con un mínimo para que se vea).
    final border = math.min(2.0, math.max(0.75, d * scale));
    canvas.drawRRect(
      pill.deflate(border / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = border
        ..color = kIslandLine,
    );

    final centers = geo.idleCenters(pillWidth, micOnLeft);
    final cy = size.height / 2;

    // Agujero: disco negro con anillo de brasa de 1,5 dp.
    final dotR = IslandGeometry.idleDotDp * d * scale / 2;
    final ring = 1.5 * d * scale;
    canvas.drawCircle(
      Offset(centers.dotCx * scale, cy),
      dotR,
      Paint()..color = kIslandBg,
    );
    canvas.drawCircle(
      Offset(centers.dotCx * scale, cy),
      dotR - ring / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring
        ..color = kEmberDark,
    );

    // Glifo del puntero: el path de 24 unidades llevado a 14 dp.
    final ptr = IslandGeometry.idlePointerDp * d * scale;
    canvas.save();
    canvas.translate(
      centers.pointerCx * scale - ptr / 2,
      cy - ptr / 2,
    );
    canvas.scale(ptr / 24);
    canvas.drawPath(
      _pointer(),
      Paint()..color = kIslandFg.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IdleIslandPainter old) =>
      old.geo.screen != geo.screen ||
      old.geo.density != geo.density ||
      old.micOnLeft != micOnLeft ||
      old.scale != scale ||
      old.pillWidth != pillWidth;
}
