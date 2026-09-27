#!/usr/bin/env python3
"""
test_c45_offline_pending_fix_suite.py
=====================================
Auditoría C-45: offline widget/app no pierde el audio [S]

Causa raíz del `no-riff 00000000`: el cliente Kotlin ceraba (`fill(0)`)
el buffer del llamador y el widget encolaba en otro hilo DESPUÉS del
cerado -> pendiente en puros ceros. Además el reparado C-44 solo viajaba
en memoria (disco seguía dañado -> irreproducible) y un solo WAV faltante
volteaba toda la cola (placeholder muerto).

Verifica (estático, sin SDK):
1. Kotlin no cera el buffer del llamador + repara hueco sin tapa.
2. Widget encola directo (sin carrera) con bytes sanos.
3. Modal del widget repara al leer y permite descartar + avisa.
4. Dart persiste el reparado en disco.
5. Colas tolerantes a faltantes (Dart + Kotlin).
6. Orden transcribir-primero en Notas.
7. Play en pendiente app + diagnóstico de dañado.
8. Tests Dart/Kotlin que lo cubren existen.
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


STT = os.path.join(KT, "SpeechToTextClient.kt")
WIDGET_SVC = os.path.join(KT, "WidgetDictationService.kt")
WIDGET_MODAL = os.path.join(KT, "WidgetNoteEditActivity.kt")
WIDGET_LIST = os.path.join(KT, "WidgetNotesListService.kt")
NOTE_STORE = os.path.join(KT, "NoteStore.kt")
KT_TEST = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "test",
    "kotlin", "com", "royleguiza", "voicebubblestt",
    "WidgetNotesBehaviorTest.kt",
)
CLOUD = os.path.join(APP, "lib", "services", "cloud_stt_service.dart")
QUEUE = os.path.join(APP, "lib", "services", "pending_note_queue.dart")
NOTES_SCREEN = os.path.join(APP, "lib", "screens", "notes_screen.dart")
PENDING_TILE = os.path.join(APP, "lib", "widgets", "pending_note_tile.dart")
AUDIO_ROW = os.path.join(APP, "lib", "widgets", "note_audio_row.dart")
WAV_TEST = os.path.join(APP, "test", "services", "wav_integrity_test.dart")
QUEUE_TEST = os.path.join(APP, "test", "services", "pending_note_queue_test.dart")
TILE_TEST = os.path.join(APP, "test", "widgets", "pending_note_tile_test.dart")
AUDIO_ROW_TEST = os.path.join(APP, "test", "widgets", "note_audio_row_test.dart")


class TestC45OfflinePendingFixSuite(unittest.TestCase):

    def test_01_cliente_no_cera_llamador_y_repara(self):
        src = read_file(STT)
        self.assertIn("fun tryRepairHolePcmBytes(", src,
                      "Espejo Kotlin del rescate C-44")
        self.assertIn("fun buildWavHeader(", src,
                      "Tapa propia para el rescate")
        self.assertIn("wav.copyOf()", src,
                      "Se sube una copia; el original queda para reintento/encolado")
        self.assertIn("tryRepairHolePcmBytes(snapshot)", src,
                      "El rescate corre antes de validar")

    def test_02_widget_encola_directo_con_sanos(self):
        src = read_file(WIDGET_SVC)
        self.assertIn("tryRepairHolePcmBytes(wav)", src,
                      "El widget persiste bytes reparados")
        self.assertIn("enqueuePendingWavResult(persist)", src,
                      "Se encola el sano, no el dañado")
        self.assertNotIn("onError = { code, message ->\n                BackgroundWork.execute {",
                         src,
                         "Sin BackgroundWork anidado en onError (carrera de ceros)")

    def test_03_modal_repara_descarta_y_avisa(self):
        src = read_file(WIDGET_MODAL)
        self.assertIn("tryRepairHolePcmBytes(raw)", src,
                      "La modal repara al leer el pendiente")
        self.assertIn("requestDiscardPending", src,
                      "El pendiente dañado tiene salida (descartar)")
        self.assertIn("removePending(id)", src,
                      "Descartar quita el índice compartido")
        self.assertIn("Audio dañado", src,
                      "El play fallido avisa en vez de callar")

    def test_04_dart_persiste_reparado(self):
        src = read_file(CLOUD)
        self.assertIn("await file.writeAsBytes(repaired", src,
                      "El reparado se persiste para playback/reintentos")

    def test_05_colas_tolerantes(self):
        dart = read_file(QUEUE)
        self.assertIn("if (!File(item.audioPath).existsSync()) continue;", dart,
                      "Dart filtra faltantes sin corromper")
        self.assertNotIn(
            "if (!File(item.audioPath).existsSync()) {\n          return const _PendingReadResult(",
            dart,
            "Dart ya no voltea la cola por un faltante")
        kotlin_list = read_file(WIDGET_LIST)
        self.assertIn("if (!audio.exists() || !audio.isFile) continue",
                      kotlin_list,
                      "Widget filtra faltantes")
        store = read_file(NOTE_STORE)
        self.assertIn("if (!audio.isFile) continue", store,
                      "NoteStore filtra faltantes")

    def test_06_transcribir_primero_en_notas(self):
        src = read_file(NOTES_SCREEN)
        stop = src.index("Future<void> _stopAndSave()")
        transcribe_pos = src.index("_transcriptionService.transcribe(", stop)
        keep_pos = src.index("keepCopyForNote(path)", stop)
        self.assertLess(transcribe_pos, keep_pos,
                        "_stopAndSave: transcribir antes de conservar")
        pend = src.index("Future<void> _transcribePending(")
        transcribe_p = src.index("_transcriptionService.transcribe(", pend)
        promote_p = src.index("promoteToKept(item)", pend)
        self.assertLess(transcribe_p, promote_p,
                        "_transcribePending: transcribir antes de promover")

    def test_07_play_y_diagnostico(self):
        tile = read_file(PENDING_TILE)
        self.assertIn("playPendingButton-", tile,
                      "El pendiente en app se puede escuchar")
        self.assertIn("No se pudo reproducir este audio", tile)
        row = read_file(AUDIO_ROW)
        self.assertIn("Audio dañado; borralo y grabalo de nuevo", row,
                      "El audio heredado dañado avisa")

    def test_08_cobertura_tests(self):
        self.assertIn("persiste en disco sano", read_file(WAV_TEST))
        self.assertIn("se filtra sin voltear la cola", read_file(QUEUE_TEST))
        self.assertIn("playPendingButton-", read_file(TILE_TEST))
        self.assertIn("cabecera da", read_file(AUDIO_ROW_TEST).replace("ñ", "n"),
                      "Cobertura de diagnóstico en NoteAudioRow")
        kt = read_file(KT_TEST)
        self.assertIn("tryRepairHolePcmBytesRescuesOurPcmWithoutLid", kt)
        self.assertIn("pendingSnapshotFiltersMissingWavWithoutCorruptingQueue", kt)

    def test_09_sin_secretos_ni_logs(self):
        for path in (STT, WIDGET_SVC, WIDGET_MODAL, CLOUD, QUEUE):
            src = read_file(path)
            self.assertNotIn("print(", src)
            self.assertNotIn("Log.d(", src)
            self.assertNotIn("Bearer \" + config.apiKey", src.replace(
                '"Bearer ${config.apiKey}"', ""))


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC45OfflinePendingFixSuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
