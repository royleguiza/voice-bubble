#!/usr/bin/env python3
"""
Test Suite: Keyboard Key Height Profile & Integration Verification.
Verifica:
1. Sincronización de perfiles entre Dart (StorageService) y Kotlin (VoiceKeyboardService).
2. SegmentedButton en SettingsScreen con los 4 perfiles requeridos.
3. Constantes y factores matemáticos proporcionales (15% por nivel).
4. Pruebas de regresión: los perfiles existentes ('baja', 'media', 'alta') permanecen intactos.
5. Espaciado anti-fantasma: cadena completa Dart→prefs→Kotlin→gaps
   (compacto/normal/amplio con fuente única de factores).
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
    # SPK-06 mod4: SegmentedButton vive en settings/teclado_tab.dart
    with open("app_source/lib/screens/settings/teclado_tab.dart", "r", encoding="utf-8") as f:
        teclado_content = f.read()
    combined = screen_content + teclado_content

    assert "ButtonSegment(value: 'baja', label: Text('Baja'))" in combined
    assert "ButtonSegment(value: 'media', label: Text('Media'))" in combined
    assert "ButtonSegment(value: 'alta', label: Text('Alta'))" in combined
    assert "ButtonSegment(value: 'muy_alta', label: Text('Muy alta'))" in combined
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

def test_key_spacing_chain():
    print("  [TEST] Verificando cadena de espaciado anti-fantasma...")
    with open("app_source/lib/services/storage_service.dart", "r", encoding="utf-8") as f:
        dart = f.read()
    # Dart: dominio + default + acceso validado.
    assert "'compacto'" in dart and "'normal'" in dart and "'amplio'" in dart
    assert "'extra'" in dart
    assert "defaultKeySpacing = 'normal'" in dart
    assert "getKeySpacing()" in dart and "setKeySpacing(" in dart
    # UI: selector en el tab Teclado (no en otro tab) + cableado en Settings.
    with open("app_source/lib/screens/settings/teclado_tab.dart", "r", encoding="utf-8") as f:
        tab = f.read()
    assert "kb-key-spacing-selector" in tab
    assert "ButtonSegment(value: 'compacto'" in tab
    assert "ButtonSegment(value: 'normal'" in tab
    assert "ButtonSegment(value: 'amplio'" in tab
    assert "ButtonSegment(value: 'extra'" in tab
    assert "onSaveKeySpacing" in tab
    with open("app_source/lib/screens/settings_screen.dart", "r", encoding="utf-8") as f:
        settings = f.read()
    assert "_saveKeySpacing" in settings and "getKeySpacing()" in settings
    # Contrato: la clave viaja por el puente verificado.
    with open("docs/contract-keys.txt", "r", encoding="utf-8") as f:
        assert "kb_key_spacing" in f.read().splitlines()
    assert "kbKeySpacingKey" in dart
    # Kotlin: consts + lectura tolerante + factor + punto único de escala.
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    with open(f"{kt_dir}/KeyboardSupport.kt", "r", encoding="utf-8") as f:
        support = f.read()
    assert 'SPACING_PROFILE_COMPACTO = "compacto"' in support
    assert 'SPACING_PROFILE_NORMAL = "normal"' in support
    assert 'SPACING_PROFILE_AMPLIO = "amplio"' in support
    assert 'SPACING_PROFILE_EXTRA = "extra"' in support
    assert "SPACING_FACTOR_COMPACTO = 0.8f" in support
    assert "SPACING_FACTOR_NORMAL = 1f" in support
    assert "SPACING_FACTOR_AMPLIO = 1.5f" in support
    assert "SPACING_FACTOR_EXTRA = 2.0f" in support
    with open(f"{kt_dir}/KeyboardPrefs.kt", "r", encoding="utf-8") as f:
        prefs = f.read()
    assert '"flutter.kb_key_spacing"' in prefs
    assert "SPACING_PROFILE_EXTRA" in prefs
    assert "keySpacingFactor" in prefs
    with open(f"{kt_dir}/VoiceKeyboardService.kt", "r", encoding="utf-8") as f:
        vks = f.read()
    assert "R.dimen.kb_key_gap" in vks and "R.dimen.kb_key_gap_h" in vks
    assert "R.dimen.kb_key_gap_v" in vks and "keySpacingFactor" in vks
    print("  [PASS] Cadena Dart→prefs→Kotlin→gaps verificada punta a punta (estático).")

def test_haptic_style_chain():
    print("  [TEST] Verificando cadena de estilo háptico...")
    with open("app_source/lib/services/storage_service.dart", "r", encoding="utf-8") as f:
        dart = f.read()
    assert "'nitido'" in dart and "'firme'" in dart and "'suave'" in dart
    assert "defaultHapticStyle = 'nitido'" in dart
    assert "getHapticStyle()" in dart and "setHapticStyle(" in dart
    with open("app_source/lib/screens/settings/teclado_tab.dart", "r", encoding="utf-8") as f:
        tab = f.read()
    assert "kb-haptic-style-selector" in tab
    assert "ButtonSegment(value: 'nitido'" in tab
    assert "ButtonSegment(value: 'firme'" in tab
    assert "ButtonSegment(value: 'suave'" in tab
    assert "onSaveHapticStyle" in tab
    with open("docs/contract-keys.txt", "r", encoding="utf-8") as f:
        assert "kb_haptic_style" in f.read().splitlines()
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    with open(f"{kt_dir}/KeyboardSupport.kt", "r", encoding="utf-8") as f:
        support = f.read()
    assert 'HAPTIC_STYLE_NITIDO = "nitido"' in support
    assert 'HAPTIC_STYLE_FIRME = "firme"' in support
    assert 'HAPTIC_STYLE_SUAVE = "suave"' in support
    with open(f"{kt_dir}/KeyboardPrefs.kt", "r", encoding="utf-8") as f:
        prefs = f.read()
    assert '"flutter.kb_haptic_style"' in prefs
    with open(f"{kt_dir}/VoiceKeyboardService.kt", "r", encoding="utf-8") as f:
        vks = f.read()
    assert "createOneShot" in vks and "vibrateOnce" in vks
    assert "HAPTIC_STYLE_SUAVE" in vks and "HAPTIC_STYLE_FIRME" in vks
    print("  [PASS] Estilo háptico: setting→pref→one-shot verificado.")

if __name__ == "__main__":
    print("=" * 60)
    print(" INICIANDO TEST SUITE: ALTURA DE TECLAS DEL TECLADO")
    print("=" * 60)
    try:
        test_height_profiles()
        test_settings_screen()
        test_kotlin_keyboard_service()
        test_key_spacing_chain()
        test_haptic_style_chain()
        print("=" * 60)
        print(" RESULTADOS: Todos los tests pasaron exitosamente.")
        print("=" * 60)
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        sys.exit(1)
