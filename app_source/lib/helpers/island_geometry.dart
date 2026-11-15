import 'dart:math' as math;
import 'dart:ui';

/// Geometría de la isla en reposo: espejo en Dart de `IslandGeometry.kt` del
/// complemento (`puntero_android/`), para que Ajustes dibuje la maqueta y
/// acote los deslizadores con EXACTAMENTE las mismas cuentas con las que el
/// complemento dibuja la isla real. Si una constante cambia allá, cambia acá
/// (el test `island_geometry_test.dart` fija los valores).
///
/// Todo en px de pantalla completa, con la pantalla y la densidad de la vista
/// de Flutter (en Android, `devicePixelRatio` = `displayMetrics.density`).
/// `-1` ([auto]) = valor por defecto: centrada, 3 dp desde arriba,
/// 112 × 30 dp.
class IslandGeometry {
  /// Medidas en dp (maqueta `laboratorio_ui/isla.html`).
  static const double defaultWidthDp = 112;
  static const double defaultHeightDp = 30;
  static const double minWidthDp = 72;
  static const double maxWidthDp = 180;
  static const double minHeightDp = 22;
  static const double maxHeightDp = 48;
  static const double defaultTopDp = 3;

  /// Separación mínima de la píldora a los bordes laterales.
  static const double edgeMarginDp = 4;

  /// Reposo: agujero chico, glifo del puntero y relleno lateral.
  static const double idleDotDp = 12;
  static const double idlePointerDp = 14;
  static const double idlePadDp = 10;

  /// Valor «por defecto» que se guarda y se manda al complemento.
  static const int auto = -1;

  /// Pantalla completa en px (físicos) y densidad (px por dp).
  final Size screen;
  final double density;

  const IslandGeometry({required this.screen, required this.density});

  int px(double dp) => (dp * density).round();

  int get screenW => screen.width.round();
  int get screenH => screen.height.round();
  int get margin => px(edgeMarginDp);

  /// Rango del ancho en reposo (nunca más ancho que la pantalla con sus márgenes).
  int get minWidth => px(minWidthDp);
  int get maxWidth =>
      math.max(minWidth, math.min(px(maxWidthDp), screenW - 2 * margin));

  /// Rango del alto en reposo.
  int get minHeight => px(minHeightDp);
  int get maxHeight => px(maxHeightDp);

  /// Ancho real: el pedido ([auto] = 112 dp) acotado al rango.
  int resolveWidth(int requested) {
    final w = requested < 0 ? px(defaultWidthDp) : requested;
    return w.clamp(minWidth, maxWidth);
  }

  /// Alto real: el pedido ([auto] = 30 dp) acotado al rango.
  int resolveHeight(int requested) {
    final h = requested < 0 ? px(defaultHeightDp) : requested;
    return h.clamp(minHeight, maxHeight);
  }

  /// Centro horizontal más a la izquierda / derecha para una píldora de
  /// [width] px: sin salirse de la pantalla ni de su margen.
  int minCenterX(int width) => margin + width ~/ 2;
  int maxCenterX(int width) =>
      math.max(minCenterX(width), screenW - width - margin + width ~/ 2);

  /// Borde superior máximo que ofrece Ajustes: un tercio del alto.
  int get maxTop => math.max(1, screenH ~/ 3);

  /// Centro horizontal real: el pedido ([auto] = centro de la pantalla)
  /// acotado como en el complemento.
  int resolveCenterX(int requested, int width) {
    final cx = requested < 0 ? screenW ~/ 2 : requested;
    return cx.clamp(minCenterX(width), maxCenterX(width));
  }

  /// Borde superior real: el pedido ([auto] = 3 dp) sin salirse de la pantalla.
  int resolveTop(int requested, int height) {
    final y = requested < 0 ? px(defaultTopDp) : requested;
    return y.clamp(0, math.max(0, screenH - height));
  }

  /// Rectángulo de la píldora en reposo, tal como la dibuja el complemento.
  Rect pill({
    required int x,
    required int y,
    required int w,
    required int h,
  }) {
    final width = resolveWidth(w);
    final height = resolveHeight(h);
    final cx = resolveCenterX(x, width);
    final left = (cx - width ~/ 2).clamp(
      margin,
      math.max(margin, screenW - width - margin),
    );
    return Rect.fromLTWH(
      left.toDouble(),
      resolveTop(y, height).toDouble(),
      width.toDouble(),
      height.toDouble(),
    );
  }

  /// Reposo: centro (relativo a la píldora) del agujero y del glifo del
  /// puntero. El micrófono (el agujero) va del lado [micOnLeft].
  ({double dotCx, double pointerCx}) idleCenters(double w, bool micOnLeft) {
    final pad = px(idlePadDp);
    final dot = px(idleDotDp);
    final ptr = px(idlePointerDp);
    final left = pad + dot / 2;
    final right = w - pad - ptr / 2;
    return micOnLeft
        ? (dotCx: left, pointerCx: right)
        : (dotCx: w - pad - dot / 2, pointerCx: pad + ptr / 2);
  }
}
