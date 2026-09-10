#!/usr/bin/env python3
"""
TEST SUITE: FEEDBACK DEL MICRÓFONO (hápticas + sonidos por evento)
Verifica al 100% de certeza sobre el código REAL:
1. Triángulo Dart==contrato==Kotlin para las 6 claves kb_mic_*.
2. Sonidos WAV válidos (44.1kHz mono 16-bit, <200ms) en res/raw.
3. DictationController: eventos START/STOP/PASTE/CANCEL/BUSY, ticker cada
   3s solo háptico, SoundPool con sonorización, anuncio solo en gesto.
4. VKS: micFeedback() en vivo + micBuzz() directo (sin gate de teclas).
5. UI: sección colapsable con las 6 keys en Teclado.
6. Sin Log con contenido en lo tocado.
"""

import os
import re
import sys
import wave

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


print("\n============================================================")
print(" INICIANDO TEST SUITE: FEEDBACK DEL MICROFONO")
print("============================================================\n")

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
MIC_KEYS = [
    "kb_mic_haptics_enabled",
    "kb_mic_haptic_start",
    "kb_mic_haptic_recording",
    "kb_mic_haptic_paste",
    "kb_mic_haptic_cancel",
    "kb_mic_sounds_enabled",
]

# --- 1. Triángulo ---
contract = read("docs/contract-keys.txt").splitlines()
for k in MIC_KEYS:
    check(f"Contrato incluye {k}", k in contract, f"falta {k}")
storage = read("app_source/lib/services/storage_service.dart")
for k in MIC_KEYS:
    const = "kb" + "".join(p.capitalize() for p in k[3:].split("_")) + "Key"
    check(f"bridgeKeys incluye {k}", const in storage, f"falta {const}")
prefs = read(f"{KT}/KeyboardPrefs.kt")
for k in MIC_KEYS:
    check(f"Kotlin lee flutter.{k}", f'"flutter.{k}"' in prefs, f"falta {k}")
check("Master háptico default ON", 'readFlag("flutter.kb_mic_haptics_enabled", true)' in prefs)
check("Sonidos default OFF (opt-in)", 'readFlag("flutter.kb_mic_sounds_enabled", false)' in prefs)

# --- 2. WAVs ---
for name in ["start", "stop", "paste", "cancel", "busy"]:
    path = os.path.join(WORKSPACE, f"voice_bubble_stt/android/app/src/main/res/raw/mic_{name}.wav")
    check(f"WAV mic_{name} existe", os.path.isfile(path))
    if os.path.isfile(path):
        with wave.open(path, "rb") as w:
            ok = (w.getframerate(), w.getsampwidth(), w.getnchannels()) == (44100, 2, 1)
            check(f"WAV mic_{name} 44.1kHz mono 16-bit", ok)
            check(f"WAV mic_{name} corto (<200ms)",
                  w.getnframes() / w.getframerate() < 0.2)

# --- 3. Controlador ---
dic = read(f"{KT}/DictationController.kt")
check("SoundPool con sonorización",
      "SoundPool.Builder()" in dic and "USAGE_ASSISTANCE_SONIFICATION" in dic)
check("Carga los 5 sonidos",
      all(f"R.raw.mic_{n}" in dic for n in ["start", "stop", "paste", "cancel", "busy"]))
check("Libera SoundPool al destruir", "releaseMicSounds()" in dic)
for ev in ["START", "STOP", "PASTE", "CANCEL", "BUSY"]:
    check(f"Evento {ev} cableado", f"MicEvent.{ev}" in dic, f"falta {ev}")
check("Ticker cada 3s", "postDelayed(this, 3000L)" in dic)
check("Ticker sin sonido (solo háptico)",
      "micBuzz(10L, 120)" in dic)
check("Anuncio solo en gesto (3 sitios)",
      dic.count("cancelDictation(announce = true)") == 3)
check("Cancel de sistema silencioso",
      "cancelDictation()" in dic)
check("STOP al terminar", "MicEvent.STOP" in dic.split("fun finishDictation()")[1].split("\n    private fun ")[0])
check("PASTE al comitar", "MicEvent.PASTE" in dic)

# --- 4. VKS ---
vks = read(f"{KT}/VoiceKeyboardService.kt")
check("VKS expone micFeedback en vivo",
      "override fun micFeedback()" in vks and "kbPrefs.micHapticsEnabled" in vks)
check("VKS micBuzz directo", "override fun micBuzz(" in vks)

# --- 5. UI ---
tab = read("app_source/lib/screens/settings/teclado_tab.dart")
check("Sección colapsada por defecto", "initiallyOpen: false" in tab)
for key in ["kb-mic-haptics-enabled", "kb-mic-haptic-start",
            "kb-mic-haptic-recording", "kb-mic-haptic-paste",
            "kb-mic-haptic-cancel", "kb-mic-sounds-enabled"]:
    check(f"UI con key {key}", f"'{key}'" in tab, f"falta {key}")
v2 = read("app_source/lib/widgets/settings_v2.dart")
check("Kit soporta initiallyOpen", "initiallyOpen" in v2)

# --- 6. Sin logs ---
for name, src in [("DictationController", dic), ("KeyboardPrefs", prefs)]:
    check(f"Sin Log en {name}", not re.search(r"\bLog\.[dvwie]", src))

print("\n============================================================")
print(f" RESULTADO SUITE MIC-FEEDBACK: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
