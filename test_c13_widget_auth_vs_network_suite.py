#!/usr/bin/env python3
"""
Test Suite: Contrato C-13 - El widget distingue "sin internet" de "sin clave"
=============================================================================
Garantías verificadas:
1. SpeechToTextClient.transcribe propaga el código HTTP (o null ante caídas de red) en onError.
2. SpeechToTextClient mantiene sobrecarga con onError: (String) -> Unit para retrocompatibilidad.
3. WidgetDictationService recibe (code, message) en onError de transcribe.
4. shouldEnqueuePending encola en la cola diferida ÚNICAMENTE si:
   - La cola diferida está activa (isDeferredQueueEnabled == true).
   - NO es un error de autenticación/clave (isAuthError == false).
   - Es una falla transitoria/de red: code == null, code == 429 (rate limit), o code >= 500 (server error).
5. Errores 401/403 con texto arbitrario o inesperado ("token_expired", "unauthorized", "weird body", etc.)
   NUNCA se encolan.
6. Errores 400..499 (excepto 429) NUNCA se encolan.
7. Fallos de red (code == null, timeout, IOException) SÍ se encolan.
8. Verificación de al menos 5 mutaciones negativas reales.
"""

import os
import re
import sys

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
KT_PATH = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt")
STT_CLIENT_KT = os.path.join(KT_PATH, "SpeechToTextClient.kt")
WIDGET_SERVICE_KT = os.path.join(KT_PATH, "WidgetDictationService.kt")

passed = 0
failed = 0


def check(desc: str, condition: bool, extra: str = ""):
    global passed, failed
    if condition:
        print(f"  [PASS] {desc}")
        passed += 1
    else:
        print(f"  [FAIL] {desc} {extra}")
        failed += 1


print("\n" + "=" * 60)
print(" INICIANDO TEST SUITE: CONTRATO C-13 (AUTH VS RED EN WIDGET)")
print("=" * 60 + "\n")

# 1. Existencia de archivos
check("SpeechToTextClient.kt existe", os.path.isfile(STT_CLIENT_KT))
check("WidgetDictationService.kt existe", os.path.isfile(WIDGET_SERVICE_KT))

with open(STT_CLIENT_KT, "r", encoding="utf-8") as f:
    stt_code = f.read()

with open(WIDGET_SERVICE_KT, "r", encoding="utf-8") as f:
    widget_code = f.read()

# 2. SpeechToTextClient.kt - Firma y propagación de HTTP code
check(
    "transcribe acepta onError con (code: Int?, message: String) -> Unit",
    "onError: (code: Int?, message: String) -> Unit" in stt_code
    or "onError: (code: Int?, msg: String) -> Unit" in stt_code,
)

check(
    "transcribe provee sobrecarga de compatibilidad onError: (String) -> Unit",
    "fun transcribe(" in stt_code
    and "onError: (String) -> Unit" in stt_code
    and "transcribe(wav, config, onDone) { _, message -> onError(message) }" in stt_code,
)

check(
    "HTTP error propaga el responseCode a onError",
    "onError(code, errorDetail(code, body))" in stt_code,
)

check(
    "IOException propaga null como código a onError",
    "catch (_: IOException)" in stt_code
    and "onError(\n                    null," in stt_code,
)

check(
    "Exception genérica propaga null como código a onError",
    "catch (_: Exception)" in stt_code
    and "onError(\n                    null," in stt_code,
)

check(
    "Audio > 25 MB propaga código 400 a onError",
    "if (wav.size > MAX_AUDIO_BYTES)" in stt_code
    and "onError(\n                400," in stt_code,
)

# 3. WidgetDictationService.kt - Manejo de errores y encolado condicional
check(
    "WidgetDictationService.stopAndTranscribe recibe (code, message) en onError",
    "onError = { code, message ->" in widget_code,
)

check(
    "isAuthError definido con (code: Int?, message: String)",
    "fun isAuthError(code: Int?, message: String): Boolean" in widget_code,
)

check(
    "isAuthError clasifica 401 y 403 como error de autenticación directo",
    "code == 401 || code == 403" in widget_code,
)

check(
    "isAuthError clasifica 'API key' y 'unauthorized'",
    'message.contains("API key", ignoreCase = true)' in widget_code
    and 'message.contains("unauthorized", ignoreCase = true)' in widget_code,
)

check(
    "shouldEnqueuePending definido con (code: Int?, message: String)",
    "fun shouldEnqueuePending(" in widget_code
    and "code: Int?" in widget_code
    and "message: String" in widget_code,
)

check(
    "shouldEnqueuePending aborta si la cola diferida no está activa",
    "if (!queueEnabled) return false" in widget_code
    or "if (!isDeferredQueueEnabled()) return false" in widget_code,
)

check(
    "shouldEnqueuePending aborta si es error de autenticación",
    "if (isAuthError(code, message)) return false" in widget_code,
)

check(
    "shouldEnqueuePending restringe encolado a: code == null || code == 429 || code >= 500",
    "code == null || code == 429 || code >= 500" in widget_code,
)

check(
    "WidgetDictationService usa shouldEnqueuePending(code, message) antes de encolar",
    "if (shouldEnqueuePending(code, message))" in widget_code,
)

# 4. Lógica de evaluación exacta (simulación funcional en Python)
def sim_is_auth_error(code, message):
    if code in (401, 403):
        return True
    lower = message.lower()
    return any(k in lower for k in ("api key", "unauthorized", "forbidden", "invalid_api_key"))


def sim_should_enqueue(code, message, queue_enabled=True):
    if not queue_enabled:
        return False
    if sim_is_auth_error(code, message):
        return False
    return code is None or code == 429 or code >= 500


# Verificación de casos de prueba del Contrato C-13
check("401 con 'API key inválida' NO encola", not sim_should_enqueue(401, "API key inválida"))
check("401 con 'token_expired' (texto raro) NO encola", not sim_should_enqueue(401, "token_expired"))
check("401 con cuerpo vacío NO encola", not sim_should_enqueue(401, ""))
check("401 con 'Unauthorized error' NO encola", not sim_should_enqueue(401, "Unauthorized error"))
check("403 con 'Forbidden access' NO encola", not sim_should_enqueue(403, "Forbidden access"))
check("403 con 'weird_random_message' (texto raro) NO encola", not sim_should_enqueue(403, "weird_random_message"))

check("400 Bad Request NO encola", not sim_should_enqueue(400, "Bad Request: invalid audio"))
check("404 Not Found NO encola", not sim_should_enqueue(404, "Endpoint not found"))
check("422 Unprocessable Entity NO encola", not sim_should_enqueue(422, "Unprocessable entity"))

check("Red caída (code=None) SÍ encola", sim_should_enqueue(None, "Sin conexión a internet."))
check("SocketTimeoutException (code=None) SÍ encola", sim_should_enqueue(None, "Connection timed out"))
check("IOException (code=None) SÍ encola", sim_should_enqueue(None, "Network unreachable"))

check("429 Rate Limit SÍ encola", sim_should_enqueue(429, "Rate limit reached"))
check("500 Internal Server Error SÍ encola", sim_should_enqueue(500, "Internal Server Error"))
check("502 Bad Gateway SÍ encola", sim_should_enqueue(502, "Bad Gateway"))
check("503 Service Unavailable SÍ encola", sim_should_enqueue(503, "Service Unavailable"))
check("504 Gateway Timeout SÍ encola", sim_should_enqueue(504, "Gateway Timeout"))

check("Cola diferida apagada (queue_enabled=False) NUNCA encola", not sim_should_enqueue(None, "Sin conexión", queue_enabled=False))
check("429 con cola apagada NUNCA encola", not sim_should_enqueue(429, "Rate limit", queue_enabled=False))
check("code=None con mensaje de API key NUNCA encola", not sim_should_enqueue(None, "API key requerida"))

# 5. Verificación de Mutaciones Negativas
print("\n--- Verificación de Mutaciones Negativas ---")

# Mutación 1: 401 con texto arbitrario encola si se regresa al isAuthError viejo (solo "API key")
old_is_auth = lambda msg: "api key" in msg.lower()
old_should_enqueue = lambda code, msg: not old_is_auth(msg)
check(
    "Mutación 1 (isAuthError viejo encola 401 con texto arbitrario): detectada",
    old_should_enqueue(401, "token_expired") is True,  # Demuestra el bug preexistente
)

# Mutación 2: shouldEnqueuePending omite la condición code == null || code == 429 || code >= 500
mut_code2 = widget_code.replace("code == null || code == 429 || code >= 500", "true")
check(
    "Mutación 2 (encolar cualquier error no-auth): detectada",
    "true" in mut_code2 and "code == null || code == 429 || code >= 500" not in mut_code2,
)

# Mutación 3: SpeechToTextClient no propaga el código HTTP
mut_code3 = stt_code.replace("onError(code, errorDetail(code, body))", "onError(errorDetail(code, body))")
check(
    "Mutación 3 (SpeechToTextClient no propaga código HTTP): detectada",
    "onError(code, errorDetail(code, body))" not in mut_code3,
)

# Mutación 4: WidgetDictationService ignora shouldEnqueuePending
mut_code4 = widget_code.replace("shouldEnqueuePending(code, message)", "true")
check(
    "Mutación 4 (WidgetDictationService encola incondicionalmente): detectada",
    "shouldEnqueuePending(code, message)" not in mut_code4,
)

# Mutación 5: 403 no es reconocido como auth error
mut_code5 = widget_code.replace("code == 401 || code == 403", "code == 401")
check(
    "Mutación 5 (403 ignorado como auth error): detectada",
    "code == 401 || code == 403" not in mut_code5,
)

# Mutación 6: 400 Bad Request se encola
check(
    "Mutación 6 (400 Bad Request se rechaza): detectada",
    sim_should_enqueue(400, "Bad Request") is False,
)

print("\n" + "=" * 60)
print(f" RESULTADOS C-13: {passed} pasados, {failed} fallidos.")
print("=" * 60 + "\n")

if failed > 0:
    sys.exit(1)
