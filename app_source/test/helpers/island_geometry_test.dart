import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/helpers/island_geometry.dart';

/// Espejo Dart de `IslandGeometryTest.kt` (complemento): las mismas cuentas
/// con los mismos números, para que la maqueta de Ajustes no se separe de la
/// isla que dibuja el complemento.
void main() {
  // Pantalla típica: 1080 x 2400 px a 3x (xxhdpi).
  const geo = IslandGeometry(screen: Size(1080, 2400), density: 3);
  const auto = IslandGeometry.auto;

  group('IslandGeometry - medidas por defecto', () {
    test('112 x 30 dp, centrada y a 3 dp del borde de arriba', () {
      final r = geo.pill(x: auto, y: auto, w: auto, h: auto);
      expect(r.width, 336);
      expect(r.height, 90);
      expect(r.left, 1080 / 2 - 168);
      expect(r.top, 9);
    });

    test('las constantes son las de IslandGeometry.kt', () {
      expect(IslandGeometry.defaultWidthDp, 112);
      expect(IslandGeometry.defaultHeightDp, 30);
      expect(IslandGeometry.minWidthDp, 72);
      expect(IslandGeometry.maxWidthDp, 180);
      expect(IslandGeometry.minHeightDp, 22);
      expect(IslandGeometry.maxHeightDp, 48);
      expect(IslandGeometry.defaultTopDp, 3);
      expect(IslandGeometry.edgeMarginDp, 4);
      expect(IslandGeometry.auto, -1);
    });
  });

  group('IslandGeometry - ancho y alto', () {
    test('respetan los límites de Ajustes', () {
      expect(geo.resolveWidth(10), 72 * 3);
      expect(geo.resolveWidth(9000), 180 * 3);
      expect(geo.resolveWidth(300), 300);
      expect(geo.resolveHeight(5), 22 * 3);
      expect(geo.resolveHeight(9000), 48 * 3);
      expect(geo.resolveHeight(80), 80);
    });

    test('los rangos de los deslizadores son 72–180 dp y 22–48 dp en px', () {
      expect(geo.minWidth, 216);
      expect(geo.maxWidth, 540);
      expect(geo.minHeight, 66);
      expect(geo.maxHeight, 144);
    });

    test('se convierten con la densidad de la vista', () {
      const dpr2 = IslandGeometry(screen: Size(720, 1600), density: 2);
      expect(dpr2.minWidth, 144);
      expect(dpr2.maxWidth, 360);
      expect(dpr2.resolveWidth(auto), 224);
      expect(dpr2.resolveHeight(auto), 60);
    });

    test('en pantallas angostas el ancho máximo cabe con sus márgenes', () {
      const narrow = IslandGeometry(screen: Size(300, 800), density: 3);
      expect(narrow.maxWidth, 300 - 2 * 12);
      expect(narrow.resolveWidth(9000), 276);
    });
  });

  group('IslandGeometry - posición', () {
    test('x es el centro y y el borde superior', () {
      final r = geo.pill(x: 540, y: 20, w: auto, h: auto);
      expect(r.left, 540 - 168);
      expect(r.top, 20);
    });

    test('el rango de x deja a la isla dentro de la pantalla', () {
      const w = 336;
      expect(geo.minCenterX(w), 12 + 168);
      expect(geo.maxCenterX(w), 1080 - w - 12 + 168);
      for (final cx in [0, 10, 1070, 1080, 5000]) {
        final r = geo.pill(x: cx, y: 0, w: w, h: auto);
        expect(r.left, greaterThanOrEqualTo(12), reason: 'cx=$cx');
        expect(r.right, lessThanOrEqualTo(1080 - 12), reason: 'cx=$cx');
      }
    });

    test('resolveCenterX acota y el centro por defecto es la mitad', () {
      expect(geo.resolveCenterX(auto, 336), 540);
      expect(geo.resolveCenterX(0, 336), geo.minCenterX(336));
      expect(geo.resolveCenterX(99999, 336), geo.maxCenterX(336));
    });

    test('el borde superior se recorta a la pantalla y y llega a un tercio',
        () {
      expect(geo.maxTop, 800);
      final r = geo.pill(x: 540, y: 99999, w: auto, h: auto);
      expect(r.bottom, 2400);
      expect(geo.resolveTop(auto, 90), 9);
      expect(geo.resolveTop(-5, 90), 9);
    });

    test('una pantalla diminuta no devuelve medidas negativas', () {
      const tiny = IslandGeometry(screen: Size(20, 40), density: 3);
      final r = tiny.pill(x: 10, y: 0, w: auto, h: auto);
      expect(r.width, greaterThanOrEqualTo(1));
      expect(r.height, greaterThanOrEqualTo(1));
      expect(tiny.maxCenterX(100), greaterThanOrEqualTo(tiny.minCenterX(100)));
    });
  });

  group('IslandGeometry - piezas del reposo', () {
    test('el micrófono (agujero) va del lado elegido y el puntero del otro',
        () {
      final left = geo.idleCenters(336, true);
      final right = geo.idleCenters(336, false);
      // pad 30 px, agujero 36 px, puntero 42 px.
      expect(left.dotCx, 30 + 18);
      expect(left.pointerCx, 336 - 30 - 21);
      expect(right.dotCx, 336 - 30 - 18);
      expect(right.pointerCx, 30 + 21);
      expect(left.dotCx, lessThan(left.pointerCx));
      expect(right.dotCx, greaterThan(right.pointerCx));
    });
  });
}
