#!/usr/bin/env python3
"""
TEST SUITE: DICTADO POR TRAMOS (Ruta IA, etapa 3)
Verifica sobre el código REAL:
1. Corte: desde 60 s en una pausa (400 ms) o a los 90 s; dictados de hasta
   un minuto siguen siendo un solo pedido.
2. Subida en orden, de a una (un hilo), con el final del texto anterior como
   `prompt`; reintentos solo por red, límite (429) o servidor.
3. Nada se pierde: si un tramo falla se sube el audio completo y queda el
   «Reintentar» con el WAV entero.
4. Cancelar corta los tramos; el cliente nuevo libera el hilo del viejo.
5. Solo el teclado corta tramos (la burbuja y el widget, como siempre).
"""

import sys

from test_helpers import Suite

suite = Suite()
check = suite.check

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/"
tr = suite.read(KT + "DictationTranches.kt")
stt = suite.read(KT + "SpeechToTextClient.kt")
dic = suite.read(KT + "DictationController.kt")
dock = suite.read(KT + "DockDictationService.kt")
widget = suite.read(KT + "WidgetDictationService.kt")
test = suite.read("voice_bubble_stt/android/app/src/test/kotlin/com/royleguiza/voicebubblestt/DictationTranchesTest.kt")

print("\n============================================================")
print(" INICIANDO TEST SUITE: DICTADO POR TRAMOS (Ruta IA 3)")
print("============================================================\n")

# 1. Corte
check("Umbrales: 60 s con pausa de 400 ms o 90 s (hasta un minuto, igual que antes)",
      "const val MIN_SEGMENT_SECONDS = 60" in tr and "const val MAX_SEGMENT_SECONDS = 90" in tr
      and "const val SILENCE_MS = 400" in tr)
check("Corte en la captura, sin trabajo pesado en ese hilo",
      "DictationTranches.shouldCut(total - cut, quietMs)" in stt and "try { listener(segment) }" in stt
      and "@Volatile\n    var segmentListener" in stt)
check("Dictado corto: pedido único de siempre",
      "if (!tranches.hasSegments() || cut <= 0) {" in dic
      and "sttClient.transcribe(wav, config, onDone, onError)" in dic)

# 2. Orden, prompt y reintentos
check("Un solo hilo: tramos en orden, nunca en paralelo",
      "Executors.newSingleThreadExecutor" in tr)
check("Prompt con el final del texto anterior",
      "cfg.copy(prompt = prompt)" in tr
      and 'config.prompt?.takeIf { it.isNotBlank() }?.let { field("prompt", it) }' in stt)
check("Reintentos solo por red, 429 o 5xx (máx. 2)",
      "fun isRetryable(code: Int?): Boolean = code == null || code == 429 || code >= 500" in tr
      and "const val MAX_RETRIES = 2" in tr)

# 3. Nada se pierde
check("Respaldo: si un tramo falla se sube el audio completo",
      "// Respaldo: el audio completo, como antes de los tramos." in tr
      and "client.transcribe(fullWav, cfg, onDone, onError)" in tr)
check("El «Reintentar» guarda el WAV entero, no el tramo",
      "lastDictationSlot = LastDictationSlot(wav, config)" in dic
      and "SpeechToTextClient.wavTail(wav, cut)" in dic)
check("Los tramos se borran de memoria al subirse (C-35)", "pcm.fill(0)" in tr)

# 4. Cancelación y ciclo de vida
check("Cancelar corta los tramos (incluye cambio de campo)",
      dic.count("if (::tranches.isInitialized) tranches.cancel()") == 2)
check("Cliente nuevo: se cierra el hilo del anterior",
      "if (::tranches.isInitialized) tranches.close()" in dic and "worker.shutdown()" in tr)
check("Cada grabación arranca tramos nuevos", "tranches.begin(sttClient.getConfig())" in dic)

# 5. Alcance
check("Solo el teclado corta tramos",
      "segmentListener" not in dock and "segmentListener" not in widget)
check("Tests JVM de las partes puras",
      all(n in test for n in ("dictados de hasta un minuto no se cortan", "el ultimo pedazo sale del WAV completo")))

print("\n============================================================")
print(f" RESULTADO SUITE TRAMOS: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")
sys.exit(1 if suite.failed else 0)
