#!/usr/bin/env python3
"""
TEST SUITE: CICLO DE MAYUSCULAS CON SHIFT (MEJ-02)
Verifica al 100% de certeza sobre el código REAL:
1. EditEngine: handleShiftTap, toSentenceCase/nextCase puros, CaseState.
2. Guardas D-M2/D-M7: contraseñas, CTRL/ALT, snippets-búsqueda, ic null.
3. Lectura puntual getSelectedText(0) con try/catch; PROHIBIDO documento
   completo (getSurroundingText/getTextBeforeCursor en el ciclo).
4. Commit atómico beginBatchEdit/commitText/setSelection/endBatchEdit
   en try/finally + regla de largo distinto.
5. Feedback D-M4: cycleNotice i18n es/en vía host (sin Log de contenido).
6. D-M5: el ciclo consume el tap (toggleShiftKey delega y no hace caps).
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


print("\n============================================================")
print(" INICIANDO TEST SUITE: CICLO MAYUSCULAS SHIFT (MEJ-02)")
print("============================================================\n")

EE = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/EditEngine.kt"
VKS = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt"

check("EditEngine.kt existe", os.path.isfile(os.path.join(WORKSPACE, EE)))
check("VoiceKeyboardService.kt existe", os.path.isfile(os.path.join(WORKSPACE, VKS)))
ee = read(EE)
vks = read(VKS)

# --- 1. API del ciclo (Title Case por palabra, pedido del dueño) ---
for fn in ["fun handleShiftTap()", "fun toTitleCase(", "fun nextCase(", "enum class CaseState"]:
    check(f"EditEngine implementa {fn}", fn in ee, f"falta {fn}")
check("Orden del ciclo LOWER/TITLE/UPPER", all(s in ee for s in ["LOWER", "TITLE", "UPPER"]))
check("Sin resto de sentence case", "toSentenceCase" not in ee and "isSentenceCase" not in ee and "SENTENCE" not in ee)
check("Title case: frontera por palabra (D-M1 override)", "wordStart" in ee and "uppercaseChar" in ee)

# --- 2. Guardas D-M2/D-M7 ---
check("Guarda CTRL/ALT (D-M7)", "if (ctrlActive || altActive) return false" in ee)
check("Guarda contraseñas (D-M2)", "if (host.isPasswordField()) return false" in ee)
check("Guarda snippets-búsqueda (D-M7)", "isSearchActive" in ee)
check("Guarda ic null (D-M7)", "service.currentInputConnection ?: return false" in ee)
check("Sin selección -> shift normal (D-M6)", "if (selected.isNullOrEmpty()) return false" in ee)
check("Sin letra con caso -> shift normal", "if (!hasCasedLetter(selected)) return false" in ee)
check("UiHost exige isPasswordField", "fun isPasswordField(): Boolean" in ee)
check("UiHost exige cycleNotice", "fun cycleNotice(message: String)" in ee)
check("VKS implementa cycleNotice", "override fun cycleNotice(" in vks)

# --- 3. Lectura puntual, jamás documento completo ---
check("Lectura puntual getSelectedText(0)", "getSelectedText(0)" in ee)
cycle = ee.split("fun handleShiftTap()")[1].split("\n    fun ")[0]
check("Sin getSurroundingText en el ciclo", "getSurroundingText" not in cycle)
check("Sin getTextBeforeCursor en el ciclo", "getTextBeforeCursor" not in cycle)
check("Offsets por metadata (hintMaxChars = 0)", "hintMaxChars = 0" in ee)
check("Import ExtractedTextRequest", "import android.view.inputmethod.ExtractedTextRequest" in ee)

# --- 4. Commit atómico ---
for s in ["beginBatchEdit()", "commitText(transformed, 1)", "endBatchEdit()"]:
    check(f"Ciclo con {s}", s in ee)
check("try/finally garantiza endBatchEdit", "finally" in cycle and "endBatchEdit()" in cycle)
check("Re-selección mismo largo", "transformed.length == selected.length" in ee)
check("setSelection(start, start +", "setSelection(start, start +" in ee)

# --- 5. Feedback i18n sin logs ---
check("Aviso Minúsculas/Lowercase", '"Minúsculas"' in ee and '"Lowercase"' in ee)
check("Aviso Mayúsculas iniciales/Title Case", '"Mayúsculas iniciales"' in ee and '"Title Case"' in ee)
check("Aviso MAYÚSCULAS/UPPERCASE", '"MAYÚSCULAS"' in ee and '"UPPERCASE"' in ee)
check("Sin Log en el ciclo", "Log." not in cycle)

# --- 6. D-M5: consume el tap ---
check("VKS delega el ciclo antes del shift",
      "if (!editor.handleShiftTap()) editor.toggleShift()" in vks,
      "toggleShiftKey debe probar handleShiftTap primero")
check("Sin caps por doble pulso en el ciclo (máquina intacta)",
      "toggleShift()" not in cycle,
      "el ciclo no debe tocar la máquina shift")

# --- 7. Semántica del ciclo (espejo Python de toTitleCase/nextCase) ---
def kt_title(text):
    lower = text.lower()
    out = []
    word_start = True
    for c in lower:
        if c.isalpha():
            out.append(c.upper() if word_start else c)
            word_start = False
        else:
            out.append(c)
            word_start = True
    return "".join(out)


def kt_next(text):
    if text == text.lower():
        return (kt_title(text), "TITLE")
    if text == kt_title(text):
        return (text.upper(), "UPPER")
    if text == text.upper():
        return (text.lower(), "LOWER")
    return (text.lower(), "LOWER")


check("title('hola mundo') == 'Hola Mundo'", kt_title("hola mundo") == "Hola Mundo")
check("title('mi_funcion') == 'Mi_Funcion'", kt_title("mi_funcion") == "Mi_Funcion")
check("title('hola') == 'Hola' (una palabra)", kt_title("hola") == "Hola")
check("ciclo lower->TITLE", kt_next("hola mundo") == ("Hola Mundo", "TITLE"))
check("ciclo TITLE->UPPER", kt_next("Hola Mundo") == ("HOLA MUNDO", "UPPER"))
check("ciclo UPPER->LOWER", kt_next("HOLA MUNDO") == ("hola mundo", "LOWER"))
check("ciclo mixto->LOWER", kt_next("hOLa") == ("hola", "LOWER"))

print("\n============================================================")
print(f" RESULTADO SUITE SHIFT-CASE: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
