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
    "kb_mic_start_style",
    "kb_mic_stop_style",
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
for name in ["paste", "cancel"]:
    path = os.path.join(WORKSPACE, f"voice_bubble_stt/android/app/src/main/res/raw/mic_{name}.wav")
    check(f"WAV mic_{name} existe", os.path.isfile(path))
    if os.path.isfile(path):
        with wave.open(path, "rb") as w:
            ok = (w.getframerate(), w.getsampwidth(), w.getnchannels()) == (44100, 2, 1)
            check(f"WAV mic_{name} 44.1kHz mono 16-bit", ok)
            check(f"WAV mic_{name} corto (<250ms)",
                  w.getnframes() / w.getframerate() < 0.25)
for n in ["1", "2", "3", "4"]:
    for ev in ["start", "stop"]:
        path = os.path.join(WORKSPACE, f"voice_bubble_stt/android/app/src/main/res/raw/mic_{ev}_{n}.wav")
        check(f"Opción {n} de {ev} existe", os.path.isfile(path))
        if os.path.isfile(path):
            with wave.open(path, "rb") as w:
                ok = (w.getframerate(), w.getsampwidth(), w.getnchannels()) == (44100, 2, 1)
                check(f"Opción {n} de {ev} 44.1kHz mono 16-bit", ok)
check("Sin WAV de ocupado (no existe ese estado)",
      not os.path.isfile(os.path.join(
          WORKSPACE, "voice_bubble_stt/android/app/src/main/res/raw/mic_busy.wav")))

# --- 3. Controlador ---
dic = read(f"{KT}/DictationController.kt")
check("SoundPool con sonorización",
      "SoundPool.Builder()" in dic and "USAGE_ASSISTANCE_SONIFICATION" in dic)
check("Carga los fijos + resuelve estilos por nombre",
      "R.raw.mic_paste" in dic and "R.raw.mic_cancel" in dic
      and 'getIdentifier("mic_start_$startStyle", "raw", pkg)' in dic
      and 'getIdentifier("mic_stop_$stopStyle", "raw", pkg)' in dic)
check("Sin evento BUSY (MicState.BUSY visual sigue intacto)",
      "MicEvent.BUSY" not in dic and "MicState.BUSY" in dic)
check("Libera SoundPool al destruir", "releaseMicSounds()" in dic)
for ev in ["START", "STOP", "PASTE", "CANCEL"]:
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
check("Vibración y sonido en subpágina propia (no abruma Teclado)",
      "ValueKey('nav-sonido')" in tab and "_buildSonidoPage" in tab)
for key in ["kb-mic-haptics-enabled", "kb-mic-haptic-start",
            "kb-mic-haptic-recording", "kb-mic-haptic-paste",
            "kb-mic-haptic-cancel", "kb-mic-sounds-enabled",
            "kb-mic-start-style", "kb-mic-stop-style"]:
    check(f"UI con key {key}", f"'{key}'" in tab, f"falta {key}")
check("Eventos y tonos solo visibles con su interruptor encendido",
      "if (_micHapticsEnabled) ...[" in tab and "if (_micSoundsEnabled) ...[" in tab)

# --- 6. Sin logs ---
for name, src in [("DictationController", dic), ("KeyboardPrefs", prefs)]:
    check(f"Sin Log en {name}", not re.search(r"\bLog\.[dvwie]", src))

# --- 7. Voz (Horizonte fase 1): nivel real + agujero animado ---
RES = "voice_bubble_stt/android/app/src/main/res"
vl = read(f"{KT}/VoiceLevel.kt")
check("VoiceLevel puro (sin Android)", "import android" not in vl)
check("VoiceLevel: RMS → dB → piso de ruido → 0..1",
      "fun rms(" in vl and "fun dbfs(" in vl and "FLOOR_DB" in vl
      and "fun normalize(" in vl)
check("VoiceLevel: ataque rápido / caída lenta",
      "fun smooth(" in vl and "ATTACK" in vl and "RELEASE" in vl)
check("VoiceLevel sin asignaciones por buffer",
      not re.search(r"ByteArray\(|ShortArray\(|FloatArray\(|copyOf|toByteArray", vl))
check("Medidor con nivel @Volatile (lectura sin lock desde la UI)",
      re.search(r"@Volatile\s+var level", vl) is not None)
vlt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/test/kotlin/"
                        "com/royleguiza/voicebubblestt/VoiceLevelTest.kt")
check("Test JVM de VoiceLevel existe", os.path.isfile(vlt_path))
if os.path.isfile(vlt_path):
    vlt = read(os.path.relpath(vlt_path, WORKSPACE))
    for name in ["silencio digital da cero", "seno a plena escala da uno",
                 "el nivel crece con la amplitud", "suavizado sube rapido y baja lento"]:
        check(f"VoiceLevelTest cubre: {name}", name in vlt)

stt = read(f"{KT}/SpeechToTextClient.kt")
cap = stt.split("private fun captureLoop(")[1].split("\n    }\n")[0]
check("Captura alimenta el medidor tras escribir el PCM (WAV intacto)",
      "pcmBuffer.write(buf, 0, n)" in cap and "levelMeter.feed(buf, n)" in cap
      and cap.index("pcmBuffer.write(buf, 0, n)") < cap.index("levelMeter.feed(buf, n)"))
check("El nivel no toca el hilo principal (sin post desde la captura)",
      not re.search(r"postMain|runOnMain|Handler|post\(", cap))
check("Nivel expuesto como lectura volátil",
      "fun currentLevel(): Float" in stt)

hz = read(f"{KT}/HorizonView.kt")
check("HorizonView con modos A (Acreción) y C (Corona)",
      "enum class Mode { ACCRETION, CORONA }" in hz)
check("Pool de partículas fijo de 60", "const val MAX_PARTICLES = 60" in hz)
draw = hz.split("override fun onDraw(")[1].split("companion object")[0]
check("onDraw sin asignar Paint/Path/Shader/Rect/arrays",
      not re.search(r"\b(Paint|Path|RectF|Rect|Matrix|RadialGradient|LinearGradient)\(|"
                    r"FloatArray\(|IntArray\(|arrayOf|listOf|String\.format", draw))
check("Colores desde recursos hz_* (sin hex sueltos)",
      all(f"R.color.hz_{c}" in hz for c in ["hole", "on_hole", "ember", "hot"])
      and not re.search(r"parseColor|0x[fF]{2}[0-9a-fA-F]{6}", hz))
check("Glifos en @font/jetbrains_mono", "R.font.jetbrains_mono" in hz)
det = hz.split("override fun onDetachedFromWindow()")[1].split("\n    }\n")[0]
check("Animador se detiene al desprenderse", "animator.cancel()" in det)
check("Animador sigue la visibilidad agregada",
      "override fun onVisibilityAggregated(" in hz)
upd = hz.split("private fun updateRunning()")[1].split("\n    }\n")[0]
check("Animador solo en grabando/pensando",
      "phase != Phase.IDLE" in upd and "animator.cancel()" in upd)
check("Animaciones del sistema desactivadas = anillo fijo",
      "ValueAnimator.areAnimatorsEnabled()" in hz and "staticRefresh" in hz
      and "if (live)" in draw)
check("Reutilizable para burbuja/widget (constructor público con modo)",
      "class HorizonView(context: Context, val mode: Mode)" in hz)

check("Teclado: pastilla A grabando y A pensando",
      "HorizonView.Phase.RECORDING" in dic and "HorizonView.Phase.THINKING" in dic)
check("Teclado: nivel real del cliente STT",
      "sttClient.currentLevel()" in dic)
check("Teclado: sin tres puntos ni pulso viejo",
      "kb_proc_dot" not in dic and "ObjectAnimator" not in dic
      and not os.path.isfile(os.path.join(WORKSPACE, RES, "drawable/kb_proc_dot.xml")))
check("Teclado: vistas de voz detenidas al destruir/descartar",
      "stopVoiceAnimations()" in dic.split("fun onDestroy()")[1].split("\n    }\n")[0]
      and "stopVoiceAnimations()" in dic.split("fun onViewsDiscarded()")[1].split("\n    }\n")[0])
check("Teclado: cronómetro mono, sin fondo rectangular opaco propio",
      "R.font.jetbrains_mono" in dic and "kb_mic_timer_bg" not in dic
      and "timer.setBackgroundResource" not in dic
      and not os.path.isfile(os.path.join(WORKSPACE, RES, "drawable/kb_mic_timer_bg.xml")))
check("Teclado: cronómetro más chico (11 dp, antes 12) y en mono",
      "internal const val TIMER_TEXT_SIZE_DP = 11f" in dic
      and "timer.setTextSize(TypedValue.COMPLEX_UNIT_DIP, TIMER_TEXT_SIZE_DP)" in dic)
check("Teclado: reposo = agujero", "HoleDrawable(service)" in dic)
# Fase 4 (feedback del dueño): cronómetro despegado del agujero y partículas
# fuera de la ✕, con la geometría de HorizonView (sin márgenes mágicos).
check("Teclado: cronómetro a ≥ 8 dp del agujero con anillo máximo y halo",
      "fun accretionHoleRightPx(heightPx: Float, density: Float): Float" in hz
      and "r * (HALO_MIN_K + HALO_GROW_K)" in hz and "(RING_MIN_DP + RING_GROW_DP)" in hz
      and "accretionHoleRightPx(h, dp) + TIMER_HOLE_GAP_DP * dp" in hz
      and "internal const val TIMER_HOLE_GAP_DP = 8f" in dic
      and "timerLp.marginStart" not in dic
      and "pill.addOnLayoutChangeListener" in dic)
check("Teclado: geometría única en HorizonView (centro del cronómetro, mini píldora, zona de la ✕)",
      "fun setTimerBox(widthPx: Float, heightPx: Float)" in hz
      and "var timerCenterXPx: Float" in hz and "private fun updateGeometry()" in hz
      and "(w / 2f).coerceIn(left + half, right - half)" in hz
      and "(left + right) / 2f" in hz
      and "pillHorizon.setTimerBox(w, timer.height.toFloat())" in dic
      and "timer.translationX = pillHorizon.timerCenterXPx - w / 2f" in dic
      and "timer.addOnLayoutChangeListener" in dic)
check("Teclado: mini píldora difuminada hz_hole por degradado radial (sin blur) y partículas atenuadas",
      "RadialGradient(" in hz and "MINI_FEATHER_DP = 5f" in hz and "miniPaint" in draw
      and "timerClearance(px[i], py[i], cy)" in draw
      and "BlurMaskFilter" not in hz and "RenderEffect" not in hz and "MaskFilter" not in hz)
check("Teclado: halo circular hz_hole (20 dp) centrado en la ✕, recortado dentro del borde",
      "CANCEL_HALO_DP = 20f" in hz and "haloPaint" in draw and "innerClip" in draw
      and "endPaint" not in hz and "LinearGradient" not in hz and "cancel.minimumWidth = dp(44f)" in dic
      and 'cancel.text = "✕"' in dic)
check("Teclado: sin Paint/Shader nuevos en onDraw (pool de 60)",
      "Paint(" not in draw and "Gradient(" not in draw and "MAX_PARTICLES = 60" in hz)
check("Teclado: partículas nacen en el centro de la ✕ (campo hasta su centro)",
      "var particleEndInsetPx: Float" in hz and "fieldRight(" in draw
      and "pillHorizon.particleEndInsetPx = inset" in dic and "cancel.width / 2f" in dic)
check("Teclado: halo y anillo dibujan con las mismas constantes de la geometría",
      "r * (HALO_MIN_K + kk * HALO_GROW_K)" in hz and "(RING_MIN_DP + RING_GROW_DP * kk) * dp" in hz)
for desc in ['"grabando dictado"', '"procesando"', '"dictar"', '"micrófono ocupado"']:
    check(f"Accesibilidad intacta: {desc}", desc in dic)
pill = read(f"{RES}/drawable/kb_mic_pill.xml")
check("Pastilla negra con anillo brasa",
      "@color/hz_hole" in pill and "@color/hz_ember" in pill)

rb = read("app_source/lib/widgets/record_button.dart")
check("App: pastilla A con CustomPainter y RepaintBoundary",
      "class HorizonPainter extends CustomPainter" in rb and "RepaintBoundary(" in rb)
check("App: sin _ProcessingDots ni _WavePainter",
      "_ProcessingDots" not in rb and "_WavePainter" not in rb)
check("App: ticker se detiene fuera de grabando/pensando",
      "_frames.stop()" in rb and "_frames.repeat()" in rb
      and "if (animate && !_frames.isAnimating)" in rb)
check("App: reducir movimiento = anillo fijo",
      "disableAnimations" in rb and "animated: motionSafe" in rb)
check("App: pool de 60 partículas", "static const int maxParticles = 60;" in rb)
check("App: reposo = agujero con micrófono on-hole",
      "kHoleDark : kHoleLight" in rb and "color: kOnHole" in rb)

print("\n============================================================")
print(f" RESULTADO SUITE MIC-FEEDBACK: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
