#!/usr/bin/env python3
"""
TEST SUITE: CONSISTENCIA VISUAL DEL TECLADO NATIVO (filas + glyphs)
Verifica al 100% de certeza sobre el código REAL:
1. Una sola línea por fila: horizontalRow sin baseline y centrado vertical.
2. Shift/borrar de Snippets a altura completa (useKeyHeight en la cadena
   SnippetsLayer.UiHost -> VKS -> KeyFactory; toolbar conserva compacto).
3. Símbolos y código en negrita (grosor consistente con letras y coma/punto).
4. Sin Log nuevo en los archivos tocados.
"""

import os
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


print("\n============================================================")
print(" INICIANDO TEST SUITE: LAYOUT TECLADO NATIVO")
print("============================================================\n")

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
kf = read(f"{KT}/KeyFactory.kt")
vks = read(f"{KT}/VoiceKeyboardService.kt")
snip = read(f"{KT}/SnippetsLayer.kt")
toolbar = read(f"{KT}/ToolbarLayer.kt")

# --- 1. Una sola línea por fila ---
row = kf.split("fun horizontalRow()")[1].split("\n    fun ")[0]
check("horizontalRow sin baseline", "baselineAligned = false" in row)
check("horizontalRow centrado vertical", "Gravity.CENTER_VERTICAL" in row)

# --- 2. Altura completa en Snippets ---
check("KeyFactory.makeIconKey con useKeyHeight",
      "useKeyHeight: Boolean = false" in kf and "host.keyHeightPx()" in kf)
check("VKS propaga useKeyHeight",
      "useKeyHeight: Boolean" in vks and "useKeyHeight, onClick" in vks)
check("SnippetsLayer.UiHost expone useKeyHeight",
      "useKeyHeight: Boolean = false" in snip)
check("Toolbar conserva firma compacta (VKS la adapta)",
      "useKeyHeight" not in toolbar
      and vks.count("override fun makeIconKey(") == 2)
check("Shift de Snippets a altura completa",
      "useKeyHeight = true" in snip.split("host.toggleShiftKey()")[0][-600:])
check("Borrar de Snippets a altura completa",
      snip.count("useKeyHeight = true") >= 2,
      "shift y borrar deben usar altura completa")
check("Toolbar conserva compacto 38dp",
      "38f" in kf and "useKeyHeight = true" not in toolbar)

# --- 3. Grosor de glyphs ---
sym = kf.split("fun makeSymbolKey(")[1].split("\n    fun ")[0] if "fun makeSymbolKey(" in kf else kf.split("fun makeSymbolKey(")[1][:600]
check("Símbolos en negrita por defecto", "isBold: Boolean = true" in kf)
code = kf.split("fun makeCodeKey(")[1].split("\n    fun ")[0]
check("Código en negrita", "isBold = true" in code)
check("Coma/punto siguen negrita 19sp",
      "kb_key_glyph_punct" in read(f"{KT}/LayoutLayer.kt"))

# --- 4. Sin logs (llamadas reales, no menciones en KDoc) ---
import re
for name, src in [("KeyFactory", kf), ("SnippetsLayer", snip), ("ToolbarLayer", toolbar)]:
    check(f"Sin Log en {name}", not re.search(r"\bLog\.[dvwie]", src))

# --- 5. Snippets compacta (lab): 4 cuartos + lupa + punteados ---
check("Lupa ic_search existe",
      os.path.isfile(os.path.join(
          WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_search.xml")))
check("Dibujable kb_chip_edit existe",
      os.path.isfile(os.path.join(
          WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/kb_chip_edit.xml")))
check("Dibujable kb_chip_delete existe",
      os.path.isfile(os.path.join(
          WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/kb_chip_delete.xml")))
for dw, color in [("kb_chip_edit.xml", "kb_key_bg_accent"), ("kb_chip_delete.xml", "kb_recording")]:
    raw = read(f"voice_bubble_stt/android/app/src/main/res/drawable/{dw}")
    check(f"{dw} punteado", "dashWidth" in raw and "dashGap" in raw, f"sin dash en {dw}")
    check(f"{dw} trazo {color}", color in raw)
check("Fila arranca colapsada (searchOpen=false)",
      "private var searchOpen = false" in snip)
check("Lupa alterna con morph", "fun toggleSearch()" in snip and "ChangeBounds" in snip)
check("Tipeo abre la lupa", "fun ensureSearchMode()" in snip and "searchOpen = true" in snip)
check("Salir colapsa", "fun exitSearchMode()" in snip and "searchOpen = false" in snip)
check("Chips con punteado en modos",
      "R.drawable.kb_chip_edit" in snip and "R.drawable.kb_chip_delete" in snip)
check("Contenido intacto en modos",
      snip.count("R.color.kb_label)") >= 2)

print("\n============================================================")
print(f" RESULTADO SUITE TECLADO-LAYOUT: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
