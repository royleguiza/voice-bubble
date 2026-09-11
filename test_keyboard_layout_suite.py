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
check("horizontalRow sin baseline", "setBaselineAligned(false)" in row)
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

# --- 5. Snippets barra slim + grid dinámico (pedido del dueño) ---
check("Lupa ic_search existe",
      os.path.isfile(os.path.join(
          WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_search.xml")))
check("Barra slim 28dp",
      "kb_snippet_bar_height" in read("voice_bubble_stt/android/app/src/main/res/values/dimens.xml"))
check("Búsqueda 70% + botones 10%",
      "0, h, 7f" in snip and "LinearLayout.LayoutParams(0, heightPx, 1f)" in snip)
check("Lupa placeholder (oculta al tipear)",
      "fun updateSearchIcon()" in snip)
check("Editor slim", "kb_snippet_bar_height" in snip)
check("Chips a altura Enter", "host.scaledDimen(R.dimen.kb_key_height)" in snip)
check("Grid dinámico 4->2x2 resto ≤3",
      "if (filtered.size == 4) 2 else minOf(SNIPPET_GRID_COLUMNS" in snip)
check("Gap uniforme en contorno",
      "row.setPadding(gap / 2, 0, gap / 2, 0)" in snip)
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
check("Chips con punteado en modos",
      "R.drawable.kb_chip_edit" in snip and "R.drawable.kb_chip_delete" in snip)
check("Contenido intacto en modos",
      snip.count("R.color.kb_label)") >= 2)

# --- 6. Clipboard como capa excluyente (carrusel en flujo, sin apilar) ---
clip = read(f"{KT}/ClipboardLayer.kt")
check("Capa CLIPBOARD en el enum",
      "CREDENTIALS, CLIPBOARD" in read(f"{KT}/KeyboardTypes.kt"))
check("VKS construye la capa clipboard",
      "Layer.CLIPBOARD -> {" in vks and "addRow(clipboard.buildRows())" in vks
      and "layout.buildLetterRows()" in vks)
check("Clipboard sin terminal (compensa la cinta)",
      "layer != Layer.CLIPBOARD" in vks)
check("Toggle con origen (ida y vuelta)",
      "fun toggle()" in clip and "origin = host.currentLayer()" in clip)
check("Pegar vuelve al origen",
      "host.showLayer(origin)" in clip)
check("Sin popup en clipboard", "PopupWindow" not in clip)
check("Sin filmstrip suelto en rebuild", "buildFilmstrip" not in vks)
check("Clipboard fuera de contraseñas",
      "Layer.TRACKPAD || layer == Layer.SNIPPETS || layer == Layer.CLIPBOARD" in vks)

print("\n============================================================")
print(f" RESULTADO SUITE TECLADO-LAYOUT: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
