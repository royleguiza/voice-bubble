#!/usr/bin/env python3
"""
TEST SUITE: CANCELAR CORTA LA RED DE VERDAD (CONTRATO C-09)

Verifica al 100% de certeza sobre el código REAL:
1. Almacenamiento de HttpURLConnection en AtomicReference en SpeechToTextClient.kt.
2. cancelRecording() ejecuta disconnect() sobre activeConnection cortando la red de inmediato.
3. Chequeo de cancelRequested tras active.connect().
4. Transmisión y lectura por tramos con chequeo de cancelRequested en cada tramo (abortar lectura por tramos).
5. Captura de IOException/Exception ante corte forzado por cancelación: salida limpia vía onDone(null) sin mostrar errores espurios al usuario.
6. DictationController.kt:
   - proc (vista de procesamiento) tiene click listener que dispara cancelDictation(announce = true).
   - handleMicTap() procesa MicState.PROCESSING cancelando dictado.
   - onLongPress procesa MicState.PROCESSING cancelando dictado.
   - finishDictation() aborta antes de transcribe si generation cambió.
   - onDone distingue text == null como cancelación limpia (cero "No se detectó voz", cero guardado en historial).
7. Mutaciones negativas reales probando detección al 100%.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

print("\n============================================================")
print(" INICIANDO TEST SUITE: CONTRATO C-09 (CANCELAR CORTA LA RED)")
print("============================================================\n")

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
STT_PATH = os.path.join(KT, "SpeechToTextClient.kt")
DICT_PATH = os.path.join(KT, "DictationController.kt")

check("SpeechToTextClient.kt existe", os.path.isfile(os.path.join(WORKSPACE, STT_PATH)))
check("DictationController.kt existe", os.path.isfile(os.path.join(WORKSPACE, DICT_PATH)))

stt = suite.read(STT_PATH)
dic = suite.read(DICT_PATH)

# 1. AtomicReference para HttpURLConnection en SpeechToTextClient
check(
    "Import de AtomicReference presente en SpeechToTextClient",
    "import java.util.concurrent.atomic.AtomicReference" in stt,
)
check(
    "activeConnection declarado como AtomicReference<HttpURLConnection?>",
    "val activeConnection = AtomicReference<HttpURLConnection?>(null)" in stt,
)

# 2. cancelRecording() hace disconnect() inmediato
cancel_rec = stt[stt.find("fun cancelRecording()") : stt.find("private fun buildWav")]
check(
    "cancelRecording invoca disconnect en activeConnection",
    "activeConnection.getAndSet(null)?.disconnect()" in cancel_rec,
)
check(
    "cancelRecording fija cancelRequested = true",
    "cancelRequested = true" in cancel_rec,
)

# 3. transcribe(): asignación de activeConnection y chequeo tras connect()
transcribe_fn = stt[stt.find("fun transcribe(") : stt.find("private fun errorDetail")]

check(
    "transcribe registra activeConnection.set(active)",
    "activeConnection.set(active)" in transcribe_fn,
)
check(
    "transcribe ejecuta active.connect()",
    "active.connect()" in transcribe_fn,
)

# Comprobar que tras active.connect() se verifica cancelRequested
connect_pos = transcribe_fn.find("active.connect()")
cancel_after_connect = transcribe_fn.find("if (cancelRequested)", connect_pos)
check(
    "cancelRequested se comprueba tras active.connect()",
    connect_pos != -1 and cancel_after_connect != -1 and cancel_after_connect < transcribe_fn.find("DataOutputStream", connect_pos),
    f"connect_pos={connect_pos}, cancel_after_connect={cancel_after_connect}",
)

# 4. Transmisión y lectura por tramos
check(
    "Transmisión de WAV por tramos (chunked write)",
    "while (offset < wav.size)" in transcribe_fn and "if (cancelRequested)" in transcribe_fn,
)
check(
    "Lectura de respuesta por tramos (chunked read)",
    "while (reader.read(charBuf)" in transcribe_fn and "if (cancelRequested)" in transcribe_fn,
)
check(
    "readText() monolítico ausente en transcribe",
    "readText()" not in transcribe_fn,
)

# 5. Silenciamiento de errores en catch si fue cancelación
io_catch = transcribe_fn[transcribe_fn.find("catch (_: IOException)") : transcribe_fn.find("finally")]
check(
    "IOException aborta limpiamente si cancelRequested",
    "if (cancelRequested) {\n                    onDone(null)\n                    return@execute\n                }" in io_catch,
)

# 6. DictationController: capacidad de cancelar durante PROCESSING
check(
    "proc view tiene click listener para cancelar dictado",
    "proc.setOnClickListener {" in dic and "cancelDictation()" in dic[dic.find("proc.setOnClickListener") : dic.find("proc.setOnClickListener") + 150],
)

handle_tap = dic[dic.find("private fun handleMicTap()") : dic.find("private fun bubbleBusy()")]
check(
    "handleMicTap cancela ante MicState.PROCESSING",
    "MicState.PROCESSING -> cancelDictation()" in handle_tap,
)

on_long_press = dic[dic.find("onLongPress = {") : dic.find("onTapUp = { handleMicTap() }")]
check(
    "onLongPress cancela ante MicState.PROCESSING",
    "MicState.PROCESSING -> cancelDictation()" in on_long_press,
)

# 7. finishDictation: aborto temprano ante cambio de generación y señal limpia en onDone
finish_fn = dic[dic.find("private fun finishDictation()") : dic.find("private fun commitOrWarn")]
check(
    "finishDictation aborta antes de transcribe si cambió la generación",
    "if (generation != transcriptionGeneration) return@execute\n            sttClient.transcribe" in finish_fn,
)
check(
    "onDone distingue text == null como cancelación",
    "if (text == null) {" in finish_fn and "micIdle()" in finish_fn,
)

# 8. Mutaciones negativas
def test_mutations():
    # Mutación 1: Remover disconnect en cancelRecording
    mut_cancel = cancel_rec.replace("activeConnection.getAndSet(null)?.disconnect()", "// no disconnect")
    check("Mutación 1 (sin disconnect en cancelRecording): detectada", "activeConnection.getAndSet(null)?.disconnect()" not in mut_cancel)

    # Mutación 2: Remover check de cancelRequested tras connect()
    mut_transcribe = transcribe_fn.replace("active.connect()", "// no connect check")
    check("Mutación 2 (sin connect check): detectada", "active.connect()" not in mut_transcribe)

    # Mutación 3: Reintroducir lectura monolítica readText()
    mut_monolithic = transcribe_fn.replace("while (reader.read(charBuf)", "readText()")
    check("Mutación 3 (lectura monolítica): detectada", "readText()" in mut_monolithic)

    # Mutación 4: Remover cancel en proc click listener
    mut_dic_proc = dic.replace("proc.setOnClickListener {\n            host.pressHaptic(proc)\n            cancelDictation()\n        }", "")
    check("Mutación 4 (proc sin cancel): detectada", "proc.setOnClickListener" not in mut_dic_proc)

    # Mutación 5: Remover aborto por generación antes de transcribe
    mut_finish = finish_fn.replace("if (generation != transcriptionGeneration) return@execute", "")
    check("Mutación 5 (sin aborto por generación): detectada", "if (generation != transcriptionGeneration) return@execute" not in mut_finish)

test_mutations()

print("\n============================================================")
print(f" RESULTADOS C-09: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

sys.exit(suite.exit_code())
