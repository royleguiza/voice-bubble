#!/usr/bin/env python3
"""
Test Suite: Keyboard Key Height Profile & Integration Verification.
Verifica:
1. Sincronización de perfiles entre Dart (StorageService) y Kotlin (VoiceKeyboardService).
2. SegmentedButton en SettingsScreen con los 4 perfiles requeridos.
3. Constantes y factores matemáticos proporcionales (15% por nivel).
4. Pruebas de regresión: los perfiles existentes ('baja', 'media', 'alta') permanecen intactos.
"""

import sys

def test_height_profiles():
    print("  [TEST] Verificando perfiles en StorageService.dart...")
    dart_file = "app_source/lib/services/storage_service.dart"
    with open(dart_file, "r", encoding="utf-8") as f:
        dart_content = f.read()

    assert "kbHeightProfiles" in dart_content
    assert "'baja'" in dart_content
    assert "'media'" in dart_content
    assert "'alta'" in dart_content
    assert "'muy_alta'" in dart_content
    print("  [PASS] Perfiles 'baja', 'media', 'alta', 'muy_alta' presentes en StorageService.")

def test_settings_screen():
    print("  [TEST] Verificando selector UI en SettingsScreen.dart...")
    screen_file = "app_source/lib/screens/settings_screen.dart"
    with open(screen_file, "r", encoding="utf-8") as f:
        screen_content = f.read()

    assert "ButtonSegment(value: 'baja', label: Text('Baja'))" in screen_content
    assert "ButtonSegment(value: 'media', label: Text('Media'))" in screen_content
    assert "ButtonSegment(value: 'alta', label: Text('Alta'))" in screen_content
    assert "ButtonSegment(value: 'muy_alta', label: Text('Muy alta'))" in screen_content
    assert "case 'muy_alta':" in screen_content
    print("  [PASS] SegmentedButton y hint text configurados para 4 niveles de altura.")

def test_kotlin_keyboard_service():
    print("  [TEST] Verificando constantes y factores en Kotlin (VKS + KeyboardSupport)...")
    kt_files = [
        "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt",
        # SPK-05: las constantes viven en el módulo de soporte y la
        # lectura en el de prefs (mismo paquete).
        "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/KeyboardSupport.kt",
        "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/KeyboardPrefs.kt",
    ]
    kt_content = ""
    for kt_file in kt_files:
        with open(kt_file, "r", encoding="utf-8") as f:
            kt_content += f.read()

    assert 'HEIGHT_PROFILE_BAJA = "baja"' in kt_content
    assert 'HEIGHT_PROFILE_MEDIA = "media"' in kt_content
    assert 'HEIGHT_PROFILE_ALTA = "alta"' in kt_content
    assert 'HEIGHT_PROFILE_MUY_ALTA = "muy_alta"' in kt_content

    assert 'HEIGHT_FACTOR_BAJA = 0.85f' in kt_content
    assert 'HEIGHT_FACTOR_MEDIA = 1f' in kt_content
    assert 'HEIGHT_FACTOR_ALTA = 1.15f' in kt_content
    assert 'HEIGHT_FACTOR_MUY_ALTA = 1.30f' in kt_content

    assert 'HEIGHT_PROFILE_MUY_ALTA -> HEIGHT_FACTOR_MUY_ALTA' in kt_content
    print("  [PASS] Factor 1.30f (+15% respecto a 'alta') configurado y mapeado en Kotlin.")

if __name__ == "__main__":
    print("=" * 60)
    print(" INICIANDO TEST SUITE: ALTURA DE TECLAS DEL TECLADO")
    print("=" * 60)
    try:
        test_height_profiles()
        test_settings_screen()
        test_kotlin_keyboard_service()
        print("=" * 60)
        print(" RESULTADOS: Todos los tests pasaron exitosamente.")
        print("=" * 60)
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        sys.exit(1)
