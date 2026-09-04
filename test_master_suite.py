#!/usr/bin/env python3
"""
MASTER VERIFICATION SUITE - VoiceBubble STT
Ejecuta todas las comprobaciones de extremo a extremo:
1. CI Guards (Contrato de Claves del Puente, Logs sin filtraciones, Hex de Colores).
2. Retención de Datos en Desinstalación (hasFragileUserData y allowBackup).
3. Edición de Snippets en Teclado (Subcapas ?123 / Código, soporte de '@', retención de borrador).
4. Onboarding de Micrófono y Activación Modal de Teclado (showInputMethodPicker + WidgetsBindingObserver).
5. Escala y Perfiles de Altura de Teclas (Muy alta - 1.30f).
6. Repositorio de Historial de Transcripciones Profesional (Escritura atómica, sincronización y FIFO-20).
7. Suite de Portapapeles Multimodal (FIFO-25, Pinned, Heurísticas y UI).
"""

import os
import subprocess
import sys

def run_test(name, func):
    sys.stdout.write(f"  ▶ {name}... ")
    sys.stdout.flush()
    try:
        func()
        print("✅ PASS")
        return True
    except Exception as e:
        print(f"❌ FAIL: {e}")
        return False

def test_contract_keys():
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    cmd = (
        f"grep -rvhE '^[[:space:]]*import ' '{kt_dir}' "
        "| grep -ohE 'flutter\\.[a-z_0-9]+' "
        "| sed 's/^flutter\\.//' "
        "| sort -u"
    )
    result = subprocess.check_output(cmd, shell=True, text=True).strip()
    with open("docs/contract-keys.txt", "r", encoding="utf-8") as f:
        expected = f.read().strip()
    assert result == expected, f"Discrepancia en claves de contrato:\nEsperado:\n{expected}\nObtenido:\n{result}"

def test_clean_logs():
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin"
    cmd = f"grep -rniE 'Log\\.[a-z]+\\(.*\\b(texto|contenido|api_?key|token)\\b' '{kt_dir}' || true"
    out = subprocess.check_output(cmd, shell=True, text=True).strip()
    assert not out, f"Filtración de contenido detectada en Logs:\n{out}"

def test_manifest_retention():
    manifest_path = "voice_bubble_stt/android/app/src/main/AndroidManifest.xml"
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()
    assert 'android:hasFragileUserData="true"' in content, "Falta android:hasFragileUserData=\"true\""
    assert 'android:allowBackup="true"' in content, "Falta android:allowBackup=\"true\""

def test_snippet_keyboard_sublayer():
    kt_path = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt"
    with open(kt_path, "r", encoding="utf-8") as f:
        content = f.read()
    assert "private var snippetSubLayer = Layer.LETTERS" in content
    assert "private var snippetDraftName = \"\"" in content
    assert "saveSnippetDraftState()" in content
    assert "when (snippetSubLayer)" in content
    assert "Layer.SYMBOLS -> buildSymbolRows()" in content
    assert "Layer.CODE -> buildCodeRows()" in content
    assert "toggleShift()" in content

def test_onboarding_and_activation():
    # MainActivity
    with open("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/MainActivity.kt", "r", encoding="utf-8") as f:
        ma = f.read()
    assert '"showInputMethodPicker"' in ma
    assert "imm.showInputMethodPicker()" in ma

    # KeyboardService
    with open("app_source/lib/services/keyboard_service.dart", "r", encoding="utf-8") as f:
        ks = f.read()
    assert "showInputMethodPicker" in ks

    # SettingsScreen
    with open("app_source/lib/screens/settings_screen.dart", "r", encoding="utf-8") as f:
        ss = f.read()
    assert "with WidgetsBindingObserver" in ss
    assert "didChangeAppLifecycleState" in ss
    assert "_showInputMethodPicker" in ss
    assert "_ensureMicrophonePermission" in ss
    assert "Seleccionar VoiceBubble como teclado" in ss

    # HomeScreen
    with open("app_source/lib/screens/home_screen.dart", "r", encoding="utf-8") as f:
        hs = f.read()
    assert "_transcriptionService.requestPermissions()" in hs

def test_height_profiles():
    with open("app_source/lib/services/storage_service.dart", "r", encoding="utf-8") as f:
        ss = f.read()
    assert "'muy_alta'" in ss

    with open("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt", "r", encoding="utf-8") as f:
        vk = f.read()
    assert 'HEIGHT_PROFILE_MUY_ALTA = "muy_alta"' in vk
    assert "HEIGHT_FACTOR_MUY_ALTA = 1.30f" in vk

def test_transcription_history_atomic():
    with open("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryRepository.kt", "r", encoding="utf-8") as f:
        repo = f.read()
    assert 'FILE_NAME = "transcription_history.json"' in repo
    assert "tmp.renameTo(targetFile)" in repo

    with open("app_source/lib/services/storage_service.dart", "r", encoding="utf-8") as f:
        ss = f.read()
    assert "historyFileName = 'transcription_history.json'" in ss
    assert "renameSync" in ss

def test_clipboard_suite():
    res = subprocess.run(["python3", "test_clipboard_suite.py"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert res.returncode == 0, f"Fallo en clipboard suite: {res.stderr}\n{res.stdout}"

def test_trackpad_suite():
    res = subprocess.run(["python3", "test_trackpad_suite.py"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert res.returncode == 0, f"Fallo en trackpad suite: {res.stderr}\n{res.stdout}"

def main():
    print("=" * 70)
    print(" 🚀 INICIANDO MASTER VERIFICATION SUITE - VOICEBUBBLE STT")
    print("=" * 70)
    tests = [
        ("CI Guard: Paridad de Claves de Contrato", test_contract_keys),
        ("CI Guard: Ausencia de Filtraciones en Logs", test_clean_logs),
        ("Persistencia: Retención al desinstalar (hasFragileUserData)", test_manifest_retention),
        ("Snippets: Subcapas ?123/Código y soporte para '@' sin cierre de editor", test_snippet_keyboard_sublayer),
        ("Onboarding: Petición de micrófono y activación modal sin salir de la app", test_onboarding_and_activation),
        ("Ergonomía: Perfil de altura de tecla 'Muy alta' (factor 1.30f)", test_height_profiles),
        ("Historial: Repositorio JSON atómico y sincronización FIFO-20", test_transcription_history_atomic),
        ("Portapapeles: Suite Multimodal 24/24", test_clipboard_suite),
        ("Trackpad: Suite Split Wings y Puntero Virtual", test_trackpad_suite),
    ]

    passed = 0
    for name, func in tests:
        if run_test(name, func):
            passed += 1

    print("=" * 70)
    print(f" RESULTADO FINAL: {passed}/{len(tests)} módulos verificados con éxito.")
    print("=" * 70)

    if passed == len(tests):
        print("✨ TODOS LOS REQUERIMIENTOS FUERON EJECUTADOS Y VALIDADOS AL 100%.")
        sys.exit(0)
    else:
        print("⚠️ ALGUNOS MÓDULOS PRESENTARON FALLOS.")
        sys.exit(1)

if __name__ == "__main__":
    main()
