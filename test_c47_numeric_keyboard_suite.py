#!/usr/bin/env python3
"""
test_c47_numeric_keyboard_suite.py
==================================
Auditoría C-47: teclado numérico inteligente [S]

Diseño acordado con el dueño: calculadora 5x3 + fila inferior de 7
(ABC, coma, !?#, 0, igual, punto, Enter), sin espacio y con el mismo
Enter accent del resto del teclado.

Verifica (estático, sin SDK):
1. Layer.NUMERIC + isNumericInput (NUMBER/PHONE/DATETIME, incluye PIN).
2. Auto en onStartInputView (campo nuevo numérico -> NUMERIC, con
   currentIsNumericField en el early return anti-restart).
3. Filas calculadora: dígitos con fondo principal, operadores con
   secundario, ⌫ con gestos, filas gap-tolerantes.
4. Fila inferior exacta sin espacio y con el mismo Enter.
5. Toggles: tap ?123 intacto, mantener -> numérico, ABC -> letras,
   !?# -> símbolos con retorno al numérico.
6. Saneados: sin terminal en numérico, PIN numérico permitido,
   mini expande, sin Log con contenido.
"""

from test_helpers import install_l10n_reader
install_l10n_reader()

import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
KT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "kotlin", "com", "royleguiza", "voicebubblestt",
)


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


TYPES = os.path.join(KT, "KeyboardTypes.kt")
SUPPORT = os.path.join(KT, "KeyboardSupport.kt")
VKS = os.path.join(KT, "VoiceKeyboardService.kt")
LAYOUT = os.path.join(KT, "LayoutLayer.kt")
KEYS = os.path.join(KT, "KeyFactory.kt")


class TestC47NumericKeyboardSuite(unittest.TestCase):

    def test_01_layer_numeric(self):
        src = read_file(TYPES)
        self.assertIn("NUMERIC", src)
        self.assertIn("enum class Layer", src)

    def test_02_is_numeric_input(self):
        src = read_file(SUPPORT)
        self.assertIn("fun isNumericInput(", src)
        self.assertIn("TYPE_CLASS_NUMBER", src)
        self.assertIn("TYPE_CLASS_PHONE", src)
        self.assertIn("TYPE_CLASS_DATETIME", src)

    def test_03_auto_en_on_start(self):
        src = read_file(VKS)
        on_start = src[src.find("override fun onStartInputView"):]
        self.assertIn("isNumericInput(info)", on_start)
        self.assertIn("currentIsNumericField", on_start)
        self.assertIn("isNumeric == currentIsNumericField", on_start)
        self.assertIn("layer = Layer.NUMERIC", on_start)

    def test_04_filas_calculadora(self):
        src = read_file(LAYOUT)
        self.assertIn("fun buildNumericRows()", src)
        rows = src.split("fun buildNumericRows()")[1].split("fun buildNumericBottomRow")[0]
        for group in ('"789"', '"456"', '"123"'):
            self.assertIn(group, rows)
        for op, name in [("-", "menos"), ("+", "más"), ("*", "multiplicaci"),
                         ("%", "porcentaje"), ("/", "divisi")]:
            self.assertIn(f'"{op}"', rows)
        self.assertIn("menos", rows)
        self.assertIn("makeBackspaceKey(weight = NUM_EDGE_W)", rows)
        self.assertEqual(rows.count("keys.horizontalRow()"), 3)  # T5: KeyRow sin huecos
        # Dígitos fondo principal, operadores secundario.
        self.assertIn("makeSymbolKey(c.toString(), textSizePx = numText, weight = NUM_DIGIT_W)", rows)
        self.assertIn("makeAltSymbolKey(", rows)

    def test_05_fila_inferior_propuesta_a(self):
        """T8 (K4): ABC · coma · 0 · punto · Enter; !?# e = en pulsaciones largas."""
        src = read_file(LAYOUT)
        self.assertIn("fun buildNumericBottomRow()", src)
        bottom = src.split("fun buildNumericBottomRow()")[1].split("fun buildBottomBar")[0]
        order = ['"ABC"', '","', '"0"', '"."', "R.drawable.ic_enter"]
        idx = [bottom.index(label) for label in order]
        self.assertEqual(idx, sorted(idx))
        # !?# en la pulsación larga de ABC (con pista visible), sin tecla propia.
        self.assertIn("onLongPress = { host.pressSymbolsFromNumeric() }", bottom)
        self.assertIn('withCornerHint("ABC", "!?#")', bottom)
        self.assertNotIn('makeAltSymbolKey("="', bottom)
        # «=» en la pulsación larga de «+».
        rows = src.split("fun buildNumericRows()")[1].split("fun buildNumericBottomRow")[0]
        self.assertIn('longPressText = "="', rows)
        self.assertIn("R.drawable.kb_key_accent", bottom)
        self.assertIn("host.pressEnter()", bottom)
        self.assertNotIn("pressSpace", bottom)
        self.assertNotIn("attachSpacebar", bottom)

    def test_05b_simetria_de_pesos(self):
        src = read_file(LAYOUT)
        for const in ("NUM_EDGE_W = 0.85f", "NUM_DIGIT_W = 1.1f"):
            self.assertIn(const, src)
        self.assertNotIn("NUM_PUNCT_W", src)
        self.assertNotIn("NUM_SYM_W", src)
        edge, digit = 0.85, 1.1
        self.assertAlmostEqual(edge + 3 * digit + edge, 5.0)
        bottom = src.split("fun buildNumericBottomRow()")[1].split("fun buildBottomBar")[0]
        rows = src.split("fun buildNumericRows()")[1].split("fun buildNumericBottomRow")[0]
        self.assertIn("makeBackspaceKey(weight = NUM_EDGE_W)", rows)
        # Coma, 0 y punto del ancho de un dígito (≥ 48 dp en 411 dp) y a 22 sp.
        for ch in (",", "0", "."):
            self.assertIn(f'makeSymbolKey("{ch}", textSizePx = numText, weight = NUM_DIGIT_W)', bottom)
        self.assertIn("kb_key_text_size_numeric", bottom)
        dimens = read_file(os.path.join(os.path.dirname(os.path.abspath(__file__)), "voice_bubble_stt/android/app/src/main/res/values/dimens.xml"))
        self.assertIn('<dimen name="kb_key_text_size_numeric">22sp</dimen>', dimens)
        self.assertIn('<dimen name="kb_key_text_size_symbol">18sp</dimen>', dimens)

    def test_06_toggles_bidireccionales(self):
        vks = read_file(VKS)
        lay = read_file(LAYOUT)
        self.assertIn("override fun pressNumericKey()", vks)
        self.assertIn("override fun pressSymbolsFromNumeric()", vks)
        # Tap ?123 intacto + mantener -> numérico en la barra común.
        bar = lay.split("fun buildBottomBar")[1]
        self.assertIn("makeSpecialKeyWithLongPress", bar)
        self.assertIn("host.pressSymbolsKey()", bar)
        self.assertIn("host.pressNumericKey()", bar)
        # ABC del numérico vuelve a letras; !?# va a símbolos.
        bottom = lay.split("fun buildNumericBottomRow()")[1].split("fun buildBottomBar")[0]
        self.assertIn("host.pressSymbolsKey()", bottom)
        self.assertIn("host.pressSymbolsFromNumeric()", bottom)
        # Retorno !?# -> ABC -> numérico.
        self.assertIn("lastLettersLayer == Layer.NUMERIC", vks)
        # Etiqueta ABC en numérico.
        self.assertIn("layer == Layer.NUMERIC -> \"ABC\"", vks)

    def test_07_saneados(self):
        vks = read_file(VKS)
        # Sin terminal en numérico (como en clipboard).
        self.assertIn("layer != Layer.CLIPBOARD && layer != Layer.NUMERIC", vks)
        # PIN numérico permitido: el guard de password no incluye NUMERIC.
        rebuild = vks.split("fun rebuild()")[1].split("fun makeSpecial(")[0]
        self.assertIn("Layer.CLIPBOARD || layer == Layer.SNIPPETS || layer == Layer.TRACKPAD", rebuild)
        self.assertNotIn("Layer.NUMERIC", rebuild.split("currentIsPasswordField")[1].split("root.removeAllViews()")[0])
        # Numérico exige altura completa (sale de mini).
        self.assertIn("override fun pressNumericKey()", vks)
        numeric_fn = vks.split("override fun pressNumericKey()")[1].split("override fun pressSymbolsFromNumeric")[0]
        self.assertIn("setMiniMode(false", numeric_fn)

    def test_08_fabrica_y_hablado(self):
        kf = read_file(KEYS)
        self.assertIn("fun makeSpecialKeyWithLongPress(", kf)
        self.assertIn("fun makeAltSymbolKey(", kf)
        self.assertIn("R.drawable.kb_key_alt", kf)
        self.assertIn("host.commitSymbolKey(label)", kf)
        lay = read_file(LAYOUT)
        # TalkBack: cada operador con nombre + pista del mantener.
        for name in ["letras", "igual", "menos", "mantén para números"]:
            self.assertIn(name, lay)

    def test_09_sin_logs_con_contenido(self):
        for path in (VKS, LAYOUT, KEYS, SUPPORT):
            src = read_file(path)
            self.assertNotIn("Log.d(", src)
            self.assertNotIn("Log.i(", src)


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC47NumericKeyboardSuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
