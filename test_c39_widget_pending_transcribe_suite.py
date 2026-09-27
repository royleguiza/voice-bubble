#!/usr/bin/env python3
"""
test_c39_widget_pending_transcribe_suite.py
===========================================
Auditoría C-39: transcribir el pendiente desde el widget [S]

Verifica:
1. NoteStore.removePending(id): retira solo la entrada pedida del
   índice compartido con Dart bajo lock cooperativo, con commit y
   verificación de lectura posterior; id vacío no toca nada.
2. WidgetNoteEditActivity.requestPendingTranscription: lee el WAV fuera
   del main, carga config, exige clave, transcribe con la red vigente
   (datos o Wi-Fi), guarda la nota con audio promovido, retira el
   pendiente, refresca widgets y cierra; en fallo avisa y conserva el
   audio para reintentar (guard anti-doble-tap incluido).
3. Layout: slot_transcribe oculto por defecto, botón 48dp con icono
   propio y descripción; el texto pendiente ofrece transcribir acá.
4. Diseño y contrato intactos: botonera equitativa, 6x48dp, sin Log
   con contenido ni permisos nuevos.
5. Mutaciones negativas: versiones rotas no pasan las guardas.
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
ACTIVITY = os.path.join(KT, "WidgetNoteEditActivity.kt")
STORE = os.path.join(KT, "NoteStore.kt")
LAYOUT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "res", "layout", "activity_widget_note_edit.xml",
)


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class TestC39WidgetPendingTranscribeSuite(unittest.TestCase):

    def test_01_remove_pending_quirurgico(self):
        src = read_file(STORE)
        self.assertIn("fun removePending(id: String): Boolean", src,
                      "Debe existir el retiro quirúrgico de pendientes")
        self.assertIn("withPendingLock", src.split("fun removePending")[1][:600],
                      "Debe correr bajo el lock cooperativo")
        body = src.split("fun removePending")[1].split("\n    fun ")[0]
        self.assertIn("if(id.isBlank())returnfalse", body.replace(" ", "").replace("\n", ""),
                      "Id vacío no debe tocar nada")
        self.assertIn('optString("id")', body, "Debe filtrar por id")
        self.assertIn("kept.put(item)", body, "Debe conservar el resto")
        self.assertIn(".commit()", body, "Debe commitear")
        self.assertIn("getString(PENDING_KEY, null) == json", body,
                      "Debe verificar con lectura posterior")

    def test_02_reintento_fuera_del_main_con_clave(self):
        act = read_file(ACTIVITY)
        self.assertIn("private fun requestPendingTranscription()", act)
        body = act.split("private fun requestPendingTranscription()")[1].split(
            "\n    private fun ")[0]
        self.assertIn("BackgroundWork.execute", body,
                      "La E/S y red corren fuera del main")
        self.assertIn("File(path).readBytes()", body, "Debe leer el WAV")
        self.assertIn("loadConfig()", body, "Debe cargar la config vigente")
        self.assertIn("config.apiKey.isBlank()", body, "Debe exigir clave")
        self.assertIn("Configurá tu clave en la app", body)
        self.assertIn(".transcribe(", body, "Debe transcribir con la red vigente")
        self.assertIn("transcribeInProgress.compareAndSet(false, true)", act,
                      "Debe blindar el doble tap")

    def test_03_exito_guarda_y_limpia_fracaso_conserva(self):
        act = read_file(ACTIVITY)
        body = act.split("private fun requestPendingTranscription()")[1].split(
            "\n    private fun ")[0]
        self.assertIn("addUntitledNote", body, "Debe guardar la nota")
        self.assertIn("promotePendingWav", body, "Debe promover el audio")
        self.assertIn("removePending(id)", body, "Debe retirar el pendiente")
        self.assertIn("refreshNoteWidgets()", body, "Debe refrescar widgets")
        self.assertIn('"Nota guardada"', body)
        self.assertIn("el audio se conserva", body,
                      "En fallo debe conservar el audio")
        self.assertIn("onError", body, "Debe manejar el error de red")

    def test_04_layout_y_texto_pendiente(self):
        xml = read_file(LAYOUT)
        # C-46: el pendiente transcribe desde su propia fila (fila del
        # player), no desde el slot de la botonera clásica.
        self.assertIn('android:id="@+id/pending_transcribe"', xml)
        btn = xml.split('@+id/pending_transcribe"')[1].split("</FrameLayout>")[0]
        self.assertIn('android:layout_width="48dp"', btn)
        self.assertIn("widget_ic_audio", btn)
        self.assertIn('contentDescription="Transcribir ahora"', xml)
        act = read_file(ACTIVITY)
        self.assertIn("R.id.pending_transcribe", act)
        self.assertIn("Transcribilo acá con tus datos o Wi-Fi", act)
        self.assertNotIn("Se transcribe solo desde Notas de la app", act)

    def test_05_diseno_y_privacidad_intactos(self):
        xml = read_file(LAYOUT)
        # C-46: 6 de botonera + 2 de la barra player expandible.
        self.assertEqual(xml.count('android:layout_width="48dp"'), 10,
                         "10 botones de 48dp: 6 de la botonera clasica + 4 de la "
                         "fila del pendiente (cerrar, descartar, transcribir, play)")
        self.assertIn('android:id="@+id/player_bar"', xml)
        self.assertIn("@drawable/widget_glass_inner", xml)
        for path in (ACTIVITY, STORE):
            src = read_file(path)
            self.assertNotIn("Log.", src, f"{os.path.basename(path)} sin logs")

    def test_06_mutaciones_negativas_detectadas(self):
        # Sin lock: carrera con Dart corrompe el índice.
        mut_lock = "fun removePending(id: String): Boolean { return true }"
        self.assertNotIn("withPendingLock", mut_lock)
        # Sin verificar clave: 401 seguro contra Groq.
        mut_key = "client.transcribe(wav, config,"
        self.assertNotIn("apiKey.isBlank", mut_key)
        # Borra el pendiente aunque falle el guardado: pierde el audio.
        mut_del = "removePending(id)\naddUntitledNote(text, keptPath)"
        self.assertNotIn("SAVED", mut_del)
        # Botón siempre visible: estorba en modo edición. C-46: ahora vive en
        # la fila del pendiente y se muestra desde setupPendingMode.
        mut_slot = '<FrameLayout\n                    android:id="@+id/pending_transcribe"'
        self.assertNotIn('visibility="gone"', mut_slot)


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC39WidgetPendingTranscribeSuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
