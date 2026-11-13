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
check("Chips a altura compacta 40dp", "host.scaledDimen(R.dimen.kb_snippet_chip_height)" in snip)
# Horizonte fase 2: el nombre del chip pasa de bold a JetBrains Mono medium
# (mismo tamaño 16sp firmado por el dueño).
check("Chips 16sp mono medium", "kb_snippet_chip_text_size" in snip
      and "KbFonts.mono(service, KeyFactory.MONO_LABEL_WEIGHT)" in snip)
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
for dw, color in [("kb_chip_edit.xml", "kb_key_bg_accent"), ("kb_chip_delete.xml", "kb_danger")]:
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

# --- 7. Horizonte fase 2: barra sin cajas, teclas, paneles ---
RES = "voice_bubble_stt/android/app/src/main/res"
dimens = read(f"{RES}/values/dimens.xml")
colors_l = read(f"{RES}/values/colors.xml")
colors_n = read(f"{RES}/values-night/colors.xml")
tool_fn = toolbar.split("private fun makeTool(")[1].split("\n    private fun ")[0] if "private fun makeTool(" in toolbar else ""
build_tb = toolbar.split("fun buildToolbar()")[1].split("return row")[0]
check("Toolbar: herramientas por makeTool (sin cajas)",
      build_tb.count("makeTool(") >= 8 and "host.makeIconKey(" not in build_tb
      and "kb_key_alt" not in build_tb and "kb_key_accent" not in build_tb,
      "ninguna herramienta debe usar fondo de tecla")
check("Toolbar: reposo sin fondo e ícono hz_fg2, activa ember-soft + ember-t",
      "R.drawable.kb_tool_active else R.drawable.kb_tool" in tool_fn
      and "R.color.hz_ember_t else R.color.hz_fg2" in tool_fn)
check("Toolbar: activa = panel abierto (snippets, claves, portapapeles, código, trackpad)",
      all(f"host.currentLayer() == Layer.{l}" in build_tb for l in ("SNIPPETS", "CREDENTIALS", "CLIPBOARD", "CODE"))
      and "isTp," in build_tb)
check("Toolbar: target táctil >= 44dp (kb_tool_min_target) a todo el alto",
      '<dimen name="kb_tool_min_target">44dp</dimen>' in dimens
      and "maxOf(host.dimenPx(R.dimen.kb_tool_min_target)" in toolbar
      and "lp.height = toolTargetPx()" in tool_fn and "lp.topMargin = 0" in tool_fn
      and "lp.bottomMargin = 0" in tool_fn)
check("Toolbar: mismas descripciones y orden invertible",
      all(d in toolbar for d in ('"fragmentos"', '"credenciales"', '"ajustes"', '"fila terminal"',
                                 '"portapapeles"', '"capa código"', '"trackpad"', '"mini-teclado"',
                                 '"teclado completo"'))
      and "items.reverse()" in toolbar)
for dw in ("kb_tool.xml", "kb_tool_active.xml"):
    raw = read(f"{RES}/drawable/{dw}")
    check(f"{dw}: presionado visible (kb_key_pressed) y radio kb_tool_radius",
          'state_pressed="true"' in raw and "kb_key_pressed" in raw and "@dimen/kb_tool_radius" in raw
          and "<stroke" not in raw)
check("kb_tool.xml: reposo transparente", "@android:color/transparent" in read(f"{RES}/drawable/kb_tool.xml"))
check("kb_tool_active.xml: ember-soft", "@color/hz_ember_soft" in read(f"{RES}/drawable/kb_tool_active.xml"))
check("Radio de herramienta 10dp", '<dimen name="kb_tool_radius">10dp</dimen>' in dimens)
import re as _re
for icon in ("ic_snippets", "ic_settings", "ic_paste", "ic_code", "ic_key", "ic_keyboard",
             "ic_trackpad", "ic_terminal", "ic_micro_collapse", "ic_micro_expand"):
    raw = read(f"{RES}/drawable/{icon}.xml")
    n = raw.count("strokeWidth=")
    check(f"{icon}: trazo 1.8 redondeado sobre viewport 24",
          'android:viewportWidth="24"' in raw and n >= 1
          and set(_re.findall(r'strokeWidth="([0-9.]+)"', raw)) == {"1.8"}
          and raw.count('strokeLineCap="round"') == n and raw.count('strokeLineJoin="round"') == n)
    fills = [f for f in _re.findall(r'fillColor="([^"]+)"', raw) if f != "#00000000"]
    check(f"{icon}: sin rellenos salvo la barra de mini",
          (len(fills) == 1) if icon == "ic_micro_collapse" else not fills, f"rellenos: {fills}")
check("Ajustes = deslizadores (path set)", "M4,7h9M19,7h1M4,17h1M11,17h9" in read(f"{RES}/drawable/ic_settings.xml"))
check("Snippets = renglones (path menu)", "M4,7h16M4,12h16M4,17h16" in read(f"{RES}/drawable/ic_snippets.xml"))
check("Código = chevrones (path code)", "M9,8l-4,4 4,4M15,8l4,4 -4,4" in read(f"{RES}/drawable/ic_code.xml"))
check("Llave (path key)", "M11.5,12H21M17,12v3M20.5,12v2" in read(f"{RES}/drawable/ic_key.xml"))

# Teclas: sólidas, radio 7, sin borde perimetral; línea inferior solo en claro.
for dw, fill in (("kb_key_bg.xml", "kb_key_bg"), ("kb_key_alt.xml", "kb_key_bg_alt"),
                 ("kb_key_accent.xml", "kb_key_bg_accent")):
    raw = read(f"{RES}/drawable/{dw}")
    check(f"{dw}: sólida radio 7dp sin borde", f"@color/{fill}" in raw and "@dimen/kb_key_radius" in raw
          and "<stroke" not in raw)
    check(f"{dw}: línea inferior kb_key_shadow + presionado conservado",
          raw.count("@color/kb_key_shadow") == 2 and 'state_pressed="true"' in raw
          and raw.count('android:bottom="@dimen/kb_key_shadow_height"') == 2)
check("kb_key_shadow: kb_key_stroke en claro, transparente en oscuro",
      '<color name="kb_key_shadow">@color/kb_key_stroke</color>' in colors_l
      and '<color name="kb_key_shadow">#00000000</color>' in colors_n)
mk = kf.split("fun makeKey(")[1]
check("Teclas: alt en JetBrains Mono medium, resto en Inter",
      "bgRes == R.drawable.kb_key_alt" in mk and "KbFonts.mono(service, MONO_LABEL_WEIGHT)" in mk
      and "KbFonts.body(service, strong = isBold)" in mk and "MONO_LABEL_WEIGHT = 500" in kf)
sup = read(f"{KT}/KeyboardSupport.kt")
check("KbFonts usa las fuentes empaquetadas con respaldo",
      "R.font.inter" in sup and "R.font.jetbrains_mono" in sup and "Typeface.MONOSPACE" in sup)
check("Enter en brasa con glifo on-accent",
      "R.drawable.kb_key_accent" in read(f"{KT}/LayoutLayer.kt")
      and "R.color.kb_label_on_accent" in read(f"{KT}/LayoutLayer.kt"))

# Snippets: buscador surf2 + botones sueltos; borrar en rojo solo activo.
check("Buscador de snippets sobre hz_surf2",
      "R.drawable.kb_search_bg" in snip and "@color/kb_key_bg" in read(f"{RES}/drawable/kb_search_bg.xml"))
mv = snip.split("private fun updateModeVisuals()")[1].split("\n    private fun ")[0]
check("+ / editar / borrar como íconos sueltos (kb_tool, hz_fg2)",
      "key.setBackgroundResource(R.drawable.kb_tool)" in snip and "R.color.hz_fg2" in snip
      and "kb_key_danger" not in mv and "kb_key_accent" not in mv)
check("Borrar en kb_danger solo con modo borrar activo",
      "if (mode == SnippetMode.DELETE) ContextCompat.getColor(service, R.color.kb_danger)" in mv)

# Portapapeles: tarjetas mono con etiqueta de tipo; «Limpiar libres» como ícono al final.
film = read(f"{KT}/ClipboardFilmstripLayout.kt")
render = film.split("fun renderClips(")[1].split("\n    override fun ")[0]
clear = film.split("private fun createClearButton()")[1].split("\n    private fun ")[0]
check("Clipboard: «Limpiar libres» al final de la fila",
      render.find("createClearButton()") > render.find("for (clip in clips)") > 0)
check("Clipboard: «Limpiar libres» es ícono con contentDescription y misma acción",
      "ImageView(context)" in clear and 'contentDescription = "Limpiar libres"' in clear
      and "R.drawable.ic_delete" in clear and "setOnClickListener { onClearClicked() }" in clear
      and '"Limpiar\\nlibres"' not in film)
check("Clipboard: «Limpiar libres» con ancho táctil >= 44dp",
      "CLEAR_TARGET_DP = 44" in film and "dpToPx(CLEAR_TARGET_DP)" in clear)
check("Clipboard: etiqueta de tipo mono bold con tracking (URL ember-t, TXT fg2)",
      "letterSpacing = BADGE_TRACKING" in film and "KbFonts.mono(context, BADGE_WEIGHT)" in film
      and "ClipType.TEXT -> ContextCompat.getColor(context, R.color.hz_fg2)" in film
      and "else -> ContextCompat.getColor(context, R.color.hz_ember_t)" in film)
check("Clipboard: contenido en mono", "typeface = KbFonts.mono(context)" in film)

# Claves: usuario en mono; brasa fuera del botón pegar (no es estado activo).
cred = read(f"{KT}/CredentialsLayer.kt")
check("Claves: usuario en mono y pegar como ícono suelto",
      "typeface = KbFonts.mono(service)" in cred and "kb_key_accent" not in cred
      and "R.drawable.kb_tool" in cred and "touchMin, touchMin" in cred)

# Micrófono ocupado = agujero atenuado (lógica intacta).
dic = read(f"{KT}/DictationController.kt")
busy = dic.split("MicState.BUSY -> {")[-1].split("\n            }")[0]
check("Mic ocupado: mismo HoleDrawable con alfa reducido",
      "HoleDrawable(service)" in busy and "MIC_BUSY_ALPHA" in busy and "kb_key_alt" not in busy
      and "MIC_BUSY_ALPHA = 0.5f" in dic)

# Sin hex literales en las capas del teclado tocadas.
for name in ("ToolbarLayer", "KeyFactory", "LayoutLayer", "SnippetsLayer", "SnippetsCardView",
             "ClipboardLayer", "ClipboardFilmstripLayout", "CredentialsLayer", "HistoryLayer",
             "AccentLayer", "KeyboardSupport"):
    src = read(f"{KT}/{name}.kt")
    lits = _re.findall(r"0x[0-9A-Fa-f]{6,8}|Color\.(?:WHITE|BLACK|GRAY|GREEN|RED|parseColor|rgb|argb)", src)
    check(f"Sin colores literales en {name}", not lits, f"literales: {lits}")

# Limpieza de tokens.
check("kb_recording_pressed retirado (sin uso)",
      "kb_recording_pressed" not in colors_l and "kb_recording_pressed" not in colors_n)
check("bubble_transcribing_bg retirado (sin uso; Horizonte fase 4)",
      "bubble_transcribing_bg" not in colors_l and "bubble_transcribing_bg" not in colors_n)
check("CI corre VoiceLevelTest",
      "--tests com.royleguiza.voicebubblestt.VoiceLevelTest" in read(".github/workflows/android.yml"))

print("\n============================================================")
print(f" RESULTADO SUITE TECLADO-LAYOUT: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
