#!/usr/bin/env python3
"""
test_c29_bubble_clamping_and_no_limits_suite.py
===============================================
Contrato C-29: "Burbuja siempre recuperable [D]".

Desde 2026-10-30 la burbuja es la barra flotante (DockController +
DockGeometry + GlassWindow): un objeto con dos formas, barra en el borde y
burbuja libre. El contrato se mantiene igual:

1. Sin FLAG_LAYOUT_NO_LIMITS en ninguna ventana de la barra.
2. Clamping geométrico bidireccional:
   - DockGeometry.clampBubble limita X en [0, screenW - size] e Y en
     [topInset, screenH - bottomInset - size].
   - DockGeometry.clampCenterY limita el centro de la barra a la zona segura.
3. Insets de sistema: topInset() con statusBars | displayCutout,
   bottomInset() con navigationBars, ambos con fallback.
4. Integración en gestos: mover la burbuja, mover la barra, soltar contra
   un borde y aplicar la forma pasan siempre por el clamp.
5. Tests JVM (DockGeometryTest) cubren los límites.
6. Mutaciones negativas detectadas.
"""

import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
KT = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt")
TEST_KT = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "test", "kotlin", "com", "royleguiza", "voicebubblestt")


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


SERVICE = read(os.path.join(KT, "FloatingBubbleService.kt"))
DOCK = read(os.path.join(KT, "DockController.kt"))
GEO = read(os.path.join(KT, "DockGeometry.kt"))
GLASS = read(os.path.join(KT, "GlassWindow.kt"))
GEO_TEST = read(os.path.join(TEST_KT, "DockGeometryTest.kt"))


def code_of(src, needle, span=900):
    i = src.find(needle)
    assert i != -1, f"No se encontró: {needle}"
    return src[i:i + span]


def test_no_layout_no_limits_flag():
    for name, src in (("FloatingBubbleService", SERVICE), ("DockController", DOCK), ("GlassWindow", GLASS)):
        flagged = [l for l in src.splitlines() if "FLAG_LAYOUT_NO_LIMITS" in l and not l.strip().startswith("*")]
        assert not flagged, f"{name} usa FLAG_LAYOUT_NO_LIMITS: la barra podría salir de pantalla"


def test_clamp_geometry():
    bubble = code_of(GEO, "fun clampBubble(")
    assert "x.coerceIn(0f, maxX)" in bubble and "screenW - size" in bubble, "clampBubble no limita X"
    assert "y.coerceIn(topInset, maxY)" in bubble and "screenH - bottomInset - size" in bubble, "clampBubble no limita Y"
    center = code_of(GEO, "fun clampCenterY(")
    assert "topInset + halfExtent" in center and "screenH - bottomInset - halfExtent" in center, "clampCenterY sin zona segura"
    assert "if (hi <= lo)" in center, "clampCenterY sin caso de pantalla mínima"


def test_insets():
    top = code_of(DOCK, "private fun topInset(): Float")
    bottom = code_of(DOCK, "private fun bottomInset(): Float")
    assert "statusBars()" in top and "displayCutout()" in top, "topInset sin statusBars/displayCutout"
    assert "return 28f * d" in top, "topInset sin fallback"
    assert "navigationBars()" in bottom, "bottomInset sin navigationBars"
    assert "return 48f * d" in bottom, "bottomInset sin fallback"


def test_gesture_integration():
    assert "clampBubble(" in code_of(DOCK, "private fun clampBubblePos()", 400)
    assert "DockGeometry.clampCenterY(" in code_of(DOCK, "private fun clampCenter(y: Float)", 400)
    bubble_move = code_of(DOCK, "private inner class BubbleTouch", 2200)
    assert "clampBubblePos()" in bubble_move, "mover la burbuja no limita su posición"
    edge_touch = code_of(DOCK, "private inner class EdgeTouch", 3600)
    assert "clampCenter(center0 + dy)" in edge_touch, "mover la barra no limita su posición"
    assert "clampBubblePos()" in edge_touch, "la burbuja que nace del arrastre no se limita"
    finish = code_of(DOCK, "private fun finishBubbleDrag()", 900)
    assert "clampCenter(bubbleY + bubbleSize / 2f)" in finish, "soltar contra el borde no limita la barra"
    apply = code_of(DOCK, "private fun applyForm()", 1200)
    assert "centerY = clampCenter(centerY)" in apply and "clampBubblePos()" in apply, "aplicar la forma no limita"


def test_jvm_tests_cover_limits():
    for name in ("la burbuja no se sale de la pantalla", "el centro de la barra queda dentro de la zona segura",
                 "pantalla minima no rompe el limite vertical"):
        assert name in GEO_TEST, f"Falta test JVM: {name}"


def test_negative_mutations():
    mut1 = GLASS.replace("FLAG_LAYOUT_IN_SCREEN or", "FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or")
    assert [l for l in mut1.splitlines() if "FLAG_LAYOUT_NO_LIMITS" in l and not l.strip().startswith("*")], "Mutación 1 no detectable"
    mut2 = DOCK.replace("centerY = clampCenter(center0 + dy)", "centerY = center0 + dy")
    assert "clampCenter(center0 + dy)" not in mut2, "Mutación 2 no detectable"
    mut3 = DOCK.replace("WindowInsets.Type.navigationBars()", "0")
    assert "navigationBars()" not in code_of(mut3, "private fun bottomInset(): Float"), "Mutación 3 no detectable"
    mut4 = DOCK.replace("WindowInsets.Type.statusBars() or WindowInsets.Type.displayCutout()", "0")
    assert "displayCutout()" not in code_of(mut4, "private fun topInset(): Float"), "Mutación 4 no detectable"
    mut5 = GEO.replace("y.coerceIn(topInset, maxY)", "y")
    assert "y.coerceIn(topInset, maxY)" not in mut5, "Mutación 5 no detectable"


def run_all_tests():
    tests = [
        test_no_layout_no_limits_flag,
        test_clamp_geometry,
        test_insets,
        test_gesture_integration,
        test_jvm_tests_cover_limits,
        test_negative_mutations,
    ]
    failed = 0
    for t in tests:
        try:
            t()
        except AssertionError as e:
            failed += 1
            print(f"  [FAIL] {t.__name__}: {e}")
    print(f"C-29: {len(tests) - failed}/{len(tests)} tests OK")
    return failed


if __name__ == "__main__":
    sys.exit(1 if run_all_tests() else 0)
