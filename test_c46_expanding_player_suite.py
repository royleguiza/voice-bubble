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
import xml.dom.minidom

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
KT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "kotlin", "com", "royleguiza", "voicebubblestt",
)
APP = os.path.join(REPO_ROOT, "app_source")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def read_code(path):
    """Igual que read_file pero sin comentarios: las aserciones de mecanismo
    (sin translación, sin IgnorePointer) tienen que mirar código, no prosa."""
    src = read_file(path)
    out, in_block = [], False
    for line in src.splitlines():
        stripped = line.strip()
        if in_block:
            if "*/" in stripped:
                in_block = False
            continue
        if stripped.startswith("/*"):
            if "*/" not in stripped:
                in_block = True
            continue
        if stripped.startswith("//"):
            continue
        out.append(line.split("//")[0])
    return "\n".join(out)


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

    def test_01_layout_bien_formsdo(self):
        # Un <!-- anidado o un tag sin cerrar hace fallar AAPT2 en el CI con
        # un error que no dice qué línea es. Se valida el XML de verdad.
        for path in (LAYOUT,):
            try:
                xml.dom.minidom.parse(path)
            except Exception as exc:  # noqa: BLE001
                self.fail(f"XML mal formado en {os.path.basename(path)}: {exc}")

    def test_02_player_vive_en_la_fila_de_acciones(self):
        xml = read_file(LAYOUT)
        # La fila del pendiente: grupo izq | espaciador | player | espaciador | grupo der.
        self.assertIn('android:id="@+id/pending_row"', xml)
        self.assertIn('android:id="@+id/classic_row"', xml)
        for name in ("player_bar", "player_spacer_left", "player_spacer_right",
                     "player_group_left", "pending_cancel", "pending_delete",
                     "pending_transcribe"):
            self.assertIn(f'android:id="@+id/{name}"', xml)
        # Los dos espaciadores reparten el sobrante por igual: eso es lo que
        # centra el play colapsado y lo que empuja a los costados al abrir.
        for spacer in ("player_spacer_left", "player_spacer_right"):
            chunk = xml.split(f'@+id/{spacer}"')[1].split(">")[0]
            self.assertIn('android:layout_width="0dp"', chunk)
            self.assertIn('android:layout_weight="1"', chunk)
        # El reloj y la X arrancan en ancho 0: nunca tapan al play.
        clock = xml.split('@+id/player_clock"')[1].split(">")[0]
        self.assertIn('android:layout_width="0dp"', clock)
        close = xml.split('@+id/btn_player_close"')[1].split(">")[0]
        self.assertIn('android:layout_width="0dp"', close)
        # El player no puede vivir en una fila propia: eso lo empujaba abajo.
        bar = xml.split('@+id/player_bar"')[1].split(">")[0]
        self.assertNotIn('match_parent', bar)
        # La botonera clásica se oculta por defecto (solo nota normal).
        classic = xml.split('@+id/classic_row"')[1].split(">")[0]
        self.assertIn('android:visibility="gone"', classic)

    def test_02_actividad_empuja_en_vez_de_superponer(self):
        src = read_file(ACT)
        code = read_code(ACT)
        for name in ("openExpandingPlayer", "collapseExpandingPlayer",
                     "toggleExpandingPlayback", "closeExpandingPlayback",
                     "setupExpandingPlayer", "applyPlayerSpread",
                     "animatePlayerSpread", "measureClockWidth"):
            self.assertIn(name, src, f"Falta {name}")
        # Sin translación: la expansión es de ancho, no de posición. Esto es
        # lo que mata la clase de bug de hit-test que quemó 10 CI.
        self.assertNotIn("translationX", code)
        self.assertNotIn("IgnorePointer", code)
        self.assertIn("closeParams.width = (button * progress)", code)
        self.assertIn("clockParams.width = (playerClockWidthPx * progress)", code)
        self.assertIn("playerSpreadAnimator?.cancel()", code,
                      "una apertura a la vez, sin animaciones cruzadas")
        # El player pertenece a la fila del pendiente, no a la clásica.
        self.assertIn("R.id.pending_row", code)
        self.assertIn("R.id.classic_row", code)
        self.assertIn("R.id.pending_transcribe", code)
        self.assertRegex(
            code,
            r"R\.id\.classic_row\)\?\.visibility = View\.VISIBLE",
            "La nota normal debe mostrar la botonera clásica")

    def test_04_tiempos_reales(self):
        src = read_file(ACT)
        self.assertIn("mediaPlayer.duration", src, "Total real al preparar")
        self.assertIn("postDelayed(this, 500L)", src, "Transcurrido cada 500 ms")
        self.assertIn("currentPosition", src)
        self.assertIn("widget_ic_pause", src)
        self.assertIn("widget_ic_play", src)

    def test_05_helpers_puros(self):
        src = read_file(HELPER)
        self.assertIn("formatPlayerClock", src)
        self.assertIn("estimatePlayerTotalMs", src)
        self.assertIn("32000", src)
        kt = read_file(KT_TEST)
        for name in ("expandingPlayerClockFormatsWithSlash",
                     "expandingPlayerTotalEstimatesFromPcmSize"):
            self.assertIn(name, kt, f"Falta test {name}")

    def test_06_dart_stage_por_ancho(self):
        src = read_file(TILE)
        code = read_code(TILE)
        test = read_file(TILE_TEST)
        self.assertIn("class _PlayerStage", src)
        self.assertIn("AnimatedContainer", src)
        self.assertIn("playPendingButton-", src)
        self.assertIn("closePendingPlayer-", src)
        self.assertIn("pendingPlayerClock-", src)
        self.assertIn("onPositionChanged", src, "Transcurrido real del player")
        self.assertIn("getDuration()", src, "Total real al sonar")
        self.assertIn("padLeft(2, '0')", src, "Formato 00:17 / 00:56")
        self.assertNotIn("Slider(", code)
        # Sin superposición ni translación en Dart tampoco.
        self.assertNotIn("AnimatedPositioned", code)
        self.assertNotIn("IgnorePointer", code)
        # El reloj mide ancho 0 colapsado y se ensancha al abrir.
        self.assertIn("width: open ? _clockWidth : 0", code)
        self.assertIn("width: open ? _buttonSize : 0", code)
        # El test mide la caja renderizada, no una propiedad inexistente.
        self.assertIn("tester.getSize(", test)
        self.assertNotIn(".width ??", test)
        # Y debe medir la CAJA (ancestor AnimatedContainer), no el texto: con
        # alignment el Text conserva su ancho intrinseco y daria 104 siempre.
        self.assertIn("find.ancestor(", test)
        self.assertIn("matching: find.byType(AnimatedContainer)", test)
        # El player debe quedar en la misma fila que las acciones.
        row = code.split("Row(")[-1]
        self.assertIn("_PlayerStage(", code)
        self.assertIn("transcribeCloudButton-", code)
        self.assertIn("discardPendingButton-", code)

    def test_07_izquierda_es_pausa_no_play(self):
        # Requisito del dueño: al reproducir, la burbuja izquierda muestra
        # PAUSA (no play). El ternario debe tener la pausa en el lado True.
        src = read_file(TILE)
        self.assertIn(
            "playing ? Icons.pause_rounded : Icons.play_arrow_rounded", src,
            "La burbuja izquierda debe ser pausa mientras suena")
        stage = src.split("class _PlayerStage")[1]
        # Orden de izquierda a derecha en el build: pausa, reloj, X.
        build = stage.split("Widget build(")[1]
        self.assertLess(build.index("mainKey"), build.index("clockKey"))
        self.assertLess(build.index("clockKey"), build.index("closeKey"))
        self.assertIn("enabled: enabled && open", stage,
                      "La X solo captura toques con el player abierto")
        act = read_file(ACT)
        self.assertIn("widget_ic_pause", act)
        self.assertIn('contentDescription = "Pausar audio"', act)

    def test_08_cobertura_dart(self):
        test = read_file(TILE_TEST)
        self.assertIn("play abre reloj+X y la X reagrupa en un play", test)
        self.assertIn("pendingPlayerClock-$id", test)
        self.assertIn("closePendingPlayer-$id", test)
        self.assertIn("00:00 / 00:00", test)
        # El test no puede depender de geometria de puntero sobre los
        # botones del player: invoca el callback, no un tap por coordenadas.
        self.assertNotIn("tap(\n        find.byKey(ValueKey('playPendingButton", test)
        self.assertNotIn("tap(\n        find.byKey(ValueKey('closePendingPlayer", test)
        self.assertIn(".onPressed!()", test)

    def test_09_sin_secretos_ni_logs(self):
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
