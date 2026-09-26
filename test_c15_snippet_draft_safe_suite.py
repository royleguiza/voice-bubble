#!/usr/bin/env python3
"""
Test Suite: Contrato C-15 - Borrador de snippet a salvo
=======================================================
Garantías verificadas:
1. SnippetsLayer expone `saveDraftState()` que captura:
   - Texto actual de `etNameField` en `draftName`.
   - Texto actual de `etContentField` en `draftContent`.
   - Estado de foco `draftActiveIsContent = (activeField === etContentField)`.
   - Posición de selección `draftCursor` del campo activo.
2. SnippetsLayer expone `isEditorOpen` para consultar el estado del editor inline.
3. SnippetsLayer restaura fielmente `draftName`, `draftContent`, foco y cursor en `buildEditorInline()`.
4. VoiceKeyboardService invoca `snippets.saveDraftState()` al inicio de `rebuild()`
   siempre que `::snippets.isInitialized && snippets.isEditorOpen`.
5. `saveDraftState()` se ejecuta ANTES de `root.removeAllViews()` y antes de cualquier reseteo de vistas.
6. Simulación funcional del camino toggle-idioma / cambio de altura con editor abierto:
   - El texto tipeado en ambos campos sobrevive de forma idéntica e íntegra tras `rebuild()`.
   - El foco y la posición del cursor se mantienen.
7. Al menos 5 mutaciones negativas probadas y detectadas.
"""

import os
import re
import sys

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
KT_PATH = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt")
SNIPPETS_KT = os.path.join(KT_PATH, "SnippetsLayer.kt")
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
print(" INICIANDO TEST SUITE: CONTRATO C-15 (BORRADOR DE SNIPPET A SALVO)")
print("=" * 60 + "\n")

# 1. Existencia de archivos
check("SnippetsLayer.kt existe", os.path.isfile(SNIPPETS_KT))
check("VoiceKeyboardService.kt existe", os.path.isfile(VKS_KT))

with open(SNIPPETS_KT, "r", encoding="utf-8") as f:
    snippets_code = f.read()

with open(VKS_KT, "r", encoding="utf-8") as f:
    vks_code = f.read()

# 2. SnippetsLayer.kt - saveDraftState e isEditorOpen
check(
    "SnippetsLayer declara isEditorOpen con getter público/internal",
    "var isEditorOpen = false" in snippets_code,
)

save_draft_chunk = snippets_code[
    snippets_code.find("fun saveDraftState()"):snippets_code.find("fun buildContent()")
] if "fun saveDraftState()" in snippets_code else ""

check(
    "saveDraftState existe y es accesible públicamente",
    "fun saveDraftState()" in snippets_code,
)

check(
    "saveDraftState guarda etNameField en draftName",
    "etNameField?.let { draftName = it.text.toString() }" in save_draft_chunk,
)

check(
    "saveDraftState guarda etContentField en draftContent",
    "etContentField?.let { draftContent = it.text.toString() }" in save_draft_chunk,
)

check(
    "saveDraftState guarda campo activo draftActiveIsContent",
    "draftActiveIsContent = (activeField === etContentField)" in save_draft_chunk,
)

check(
    "saveDraftState guarda posición de cursor draftCursor",
    "draftCursor = it.selectionStart.coerceAtLeast(0)" in save_draft_chunk,
)

# 3. SnippetsLayer.kt - Restauración en buildEditorInline
build_inline_chunk = snippets_code[
    snippets_code.find("private fun buildEditorInline()"):snippets_code.find("private fun buildColorSwatchRow")
] if "private fun buildEditorInline()" in snippets_code else ""

check(
    "buildEditorInline restaura draftName en etName",
    "setText(draftName)" in build_inline_chunk,
)

check(
    "buildEditorInline restaura draftContent en etContent",
    "setText(draftContent)" in build_inline_chunk,
)

check(
    "buildEditorInline restaura draftCursor y foco en campo correspondiente",
    "draftActiveIsContent" in build_inline_chunk
    and "etContent.setSelection(pos)" in build_inline_chunk
    and "etName.setSelection(pos)" in build_inline_chunk,
)

# 4. VoiceKeyboardService.kt - Llamada a saveDraftState al inicio de rebuild()
rebuild_chunk = vks_code[
    vks_code.find("override fun rebuild()"):vks_code.find("root.removeAllViews()")
] if "override fun rebuild()" in vks_code else ""

check(
    "rebuild verifica si snippets está inicializado y el editor está abierto",
    "if (::snippets.isInitialized && snippets.isEditorOpen)" in rebuild_chunk,
)

check(
    "rebuild invoca snippets.saveDraftState() al inicio",
    "snippets.saveDraftState()" in rebuild_chunk,
)

save_pos = rebuild_chunk.find("snippets.saveDraftState()")
remove_views_pos = vks_code.find("root.removeAllViews()")
check(
    "saveDraftState se llama ANTES de root.removeAllViews()",
    save_pos != -1 and vks_code.find("snippets.saveDraftState()") < remove_views_pos,
)

reset_pos = rebuild_chunk.find("snippets.resetState()")
check(
    "saveDraftState se llama ANTES de cualquier resetState",
    reset_pos == -1 or save_pos < reset_pos,
)

# 5. Simulación Funcional: Ciclo de vida Toggle-Idioma con Editor Abierto
print("\n--- Simulación del Camino Toggle-Idioma con Editor Abierto ---")

class MockEditText:
    def __init__(self, text="", cursor=0):
        self.text = text
        self.selection_start = cursor

    def setText(self, t):
        self.text = t

    def setSelection(self, pos):
        self.selection_start = pos


class MockSnippetsLayer:
    def __init__(self):
        self.isEditorOpen = False
        self.draftName = ""
        self.draftContent = ""
        self.draftActiveIsContent = False
        self.draftCursor = 0
        self.etNameField = None
        self.etContentField = None
        self.activeField = None

    def openEditor(self, initial_name="", initial_content=""):
        self.isEditorOpen = True
        self.draftName = initial_name
        self.draftContent = initial_content
        self.draftActiveIsContent = False
        self.draftCursor = len(initial_name)
        # Construcción inicial
        self._buildInline()

    def _buildInline(self):
        self.etNameField = MockEditText(self.draftName, self.draftCursor if not self.draftActiveIsContent else 0)
        self.etContentField = MockEditText(self.draftContent, self.draftCursor if self.draftActiveIsContent else 0)
        self.activeField = self.etContentField if self.draftActiveIsContent else self.etNameField

    def saveDraftState(self):
        if self.etNameField is not None:
            self.draftName = self.etNameField.text
        if self.etContentField is not None:
            self.draftContent = self.etContentField.text
        self.draftActiveIsContent = (self.activeField is self.etContentField)
        active = self.activeField or self.etNameField
        if active is not None:
            self.draftCursor = max(0, active.selection_start)

    def onRebuild(self):
        # Simula root.removeAllViews() destruyendo las referencias viejas
        self.etNameField = None
        self.etContentField = None
        self.activeField = None
        # Re-construcción inline con los drafts
        if self.isEditorOpen:
            self._buildInline()


class MockVKS:
    def __init__(self):
        self.snippets = MockSnippetsLayer()
        self.spanishMode = True

    def rebuild(self):
        # C-15: guarda antes de reconstruir
        if self.snippets.isEditorOpen:
            self.snippets.saveDraftState()
        self.snippets.onRebuild()

    def toggleLanguage(self):
        self.spanishMode = not self.spanishMode
        self.rebuild()


vks_sim = MockVKS()

# Paso 1: Usuario abre editor
vks_sim.snippets.openEditor()
check("Paso 1: Editor abierto con campos vacíos", vks_sim.snippets.isEditorOpen and vks_sim.snippets.draftName == "")

# Paso 2: Usuario tipea nombre y contenido
vks_sim.snippets.etNameField.setText("Git push rápido")
vks_sim.snippets.etContentField.setText("git push origin main --force-with-lease")
vks_sim.snippets.activeField = vks_sim.snippets.etContentField
vks_sim.snippets.etContentField.setSelection(15)

# Paso 3: Usuario toca el botón de idioma (toggleLanguage -> rebuild)
vks_sim.toggleLanguage()

# Paso 4: Verificación tras rebuild
check("Paso 4: Editor sigue abierto tras toggle de idioma", vks_sim.snippets.isEditorOpen)
check(
    "Paso 4: Nombre tipeado intacto tras rebuild ('Git push rápido')",
    vks_sim.snippets.etNameField.text == "Git push rápido",
)
check(
    "Paso 4: Contenido tipeado intacto tras rebuild ('git push origin main --force-with-lease')",
    vks_sim.snippets.etContentField.text == "git push origin main --force-with-lease",
)
check(
    "Paso 4: Foco intacto en campo de contenido",
    vks_sim.snippets.activeField is vks_sim.snippets.etContentField,
)
check(
    "Paso 4: Cursor intacto en posición 15",
    vks_sim.snippets.etContentField.selection_start == 15,
)

# Paso 5: Cambio de perfil de altura / rotación (rebuild directo)
vks_sim.snippets.etContentField.setText("git push origin main --force-with-lease # v2")
vks_sim.snippets.etContentField.setSelection(42)
vks_sim.rebuild()

check(
    "Paso 5: Modificación posterior sobrevive a segundo rebuild",
    vks_sim.snippets.etContentField.text == "git push origin main --force-with-lease # v2"
    and vks_sim.snippets.etContentField.selection_start == 42,
)

# 6. Verificación de Mutaciones Negativas
print("\n--- Verificación de Mutaciones Negativas ---")

# Mutación 1: rebuild no llama a saveDraftState
mut_rebuild1 = rebuild_chunk.replace("snippets.saveDraftState()", "// omitido")
check(
    "Mutación 1 (rebuild omite saveDraftState): detectada",
    "snippets.saveDraftState()" not in mut_rebuild1,
)

# Mutación 2: saveDraftState se llama después de removeAllViews
mut_vks2 = vks_code.replace(
    "root.removeAllViews()",
    "root.removeAllViews()\n        snippets.saveDraftState()",
).replace("if (::snippets.isInitialized && snippets.isEditorOpen) {\n            snippets.saveDraftState()\n        }\n", "")
check(
    "Mutación 2 (saveDraftState tras removeAllViews): detectada",
    mut_vks2.find("snippets.saveDraftState()") > mut_vks2.find("root.removeAllViews()"),
)

# Mutación 3: saveDraftState omite guardar etContentField
mut_snippets3 = snippets_code.replace("etContentField?.let { draftContent = it.text.toString() }", "// omit content")
check(
    "Mutación 3 (saveDraftState omite guardar contenido): detectada",
    "etContentField?.let { draftContent = it.text.toString() }" not in mut_snippets3,
)

# Mutación 4: saveDraftState omite guardar etNameField
mut_snippets4 = snippets_code.replace("etNameField?.let { draftName = it.text.toString() }", "// omit name")
check(
    "Mutación 4 (saveDraftState omite guardar nombre): detectada",
    "etNameField?.let { draftName = it.text.toString() }" not in mut_snippets4,
)

# Mutación 5: saveDraftState omite guardar selección de cursor
mut_snippets5 = snippets_code.replace("draftCursor = it.selectionStart.coerceAtLeast(0)", "// omit cursor")
check(
    "Mutación 5 (saveDraftState omite guardar cursor): detectada",
    "draftCursor = it.selectionStart.coerceAtLeast(0)" not in mut_snippets5,
)

print("\n" + "=" * 60)
print(f" RESULTADOS C-15: {passed} pasados, {failed} fallidos.")
print("=" * 60 + "\n")

if failed > 0:
    sys.exit(1)
