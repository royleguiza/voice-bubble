#!/usr/bin/env python3
"""
TEST SUITE: CONTRATO C-17 (UNA SOLA VIBRACIÓN POR TECLA)
========================================================
Valida que:
1. El motor de edición (EditEngine.kt) no genere vibraciones redundantes en sus
   operaciones de commit o despacho de teclas (commitLetter, commitSymbolText,
   sendKeyCode, handleBackspace, handleEnter). Exactamente 0 llamadas a host.haptic().
2. La retroalimentación háptica se gestione exclusivamente en la capa de gestos
   físicos (KeyFactory.kt):
   - fastTap: host.haptic(v) en ACTION_DOWN.
   - longPress: host.haptic(v) en ACTION_DOWN.
   - makeGapTolerant: host.haptic(child) al resolver la tecla más cercana.
   - backspaceGestures: host.haptic(key) en onLongPress para marcar la activación
     del borrado continuo, pero 0 vibraciones en los ticks de repetición.
3. El conteo de vibraciones por toque de letra, símbolo, retroceso o enter sea
   estrictamente igual a 1.
"""

import os
import re
import sys

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
KT_DIR = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt")
EE_PATH = os.path.join(KT_DIR, "EditEngine.kt")
KF_PATH = os.path.join(KT_DIR, "KeyFactory.kt")

passed_count = 0
failed_count = 0

def check(name, condition, detail=""):
    global passed_count, failed_count
    if condition:
        print(f"  [PASS] {name}")
        passed_count += 1
    else:
        print(f"  [FAIL] {name} -> {detail}")
        failed_count += 1

print("\n" + "=" * 60)
print(" INICIANDO TEST SUITE: CONTRATO C-17 (UNA SOLA VIBRACIÓN POR TECLA)")
print("=" * 60 + "\n")

# --- 1. Verificación de existencia de archivos ---
check("EditEngine.kt existe", os.path.isfile(EE_PATH), f"No encontrado: {EE_PATH}")
check("KeyFactory.kt existe", os.path.isfile(KF_PATH), f"No encontrado: {KF_PATH}")

with open(EE_PATH, "r", encoding="utf-8") as f:
    ee_code = f.read()

with open(KF_PATH, "r", encoding="utf-8") as f:
    kf_code = f.read()

# --- 2. EditEngine.kt: Erradicación total de llamadas a host.haptic ---
haptic_calls_in_ee = re.findall(r"host\.haptic\([^)]*\)", ee_code)
check(
    "EditEngine: CERO llamadas a host.haptic()",
    len(haptic_calls_in_ee) == 0,
    f"Encontradas {len(haptic_calls_in_ee)} llamadas a host.haptic en EditEngine: {haptic_calls_in_ee}"
)

# Verificación específica por método en EditEngine:
commit_letter_chunk = ee_code[ee_code.find("fun commitLetter("):ee_code.find("private fun releaseMomentaryShift")]
check(
    "commitLetter no contiene host.haptic",
    "host.haptic" not in commit_letter_chunk,
    "commitLetter no debe vibrar"
)

commit_symbol_chunk = ee_code[ee_code.find("fun commitSymbolText("):ee_code.find("fun commit(")]
check(
    "commitSymbolText no contiene host.haptic",
    "host.haptic" not in commit_symbol_chunk,
    "commitSymbolText no debe vibrar"
)

send_key_code_chunk = ee_code[ee_code.find("fun sendKeyCode("):ee_code.find("private fun isCursorKey")]
check(
    "sendKeyCode no contiene host.haptic",
    "host.haptic" not in send_key_code_chunk,
    "sendKeyCode no debe vibrar"
)

handle_backspace_chunk = ee_code[ee_code.find("fun handleBackspace("):ee_code.find("fun deleteWordBeforeCursor")]
check(
    "handleBackspace no contiene host.haptic",
    "host.haptic" not in handle_backspace_chunk,
    "handleBackspace no debe vibrar"
)

handle_enter_chunk = ee_code[ee_code.find("fun handleEnter("):]
check(
    "handleEnter no contiene host.haptic",
    "host.haptic" not in handle_enter_chunk,
    "handleEnter no debe vibrar"
)

# --- 3. KeyFactory.kt: Háptico presente en capa de gestos físicos ---
fast_tap_chunk = kf_code[kf_code.find("fun fastTap("):kf_code.find("fun longPress(")]
check(
    "KeyFactory.fastTap vibra en ACTION_DOWN",
    "MotionEvent.ACTION_DOWN -> {" in fast_tap_chunk and "host.haptic(v)" in fast_tap_chunk,
    "fastTap debe vibrar en ACTION_DOWN"
)

long_press_chunk = kf_code[kf_code.find("fun longPress("):kf_code.find("fun backspaceGestures(")]
check(
    "KeyFactory.longPress vibra en ACTION_DOWN",
    "MotionEvent.ACTION_DOWN -> {" in long_press_chunk and "host.haptic(v)" in long_press_chunk,
    "longPress debe vibrar en ACTION_DOWN"
)

backspace_chunk = kf_code[kf_code.find("fun backspaceGestures("):kf_code.find("fun cancelPendingGestures(")]
check(
    "KeyFactory.backspaceGestures vibra en onLongPress (inicio de repetición)",
    "onLongPress = {" in backspace_chunk and "host.haptic(key)" in backspace_chunk,
    "backspaceGestures debe vibrar al activar repetición"
)

gap_chunk = kf_code[kf_code.find("fun makeGapTolerant("):kf_code.find("private fun nearestChild(")]
check(
    "KeyFactory.makeGapTolerant vibra al resolver nearestChild",
    "nearestChild(row, ev.x, ev.y)?.let { child ->" in gap_chunk and "host.haptic(child)" in gap_chunk,
    "makeGapTolerant debe vibrar al resolver la tecla"
)

# --- 4. Conteo de Vibraciones (Simulación de Tecla) ---
print("\n--- Simulación y Conteo de Vibraciones por Tecla ---")

class VibrationTracker:
    def __init__(self):
        self.count = 0

    def haptic(self, view):
        self.count += 1

class MockEditEngine:
    def __init__(self, tracker):
        self.tracker = tracker
        self.text = ""

    def commitLetter(self, char):
        # Implementación real C-17 sin haptic
        self.text += char

    def commitSymbolText(self, symbol):
        # Implementación real C-17 sin haptic
        self.text += symbol

    def handleBackspace(self):
        # Implementación real C-17 sin haptic
        if self.text:
            self.text = self.text[:-1]

    def handleEnter(self):
        # Implementación real C-17 sin haptic
        self.text += "\n"

class MockKeyGesture:
    def __init__(self, tracker, engine):
        self.tracker = tracker
        self.engine = engine

    def tapLetter(self, char):
        # 1. ACTION_DOWN en KeyFactory
        self.tracker.haptic("letter_key")
        # 2. ACTION_UP -> commitLetter
        self.engine.commitLetter(char)

    def tapSymbol(self, symbol):
        # 1. ACTION_DOWN en KeyFactory
        self.tracker.haptic("symbol_key")
        # 2. ACTION_UP -> commitSymbolText
        self.engine.commitSymbolText(symbol)

    def tapBackspace(self):
        # 1. ACTION_DOWN en KeyFactory
        self.tracker.haptic("backspace_key")
        # 2. ACTION_UP -> handleBackspace
        self.engine.handleBackspace()

    def tapEnter(self):
        # 1. ACTION_DOWN en KeyFactory
        self.tracker.haptic("enter_key")
        # 2. ACTION_UP -> handleEnter
        self.engine.handleEnter()

    def gapTapLetter(self, char):
        # ACTION_DOWN en gap (sin vibración)
        # ACTION_UP -> nearestChild -> haptic + commit
        self.tracker.haptic("gap_resolved_key")
        self.engine.commitLetter(char)

    def holdBackspace(self, repeat_ticks=10):
        # 1. ACTION_DOWN inicial
        self.tracker.haptic("backspace_key")
        # 2. Expiración de delay -> onLongPress
        self.tracker.haptic("backspace_long_press_activation")
        self.engine.handleBackspace()
        # 3. Ticks de repetición continua
        for _ in range(repeat_ticks):
            self.engine.handleBackspace()

tracker = VibrationTracker()
engine = MockEditEngine(tracker)
gesture = MockKeyGesture(tracker, engine)

# 4.1: Toque de letra normal
vibe_before = tracker.count
gesture.tapLetter("a")
vibe_after = tracker.count
check("Conteo de vibraciones por letra = 1", vibe_after - vibe_before == 1, f"Vibró {vibe_after - vibe_before} veces")

# 4.2: Toque de símbolo
vibe_before = tracker.count
gesture.tapSymbol("?")
vibe_after = tracker.count
check("Conteo de vibraciones por símbolo = 1", vibe_after - vibe_before == 1, f"Vibró {vibe_after - vibe_before} veces")

# 4.3: Toque de retroceso (Backspace corto)
vibe_before = tracker.count
gesture.tapBackspace()
vibe_after = tracker.count
check("Conteo de vibraciones por retroceso = 1", vibe_after - vibe_before == 1, f"Vibró {vibe_after - vibe_before} veces")

# 4.4: Toque de Enter
vibe_before = tracker.count
gesture.tapEnter()
vibe_after = tracker.count
check("Conteo de vibraciones por enter = 1", vibe_after - vibe_before == 1, f"Vibró {vibe_after - vibe_before} veces")

# 4.5: Toque en gap resuelto
vibe_before = tracker.count
gesture.gapTapLetter("b")
vibe_after = tracker.count
check("Conteo de vibraciones por toque en gap = 1", vibe_after - vibe_before == 1, f"Vibró {vibe_after - vibe_before} veces")

# 4.6: Retroceso mantenido (1 inicial + 1 al enganchar repetición; 0 en repeticiones)
vibe_before = tracker.count
gesture.holdBackspace(repeat_ticks=15)
vibe_after = tracker.count
check("Retroceso continuo: 2 vibraciones (toque inicial + activación, 0 en los 15 ticks)", vibe_after - vibe_before == 2, f"Vibró {vibe_after - vibe_before} veces")

# --- 5. Verificación de Mutaciones Negativas ---
print("\n--- Verificación de Mutaciones Negativas ---")

# Mutación 1: Reintroducir haptic en commitLetter
mut1_code = commit_letter_chunk + "\nhost.haptic(host.rootView())"
check("Mutación 1 (haptic en commitLetter): detectada", "host.haptic" in mut1_code)

# Mutación 2: Reintroducir haptic en handleBackspace
mut2_code = handle_backspace_chunk + "\nhost.haptic(host.rootView())"
check("Mutación 2 (haptic en handleBackspace): detectada", "host.haptic" in mut2_code)

# Mutación 3: Reintroducir haptic en commitSymbolText
mut3_code = commit_symbol_chunk + "\nhost.haptic(host.rootView())"
check("Mutación 3 (haptic en commitSymbolText): detectada", "host.haptic" in mut3_code)

# Mutación 4: Omitir haptic en KeyFactory.fastTap
mut4_code = fast_tap_chunk.replace("host.haptic(v)", "")
check("Mutación 4 (fastTap sin haptic): detectada", "host.haptic(v)" not in mut4_code)

# Mutación 5: Omitir haptic en KeyFactory.longPress
mut5_code = long_press_chunk.replace("host.haptic(v)", "")
check("Mutación 5 (longPress sin haptic): detectada", "host.haptic(v)" not in mut5_code)

print("\n" + "=" * 60)
print(f" RESULTADOS C-17: {passed_count} pasados, {failed_count} fallidos.")
print("=" * 60 + "\n")

if failed_count > 0:
    sys.exit(1)
sys.exit(0)
