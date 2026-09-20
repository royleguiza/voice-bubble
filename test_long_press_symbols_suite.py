#!/usr/bin/env python3
"""
TEST SUITE: PULSACIÓN LARGA DE SÍMBOLOS Y TILDES (MEJ-05)
Verifica sobre el código REAL:
1. Tablas: symbolsFor('.' / ',') exactas + accentsFor con subset MEJ-05
   (a/e/i/o/u/n) + longPressDelayMillis (250/350/450).
2. Prefs: KeyboardPrefs con kb_long_press_symbols (default true) +
   kb_long_press_delay (default normal, tolerante) + longPressDelayMs.
3. Popup: AccentLayer.attachSymbol + showSymbolsPopup + showOptionsPopup
   con deslizamiento (MOVE resalta, UP comite, primera = default) + sin Log.
4. Cableado: KeyFactory.attachSymbolKey + makeSymbolKey con popup solo en
   coma/punto + delay configurable en longPress() + VKS implementa el host.
5. Puente: docs/contract-keys.txt + StorageService.bridgeKeys (45) con
   getters/setters validados + UI Ajustes (switch + segmented con Keys).
6. Privacidad: sin Log de contenido, sin getSurroundingText en el menú.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


print("\n============================================================")
print(" INICIANDO TEST SUITE: PULSACIÓN LARGA (MEJ-05)")
print("============================================================\n")

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
ks = read(f"{KT}/KeyboardSupport.kt")
kp = read(f"{KT}/KeyboardPrefs.kt")
ac = read(f"{KT}/AccentLayer.kt")
kf = read(f"{KT}/KeyFactory.kt")
vks = read(f"{KT}/VoiceKeyboardService.kt")

# --- 1. Tablas puras ---
check("KeyboardSupport.kt existe", True)
check("symbolsFor('.') exacta [;, :, ..., !, ?, /]",
      '".", "..."' not in ks and "'.' -> listOf(\";\", \":\", \"...\", \"!\", \"?\", \"/\")" in ks,
      "tabla del punto rota")
check("symbolsFor(',') exacta [:, ;, _, -, \\]",
      "',' -> listOf(\":\", \";\", \"_\", \"-\", \"\\\\\")" in ks,
      "tabla de la coma rota")
check("symbolsFor default vacío", "else -> emptyList()" in ks)
check("accents a cubre á/à/â/ä", all(s in ks for s in ['"á"', '"à"', '"â"', '"ä"']))
check("accents e cubre é/è/ê/ë", all(s in ks for s in ['"é"', '"è"', '"ê"', '"ë"']))
check("accents i cubre í/ì/î/ï", all(s in ks for s in ['"í"', '"ì"', '"î"', '"ï"']))
check("accents o cubre ó/ò/ô/ö", all(s in ks for s in ['"ó"', '"ò"', '"ô"', '"ö"']))
check("accents u cubre ú/ù/û/ü", all(s in ks for s in ['"ú"', '"ù"', '"û"', '"ü"']))
check("accents n cubre ñ", '"ñ"' in ks)
check("Delays 250/350/450", all(s in ks for s in ["250L", "350L", "450L"]))
check("longPressDelayMillis rapido->250", "LONG_PRESS_DELAY_RAPIDO -> LONG_PRESS_DELAY_RAPIDO_MS" in ks)
check("longPressDelayMillis relajado->450", "LONG_PRESS_DELAY_RELAJADO -> LONG_PRESS_DELAY_RELAJADO_MS" in ks)
check("longPressDelayMillis default normal", "else -> LONG_PRESS_DELAY_NORMAL_MS" in ks)

# --- 2. Prefs Kotlin ---
check("Prefs: flag kb_long_press_symbols", '"flutter.kb_long_press_symbols"' in kp)
check("Prefs: default ON (true)", "longPressSymbolsEnabled = true" in kp)
check("Prefs: clave kb_long_press_delay", '"flutter.kb_long_press_delay"' in kp)
check("Prefs: default normal", "LONG_PRESS_DELAY_NORMAL" in kp)
check("Prefs: parseo tolerante delay", "takeIf { it ==" in kp and "LONG_PRESS_DELAY_RAPIDO" in kp)
check("Prefs: expone longPressDelayMs", "longPressDelayMs = longPressDelayMillis(longPressDelay)" in kp)
check("Prefs: sin Log", "Log." not in kp)

# --- 3. Popup compartido con deslizamiento ---
check("AccentLayer.attachSymbol existe", "fun attachSymbol(" in ac)
check("attachSymbol respeta switch OFF (tap plano)", "if (!enabled())" in ac)
check("showSymbolsPopup existe", "fun showSymbolsPopup(" in ac)
check("showOptionsPopup compartido existe", "fun showOptionsPopup(" in ac)
check("Popup: tap comite opción", "host.commitText(opt)" in ac or "host.commitText(text)" in ac)
check("Popup: MOVE resalta bajo el dedo", "ACTION_MOVE" in ac and "childAt(ev.x, ev.y)" in ac)
check("Popup: UP comite resaltada o primera (default)",
      "?: highlighted ?:" in ac and "box.getChildAt(0)" in ac)
check("Popup: Y jamás negativo (AT-A12 intacto)", "maxOf(gap, loc[1]" in ac)
check("Popup: import MotionEvent", "import android.view.MotionEvent" in ac)
check("Sin Log de contenido en popup",
      "android.util.Log" not in ac and "Log.d(" not in ac and "Log.i(" not in ac and "Log.e(" not in ac)
check("Sin lectura de documento en popup",
      "getSurroundingText" not in ac and "getTextBeforeCursor" not in ac)

# --- 4. Cableado KeyFactory + VKS ---
check("KeyFactory.UiHost exige attachSymbolKey", "fun attachSymbolKey(" in kf)
check("KeyFactory.UiHost exige isLongPressSymbolsEnabled", "fun isLongPressSymbolsEnabled()" in kf)
check("KeyFactory.UiHost exige longPressDelayMs", "fun longPressDelayMs(): Long" in kf)
check("longPress() usa delay configurable",
      "host.longPressDelayMs()" in kf, "sigue fijo en LONG_PRESS_MILLIS")
check("makeSymbolKey con popup en coma/punto",
      "symbolsFor(base).isNotEmpty()" in kf and "host.attachSymbolKey(key, base, commit)" in kf)
check("makeSymbolKey: resto tap plano", "host.attachTap(key, commit)" in kf)
check("Tag gap-tolerante conserva tap", "key.tag = commit" in kf)
check("VKS implementa attachSymbolKey", "override fun attachSymbolKey(" in vks)
check("VKS implementa isLongPressSymbolsEnabled", "override fun isLongPressSymbolsEnabled()" in vks)
check("VKS implementa longPressDelayMs", "override fun longPressDelayMs()" in vks)
check("VKS lee prefs con fallback seguro", "kbPrefs.longPressDelayMs" in vks)

# --- 5. Puente Dart + contrato + UI ---
contract = read("docs/contract-keys.txt").splitlines()
check("Contrato incluye kb_long_press_symbols", "kb_long_press_symbols" in contract)
check("Contrato incluye kb_long_press_delay", "kb_long_press_delay" in contract)
check("Contrato ordenado", contract == sorted(contract), "rompe fuente de verdad")
dart = read("app_source/lib/services/storage_service.dart")
check("Dart: const kbLongPressSymbolsKey", "kbLongPressSymbolsKey = 'kb_long_press_symbols'" in dart)
check("Dart: const kbLongPressDelayKey", "kbLongPressDelayKey = 'kb_long_press_delay'" in dart)
check("Dart: defaults true + normal",
      "defaultLongPressSymbols = true" in dart and "defaultLongPressDelay = 'normal'" in dart)
check("Dart: bridgeKeys incluye las 2", "kbLongPressDelayKey," in dart and "kbLongPressSymbolsKey," in dart)
tab = read("app_source/lib/screens/settings/teclado_tab.dart")
check("UI: switch con Key", "kb-long-press-symbols-switch" in tab)
check("UI: segmented delay con Key", "kb-long-press-delay-selector" in tab)
check("UI: textos Rápido/Normal/Relajado",
      all(s in tab for s in ["'Rápido'", "'Normal'", "'Relajado'"]) or
      all(s in tab for s in ["Rápido", "Normal", "Relajado"]))
screen = read("app_source/lib/screens/settings_screen.dart")
check("Settings carga switch", "getLongPressSymbolsEnabled()" in screen)
check("Settings carga delay", "getLongPressDelay()" in screen)
check("Settings guarda switch", "setLongPressSymbolsEnabled(" in screen)
check("Settings guarda delay", "setLongPressDelay(" in screen)

print("\n============================================================")
print(f" RESULTADO SUITE LONG-PRESS: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
