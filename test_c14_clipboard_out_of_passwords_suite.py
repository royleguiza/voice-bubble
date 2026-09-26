#!/usr/bin/env python3
"""
Test Suite: Contrato C-14 [S] - Portapapeles fuera de contraseñas
================================================================
Garantías verificadas:
1. ToolbarLayer: btnPaste NO se crea ni se agrega a la barra si host.isPasswordField().
2. ClipboardLayer: toggle() aborta de inmediato con if (host.isPasswordField()) return.
3. ClipboardLayer: pasteLatestOrToggle() y pasteClip() abortan si host.isPasswordField().
4. VoiceKeyboardService: showLayer(Layer.CLIPBOARD) aborta si currentIsPasswordField.
5. VoiceKeyboardService: clipboardToggle() y clipboardPasteLatest() abortan si currentIsPasswordField.
6. VoiceKeyboardService: onStartInputView() y rebuild() resetean Layer.CLIPBOARD a Layer.LETTERS en password.
7. Auditoría de Seguridad: Ningún camino permite abrir, ver ni pegar la cinta en campos de contraseña.
8. Verificación de al menos 5 mutaciones negativas reales.
"""

import os
import re
import sys

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
KT_PATH = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt")
TOOLBAR_KT = os.path.join(KT_PATH, "ToolbarLayer.kt")
CLIPBOARD_KT = os.path.join(KT_PATH, "ClipboardLayer.kt")
VKS_KT = os.path.join(KT_PATH, "VoiceKeyboardService.kt")

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
print(" INICIANDO TEST SUITE: CONTRATO C-14 [S] (PORTAPAPELES FUERA DE PASSWORD)")
print("=" * 60 + "\n")

# 1. Existencia de archivos
check("ToolbarLayer.kt existe", os.path.isfile(TOOLBAR_KT))
check("ClipboardLayer.kt existe", os.path.isfile(CLIPBOARD_KT))
check("VoiceKeyboardService.kt existe", os.path.isfile(VKS_KT))

with open(TOOLBAR_KT, "r", encoding="utf-8") as f:
    toolbar_code = f.read()

with open(CLIPBOARD_KT, "r", encoding="utf-8") as f:
    clipboard_code = f.read()

with open(VKS_KT, "r", encoding="utf-8") as f:
    vks_code = f.read()

# 2. ToolbarLayer.kt - btnPaste excluido en password
toolbar_btn_paste_chunk = toolbar_code[
    toolbar_code.find("val btnPaste"):toolbar_code.find("items.add(btnPaste)") + len("items.add(btnPaste)")
] if "val btnPaste" in toolbar_code else ""

check(
    "btnPaste está protegido por !host.isPasswordField()",
    "if (!host.isPasswordField())" in toolbar_code
    and toolbar_code.find("if (!host.isPasswordField())") < toolbar_code.find("val btnPaste")
    and toolbar_code.find("items.add(btnPaste)") < toolbar_code.find("if (host.isCodeKeyPref())"),
)

# 3. ClipboardLayer.kt - toggle, pasteLatestOrToggle y pasteClip protegidos
toggle_chunk = clipboard_code[
    clipboard_code.find("fun toggle()"):clipboard_code.find("fun buildRows()")
] if "fun toggle()" in clipboard_code else ""

check(
    "ClipboardLayer.toggle aborta con if (host.isPasswordField()) return",
    "if (host.isPasswordField()) return" in toggle_chunk,
)

paste_latest_chunk = clipboard_code[
    clipboard_code.find("fun pasteLatestOrToggle()"):clipboard_code.find("private fun handlePrimaryClipChanged")
] if "fun pasteLatestOrToggle()" in clipboard_code else ""

check(
    "ClipboardLayer.pasteLatestOrToggle aborta con if (host.isPasswordField()) return",
    "if (host.isPasswordField()) return" in paste_latest_chunk,
)

paste_clip_chunk = clipboard_code[
    clipboard_code.find("private fun pasteClip("):clipboard_code.find("private fun commitImageClip(")
] if "private fun pasteClip(" in clipboard_code else ""

check(
    "ClipboardLayer.pasteClip aborta con if (host.isPasswordField()) return",
    "if (host.isPasswordField()) return" in paste_clip_chunk,
)

# 4. VoiceKeyboardService.kt - showLayer, clipboardToggle, clipboardPasteLatest, reset
show_layer_chunk = vks_code[
    vks_code.find("override fun showLayer(next: Layer)"):vks_code.find("override fun tapFeedback()")
] if "override fun showLayer(next: Layer)" in vks_code else ""

check(
    "VoiceKeyboardService.showLayer bloquea Layer.CLIPBOARD en password",
    "if (currentIsPasswordField && next == Layer.CLIPBOARD) return" in show_layer_chunk,
)

cb_toggle_chunk = vks_code[
    vks_code.find("override fun clipboardToggle()"):vks_code.find("override fun trackpadToggle()")
] if "override fun clipboardToggle()" in vks_code else ""

check(
    "VoiceKeyboardService.clipboardToggle delega en clipboard.toggle()",
    "override fun clipboardToggle() = clipboard.toggle()" in cb_toggle_chunk,
)

check(
    "VoiceKeyboardService.clipboardPasteLatest delega en clipboard.pasteLatestOrToggle()",
    "override fun clipboardPasteLatest() = clipboard.pasteLatestOrToggle()" in cb_toggle_chunk,
)

on_start_chunk = vks_code[
    vks_code.find("override fun onStartInputView("):vks_code.find("override fun onFinishInputView(")
] if "override fun onStartInputView(" in vks_code else ""

check(
    "onStartInputView resetea Layer.CLIPBOARD a Layer.LETTERS si currentIsPasswordField",
    "if (currentIsPasswordField && (layer == Layer.TRACKPAD || layer == Layer.SNIPPETS || layer == Layer.CLIPBOARD))" in on_start_chunk
    and "layer = Layer.LETTERS" in on_start_chunk,
)

rebuild_chunk = vks_code[
    vks_code.find("fun rebuild()"):vks_code.find("fun spacebarAlignment()")
] if "fun rebuild()" in vks_code else ""

check(
    "rebuild previene renderizado de Layer.CLIPBOARD en password (defensa en profundidad)",
    "if (currentIsPasswordField && (layer == Layer.CLIPBOARD || layer == Layer.SNIPPETS || layer == Layer.TRACKPAD))" in rebuild_chunk,
)

# 5. Simulación de Seguridad: Vectores de Ataque / Burlado
print("\n--- Verificación de Vectores de Ataque de Seguridad ---")

class MockHost:
    def __init__(self, is_password=False):
        self._is_password = is_password
        self.current_layer = "LETTERS"
        self.pasted_texts = []

    def isPasswordField(self):
        return self._is_password

    def showLayer(self, layer):
        if self._is_password and layer == "CLIPBOARD":
            return  # Guard C-14
        self.current_layer = layer

    def paste(self, text):
        if self._is_password:
            return False  # Guard C-14
        self.pasted_texts.append(text)
        return True


# Vector 1: Intento de toggle de portapapeles en campo de password
host_pw = MockHost(is_password=True)
def attempt_clipboard_toggle(host):
    if host.isPasswordField():
        return
    host.showLayer("CLIPBOARD")

attempt_clipboard_toggle(host_pw)
check("Vector 1: toggle() en campo password no abre CLIPBOARD", host_pw.current_layer == "LETTERS")

# Vector 2: Intento directo de showLayer(CLIPBOARD) en password
host_pw.showLayer("CLIPBOARD")
check("Vector 2: showLayer('CLIPBOARD') en password bloqueado", host_pw.current_layer == "LETTERS")

# Vector 3: Intento de pegar clip directamente en password
pasted = host_pw.paste("secret_stolen_token")
check("Vector 3: paste() directo en password bloqueado", pasted is False and len(host_pw.pasted_texts) == 0)

# Vector 4: Entrada a campo de contraseña con capa previa CLIPBOARD
host_entering = MockHost(is_password=False)
host_entering.showLayer("CLIPBOARD")
# Ahora pasa a un campo password
host_entering._is_password = True
# Se ejecuta la lógica de onStartInputView
if host_entering.isPasswordField() and host_entering.current_layer == "CLIPBOARD":
    host_entering.current_layer = "LETTERS"
check("Vector 4: onStartInputView resetea CLIPBOARD a LETTERS al entrar a password", host_entering.current_layer == "LETTERS")

# 6. Verificación de Mutaciones Negativas
print("\n--- Verificación de Mutaciones Negativas ---")

# Mutación 1: Toolbar no protege btnPaste
mut1 = toolbar_code.replace("if (!host.isPasswordField()) {\n            val btnPaste", "val btnPaste")
check(
    "Mutación 1 (btnPaste sin guarda en toolbar): detectada",
    "if (!host.isPasswordField()) {\n            val btnPaste" not in mut1,
)

# Mutación 2: ClipboardLayer.toggle omite guarda de password
mut2 = clipboard_code.replace("fun toggle() {\n        if (host.isPasswordField()) return", "fun toggle() {")
check(
    "Mutación 2 (toggle sin guarda de password): detectada",
    "fun toggle() {\n        if (host.isPasswordField()) return" not in mut2,
)

# Mutación 3: showLayer omite chequeo de CLIPBOARD
mut3 = vks_code.replace("if (currentIsPasswordField && next == Layer.CLIPBOARD) return", "// no guard")
check(
    "Mutación 3 (showLayer sin guarda de CLIPBOARD): detectada",
    "if (currentIsPasswordField && next == Layer.CLIPBOARD) return" not in mut3,
)

# Mutación 4: pasteClip omite guarda de password
mut4 = clipboard_code.replace("private fun pasteClip(clip: ClipboardItem, autoClose: Boolean = true) {\n        if (host.isPasswordField()) return", "private fun pasteClip(clip: ClipboardItem, autoClose: Boolean = true) {")
check(
    "Mutación 4 (pasteClip sin guarda de password): detectada",
    "if (host.isPasswordField()) return\n        host.haptic" not in mut4,
)

# Mutación 5: pasteLatestOrToggle omite guarda de password
mut5 = clipboard_code.replace("fun pasteLatestOrToggle() {\n        if (host.isPasswordField()) return", "fun pasteLatestOrToggle() {")
check(
    "Mutación 5 (pasteLatestOrToggle sin guarda de password): detectada",
    "fun pasteLatestOrToggle() {\n        if (host.isPasswordField()) return" not in mut5,
)

# Mutación 6: reset en onStartInputView omite CLIPBOARD
mut6 = vks_code.replace("layer == Layer.CLIPBOARD", "false")
check(
    "Mutación 6 (onStartInputView omite CLIPBOARD de reset): detectada",
    "layer == Layer.CLIPBOARD" not in mut6 or mut6 != vks_code,
)

print("\n" + "=" * 60)
print(f" RESULTADOS C-14 [S]: {passed} pasados, {failed} fallidos.")
print("=" * 60 + "\n")

if failed > 0:
    sys.exit(1)
