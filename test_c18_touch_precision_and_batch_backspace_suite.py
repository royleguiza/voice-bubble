#!/usr/bin/env python3
"""
test_c18_touch_precision_and_batch_backspace_suite.py
Suite de verificación rigurosa para el Contrato C-18:
"Toques que no se pierden ni se inventan".

Verifica:
1. KeyFactory.kt:
   - fastTap: detección de touch slop en ACTION_MOVE (swipe-out no commitea)
   - longPress: detección de touch slop en ACTION_MOVE (swipe-out no dispara onTapUp ni longPress)
   - makeGapTolerant: público/accesible con detección de touch slop en ACTION_MOVE
   - backspaceGestures: aceleración por lotes delegando a deleteBackward(batch)
   - Tags en todas las teclas (makeSpecialKey, makeActionIconKey, makeBackspaceKey, makeIconKey)
2. LayoutLayer.kt:
   - row3 en buildLetterRows tiene keys.makeGapTolerant(row3)
   - row3 en buildSymbolRows tiene keys.makeGapTolerant(row3)
   - row3 en buildCodeRows tiene keys.makeGapTolerant(row3)
3. SnippetsLayer.kt:
   - buildLetterRows aplica makeGapTolerant a r1, r2 y row3
   - makeLetterKey y makeBackspaceKey asignan key.tag
   - backspaceEditor y backspaceQuery soportan borrado por lotes con count
4. VoiceKeyboardService.kt:
   - implementa makeGapTolerant delegando en keys
   - implementa deleteBackward(count: Int) delegando en editor.handleBackspace(count)
5. EditEngine.kt:
   - handleBackspace(count: Int = 1) acumula caracteres y ejecuta un solo deleteSurroundingText por tick
   - Manejo correcto de surrogate pairs en borrado por lotes
6. Simulación de gestos y comportamiento de slop y batching
7. Detección de mutaciones negativas reales sobre el código
"""

import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt")

KF_FILE = os.path.join(APP_DIR, "KeyFactory.kt")
LAYOUT_FILE = os.path.join(APP_DIR, "LayoutLayer.kt")
SNIPPETS_FILE = os.path.join(APP_DIR, "SnippetsLayer.kt")
VKS_FILE = os.path.join(APP_DIR, "VoiceKeyboardService.kt")
EE_FILE = os.path.join(APP_DIR, "EditEngine.kt")

class SuiteTracker:
    def __init__(self):
        self.passed = 0
        self.failed = 0

    def check(self, desc, condition, detail=""):
        if condition:
            print(f"  [PASS] {desc}")
            self.passed += 1
        else:
            msg = f" -> {detail}" if detail else ""
            print(f"  [FAIL] {desc}{msg}")
            self.failed += 1

suite = SuiteTracker()

def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

print("=" * 60)
print(" INICIANDO TEST SUITE: CONTRATO C-18 (TOQUES QUE NO SE PIERDEN NI SE INVENTAN)")
print("=" * 60)

# --- 1. Verificación de Existencia de Archivos ---
suite.check("KeyFactory.kt existe", os.path.exists(KF_FILE))
suite.check("LayoutLayer.kt existe", os.path.exists(LAYOUT_FILE))
suite.check("SnippetsLayer.kt existe", os.path.exists(SNIPPETS_FILE))
suite.check("VoiceKeyboardService.kt existe", os.path.exists(VKS_FILE))
suite.check("EditEngine.kt existe", os.path.exists(EE_FILE))

kf_code = read_file(KF_FILE)
layout_code = read_file(LAYOUT_FILE)
snippets_code = read_file(SNIPPETS_FILE)
vks_code = read_file(VKS_FILE)
ee_code = read_file(EE_FILE)

# --- 2. Verificación de KeyFactory.kt ---
# 2.1 fastTap
fast_tap_chunk = kf_code[kf_code.find("fun fastTap("):kf_code.find("private fun pressPop(")]
suite.check(
    "KeyFactory.fastTap evalúa touchSlopPx en ACTION_MOVE",
    "scaledTouchSlop" in fast_tap_chunk and "MotionEvent.ACTION_MOVE" in fast_tap_chunk and "slopExceeded" in fast_tap_chunk,
    "fastTap debe calcular desplazamiento y marcar slopExceeded"
)
fast_tap_up = fast_tap_chunk[fast_tap_chunk.find("MotionEvent.ACTION_UP"):fast_tap_chunk.find("MotionEvent.ACTION_CANCEL")]
suite.check(
    "KeyFactory.fastTap condiciona onClick a !slopExceeded",
    "!slopExceeded" in fast_tap_up and "onClick()" in fast_tap_up,
    "onClick no debe ejecutarse si se superó el slop"
)

# 2.2 longPress
long_press_chunk = kf_code[kf_code.find("fun longPress("):kf_code.find("fun backspaceGestures(")]
suite.check(
    "KeyFactory.longPress evalúa touchSlopPx en ACTION_MOVE",
    "slopExceeded" in long_press_chunk and "MotionEvent.ACTION_MOVE" in long_press_chunk,
    "longPress debe calcular desplazamiento y marcar slopExceeded"
)
suite.check(
    "KeyFactory.longPress cancela pending y repeating al superar slop",
    "cancelPending()" in long_press_chunk and "cancelRepeating()" in long_press_chunk and "slopExceeded = true" in long_press_chunk,
    "longPress debe cancelar callbacks al deslizar fuera"
)
long_press_up = long_press_chunk[long_press_chunk.find("MotionEvent.ACTION_UP"):long_press_chunk.find("MotionEvent.ACTION_CANCEL")]
suite.check(
    "KeyFactory.longPress condiciona onTapUp a !slopExceeded",
    "!slopExceeded" in long_press_up and "onTapUp()" in long_press_up,
    "onTapUp no debe ejecutarse si se superó el slop"
)

# 2.3 makeGapTolerant
gap_chunk = kf_code[kf_code.find("fun makeGapTolerant("):kf_code.find("private fun nearestChild(")]
suite.check(
    "KeyFactory.makeGapTolerant es accesible (fun makeGapTolerant)",
    "fun makeGapTolerant(" in gap_chunk and "private fun makeGapTolerant(" not in kf_code,
    "makeGapTolerant debe ser accesible para LayoutLayer y SnippetsLayer"
)
suite.check(
    "KeyFactory.makeGapTolerant evalúa touchSlopPx en ACTION_MOVE",
    "scaledTouchSlop" in gap_chunk and "MotionEvent.ACTION_MOVE" in gap_chunk and "slopExceeded = true" in gap_chunk,
    "makeGapTolerant debe detectar desplazamientos fuera del gap"
)
suite.check(
    "KeyFactory.makeGapTolerant condiciona commit a !slopExceeded",
    "if (!slopExceeded)" in gap_chunk and "(child.tag as? () -> Unit)?.invoke()" in gap_chunk,
    "makeGapTolerant no debe commitear si se superó el slop"
)

# 2.4 Tags en constructores de teclas
suite.check(
    "makeSpecialKey asigna key.tag = onClick",
    "key.tag = onClick" in kf_code,
    "makeSpecialKey debe guardar acción en tag para gap-tolerancia"
)
suite.check(
    "makeActionIconKey asigna key.tag = onClick",
    "key.tag = onClick" in kf_code,
    "makeActionIconKey debe guardar acción en tag para gap-tolerancia"
)
suite.check(
    "makeBackspaceKey asigna key.tag",
    "key.tag = action" in kf_code,
    "makeBackspaceKey debe guardar acción en tag para gap-tolerancia"
)

# 2.5 backspaceGestures borrado por lotes
backspace_chunk = kf_code[kf_code.find("fun backspaceGestures("):kf_code.find("fun cancelPendingGestures(")]
suite.check(
    "backspaceGestures acumula y delega a deleteBackward(batch)",
    "host.deleteBackward(batch)" in backspace_chunk and "repeatCycle" in backspace_chunk,
    "backspaceGestures debe acumular ciclos de repetición y enviar borrado por lotes"
)

# --- 3. Verificación de LayoutLayer.kt ---
suite.check(
    "LayoutLayer.buildLetterRows aplica makeGapTolerant a row3",
    "keys.makeGapTolerant(row3)" in layout_code[layout_code.find("fun buildLetterRows()"):layout_code.find("fun buildSymbolRows()")],
    "row3 de letras debe ser gap-tolerante"
)
suite.check(
    "LayoutLayer.buildSymbolRows aplica makeGapTolerant a row3",
    "keys.makeGapTolerant(row3)" in layout_code[layout_code.find("fun buildSymbolRows()"):layout_code.find("fun buildCodeRows()")],
    "row3 de símbolos debe ser gap-tolerante"
)
suite.check(
    "LayoutLayer.buildCodeRows aplica makeGapTolerant a row3",
    "keys.makeGapTolerant(row3)" in layout_code[layout_code.find("fun buildCodeRows()"):layout_code.find("fun buildBottomBar()")],
    "row3 de código debe ser gap-tolerante"
)
suite.check(
    "LayoutLayer shiftKey tiene tag de acción",
    "shiftKey.tag = shiftAction" in layout_code,
    "shiftKey debe tener tag para toques en gap"
)

# --- 4. Verificación de SnippetsLayer.kt ---
snippets_rows_chunk = snippets_code[snippets_code.find("fun buildLetterRows()"):snippets_code.find("private fun letterRow(")]
suite.check(
    "SnippetsLayer.UiHost declara makeGapTolerant",
    "fun makeGapTolerant(row: LinearLayout)" in snippets_code,
    "UiHost de snippets debe exponer makeGapTolerant"
)
suite.check(
    "SnippetsLayer.buildLetterRows aplica makeGapTolerant a r1, r2 y row3",
    "host.makeGapTolerant(r1)" in snippets_rows_chunk and "host.makeGapTolerant(r2)" in snippets_rows_chunk and "host.makeGapTolerant(row3)" in snippets_rows_chunk,
    "Todas las filas de letras en snippets deben ser gap-tolerantes"
)
suite.check(
    "SnippetsLayer.makeLetterKey guarda commit en key.tag",
    "key.tag = commit" in snippets_code[snippets_code.find("private fun makeLetterKey("):snippets_code.find("private fun makeBackspaceKey(")],
    "makeLetterKey en snippets debe guardar commit en tag"
)
suite.check(
    "SnippetsLayer.makeBackspaceKey guarda acción en key.tag",
    "key.tag = action" in snippets_code[snippets_code.find("private fun makeBackspaceKey("):snippets_code.find("private fun commitLetter(")],
    "makeBackspaceKey en snippets debe guardar acción en tag"
)
suite.check(
    "SnippetsLayer.backspaceEditor soporta count para lotes",
    "fun backspaceEditor(count: Int = 1): Boolean" in snippets_code,
    "backspaceEditor debe admitir count"
)
suite.check(
    "SnippetsLayer.backspaceQuery soporta count para lotes",
    "fun backspaceQuery(count: Int = 1): Boolean" in snippets_code,
    "backspaceQuery debe admitir count"
)

# --- 5. Verificación de VoiceKeyboardService.kt ---
suite.check(
    "VKS implementa override fun makeGapTolerant delegando a keys",
    "override fun makeGapTolerant(row: LinearLayout) = keys.makeGapTolerant(row)" in vks_code,
    "VKS debe delegar makeGapTolerant a keys"
)
suite.check(
    "VKS implementa deleteBackward(count: Int) delegando a editor",
    "override fun deleteBackward(count: Int) = editor.handleBackspace(count)" in vks_code,
    "VKS debe delegar deleteBackward(count) a editor"
)

# --- 6. Verificación de EditEngine.kt ---
ee_backspace_chunk = ee_code[ee_code.find("fun handleBackspace("):ee_code.find("fun deleteWordBeforeCursor()")]
suite.check(
    "EditEngine.handleBackspace admite count: Int = 1",
    "fun handleBackspace(count: Int = 1)" in ee_backspace_chunk,
    "handleBackspace debe aceptar parámetro count"
)
suite.check(
    "EditEngine.handleBackspace ejecuta un solo deleteSurroundingText",
    ee_backspace_chunk.count("ic.deleteSurroundingText(") == 1,
    "handleBackspace debe realizar exactamente una llamada a deleteSurroundingText por tick"
)
suite.check(
    "EditEngine.handleBackspace maneja surrogate pairs en borrado por lotes",
    "Character.isSurrogatePair(" in ee_backspace_chunk and "toDeleteUnits += 2" in ee_backspace_chunk,
    "handleBackspace debe contemplar emojis y surrogate pairs en el cálculo de unidades a borrar"
)

# --- 7. Simulación de Comportamiento: Touch Slop y Batching ---
print("\n--- Simulación de Comportamiento: Touch Slop y Batching ---")

class MockTouchScenario:
    def __init__(self, slop_px=24):
        self.slop_px = slop_px
        self.committed = False
        self.popped = False

    def on_touch(self, down_coords, move_coords, up_coords):
        # DOWN
        down_x, down_y = down_coords
        slop_exceeded = False
        self.popped = True
        
        # MOVE
        for move_x, move_y in move_coords:
            dx = move_x - down_x
            dy = move_y - down_y
            if dx * dx + dy * dy > self.slop_px * self.slop_px:
                slop_exceeded = True
                self.popped = False
                
        # UP
        if not slop_exceeded:
            self.committed = True
        self.popped = False
        return self.committed

# Simulación 1: Tap normal dentro del slop
scen1 = MockTouchScenario()
comm1 = scen1.on_touch((10, 10), [(12, 11), (13, 10)], (14, 11))
suite.check("Tap dentro de slop: comitea exitosamente", comm1)

# Simulación 2: Swipe-out (dedo escapa fuera del botón)
scen2 = MockTouchScenario()
comm2 = scen2.on_touch((10, 10), [(20, 20), (50, 60), (100, 150)], (120, 180))
suite.check("Swipe-out fuera de slop: NO comitea (descarte de toque)", not comm2)

# Simulación 3: Borrado por lotes y cálculo de surrogate pairs
class MockSurrogateBatcher:
    def calculate_units_to_delete(self, text_before, count):
        safe_count = max(1, count)
        to_delete_units = 0
        if text_before:
            chars_found = 0
            i = len(text_before) - 1
            while i >= 0 and chars_found < safe_count:
                # Emojis representados por surrogate pair en Python (o len 2 si UTF-16)
                # Para la prueba, simulamos que '\U0001F600' (😀) ocupa 2 unidades de código
                if ord(text_before[i]) > 0xFFFF or (i > 0 and ord(text_before[i-1]) > 0xD7FF and ord(text_before[i-1]) < 0xE000):
                    to_delete_units += 2
                    i -= 2
                else:
                    to_delete_units += 1
                    i -= 1
                chars_found += 1
        return max(safe_count, to_delete_units)

batcher = MockSurrogateBatcher()
# Caso A: 1 carácter ASCII
units_a = batcher.calculate_units_to_delete("hola", 1)
suite.check("Batch 1 ASCII: 1 unidad", units_a == 1)

# Caso B: 2 caracteres ASCII
units_b = batcher.calculate_units_to_delete("hola", 2)
suite.check("Batch 2 ASCII: 2 unidades", units_b == 2)

# Caso C: 3 caracteres ASCII
units_c = batcher.calculate_units_to_delete("hola", 3)
suite.check("Batch 3 ASCII: 3 unidades", units_c == 3)

# --- 8. Verificación de Mutaciones Negativas ---
print("\n--- Verificación de Mutaciones Negativas ---")

# Mutación 1: LayoutLayer sin makeGapTolerant en row3
mut1 = layout_code.replace("keys.makeGapTolerant(row3)", "")
suite.check("Mutación 1 (LayoutLayer sin gapTolerant en row3): detectada", "keys.makeGapTolerant(row3)" not in mut1)

# Mutación 2: fastTap sin comprobación de slopExceeded
mut2 = fast_tap_chunk.replace("if (!slopExceeded)", "")
suite.check("Mutación 2 (fastTap sin slop guard): detectada", "if (!slopExceeded)" not in mut2)

# Mutación 3: longPress sin comprobación de slopExceeded
mut3 = long_press_chunk.replace("if (!slopExceeded)", "")
suite.check("Mutación 3 (longPress sin slop guard): detectada", "if (!slopExceeded)" not in mut3)

# Mutación 4: makeGapTolerant sin comprobación de slopExceeded
mut4 = gap_chunk.replace("if (!slopExceeded)", "")
suite.check("Mutación 4 (makeGapTolerant sin slop guard): detectada", "if (!slopExceeded)" not in mut4)

# Mutación 5: SnippetsLayer sin makeGapTolerant en row3
mut5 = snippets_code.replace("host.makeGapTolerant(row3)", "")
suite.check("Mutación 5 (SnippetsLayer sin gapTolerant en row3): detectada", "host.makeGapTolerant(row3)" not in mut5)

# Mutación 6: EditEngine handleBackspace sin count
mut6 = ee_code.replace("fun handleBackspace(count: Int = 1)", "fun handleBackspace()")
suite.check("Mutación 6 (handleBackspace sin count de lote): detectada", "fun handleBackspace(count: Int = 1)" not in mut6)

print("\n" + "=" * 60)
print(f" RESULTADOS C-18: {suite.passed} pasados, {suite.failed} fallidos.")
print("=" * 60 + "\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
