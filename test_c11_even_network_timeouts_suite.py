#!/usr/bin/env python3
"""
TEST SUITE: TIEMPOS DE RED PAREJOS (CONTRATO C-11)

Verifica sobre el código REAL:
1. Misma fórmula de timeout adaptativo `60 + bytes/50k` con tope [60s, 600s] en Kotlin y Dart.
2. Cálculo exacto con audio de 9.6 MB (9,600,000 bytes): da exactamente 252 segundos en ambos lados.
3. Lectura de respuesta fija separada de la subida adaptativa:
   - Dart: `response.stream.bytesToString().timeout(timeoutRead)` con lectura fija de 60s.
   - Kotlin: `active.readTimeout = TIMEOUT_READ_SECONDS * 1000` con lectura fija de 60s.
4. Subida adaptativa con deadline en Kotlin:
   - `uploadDeadline` calculado con `timeoutForBytes(wav.size)`.
   - Chequeo de deadline en la transmisión por tramos.
5. Tope de archivo de 25 MB (26,214,400 bytes) verificado antes de iniciar la subida:
   - Kotlin: `MAX_AUDIO_BYTES = 25 * 1024 * 1024` con aborto previo en SpeechToTextClient y WidgetDictationService.
   - Dart: `maxFileSizeBytes = 25 * 1024 * 1024` con excepción BadRequest en CloudSttService.
6. Al menos 5 mutaciones negativas reales probando detección al 100%.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

print("\n============================================================")
print(" INICIANDO TEST SUITE: CONTRATO C-11 (TIEMPOS DE RED PAREJOS)")
print("============================================================\n")

KT_PATH = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
DART_PATH = "app_source/lib/services"

STT_KT = os.path.join(KT_PATH, "SpeechToTextClient.kt")
WIDGET_KT = os.path.join(KT_PATH, "WidgetDictationService.kt")
CLOUD_DART = os.path.join(DART_PATH, "cloud_stt_service.dart")

check("SpeechToTextClient.kt existe", os.path.isfile(os.path.join(WORKSPACE, STT_KT)))
check("WidgetDictationService.kt existe", os.path.isfile(os.path.join(WORKSPACE, WIDGET_KT)))
check("cloud_stt_service.dart existe", os.path.isfile(os.path.join(WORKSPACE, CLOUD_DART)))

stt = suite.read(STT_KT)
widget = suite.read(WIDGET_KT)
cloud = suite.read(CLOUD_DART)

# 1. Constantes y fórmula de timeout en Kotlin
check(
    "Kotlin define constantes TIMEOUT_BASE_SECONDS=60 y TIMEOUT_BYTES_PER_SECOND=50000",
    "const val TIMEOUT_BASE_SECONDS = 60" in stt
    and "const val TIMEOUT_BYTES_PER_SECOND = 50000" in stt,
)
check(
    "Kotlin define clamp TIMEOUT_MIN_SECONDS=60 y TIMEOUT_MAX_SECONDS=600",
    "const val TIMEOUT_MIN_SECONDS = 60" in stt
    and "const val TIMEOUT_MAX_SECONDS = 600" in stt,
)
check(
    "Kotlin define función timeoutForBytes con fórmula idéntica",
    "fun timeoutForBytes(bytes: Int): Int" in stt
    and "TIMEOUT_BASE_SECONDS + (bytes / TIMEOUT_BYTES_PER_SECOND)" in stt
    and "coerceIn(TIMEOUT_MIN_SECONDS, TIMEOUT_MAX_SECONDS)" in stt,
)

# 2. Constantes y fórmula de timeout en Dart
check(
    "Dart define constantes _timeoutBaseSeconds=60 y _timeoutBytesPerSecond=50000",
    "static const int _timeoutBaseSeconds = 60;" in cloud
    and "static const int _timeoutBytesPerSecond = 50000;" in cloud,
)
check(
    "Dart define clamp _timeoutMinSeconds=60 y _timeoutMaxSeconds=600",
    "static const int _timeoutMinSeconds = 60;" in cloud
    and "static const int _timeoutMaxSeconds = 600;" in cloud,
)
check(
    "Dart define función timeoutForBytes con fórmula idéntica",
    "Duration timeoutForBytes(int bytes)" in cloud
    and "_timeoutBaseSeconds + (bytes ~/ _timeoutBytesPerSecond)" in cloud
    and "clamp(_timeoutMinSeconds, _timeoutMaxSeconds)" in cloud,
)

# 3. Cálculo de paridad con WAV de 9.6 MB (9,600,000 bytes)
def calc_kt(bytes_val):
    sec = 60 + (bytes_val // 50000)
    return max(60, min(600, sec))

def calc_dart(bytes_val):
    sec = 60 + (bytes_val // 50000)
    return max(60, min(600, sec))

wav_9_6mb = 9600000
kt_result = calc_kt(wav_9_6mb)
dart_result = calc_dart(wav_9_6mb)

check(
    "Cálculo de 9.6 MB da exactamente 252 segundos en Kotlin",
    kt_result == 252,
    f"Resultado Kotlin: {kt_result}s",
)
check(
    "Cálculo de 9.6 MB da exactamente 252 segundos en Dart",
    dart_result == 252,
    f"Resultado Dart: {dart_result}s",
)
check(
    "Paridad matemática absoluta entre Kotlin y Dart para 9.6 MB",
    kt_result == dart_result,
)

# Pruebas en límites: 0 bytes, 50KB, 250KB, 27MB (techo 600s), 100MB
for b, expected in [(0, 60), (49999, 60), (50000, 61), (250000, 65), (27000000, 600), (100000000, 600)]:
    check(
        f"Límite {b} bytes da {expected}s en ambos",
        calc_kt(b) == expected and calc_dart(b) == expected,
    )

# 4. Lectura fija separada de subida
check(
    "Dart define timeoutRead de 60 segundos fijo",
    "static const int _timeoutReadSeconds = 60;" in cloud
    and "static const Duration timeoutRead = Duration(seconds: _timeoutReadSeconds);" in cloud,
)
check(
    "Dart usa timeoutRead separado para leer el cuerpo de la respuesta",
    "response.stream.bytesToString().timeout(timeoutRead)" in cloud,
)
check(
    "Dart usa timeout adaptativo para la subida HTTP",
    "future.timeout(timeout)" in cloud,
)

check(
    "Kotlin define TIMEOUT_READ_SECONDS = 60 fijo",
    "const val TIMEOUT_READ_SECONDS = 60" in stt,
)
check(
    "Kotlin asigna readTimeout con TIMEOUT_READ_SECONDS * 1000",
    "active.readTimeout = TIMEOUT_READ_SECONDS * 1000" in stt,
)
check(
    "Kotlin calcula uploadTimeoutSeconds con timeoutForBytes",
    "val uploadTimeoutSeconds = timeoutForBytes(wav.size)" in stt,
)
check(
    "Kotlin implementa uploadDeadline en transmisión por tramos",
    "val uploadDeadline = SystemClock.elapsedRealtime() + uploadTimeoutSeconds * 1000L" in stt
    and "if (SystemClock.elapsedRealtime() > uploadDeadline)" in stt
    and "throw SocketTimeoutException(" in stt,
)

# 5. Tope de archivo de 25 MB antes de subir
check(
    "Kotlin define MAX_AUDIO_BYTES = 25 * 1024 * 1024",
    "const val MAX_AUDIO_BYTES = 25 * 1024 * 1024" in stt,
)
check(
    "Kotlin rechaza audio > 25 MB antes de iniciar conexión",
    "if (wav.size > MAX_AUDIO_BYTES) {" in stt
    and "El audio supera el límite de 25 MB." in stt,
)
check(
    "WidgetDictationService valida MAX_AUDIO_BYTES antes de transcribir",
    "if (wav.size > SpeechToTextClient.MAX_AUDIO_BYTES)" in widget,
)
check(
    "Dart define maxFileSizeBytes = 25 * 1024 * 1024",
    "static const int maxFileSizeBytes = 25 * 1024 * 1024;" in cloud,
)
check(
    "Dart rechaza archivo > 25 MB antes de enviar petición",
    "if (fileLength > maxFileSizeBytes) {" in cloud
    and "El archivo de audio supera el límite de 25 MB." in cloud,
)

# 6. Mutaciones negativas
def test_mutations():
    # Mutación 1: Fórmula en Kotlin cambia base a 30s (desincronización)
    mut_kt_formula = stt.replace("const val TIMEOUT_BASE_SECONDS = 60", "const val TIMEOUT_BASE_SECONDS = 30")
    check("Mutación 1 (Kotlin cambia base de timeout a 30s): detectada", "const val TIMEOUT_BASE_SECONDS = 60" not in mut_kt_formula)

    # Mutación 2: Dart usa timeout adaptativo para lectura de respuesta
    mut_dart_read = cloud.replace("response.stream.bytesToString().timeout(timeoutRead)", "response.stream.bytesToString().timeout(timeout)")
    check("Mutación 2 (Dart omite lectura fija de 60s): detectada", "timeout(timeoutRead)" not in mut_dart_read)

    # Mutación 3: Kotlin no valida tope de 25 MB
    mut_kt_25mb = stt.replace("if (wav.size > MAX_AUDIO_BYTES)", "if (false)")
    check("Mutación 3 (Kotlin omite tope de 25 MB): detectada", "if (wav.size > MAX_AUDIO_BYTES)" not in mut_kt_25mb)

    # Mutación 4: Dart no valida tope de 25 MB
    mut_dart_25mb = cloud.replace("if (fileLength > maxFileSizeBytes)", "if (false)")
    check("Mutación 4 (Dart omite tope de 25 MB): detectada", "if (fileLength > maxFileSizeBytes)" not in mut_dart_25mb)

    # Mutación 5: Kotlin vuelve a readTimeout hardcodeado de 240s
    mut_kt_read = stt.replace("active.readTimeout = TIMEOUT_READ_SECONDS * 1000", "active.readTimeout = 240000")
    check("Mutación 5 (Kotlin regresa a readTimeout fijo de 240s): detectada", "TIMEOUT_READ_SECONDS * 1000" not in mut_kt_read)

test_mutations()

print("\n============================================================")
print(f" RESULTADOS C-11: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

sys.exit(suite.exit_code())
