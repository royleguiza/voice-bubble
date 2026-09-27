#!/usr/bin/env python3
"""
test_c46_expanding_player_suite.py
==================================
Auditoría C-46: reproductor expandible del pendiente [S]

Diseño acordado en laboratorio: play centrado que se abre en dos
burbujas (pausa izq, X der) con transcurrido / total en el medio, sin
barra. Tiempos reales (MediaPlayer / audioplayers), estimado por tamaño
antes de sonar. El cierre es la inversa de la apertura.

Verifica (estático, sin SDK):
1. XML: player_bar 64dp oculta + main/close 48dp + reloj, sin tocar botonera.
2. Activity: apertura/cierre espejo, icono play<->pausa, duración real,
   elapsed cada 500ms, slot_play fuera en pendiente, helpers puros.
3. Dart: _PlayerStage espejo animado, keys, reloj tabular, stream de
   posición, sin seek bar.
4. Tests Dart/Kotlin que lo cubren existen.
5. Sin secretos ni logs con contenido.
"""

import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
KT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "kotlin", "com", "royleguiza", "voicebubblestt",
)
APP = os.path.join(REPO_ROOT, "app_source")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


LAYOUT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "res", "layout", "activity_widget_note_edit.xml",
)
ACT = os.path.join(KT, "WidgetNoteEditActivity.kt")
HELPER = os.path.join(KT, "WidgetNoteEditHelper.kt")
KT_TEST = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "test",
    "kotlin", "com", "royleguiza", "voicebubblestt",
    "WidgetNotesBehaviorTest.kt",
)
TILE = os.path.join(APP, "lib", "widgets", "pending_note_tile.dart")
TILE_TEST = os.path.join(APP, "test", "widgets", "pending_note_tile_test.dart")


class TestC46ExpandingPlayerSuite(unittest.TestCase):

    def test_01_layout_bar_oculta_y_botonera_intacta(self):
        xml = read_file(LAYOUT)
        self.assertIn('android:id="@+id/player_bar"', xml)
        self.assertIn('android:id="@+id/btn_player_main"', xml)
        self.assertIn('android:id="@+id/btn_player_close"', xml)
        self.assertIn('android:id="@+id/player_clock"', xml)
        bar = xml.split('@+id/player_bar"')[1].split(">")[0]
        self.assertIn('android:layout_height="64dp"', bar)
        self.assertIn('android:visibility="gone"', bar)
        # La botonera equitativa no se toca.
        for slot in ("@+id/slot_delete", "@+id/slot_play",
                     "@+id/slot_copy", "@+id/slot_save"):
            self.assertIn(slot, xml)

    def test_02_activity_apertura_cierre_espejo(self):
        src = read_file(ACT)
        for name in ("openExpandingPlayer", "collapseExpandingPlayer",
                     "toggleExpandingPlayback", "closeExpandingPlayback",
                     "setupExpandingPlayer"):
            self.assertIn(name, src, f"Falta {name}")
        self.assertIn("translationX(-gap)", src)
        self.assertIn("translationX(gap)", src)
        self.assertIn("translationX(0f)", src)
        self.assertIn("setDuration(280)", src)
        self.assertIn("R.id.slot_play).visibility = View.GONE", src,
                      "La reproducción vive en la barra en pendiente")

    def test_03_activity_tiempos_reales(self):
        src = read_file(ACT)
        self.assertIn("mediaPlayer.duration", src,
                      "Total real al preparar")
        self.assertIn("postDelayed(this, 500L)", src,
                      "Transcurrido cada 500 ms")
        self.assertIn("currentPosition", src)
        self.assertIn("widget_ic_pause", src)
        self.assertIn("widget_ic_play", src)

    def test_04_helpers_puros(self):
        src = read_file(HELPER)
        for name in ("formatPlayerClock", "estimatePlayerTotalMs",
                     "playerGapPx"):
            self.assertIn(name, src, f"Falta {name}")
        self.assertIn("32000", src)
        self.assertIn("0.30f", src)
        kt = read_file(KT_TEST)
        for name in ("expandingPlayerClockFormatsWithSlash",
                     "expandingPlayerTotalEstimatesFromPcmSize",
                     "expandingPlayerGapKeepsNumbersClear"):
            self.assertIn(name, kt, f"Falta test {name}")

    def test_05_dart_stage_espejo(self):
        src = read_file(TILE)
        self.assertIn("class _PlayerStage", src)
        self.assertIn("AnimatedPositioned", src)
        self.assertIn("AnimatedOpacity", src)
        self.assertIn("playPendingButton-", src)
        self.assertIn("closePendingPlayer-", src)
        self.assertIn("pendingPlayerClock-", src)
        self.assertIn("onPositionChanged", src,
                      "Transcurrido real del player")
        self.assertIn("getDuration()", src,
                      "Total real al sonar")
        self.assertIn("padLeft(2, '0')", src,
                      "Formato 00:17 / 00:56")
        self.assertNotIn("Slider(", src)
        self.assertNotIn("data-seek", src)

    def test_06_cobertura_dart(self):
        test = read_file(TILE_TEST)
        self.assertIn("play se abre con reloj y la X colapsa", test)
        self.assertIn("00:00 / 00:00", test)
        self.assertIn("closePendingPlayer-", test)

    def test_07_sin_secretos_ni_logs(self):
        for path in (ACT, HELPER, TILE):
            src = read_file(path)
            self.assertNotIn("print(", src)
            self.assertNotIn("Log.d(", src)


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC46ExpandingPlayerSuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
