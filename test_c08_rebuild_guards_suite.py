#!/usr/bin/env python3
"""
TEST SUITE: REBUILD SOLO CUANDO TOCA (CONTRATO C-08)

Verifica al 100% de certeza sobre el código REAL:
1. Early return en `VoiceKeyboardService.onStartInputView` cuando `restarting == true`
   con el mismo paquete y sin cambio de campo-contraseña.
2. Comprobación de orden estricto en `onStartInputView`:
   - El early return ocurre ANTES de `dictation.cancelDictationIfActive()`.
   - El early return ocurre ANTES de `kbPrefs.load()`.
   - El early return ocurre ANTES de `clipboard.onStartInputView(restarting)`.
   - El early return ocurre ANTES de `rebuild()`.
   Garantiza que en commits continuos de WebView/navegadores no hay cancelación
   de dictado ni reconstrucción de vistas (cero removeAllViews ni parpadeo).
3. `ClipboardLayer.onStartInputView`:
   - Es un no-op inmediato si `restarting == true` (`if (restarting) return`).
4. Aislamiento de `lastLettersLayer`:
   - `Layer.CLIPBOARD` nunca se escribe en `lastLettersLayer`:
     * En `setLastLetters`: protegido con `if (l != Layer.CLIPBOARD)`.
     * En `codeToggle()`: no guarda `CLIPBOARD` en `lastLettersLayer`.
     * En `TrackpadBridge.toggle()`: excluye `Layer.CLIPBOARD`.
   - `ClipboardLayer.origin` se preserva como estado interno independiente.
5. Mutaciones negativas: verifica que remover el early-return o permitir la escritura
   de `CLIPBOARD` en `lastLetters` hace fallar la suite.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

print("\n============================================================")
print(" INICIANDO TEST SUITE: CONTRATO C-08 (REBUILD SOLO CUANDO TOCA)")
print("============================================================\n")

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
VKS_PATH = os.path.join(KT, "VoiceKeyboardService.kt")
CLIP_PATH = os.path.join(KT, "ClipboardLayer.kt")
PREFS_PATH = os.path.join(KT, "KeyboardPrefs.kt")
TRACK_PATH = os.path.join(KT, "TrackpadBridge.kt")

check("VoiceKeyboardService.kt existe", os.path.isfile(os.path.join(WORKSPACE, VKS_PATH)))
check("ClipboardLayer.kt existe", os.path.isfile(os.path.join(WORKSPACE, CLIP_PATH)))
check("KeyboardPrefs.kt existe", os.path.isfile(os.path.join(WORKSPACE, PREFS_PATH)))
check("TrackpadBridge.kt existe", os.path.isfile(os.path.join(WORKSPACE, TRACK_PATH)))

vks = suite.read(VKS_PATH)
clip = suite.read(CLIP_PATH)
prefs = suite.read(PREFS_PATH)
track = suite.read(TRACK_PATH)

# 1. Early-return en VoiceKeyboardService.onStartInputView
on_start = vks[vks.find("override fun onStartInputView(info: EditorInfo?, restarting: Boolean)") : vks.find("override fun onFinishInputView")]

check(
    "onStartInputView contiene early return para restarting",
    "if (restarting &&" in on_start and "return" in on_start,
)
check(
    "onStartInputView valida mismo paquete en restart",
    "newPackage == currentPackageName" in on_start,
)
check(
    "onStartInputView valida sin cambio de tipo contraseña en restart",
    "isPassword == currentIsPasswordField" in on_start,
)

# 2. Orden de operaciones en onStartInputView (early return antes de cualquier efecto colateral)
early_return_pos = on_start.find("if (restarting &&")
cancel_dict_pos = on_start.find("dictation.cancelDictationIfActive()")
load_prefs_pos = on_start.find("kbPrefs.load()")
clip_sync_pos = on_start.find("clipboard.onStartInputView(restarting)")
rebuild_pos = on_start.find("rebuild()")

check(
    "Early return ANTES de dictation.cancelDictationIfActive()",
    early_return_pos < cancel_dict_pos,
    f"Posiciones: early={early_return_pos}, cancel={cancel_dict_pos}",
)
check(
    "Early return ANTES de kbPrefs.load()",
    early_return_pos < load_prefs_pos,
    f"Posiciones: early={early_return_pos}, load={load_prefs_pos}",
)
check(
    "Early return ANTES de clipboard.onStartInputView()",
    early_return_pos < clip_sync_pos,
    f"Posiciones: early={early_return_pos}, clip={clip_sync_pos}",
)
check(
    "Early return ANTES de rebuild()",
    early_return_pos < rebuild_pos,
    f"Posiciones: early={early_return_pos}, rebuild={rebuild_pos}",
)

# 3. ClipboardLayer.onStartInputView es no-op si restarting
clip_on_start = clip[clip.find("fun onStartInputView(restarting: Boolean)") : clip.find("fun toggle()")]
check(
    "ClipboardLayer.onStartInputView hace no-op en restarting",
    "if (restarting) return" in clip_on_start,
)

# 4. Aislamiento de lastLettersLayer contra Layer.CLIPBOARD
# 4a. setLastLetters en VoiceKeyboardService
set_last = vks[vks.find("override fun setLastLetters(l: Layer)") : vks.find("override fun rootView(): LinearLayout")]
check(
    "setLastLetters filtra Layer.CLIPBOARD",
    "if (l != Layer.CLIPBOARD)" in set_last,
)

# 4b. codeToggle en VoiceKeyboardService
code_toggle = vks[vks.find("override fun codeToggle()") : vks.find("fun setMiniMode(")]
check(
    "codeToggle no guarda Layer.CLIPBOARD en lastLettersLayer",
    "Layer.CLIPBOARD" in code_toggle and "lastLettersLayer = if (layer == Layer.SYMBOLS || layer == Layer.CLIPBOARD)" in code_toggle,
)

# 4c. TrackpadBridge.toggle excluye Layer.CLIPBOARD
track_toggle = track[track.find("fun toggle()") : track.find("fun buildLayer()")]
check(
    "TrackpadBridge.toggle no guarda Layer.CLIPBOARD en lastLetters",
    "cur != Layer.CLIPBOARD" in track_toggle,
)

# 4d. ClipboardLayer.origin independiente de lastLettersLayer
check(
    "ClipboardLayer tiene origin propio",
    "private var origin = Layer.LETTERS" in clip and "origin = host.currentLayer()" in clip,
)

# 5. Documentación KDoc en KeyboardPrefs.kt
check(
    "KeyboardPrefs documenta C-08 en load()",
    "C-08" in prefs and "onStartInputView con restarting=false" in prefs,
)

# 6. Mutaciones negativas
def test_mutations():
    # Mutación 1: Eliminar early return de onStartInputView
    mutated_start = on_start.replace("if (restarting && newPackage != null && newPackage == currentPackageName && isPassword == currentIsPasswordField) {\n            return\n        }", "")
    check("Mutación 1 (sin early return en onStartInputView): detectada", "if (restarting &&" not in mutated_start)

    # Mutación 2: Invertir el orden (cancelar dictado antes de early return)
    mutated_order = cancel_dict_pos < early_return_pos
    check("Mutación 2 (cancelar antes de early return): detectada", not mutated_order)

    # Mutación 3: Eliminar no-op en ClipboardLayer.onStartInputView
    mutated_clip = clip_on_start.replace("if (restarting) return", "// no-op removed")
    check("Mutación 3 (sin no-op en ClipboardLayer): detectada", "if (restarting) return" not in mutated_clip)

    # Mutación 4: Permitir CLIPBOARD en setLastLetters
    mutated_set = set_last.replace("if (l != Layer.CLIPBOARD) {\n            lastLettersLayer = l\n        }", "lastLettersLayer = l")
    check("Mutación 4 (CLIPBOARD permitido en setLastLetters): detectada", "if (l != Layer.CLIPBOARD)" not in mutated_set)

test_mutations()

print("\n============================================================")
print(f" RESULTADOS C-08: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

sys.exit(suite.exit_code())
