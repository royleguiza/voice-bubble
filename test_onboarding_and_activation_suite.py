#!/usr/bin/env python3
"""
Test Suite: Microphone Permission Onboarding & In-App Keyboard Activation.
Verifica:
1. MainActivity.kt expone canal nativo 'showInputMethodPicker' vía InputMethodManager.
2. KeyboardService (Dart) implementa showInputMethodPicker().
3. SettingsScreen registra WidgetsBindingObserver para reactivar estado al volver de ajustes.
4. SettingsScreen dispara automáticamente el modal de selección de teclado al regresar si ya fue habilitado.
5. SettingsScreen y HomeScreen solicitan el permiso de micrófono al arrancar/abrir.
6. SettingsScreen ofrece botón para seleccionar VoiceBubble STT directamente sin salir de la app.
"""

import sys

def test_main_activity_picker():
    print("  [TEST] Verificando showInputMethodPicker en MainActivity.kt...")
    path = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/MainActivity.kt"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    assert '"showInputMethodPicker"' in content, "MainActivity no implementa el canal showInputMethodPicker"
    assert "imm.showInputMethodPicker()" in content, "MainActivity no invoca imm.showInputMethodPicker()"
    print("  [PASS] MainActivity.kt implementa showInputMethodPicker con InputMethodManager nativo.")

def test_dart_keyboard_service():
    print("  [TEST] Verificando showInputMethodPicker() en KeyboardService.dart...")
    path = "app_source/lib/services/keyboard_service.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "Future<bool> showInputMethodPicker() async" in content, "KeyboardService no define showInputMethodPicker()"
    assert "'showInputMethodPicker'" in content, "KeyboardService no llama a 'showInputMethodPicker'"
    print("  [PASS] KeyboardService.dart tiene showInputMethodPicker() integrado.")

def test_settings_screen_lifecycle_and_mic():
    print("  [TEST] Verificando WidgetsBindingObserver y permiso de micrófono en SettingsScreen.dart...")
    path = "app_source/lib/screens/settings_screen.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "with WidgetsBindingObserver" in content, "SettingsScreen no implementa WidgetsBindingObserver"
    assert "didChangeAppLifecycleState" in content, "SettingsScreen no implementa didChangeAppLifecycleState"
    assert "_handleAppResumed" in content, "SettingsScreen no implementa _handleAppResumed"
    assert "_showInputMethodPicker" in content, "SettingsScreen no implementa _showInputMethodPicker"
    assert "_ensureMicrophonePermission" in content, "SettingsScreen no solicita permiso de micrófono"
    assert "Seleccionar VoiceBubble como teclado" in content, "Falta botón directo de selección modal"
    print("  [PASS] SettingsScreen.dart cuenta con ciclo de vida, modal nativo y petición de micrófono.")

def test_home_screen_mic_request():
    print("  [TEST] Verificando petición de permiso de micrófono al arrancar HomeScreen.dart...")
    path = "app_source/lib/screens/home_screen.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "_transcriptionService.requestPermissions()" in content, "HomeScreen no solicita permiso al arrancar"
    print("  [PASS] HomeScreen.dart solicita permisos de micrófono de forma reactiva al iniciar.")

if __name__ == "__main__":
    print("=" * 60)
    print(" INICIANDO TEST SUITE: ONBOARDING & ACTIVACIÓN DE TECLADO")
    print("=" * 60)
    try:
        test_main_activity_picker()
        test_dart_keyboard_service()
        test_settings_screen_lifecycle_and_mic()
        test_home_screen_mic_request()
        print("=" * 60)
        print(" RESULTADOS: Todos los tests pasaron exitosamente.")
        print("=" * 60)
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        sys.exit(1)
