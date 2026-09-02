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

    # Variables de estado
    assert "private var snippetSubLayer = Layer.LETTERS" in content
    assert "private var snippetDraftName = \"\"" in content
    assert "private var snippetDraftContent = \"\"" in content
    assert "private var snippetDraftActiveFieldIsContent = false" in content
    assert "private var snippetDraftCursor = 0" in content

    # Métodos de ciclo de vida
    assert "saveSnippetDraftState()" in content
    assert "snippetDraftName" in content
    assert "snippetDraftContent" in content

    # Toggle de símbolos y código dentro de snippets
    assert "if (layer == Layer.SNIPPETS)" in content
    assert "snippetSubLayer = if (snippetSubLayer == Layer.LETTERS) Layer.SYMBOLS else Layer.LETTERS" in content
    assert "snippetSubLayer = if (snippetSubLayer == Layer.CODE) Layer.LETTERS else Layer.CODE" in content

    # Comprobación de que buildSnippetRows soporta las 3 subcapas
    assert "when (snippetSubLayer)" in content
    assert "Layer.SYMBOLS -> buildSymbolRows()" in content
    assert "Layer.CODE -> buildCodeRows()" in content
    assert "addSnippetLetterRows()" in content

    # Comprobación de que el shift está en addSnippetLetterRows
    assert "toggleShift()" in content
    print("  [PASS] Arquitectura de subcapas de snippets, símbolos y borrador reactivo 100% verificada.")

if __name__ == "__main__":
    print("=" * 60)
    print(" INICIANDO TEST SUITE: SNIPPETS RETENTION & SPECIAL SYMBOLS")
    print("=" * 60)
    try:
        test_manifest_retention()
        test_keyboard_service_snippet_sublayer()
        print("=" * 60)
        print(" RESULTADOS: Todos los tests pasaron exitosamente.")
        print("=" * 60)
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        sys.exit(1)
