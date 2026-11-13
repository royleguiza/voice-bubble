#!/usr/bin/env python3
"""
TEST SUITE: MODO MINI / MICRO-TECLADO (MEJ-12)
Verifica sobre el código REAL:
1. Iconos (Horizonte fase 2, opción "Barra" del dueño): ic_micro_collapse =
   path `mini` (contorno atenuado + barra llena: el único relleno) e
   ic_micro_expand = path `full` (contorno atenuado + grilla y barra, sin
   rellenos); trazo 1.8 sobre viewport 24, hex válidos.
2. Estado: MiniModeStore con prefs propias (fuera del contrato flutter.*),
   default completo, parseo tolerante, sin Log.
3. Toolbar: botón micro al borde junto al mic, icono según modo, i18n es/en.
4. Rebuild mini: toolbar + inline (clip/cred) + fila compacta; sin terminal,
   sin letras, sin bottom bar completa.
5. Reglas MEJ-12: snippets/código/símbolos/trackpad expanden a completo;
   clipboard/credenciales NO expanden; saneado de capas al compactar/rotar.
6. Fila mini: borrar con gestos + espacio con gestos + enter, altura compacta
   kb_mini_key_height (40dp, escala con perfil), sin romper APIs existentes.
7. Contrato intacto: cero claves flutter.* nuevas; overrides makeIconKey==2.
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
print(" INICIANDO TEST SUITE: MODO MINI (MEJ-12)")
print("============================================================\n")

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
DW = "voice_bubble_stt/android/app/src/main/res/drawable"
vks = read(f"{KT}/VoiceKeyboardService.kt")
tb = read(f"{KT}/ToolbarLayer.kt")
lay = read(f"{KT}/LayoutLayer.kt")
kf = read(f"{KT}/KeyFactory.kt")
mm = read(f"{KT}/MiniModeStore.kt")
dimens = read("voice_bubble_stt/android/app/src/main/res/values/dimens.xml")

# --- 1. Iconos ---
for dw in ["ic_micro_collapse.xml", "ic_micro_expand.xml"]:
    p = os.path.join(WORKSPACE, DW, dw)
    check(f"Drawable {dw} existe", os.path.isfile(p))
    if os.path.isfile(p):
        raw = read(f"{DW}/{dw}")
        check(f"{dw} viewport 24dp", 'viewportWidth="24"' in raw and 'android:width="24dp"' in raw)
        bad = [h for h in re.findall(r"#[0-9A-Fa-f]+", raw) if len(h) not in (4, 5, 7, 9)]
        check(f"{dw} sin colores malformados (§9.1-19)", not bad)
        check(f"{dw} trazo Horizonte 1.8 redondeado",
              set(re.findall(r'strokeWidth="([0-9.]+)"', raw)) == {"1.8"}
              and raw.count('strokeLineCap="round"') == raw.count("strokeWidth=")
              and raw.count('strokeLineJoin="round"') == raw.count("strokeWidth="))
        check(f"{dw} contorno del teclado atenuado (opacity .4)",
              'android:strokeAlpha="0.4"' in raw and "M6.5,5h11a3.5,3.5" in raw)
_col = read(f"{DW}/ic_micro_collapse.xml")
_exp = read(f"{DW}/ic_micro_expand.xml")
_fills = lambda raw: [f for f in re.findall(r'fillColor="([^"]+)"', raw) if f != "#00000000"]
check("Collapse = path mini: barra llena abajo (único relleno)",
      "M8.1,13h7.8a1.6,1.6" in _col and len(_fills(_col)) == 1, f"rellenos: {_fills(_col)}")
check("Expand = path full: grilla de puntos + barra, sin rellenos",
      "M7,9.5h1M11.5,9.5h1M16,9.5h1M7,12.5h1" in _exp and "M9,15.5h6" in _exp and not _fills(_exp),
      f"rellenos: {_fills(_exp)}")
check("Sin las flechitas del ícono anterior",
      "M12,13.5 V20.5" not in _col and "M12,10.5 V3.5" not in _exp)

# --- 2. Estado y persistencia propia ---
check("MiniModeStore.kt existe", os.path.isfile(os.path.join(WORKSPACE, f"{KT}/MiniModeStore.kt")))
check("Prefs propias (fuera del puente)", "VoiceBubbleIme" in mm)
check("Sin claves flutter.* nuevas", "flutter." not in mm)
check("Default completo (false)", "mini_mode" in mm and ", false)" in mm)
check("Parseo tolerante", "catch (_: Exception)" in mm)
check("Sin Log", "Log." not in mm)
check("VKS guarda el modo", "miniMode = false" in vks and "miniStore = MiniModeStore(this)" in vks)
check("VKS carga al abrir campo (sobrevive rotación)", "miniMode = miniStore.load()" in vks)

# --- 3. Toolbar ---
check("UiHost exige isMiniMode/miniToggle", "fun isMiniMode(): Boolean" in tb and "fun miniToggle()" in tb)
check("Botón micro en toolbar", "btnMicro" in tb)
check("Icono según modo", "ic_micro_expand" in tb and "ic_micro_collapse" in tb)
check("i18n mini/teclado completo", "mini-teclado" in tb and "teclado completo" in tb)
check("Sin useKeyHeight en toolbar (§layout)", "useKeyHeight" not in tb)
check("VKS implementa isMiniMode/miniToggle", "override fun isMiniMode()" in vks and "override fun miniToggle()" in vks)

# --- 4. Rebuild mini ---
mini = vks.split("if (miniMode) {")[1].split("} else if (layer == Layer.TRACKPAD)")[0] if "if (miniMode) {" in vks else ""
check("Rama mini en rebuild()", "if (miniMode)" in vks)
check("Mini: clipboard inline", "Layer.CLIPBOARD -> addRow(clipboard.buildRows())" in vks)
check("Mini: credenciales inline", "credentials.buildRows(root)" in vks)
check("Mini: fila compacta al final", "layout.buildMiniRow()" in mini)
check("Mini: sin fila terminal", "buildTerminalRow" not in mini)
check("Mini: sin letras ni bottom bar", "buildLetterRows" not in mini and "buildBottomBar" not in mini)
check("Saneado al abrir campo", "layer != Layer.LETTERS && layer != Layer.CLIPBOARD && layer != Layer.CREDENTIALS" in vks)

# --- 5. Reglas MEJ-12 ---
check("Snippets expande a completo", "override fun snippetsToggle()" in vks and "setMiniMode(false" in vks)
check("Trackpad expande a completo", "override fun trackpadToggle()" in vks)
check("Code expande a completo", "override fun codeToggle()" in vks)
check("Símbolos expanden a completo", "override fun pressSymbolsKey()" in vks)
check("Numérico expande a completo", "override fun pressNumericKey()" in vks and "setMiniMode(false" in vks)
check("Clipboard NO expande (inline)", "override fun clipboardToggle() = clipboard.toggle()" in vks)
check("Credenciales NO expanden (inline)", "override fun credentialsToggle() = credentials.toggle()" in vks)
check("Aviso de modo i18n", "Mini-teclado" in vks and "Teclado completo" in vks)

# --- 6. Fila mini compacta ---
check("LayoutLayer.buildMiniRow existe", "fun buildMiniRow()" in lay)
check("Mini: borrar con gestos", "makeBackspaceKey(" in lay)
check("Mini: espacio con gestos", "attachSpacebar(space)" in lay)
check("Mini: enter accent", "R.drawable.ic_enter" in lay)
check("Dimen kb_mini_key_height=40dp", '<dimen name="kb_mini_key_height">40dp</dimen>' in dimens)
check("UiHost exige miniKeyHeightPx", "fun miniKeyHeightPx(): Int" in lay)
check("VKS escala mini con perfil", "override fun miniKeyHeightPx()" in vks and "kb_mini_key_height" in vks)
check("KeyFactory: heightPx opcional sin romper firmas",
      "heightPx: Int? = null" in kf and "fun makeKey(" in kf and "fun makeBackspaceKey(" in kf)
check("APIs intactas (firmas base)", all(s in kf for s in ["fun fastTap(", "fun longPress(", "fun letterRow(",
      "fun makeLetterKey(", "fun makeSymbolKey(", "fun makeCodeKey("]))
check("Overrides makeIconKey siguen ==2", vks.count("override fun makeIconKey(") == 2)

print("\n============================================================")
print(f" RESULTADO SUITE MODO-MINI: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
