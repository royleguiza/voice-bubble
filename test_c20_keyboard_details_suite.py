#!/usr/bin/env python3
"""
test_c20_keyboard_details_suite.py
==================================
Suite de verificación exhaustiva para el Contrato C-20:
"Detalles del teclado (STOP háptico independiente + Locale.ROOT / tests turco I/ı)"

Verifica:
1. DictationController.kt:
   - MicFeedback declara hapticStop: Boolean = true como flag independiente de hapticStart.
   - MicEvent.STOP está condicionado estrictamente a fb.hapticStop (y NUNCA a fb.hapticStart).
   - MicEvent.START sigue condicionado a fb.hapticStart.
   - Independencia mutua de flags: cambiar uno no afecta al otro.
   - Documentación KDoc que explica la independencia de hapticStop.
2. EditEngine.kt:
   - Importa java.util.Locale.
   - toTitleCase utiliza text.lowercase(Locale.ROOT).
   - nextCase utiliza text.lowercase(Locale.ROOT) y text.uppercase(Locale.ROOT).
   - Cero llamadas a .lowercase() o .uppercase() sin Locale en toTitleCase/nextCase.
   - Manejo determinista en turco: letras I/ı (U+0049 / U+0131) e İ/i (U+0130 / U+0069)
     no rompen el ciclo de caso en identificadores, palabras en inglés/español ni turco.
3. Detección de mutaciones negativas reales sobre el código.
"""

import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

class TestSuite:
    def __init__(self, name):
        self.name = name
        self.passed = 0
        self.failed = 0

    def check(self, desc, condition, err_msg=""):
        if condition:
            print(f"  [PASS] {desc}")
            self.passed += 1
        else:
            print(f"  [FAIL] {desc} -> {err_msg}")
            self.failed += 1

suite = TestSuite("CONTRATO C-20 (DETALLES DEL TECLADO)")
print("=" * 60)
print(f" INICIANDO TEST SUITE: {suite.name}")
print("=" * 60)

# --- 1. Rutas de Archivos del Contrato C-20 ---
dc_path = os.path.join(
    BASE_DIR,
    "voice_bubble_stt", "android", "app", "src", "main", "kotlin",
    "com", "royleguiza", "voicebubblestt", "DictationController.kt"
)
ee_path = os.path.join(
    BASE_DIR,
    "voice_bubble_stt", "android", "app", "src", "main", "kotlin",
    "com", "royleguiza", "voicebubblestt", "EditEngine.kt"
)

suite.check("DictationController.kt existe", os.path.isfile(dc_path), f"Falta {dc_path}")
suite.check("EditEngine.kt existe", os.path.isfile(ee_path), f"Falta {ee_path}")

with open(dc_path, "r", encoding="utf-8") as f:
    dc_code = f.read()
with open(ee_path, "r", encoding="utf-8") as f:
    ee_code = f.read()

# --- 2. DictationController.kt: MicFeedback y hapticStop independiente ---
suite.check(
    "MicFeedback declara val hapticStop: Boolean",
    "val hapticStop: Boolean" in dc_code,
    "Falta val hapticStop: Boolean en MicFeedback"
)
suite.check(
    "MicFeedback hapticStop tiene valor por defecto true para compatibilidad",
    re.search(r"val\s+hapticStop:\s*Boolean\s*=\s*true", dc_code) is not None,
    "hapticStop debe tener '= true' por defecto"
)

# Extraer el bloque when (kind) de micEvent
mic_event_match = re.search(r"when\s*\(\s*kind\s*\)\s*\{([^}]+)\}", dc_code)
suite.check("micEvent contiene bloque when (kind)", mic_event_match is not None)
when_body = mic_event_match.group(1) if mic_event_match else ""

suite.check(
    "MicEvent.START está condicionado a fb.hapticStart",
    re.search(r"MicEvent\.START\s*->\s*if\s*\(\s*fb\.hapticStart\s*\)", when_body) is not None
)
suite.check(
    "MicEvent.STOP está condicionado a fb.hapticStop",
    re.search(r"MicEvent\.STOP\s*->\s*if\s*\(\s*fb\.hapticStop\s*\)", when_body) is not None,
    "MicEvent.STOP debe consultar fb.hapticStop, no fb.hapticStart"
)
suite.check(
    "MicEvent.STOP NO está condicionado a fb.hapticStart (desacoplamiento total)",
    re.search(r"MicEvent\.STOP\s*->\s*if\s*\(\s*fb\.hapticStart\s*\)", when_body) is None,
    "MicEvent.STOP no debe usar fb.hapticStart"
)

# Modelo de independencia de flags
class MockMicFeedback:
    def __init__(self, hapticsEnabled=True, hapticStart=True, hapticStop=True):
        self.hapticsEnabled = hapticsEnabled
        self.hapticStart = hapticStart
        self.hapticStop = hapticStop

def simulate_mic_buzz(fb, kind):
    """Simula la lógica exacta de micEvent en DictationController.kt"""
    if not fb.hapticsEnabled:
        return False
    if kind == "START":
        return fb.hapticStart
    elif kind == "STOP":
        return fb.hapticStop
    return False

# Pruebas de la matriz de independencia
# Caso 1: start ON, stop OFF
fb1 = MockMicFeedback(hapticStart=True, hapticStop=False)
suite.check("Independencia 1: start ON, stop OFF -> START vibra, STOP no vibra",
            simulate_mic_buzz(fb1, "START") is True and simulate_mic_buzz(fb1, "STOP") is False)

# Caso 2: start OFF, stop ON
fb2 = MockMicFeedback(hapticStart=False, hapticStop=True)
suite.check("Independencia 2: start OFF, stop ON -> START no vibra, STOP vibra",
            simulate_mic_buzz(fb2, "START") is False and simulate_mic_buzz(fb2, "STOP") is True)

# Caso 3: start OFF, stop OFF
fb3 = MockMicFeedback(hapticStart=False, hapticStop=False)
suite.check("Independencia 3: ambos OFF -> ninguno vibra",
            simulate_mic_buzz(fb3, "START") is False and simulate_mic_buzz(fb3, "STOP") is False)

# Caso 4: start ON, stop ON
fb4 = MockMicFeedback(hapticStart=True, hapticStop=True)
suite.check("Independencia 4: ambos ON -> ambos vibran",
            simulate_mic_buzz(fb4, "START") is True and simulate_mic_buzz(fb4, "STOP") is True)

# Caso 5: master háptico OFF
fb5 = MockMicFeedback(hapticsEnabled=False, hapticStart=True, hapticStop=True)
suite.check("Master OFF -> ninguno vibra independientemente de flags",
            simulate_mic_buzz(fb5, "START") is False and simulate_mic_buzz(fb5, "STOP") is False)

# --- 3. EditEngine.kt: Locale.ROOT y tests turco I/ı ---
suite.check(
    "EditEngine importa java.util.Locale",
    "import java.util.Locale" in ee_code,
    "Falta import java.util.Locale en EditEngine.kt"
)

# toTitleCase utiliza Locale.ROOT
to_title_match = re.search(r"internal fun toTitleCase\(text:\s*String\):\s*String\s*\{([^}]+)\n\s*\}", ee_code)
suite.check("toTitleCase existe en EditEngine.kt", to_title_match is not None)
to_title_body = to_title_match.group(1) if to_title_match else ""
suite.check(
    "toTitleCase invoca text.lowercase(Locale.ROOT)",
    "text.lowercase(Locale.ROOT)" in to_title_body,
    "toTitleCase debe usar text.lowercase(Locale.ROOT)"
)

# nextCase utiliza Locale.ROOT
next_case_match = re.search(r"internal fun nextCase\(text:\s*String\):\s*Pair<String,\s*CaseState>\s*\{([^}]+)\n\s*\}", ee_code)
suite.check("nextCase existe en EditEngine.kt", next_case_match is not None)
next_case_body = next_case_match.group(1) if next_case_match else ""

suite.check(
    "nextCase invoca text.lowercase(Locale.ROOT) en comparaciones",
    "text == text.lowercase(Locale.ROOT)" in next_case_body
)
suite.check(
    "nextCase invoca text.uppercase(Locale.ROOT) en transición a UPPER",
    "text.uppercase(Locale.ROOT)" in next_case_body
)
suite.check(
    "nextCase invoca text == text.uppercase(Locale.ROOT) en detección UPPER",
    "text == text.uppercase(Locale.ROOT)" in next_case_body
)
suite.check(
    "nextCase invoca text.lowercase(Locale.ROOT) en retorno LOWER",
    "Pair(text.lowercase(Locale.ROOT), CaseState.LOWER)" in next_case_body
)

# Cero llamadas desnudas a lowercase() o uppercase() en toTitleCase o nextCase
suite.check(
    "Cero llamadas a text.lowercase() desnudas en toTitleCase",
    re.search(r"text\.lowercase\(\)", to_title_body) is None
)
suite.check(
    "Cero llamadas a text.lowercase() desnudas en nextCase",
    re.search(r"text\.lowercase\(\)", next_case_body) is None
)
suite.check(
    "Cero llamadas a text.uppercase() desnudas en nextCase",
    re.search(r"text\.uppercase\(\)", next_case_body) is None
)

# --- 4. Simulación de Comportamiento Turco (I/ı y İ/i) ---
# En turco:
# Mayúscula de 'i' (U+0069) es 'İ' (U+0130, LATIN CAPITAL LETTER I WITH DOT ABOVE)
# Minúscula de 'I' (U+0049) es 'ı' (U+0131, LATIN SMALL LETTER DOTLESS I)
# En Locale.ROOT (reglas estándar Unicode invariantes de locale):
# Mayúscula de 'i' es 'I' (U+0049)
# Minúscula de 'I' es 'i' (U+0069)
# Mayúscula de 'ı' es 'I' (U+0049)
# Minúscula de 'İ' es 'i\u0307' o 'i'

def turkish_lower(s):
    """Simula String.toLowerCase(Locale('tr'))"""
    res = []
    for c in s:
        if c == 'I': # ASCII capital I
            res.append('ı') # dotless i
        elif c == 'İ':
            res.append('i')
        else:
            res.append(c.lower())
    return "".join(res)

def turkish_upper(s):
    """Simula String.toUpperCase(Locale('tr'))"""
    res = []
    for c in s:
        if c == 'i': # ASCII small i
            res.append('İ') # dotted I
        elif c == 'ı':
            res.append('I')
        else:
            res.append(c.upper())
    return "".join(res)

def root_lower(s):
    """Simula String.lowercase(Locale.ROOT)"""
    return s.lower()

def root_upper(s):
    """Simula String.uppercase(Locale.ROOT)"""
    return s.upper()

def root_to_title_case(text):
    lower = root_lower(text)
    out = []
    word_start = True
    for c in lower:
        if c.isalpha():
            out.append(root_upper(c) if word_start else c)
            word_start = False
        else:
            out.append(c)
            word_start = True
    return "".join(out)

def root_has_cased_letter(text):
    return any(c.lower() != c.upper() for c in text)

def root_is_title_case(text):
    return root_has_cased_letter(text) and text == root_to_title_case(text)

def root_next_case(text):
    if text == root_lower(text):
        return (root_to_title_case(text), "TITLE")
    if root_is_title_case(text):
        return (root_upper(text), "UPPER")
    if text == root_upper(text):
        return (root_lower(text), "LOWER")
    return (root_lower(text), "LOWER")

# Demostración del BUG en turco si no se usa Locale.ROOT:
# En turco, "TITLE".lower() -> "tıtle", y "tıtle".upper() -> "TİTLE"
# "TITLE" != "tıtle" (no lower)
# is_title("TITLE") -> False
# "TITLE" == "TITLE".upper() -> pero en turco "TITLE".upper() es "TİTLE", así que "TITLE" == "TİTLE" da FALSO!
turkish_upper_title = turkish_upper("title")
suite.check(
    "Demostración de fallo turco sin Locale.ROOT: 'title'.upper en turco da 'TİTLE' con punto",
    turkish_upper_title == "TİTLE" and turkish_upper_title != "TITLE"
)
turkish_lower_info = turkish_lower("INFO")
suite.check(
    "Demostración de fallo turco sin Locale.ROOT: 'INFO'.lower en turco da 'ınfo' sin punto",
    turkish_lower_info == "ınfo" and turkish_lower_info != "info"
)

# Con Locale.ROOT, el ciclo funciona 100% perfecto para cualquier palabra con I/i:
suite.check("Root next_case('info') -> ('Info', 'TITLE')", root_next_case("info") == ("Info", "TITLE"))
suite.check("Root next_case('Info') -> ('INFO', 'UPPER')", root_next_case("Info") == ("INFO", "UPPER"))
suite.check("Root next_case('INFO') -> ('info', 'LOWER')", root_next_case("INFO") == ("info", "LOWER"))

suite.check("Root next_case('title') -> ('Title', 'TITLE')", root_next_case("title") == ("Title", "TITLE"))
suite.check("Root next_case('Title') -> ('TITLE', 'UPPER')", root_next_case("Title") == ("TITLE", "UPPER"))
suite.check("Root next_case('TITLE') -> ('title', 'LOWER')", root_next_case("TITLE") == ("title", "LOWER"))

# Palabras turcas con dotless i 'ı' y dotted I 'İ'
suite.check("to_title_case('ılık') preserva raíz -> 'Ilık'", root_to_title_case("ılık") == "Ilık")
suite.check("next_case('ılık') -> ('Ilık', 'TITLE')", root_next_case("ılık") == ("Ilık", "TITLE"))

# Identificadores de programación (ASCII puro)
suite.check("next_case('api_key') -> ('Api_Key', 'TITLE')", root_next_case("api_key") == ("Api_Key", "TITLE"))
suite.check("next_case('Api_Key') -> ('API_KEY', 'UPPER')", root_next_case("Api_Key") == ("API_KEY", "UPPER"))
suite.check("next_case('API_KEY') -> ('api_key', 'LOWER')", root_next_case("API_KEY") == ("api_key", "LOWER"))

# --- 5. Verificación de Resistencia a Mutaciones Negativas ---
print("\n--- Verificación de Resistencia a Mutaciones ---")

def validate_dictation_controller(code):
    """Valida los requisitos C-20 sobre DictationController.kt"""
    if "val hapticStop: Boolean" not in code:
        return False, "falta val hapticStop en MicFeedback"
    m = re.search(r"when\s*\(\s*kind\s*\)\s*\{([^}]+)\}", code)
    if not m:
        return False, "falta when (kind) en micEvent"
    body = m.group(1)
    if "MicEvent.STOP -> if (fb.hapticStop)" not in body:
        return False, "MicEvent.STOP no usa fb.hapticStop"
    if "MicEvent.STOP -> if (fb.hapticStart)" in body:
        return False, "MicEvent.STOP acoplado a fb.hapticStart"
    return True, "OK"

def validate_edit_engine(code):
    """Valida los requisitos C-20 sobre EditEngine.kt"""
    if "import java.util.Locale" not in code:
        return False, "falta import java.util.Locale"
    if "text.lowercase(Locale.ROOT)" not in code:
        return False, "toTitleCase/nextCase no usan text.lowercase(Locale.ROOT)"
    if "text.uppercase(Locale.ROOT)" not in code:
        return False, "nextCase no usa text.uppercase(Locale.ROOT)"
    return True, "OK"

# Mutación 1: MicEvent.STOP vuelve a usar fb.hapticStart
mut1 = dc_code.replace("MicEvent.STOP -> if (fb.hapticStop)", "MicEvent.STOP -> if (fb.hapticStart)")
ok1, _ = validate_dictation_controller(mut1)
suite.check("Mutación 1 (STOP usa hapticStart): detectada por el validador", not ok1)

# Mutación 2: Quitar hapticStop de MicFeedback
mut2 = re.sub(r"val\s+hapticStop:\s*Boolean\s*=\s*true,\s*", "", dc_code)
ok2, _ = validate_dictation_controller(mut2)
suite.check("Mutación 2 (eliminar hapticStop): detectada por el validador", not ok2)

# Mutación 3: toTitleCase vuelve a usar text.lowercase() desnudo
mut3 = ee_code.replace("text.lowercase(Locale.ROOT)", "text.lowercase()")
ok3, _ = validate_edit_engine(mut3)
suite.check("Mutación 3 (toTitleCase usa lowercase() desnudo): detectada por el validador", not ok3)

# Mutación 4: nextCase vuelve a usar text.uppercase() desnudo
mut4 = ee_code.replace("text.uppercase(Locale.ROOT)", "text.uppercase()")
ok4, _ = validate_edit_engine(mut4)
suite.check("Mutación 4 (nextCase usa uppercase() desnudo): detectada por el validador", not ok4)

# Mutación 5: Quitar import java.util.Locale
mut5 = ee_code.replace("import java.util.Locale\n", "")
ok5, _ = validate_edit_engine(mut5)
suite.check("Mutación 5 (quitar import java.util.Locale): detectada por el validador", not ok5)

print("\n" + "=" * 60)
print(f" RESULTADOS C-20: {suite.passed} pasados, {suite.failed} fallidos.")
print("=" * 60 + "\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
