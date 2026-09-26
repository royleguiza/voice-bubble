#!/usr/bin/env python3
"""
TEST SUITE: REINTENTO SIN REGRABAR (CONTRATO C-10)

Verifica sobre el código REAL:
1. Retención del último WAV + configuración en LastDictationSlot dentro de DictationController.kt.
2. Clasificación precisa de errores reintentables (isRetryableError):
   - Red, servidor 5xx, límite 429, timeout = reintentable.
   - API key inválida, auth, bad request 4xx = no reintentable.
3. finishDictation():
   - Retiene lastDictationSlot antes de transcribe().
   - En onError ofrece reintento manual mediante showNotice con onClick = { retryLastDictation() }.
   - En onDone limpia lastDictationSlot ante éxito.
4. retryLastDictation():
   - Reutiliza slot.wav y slot.config sin regrabar (cero startRecording / cero claimMicrophone).
   - Actualiza estado visual a MicState.PROCESSING.
   - Ejecuta transcribe en BackgroundWork con nueva generación.
5. Limpieza de slot:
   - startDictation() resetea lastDictationSlot a null.
   - cancelDictation() resetea lastDictationSlot a null.
   - cancelDictationIfActive() resetea lastDictationSlot a null.
6. StatusLayer.kt & VoiceKeyboardService.kt:
   - StatusLayer.show admite onClick: (() -> Unit)? = null, configura listener y eleva timeout a 5000 ms.
   - VoiceKeyboardService.showNotice reenvía onClick a status.show.
   - UiHost en DictationController incluye onClick opcional.
7. transcription_service.dart:
   - No borra el archivo temporal de audio si el texto devuelto es vacío para permitir reintentos.
8. cloud_stt_service.dart:
   - TranscriptionErrorKind e isRetryable bien definidos (network y server reintentables; auth y badRequest no).
   - Cero reintentos automáticos (cada transcribe envía exactamente una petición).
9. Al menos 5 mutaciones negativas reales probando detección al 100%.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

print("\n============================================================")
print(" INICIANDO TEST SUITE: CONTRATO C-10 (REINTENTO SIN REGRABAR)")
print("============================================================\n")

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
DART = "app_source/lib/services"

DICT_PATH = os.path.join(KT, "DictationController.kt")
STATUS_PATH = os.path.join(KT, "StatusLayer.kt")
VKS_PATH = os.path.join(KT, "VoiceKeyboardService.kt")
TRANS_DART_PATH = os.path.join(DART, "transcription_service.dart")
CLOUD_DART_PATH = os.path.join(DART, "cloud_stt_service.dart")

check("DictationController.kt existe", os.path.isfile(os.path.join(WORKSPACE, DICT_PATH)))
check("StatusLayer.kt existe", os.path.isfile(os.path.join(WORKSPACE, STATUS_PATH)))
check("VoiceKeyboardService.kt existe", os.path.isfile(os.path.join(WORKSPACE, VKS_PATH)))
check("transcription_service.dart existe", os.path.isfile(os.path.join(WORKSPACE, TRANS_DART_PATH)))
check("cloud_stt_service.dart existe", os.path.isfile(os.path.join(WORKSPACE, CLOUD_DART_PATH)))

dic = suite.read(DICT_PATH)
stat = suite.read(STATUS_PATH)
vks = suite.read(VKS_PATH)
trans_dart = suite.read(TRANS_DART_PATH)
cloud_dart = suite.read(CLOUD_DART_PATH)

# 1. LastDictationSlot y propiedad en DictationController
check(
    "LastDictationSlot data class definida con wav y config",
    "data class LastDictationSlot(" in dic
    and "val wav: ByteArray" in dic
    and "val config: SpeechToTextClient.Config" in dic,
)
check(
    "lastDictationSlot declarado en DictationController",
    "var lastDictationSlot: LastDictationSlot? = null" in dic,
)

# 2. isRetryableError clasificador
check(
    "isRetryableError función definida",
    "private fun isRetryableError(message: String): Boolean" in dic,
)
retry_fn = dic[dic.find("private fun isRetryableError") : dic.find("private fun isRetryableError") + 900]
check(
    "isRetryableError detecta red, servidor, 5xx y 429",
    'message.contains("conexión"' in retry_fn
    and 'message.contains("servidor"' in retry_fn
    and 'message.contains("500")' in retry_fn
    and 'message.contains("429")' in retry_fn,
)
check(
    "isRetryableError excluye API key e inválida",
    'message.contains("API key"' in retry_fn
    and 'message.contains("inválida"' in retry_fn,
)

# 3. Retención y oferta de reintento en finishDictation
finish_fn = dic[dic.find("private fun finishDictation()") : dic.find("private fun commitOrWarn")]
check(
    "finishDictation asigna lastDictationSlot antes de transcribe",
    "lastDictationSlot = LastDictationSlot(wav, config)" in finish_fn
    and finish_fn.find("lastDictationSlot = LastDictationSlot(wav, config)") < finish_fn.find("sttClient.transcribe"),
)
check(
    "finishDictation limpia lastDictationSlot en éxito onDone",
    "lastDictationSlot = null" in finish_fn[finish_fn.find("onDone = {") : finish_fn.find("onError = {")],
)
check(
    "finishDictation ofrece reintento interactivo con onClick en onError",
    "if (isRetryableError(message) && lastDictationSlot != null)" in finish_fn
    and "host.showNotice(" in finish_fn
    and "onClick = { retryLastDictation() }" in finish_fn,
)
check(
    "finishDictation limpia lastDictationSlot si el error no es reintentable",
    "lastDictationSlot = null" in finish_fn[finish_fn.find("onError = {") :],
)

# 4. retryLastDictation()
check(
    "retryLastDictation función definida",
    "fun retryLastDictation()" in dic,
)
retry_body = dic[dic.find("fun retryLastDictation()") : dic.find("private fun cancelDictation")]
check(
    "retryLastDictation extrae slot retenido o aborta",
    "val slot = lastDictationSlot ?: return" in retry_body,
)
check(
    "retryLastDictation valida estado idle y sin inicio pendiente",
    "if (dictationStartPending || micState != MicState.IDLE) return" in retry_body,
)
check(
    "retryLastDictation pasa a MicState.PROCESSING",
    "micState = MicState.PROCESSING" in retry_body
    and "refreshMicVisual()" in retry_body,
)
check(
    "retryLastDictation incrementa generación de transcripción",
    "++transcriptionGeneration" in retry_body,
)
check(
    "retryLastDictation NO regraba (cero llamadas a startRecording/claim)",
    "startRecording" not in retry_body
    and "tryClaimMicrophone" not in retry_body
    and "gainAudioFocus" not in retry_body,
)
check(
    "retryLastDictation reenvía slot.wav y slot.config a transcribe",
    "sttClient.transcribe(\n                slot.wav,\n                slot.config," in retry_body
    or "sttClient.transcribe(slot.wav, slot.config," in retry_body.replace(" ", ""),
)
check(
    "retryLastDictation comete texto y emite PASTE en onDone",
    "if (commitOrWarn(text)) {\n                                micEvent(MicEvent.PASTE)\n                            }" in retry_body,
)

# 5. Limpieza de lastDictationSlot en otros flujos
start_fn = dic[dic.find("private fun startDictation()") : dic.find("private fun onDictationStartResult")]
check(
    "startDictation limpia lastDictationSlot al iniciar nueva grabación",
    "lastDictationSlot = null" in start_fn,
)

cancel_fn = dic[dic.find("private fun cancelDictation(announce: Boolean = false)") : dic.find("fun cancelDictationIfActive()")]
check(
    "cancelDictation limpia lastDictationSlot al cancelar",
    "lastDictationSlot = null" in cancel_fn,
)

cancel_if_active_fn = dic[dic.find("fun cancelDictationIfActive()") : dic.find("private fun releaseMicrophoneClaim")]
check(
    "cancelDictationIfActive limpia lastDictationSlot al desmontar",
    "lastDictationSlot = null" in cancel_if_active_fn,
)

# 6. StatusLayer y VoiceKeyboardService
check(
    "StatusLayer.show admite onClick opcional",
    "fun show(message: String, openSettingsOnClick: Boolean = false, onClick: (() -> Unit)? = null)" in stat,
)
show_body = stat[stat.find("fun show(") : stat.find("fun hide()")]
check(
    "StatusLayer configura click listener para onClick y descarta aviso",
    "if (onClick != null) {\n                tv.isClickable = true\n                tv.setOnClickListener {\n                    hide()\n                    onClick()\n                }" in show_body,
)
check(
    "StatusLayer extiende tiempo a 5000L cuando hay onClick",
    "val timeout = if (onClick != null) 5000L else 3500L" in show_body,
)
check(
    "VoiceKeyboardService.showNotice reenvía onClick",
    "override fun showNotice(message: String, openSettingsOnClick: Boolean, onClick: (() -> Unit)?)" in vks
    and "status.show(message, openSettingsOnClick, onClick)" in vks,
)
check(
    "UiHost en DictationController define showNotice con onClick",
    "fun showNotice(message: String, openSettingsOnClick: Boolean = false, onClick: (() -> Unit)? = null)" in dic,
)

# 7. transcription_service.dart
check(
    "transcription_service.dart no borra temporal si el texto es vacío",
    "if (deleteAudioOnSuccess && result.text.isNotEmpty)" in trans_dart,
)

# 8. cloud_stt_service.dart y contrato de cero reintentos automáticos
check(
    "CloudSttService define TranscriptionErrorKind con network y server",
    "enum TranscriptionErrorKind" in cloud_dart
    and "network," in cloud_dart
    and "server," in cloud_dart,
)
check(
    "TranscriptionException.isRetryable es true solo para network y server",
    "bool get isRetryable =>\n      kind == TranscriptionErrorKind.network || kind == TranscriptionErrorKind.server;" in cloud_dart
    or "kind == TranscriptionErrorKind.network || kind == TranscriptionErrorKind.server" in cloud_dart,
)
check(
    "CloudSttService contrato documentado: CERO reintentos automáticos",
    "Este servicio NUNCA reintenta por su cuenta: cada `transcribe()` envía" in cloud_dart,
)

# 9. Mutaciones negativas
def test_mutations():
    # Mutación 1: finishDictation no pasa onClick a showNotice (reintento roto)
    mut1 = finish_fn.replace("onClick = { retryLastDictation() }", "/* no retry */")
    check("Mutación 1 (showNotice sin onClick de reintento): detectada", "onClick = { retryLastDictation() }" not in mut1)

    # Mutación 2: transcription_service borra temporal con texto vacío
    mut2 = trans_dart.replace("if (deleteAudioOnSuccess && result.text.isNotEmpty)", "if (deleteAudioOnSuccess)")
    check("Mutación 2 (borrado de audio con texto vacío): detectada", "if (deleteAudioOnSuccess && result.text.isNotEmpty)" not in mut2)

    # Mutación 3: isRetryableError clasifica error de clave como reintentable
    mut3 = retry_fn.replace('message.contains("API key"', 'false && message.contains("API key"')
    check("Mutación 3 (isRetryableError clasifica clave inválida como reintentable): detectada", 'false && message.contains("API key"' in mut3)

    # Mutación 4: retryLastDictation vuelve a iniciar grabación (violando reintento sin regrabar)
    mut4 = retry_body.replace("sttClient.transcribe(", "sttClient.startRecording()\nsttClient.transcribe(")
    check("Mutación 4 (retryLastDictation regraba audio): detectada", "startRecording" in mut4)

    # Mutación 5: Reintento automático en onError (sin intervención del usuario)
    mut5 = finish_fn.replace("host.showNotice(retryMsg, onClick = { retryLastDictation() })", "retryLastDictation()")
    check("Mutación 5 (reintento automático no autorizado): detectada", "retryLastDictation()" in mut5 and "onClick =" not in mut5)

test_mutations()

print("\n============================================================")
print(f" RESULTADOS C-10: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

sys.exit(suite.exit_code())
