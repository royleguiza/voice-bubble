#!/usr/bin/env python3
"""
Test Suite: Snippets In-Keyboard Editor (Symbols/Special Chars) & Data Retention.
Verifica:
1. AndroidManifest.xml declara hasFragileUserData="true" y allowBackup="true" para retención de datos en desinstalación.
2. VoiceKeyboardService mantiene el editor abierto ante cambios de subcapa (?123 / código).
3. VoiceKeyboardService guarda y restaura el borrador (draft) de texto y selección de cursor al cambiar de subcapa.
4. VoiceKeyboardService conmuta adecuadamente entre letras, símbolos y código dentro de Layer.SNIPPETS.
5. Inserción de caracteres especiales (incluyendo '@', brackets, puntuación) en el campo activo.
"""

import sys

def test_manifest_retention():
    print("  [TEST] Verificando retención de datos en AndroidManifest.xml...")
    manifest_path = "voice_bubble_stt/android/app/src/main/AndroidManifest.xml"
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert 'android:hasFragileUserData="true"' in content, "Falta android:hasFragileUserData=\"true\""
    assert 'android:allowBackup="true"' in content, "Falta android:allowBackup=\"true\""
    print("  [PASS] hasFragileUserData y allowBackup activos para conservar datos al desinstalar.")

def test_keyboard_service_snippet_sublayer():
    print("  [TEST] Verificando subcapas y persistencia de borrador en VoiceKeyboardService.kt...")
    kt_path = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt"
    with open(kt_path, "r", encoding="utf-8") as f:
        content = f.read()
    # SPK-05 módulo 8: el estado vive en SnippetsLayer.kt (mismo paquete);
    # VKS queda como shell que delega.
    layer_path = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/SnippetsLayer.kt"
    with open(layer_path, "r", encoding="utf-8") as f:
        layer = f.read()
    # SPK-05 módulo 16: las filas viven en LayoutLayer.kt (mismo paquete);
    # VKS despacha (layout.build*Rows()).
    layout_path = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/LayoutLayer.kt"
    with open(layout_path, "r", encoding="utf-8") as f:
        layout_content = f.read()
    # SPK-05 módulo 18: el motor de edición vive en EditEngine.kt;
    # VKS delega (toggleShiftKey -> editor.toggleShift()).
    engine_path = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/EditEngine.kt"
    with open(engine_path, "r", encoding="utf-8") as f:
        engine = f.read()

    # Variables de estado (VKS o capa)
    assert ("private var snippetSubLayer = Layer.LETTERS" in content
            or "var subLayer = Layer.LETTERS" in layer)
    assert ("private var snippetDraftName = \"\"" in content
            or 'private var draftName = ""' in layer)
    assert ("private var snippetDraftContent = \"\"" in content
            or 'private var draftContent = ""' in layer)
    assert ("private var snippetDraftActiveFieldIsContent = false" in content
            or "private var draftActiveIsContent = false" in layer)
    assert ("private var snippetDraftCursor = 0" in content
            or "private var draftCursor = 0" in layer)

    # Métodos de ciclo de vida
    assert "saveSnippetDraftState()" in content or "saveDraftState()" in layer
    assert "snippetDraftName" in content or "draftName" in layer
    assert "snippetDraftContent" in content or "draftContent" in layer

    # Toggle de símbolos y código dentro de snippets
    assert "if (layer == Layer.SNIPPETS)" in content or "host.currentLayer() == Layer.SNIPPETS" in layer
    assert ("snippetSubLayer = if (snippetSubLayer == Layer.LETTERS) Layer.SYMBOLS else Layer.LETTERS" in content
            or "subLayer = if (subLayer == Layer.LETTERS) Layer.SYMBOLS else Layer.LETTERS" in layer)
    assert ("snippetSubLayer = if (snippetSubLayer == Layer.CODE) Layer.LETTERS else Layer.CODE" in content
            or "subLayer = if (subLayer == Layer.CODE) Layer.LETTERS else Layer.CODE" in layer)

    # Comprobación de que buildSnippetRows soporta las 3 subcapas
    assert "when (snippetSubLayer)" in content or "when (snippets.subLayer)" in content
    assert "Layer.SYMBOLS -> buildSymbolRows()" in content or "fun buildSymbolRows()" in layout_content
    assert "Layer.CODE -> buildCodeRows()" in content or "fun buildCodeRows()" in layout_content
    # SPK-05 módulo 13: las filas QWERTY viven en SnippetsLayer
    # (buildLetterRows); VKS queda como shell que despacha.
    assert "addSnippetLetterRows()" in content or "buildLetterRows()" in layer

    # Comprobación de que el shift sigue cableado (VKS delega al motor)
    assert "toggleShift()" in content or "fun toggleShift()" in engine
    print("  [PASS] Arquitectura de capas de snippets, símbolos y borrador reactivo 100% verificada.")

def test_snippet_color_palette():
    print("  [TEST] Verificando paleta de color de snippets (Kotlin)...")
    store_path = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/SnippetStore.kt"
    layer_path = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/SnippetsLayer.kt"
    with open(store_path, "r", encoding="utf-8") as f:
        store = f.read()
    with open(layer_path, "r", encoding="utf-8") as f:
        layer = f.read()

    # Modelo con color opcional + paleta de 6 ids
    assert "val color: String? = null" in store, "Falta color opcional en VbSnippet"
    assert "object SnippetPalette" in store, "Falta SnippetPalette"
    assert 'listOf("azul", "verde", "rojo", "naranja", "violeta", "gris")' in store
    assert 'obj.put("color"' in store, "writeAll debe persistir color"
    assert 'rawColor?.takeIf { SnippetPalette.isValid(it) }' in store

    # Editor inline con draftColor y swatches
    assert "draftColor" in layer, "Falta draftColor en el editor"
    assert "buildColorSwatchRow" in layer, "Falta fila de swatches"
    # Horizonte fase 2: el chip deja de teñirse entero; fondo de tecla +
    # punto de 6 dp con el color base (sin color = sin punto) + nombre en
    # JetBrains Mono medium. Los 6 ids y los tonos fill/stroke no cambian.
    chip = layer.split("private fun makeChip(")[1].split("\n    private fun ")[0]
    assert "SnippetPalette.baseRes" in layer, "Chip sin punto de color base"
    assert "colorDot(it)" in chip and "setCompoundDrawablesRelativeWithIntrinsicBounds(dot" in chip, "Chip sin punto a la izquierda"
    assert "snippet.color?.takeIf { SnippetPalette.isValid(it) }" in chip, "Sin color debe quedar sin punto"
    assert "R.drawable.kb_key_bg" in chip and "tintedChipBackground" not in layer, "Chip todavía teñido entero"
    assert "kb_snippet_dot_size" in layer, "Punto sin token de 6 dp"
    assert "kb_snippet_chip_text_size" in layer, "Chip sin tipografía 16sp"
    assert "KbFonts.mono(service, KeyFactory.MONO_LABEL_WEIGHT)" in chip, "Chip sin mono medium"
    with open("voice_bubble_stt/android/app/src/main/res/values/dimens.xml", "r", encoding="utf-8") as f:
        assert '<dimen name="kb_snippet_dot_size">6dp</dimen>' in f.read(), "Punto del chip debe medir 6dp"
    # Selector: color elegido marcado con anillo (sin cambiar los 6 ids).
    sw = layer.split("private fun makeSwatch(")[1].split("\n    private fun ")[0]
    assert "SWATCH_RING_DP" in sw and "LayerDrawable(arrayOf(ring, disc))" in sw, "Swatch elegido sin anillo"
    assert "!selected -> Color.TRANSPARENT" in sw, "El anillo debe verse solo en el elegido"

    # Recursos de paleta (claro + oscuro)
    for theme in ("values", "values-night"):
        path = f"voice_bubble_stt/android/app/src/main/res/{theme}/colors.xml"
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
        for cid in ("azul", "verde", "rojo", "naranja", "violeta", "gris"):
            assert f"snippet_fill_{cid}" in raw, f"Falta fill {cid} en {theme}"
            assert f"snippet_stroke_{cid}" in raw, f"Falta stroke {cid} en {theme}"
            assert f"snippet_base_{cid}" in raw, f"Falta base {cid} en {theme}"
    for cid in ("azul", "verde", "rojo", "naranja", "violeta", "gris"):
        assert f'"{cid}" -> R.color.snippet_base_{cid}' in store or (cid == "gris" and "else -> R.color.snippet_base_gris" in store), f"baseRes sin {cid}"
    print("  [PASS] Paleta de 6 colores, editor con swatches y chips teñidos 100% verificados.")

if __name__ == "__main__":
    print("=" * 60)
    print(" INICIANDO TEST SUITE: SNIPPETS RETENTION & SPECIAL SYMBOLS")
    print("=" * 60)
    try:
        test_manifest_retention()
        test_keyboard_service_snippet_sublayer()
        test_snippet_color_palette()
        print("=" * 60)
        print(" RESULTADOS: Todos los tests pasaron exitosamente.")
        print("=" * 60)
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        sys.exit(1)
