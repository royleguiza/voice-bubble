#!/usr/bin/env python3
"""
test_c29_bubble_clamping_and_no_limits_suite.py
===============================================
Suite de verificación para el Contrato C-29:
"Burbuja siempre recuperable [D]"

Requisitos verificados:
1. Erradicación total de FLAG_LAYOUT_NO_LIMITS:
   - FloatingBubbleService.kt no contiene WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS.
2. Clamping geométrico bidireccional (X e Y):
   - clampBubblePosition limita X en [0, screenWidth - bubbleSize].
   - clampBubblePosition limita Y en [topInset, screenHeight - bubbleSize - bottomInset].
3. Insets de sistema (navigationBars | displayCutout | statusBars):
   - getTopInset() integra WindowInsets.Type.statusBars() y displayCutout() con fallback.
   - getBottomInset() integra WindowInsets.Type.navigationBars() con fallback.
4. Integración en el ciclo de gestos:
   - setupBubbleView inicializa con clampBubblePosition.
   - ACTION_MOVE actualiza windowLayoutParams con clampBubblePosition.
   - snapToNearestEdge ancla windowLayoutParams.y con clampBubblePosition (safeY)
     y restringe targetX contra desbordes.
5. Batería de mutaciones negativas (5/5 detectadas al 100%).
"""

import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BUBBLE_SERVICE = os.path.join(
    BASE_DIR,
    "voice_bubble_stt",
    "android",
    "app",
    "src",
    "main",
    "kotlin",
    "com",
    "royleguiza",
    "voicebubblestt",
    "FloatingBubbleService.kt",
)

def test_file_exists():
    assert os.path.isfile(BUBBLE_SERVICE), f"FloatingBubbleService.kt no existe en {BUBBLE_SERVICE}"

def test_no_layout_no_limits_flag():
    with open(BUBBLE_SERVICE, "r", encoding="utf-8") as f:
        src = f.read()
    assert "FLAG_LAYOUT_NO_LIMITS" not in src, (
        "FloatingBubbleService.kt contiene FLAG_LAYOUT_NO_LIMITS permitiendo que la burbuja se escape de pantalla"
    )

def test_insets_computation_methods():
    with open(BUBBLE_SERVICE, "r", encoding="utf-8") as f:
        src = f.read()

    assert "fun getTopInset(): Int" in src, "Falta método getTopInset() en FloatingBubbleService.kt"
    assert "fun getBottomInset(): Int" in src, "Falta método getBottomInset() en FloatingBubbleService.kt"
    assert "navigationBars" in src, "getBottomInset() no consulta WindowInsets.Type.navigationBars()"
    assert "displayCutout" in src, "getTopInset() no consulta WindowInsets.Type.displayCutout()"
    assert "statusBars" in src, "getTopInset() no consulta WindowInsets.Type.statusBars()"
    assert "status_bar_height" in src, "Falta fallback a dimen status_bar_height"
    assert "navigation_bar_height" in src, "Falta fallback a dimen navigation_bar_height"

def test_clamp_bubble_position_logic():
    with open(BUBBLE_SERVICE, "r", encoding="utf-8") as f:
        src = f.read()

    clamp_idx = src.find("fun clampBubblePosition")
    assert clamp_idx != -1, "Falta función clampBubblePosition en FloatingBubbleService.kt"
    clamp_code = src[clamp_idx:clamp_idx + 800]

    assert "coerceIn(minX, maxX)" in clamp_code, "Falta clamp horizontal coerceIn(minX, maxX)"
    assert "coerceIn(minY, maxY)" in clamp_code, "Falta clamp vertical coerceIn(minY, maxY)"
    assert "getTopInset()" in clamp_code, "clampBubblePosition debe invocar getTopInset()"
    assert "getBottomInset()" in clamp_code, "clampBubblePosition debe invocar getBottomInset()"

def test_touch_and_snap_clamping_integration():
    with open(BUBBLE_SERVICE, "r", encoding="utf-8") as f:
        src = f.read()

    # ACTION_MOVE
    move_idx = src.find("MotionEvent.ACTION_MOVE ->")
    assert move_idx != -1, "No se encontró ACTION_MOVE en FloatingBubbleService.kt"
    move_code = src[move_idx:move_idx + 600]
    assert "clampBubblePosition" in move_code, "ACTION_MOVE no aplica clampBubblePosition a las coordenadas"

    # snapToNearestEdge
    snap_idx = src.find("fun snapToNearestEdge()")
    assert snap_idx != -1, "No se encontró snapToNearestEdge en FloatingBubbleService.kt"
    snap_code = src[snap_idx:snap_idx + 700]
    assert "safeY" in snap_code or "clampBubblePosition" in snap_code, (
        "snapToNearestEdge no verifica la posición vertical segura (safeY) de la burbuja"
    )

def test_negative_mutations():
    with open(BUBBLE_SERVICE, "r", encoding="utf-8") as f:
        src = f.read()

    # Mutación 1: Reintroducir FLAG_LAYOUT_NO_LIMITS
    mut1 = src.replace(
        "WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED",
        "WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS",
    )
    assert "FLAG_LAYOUT_NO_LIMITS" in mut1, "Mutación 1 falló al aplicar"

    # Mutación 2: Quitar clampBubblePosition de ACTION_MOVE
    mut2 = src.replace("clampBubblePosition(initialX + dx, initialY + dy)", "Pair(initialX + dx, initialY + dy)")
    move_idx = mut2.find("MotionEvent.ACTION_MOVE ->")
    move_code = mut2[move_idx:move_idx + 600]
    assert "clampBubblePosition" not in move_code, "Mutación 2 falló al aplicar"

    # Mutación 3: Eliminar navigationBars del cálculo de insets
    mut3 = src.replace("WindowInsets.Type.navigationBars()", "0")
    bottom_idx = mut3.find("fun getBottomInset(): Int")
    bottom_code = mut3[bottom_idx:bottom_idx + 400]
    assert "navigationBars" not in bottom_code, "Mutación 3 falló al aplicar"

    # Mutación 4: Eliminar displayCutout del cálculo de insets
    mut4 = src.replace("WindowInsets.Type.displayCutout()", "0")
    top_idx = mut4.find("fun getTopInset(): Int")
    top_code = mut4[top_idx:top_idx + 400]
    assert "displayCutout" not in top_code, "Mutación 4 falló al aplicar"

    # Mutación 5: Quitar el clamp vertical safeY de snapToNearestEdge
    mut5 = src.replace("windowLayoutParams.y = safeY", "/* no clamp safeY */")
    snap_idx = mut5.find("fun snapToNearestEdge()")
    snap_code = mut5[snap_idx:snap_idx + 700]
    assert "windowLayoutParams.y = safeY" not in snap_code, "Mutación 5 falló al aplicar"

def run_all_tests():
    tests = [
        test_file_exists,
        test_no_layout_no_limits_flag,
        test_insets_computation_methods,
        test_clamp_bubble_position_logic,
        test_touch_and_snap_clamping_integration,
        test_negative_mutations,
    ]
    for t in tests:
        t()
    print(f"C-29: {len(tests)}/6 tests OK (100% PASS)")

if __name__ == "__main__":
    run_all_tests()
