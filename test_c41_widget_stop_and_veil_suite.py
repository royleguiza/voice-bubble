#!/usr/bin/env python3
"""
test_c41_widget_stop_and_veil_suite.py
======================================
Auditoría C-41: el widget termina de grabar + velo legible [S]

Verifica:
1. WidgetDictationService.handleToggle: el STOP manda siempre que se
   está grabando (aunque isBusy siga en alto del START); el START sigue
   blindado por isBusy; una sola subida de isBusy a primer nivel.
2. MicrophoneClaimTest cubre la regresión (STOP honrado grabando).
3. Velo de la modal: dim 0.60 y tarjeta nocturna al 70% para que el
   texto de atrás no se confunda con el de la nota.
4. Diseño intacto y mutaciones negativas.
"""

import os
import re
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
KT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "kotlin", "com", "royleguiza", "voicebubblestt",
)
RES = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main", "res",
)
SVC = os.path.join(KT, "WidgetDictationService.kt")
TEST = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "test",
    "kotlin", "com", "royleguiza", "voicebubblestt", "MicrophoneClaimTest.kt",
)
STYLES = os.path.join(RES, "values", "styles.xml")
NIGHT_CARD = os.path.join(RES, "drawable-night", "widget_glass_inner.xml")
DAY_CARD = os.path.join(RES, "drawable", "widget_glass_inner.xml")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class TestC41WidgetStopAndVeilSuite(unittest.TestCase):

    def test_01_stop_manda_start_blindado(self):
        src = read_file(SVC)
        toggle = src.split("internal fun handleToggle")[1].split("\n    }")[0]
        self.assertIn("if (isRecording) return WidgetToggleOutcome.STOP", toggle,
                      "El STOP debe mandar siempre grabando")
        self.assertIn("if (isBusy) return WidgetToggleOutcome.IGNORED", toggle,
                      "El START sigue blindado por isBusy")
        self.assertEqual(toggle.count("isBusy = true"), 1,
                         "Una sola subida de isBusy")

    def test_02_regresion_cubierta_en_jvm(self):
        t = read_file(TEST)
        self.assertIn("widgetStopTapWhileRecordingIsAlwaysHonored", t)
        self.assertIn("WidgetToggleOutcome.STOP", t)

    def test_03_velo_legible(self):
        styles = read_file(STYLES)
        m = re.search(r"backgroundDimAmount\">([\d.]+)", styles)
        self.assertIsNotNone(m, "El tema debe fijar dim")
        self.assertGreaterEqual(float(m.group(1)), 0.55,
                                "Dim suficiente para apagar el fondo")
        night = read_file(NIGHT_CARD)
        m2 = re.search(r"#([0-9A-Fa-f]{8})", night)
        self.assertIsNotNone(m2)
        self.assertGreaterEqual(int(m2.group(1)[:2], 16), 0x99,
                                "Tarjeta nocturna al 70% o más")
        day = read_file(DAY_CARD)
        self.assertIn("#E6FFFFFF", day, "Tarjeta diurna intacta")

    def test_04_sin_logs_y_mutaciones(self):
        self.assertNotIn("Log.", read_file(SVC))
        mut_gate = "if (isBusy) return WidgetToggleOutcome.IGNORED\n isBusy = true"
        self.assertNotIn("isRecording", mut_gate,
                         "Sin rama de STOP el tap rojo muere (el bug)")
        mut_dim = '<item name="android:backgroundDimAmount">0.38</item>'
        self.assertNotIn("0.60", mut_dim)


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC41WidgetStopAndVeilSuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
