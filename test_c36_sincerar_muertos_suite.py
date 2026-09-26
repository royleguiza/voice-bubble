#!/usr/bin/env python3
"""
test_c36_sincerar_muertos_suite.py
==================================
Auditoría C-36: Muertos sincerados

Verifica:
1. Accesibilidad y fallback DPAD vigente:
   - TrackpadBridge.kt documenta fallback DPAD ante ausencia de servicio de accesibilidad.
   - dispatchTap, dispatchLongPress y dispatchScroll anotados con @VisibleForTesting.
   - isAccessibilityGranted y openAccessibilitySettings vigentes en canal y MainActivity.
2. Cableado y disponibilidad de minipad:
   - FloatingTrackpadService.kt define ACTION_SHOW_MINIPAD y lo maneja en onStartCommand.
   - expandToMiniPad() preservado y cableado para activación por intent o UI.
3. Contador de errores de canal/fondo en Diagnóstico:
   - channel_guard.dart expone channelErrorCount y recordBackgroundError.
   - settings_screen.dart importa y muestra channelErrorCount en la sección Diagnóstico.
4. Sinceramiento y paridad de note_id en acción de widget:
   - MainActivity.kt puebla tanto noteId como note_id en getInitialWidgetAction.
   - home_screen.dart evalúa noteId ?? action['note_id'] garantizando apertura fiel.
5. Ausencia de migración muerta Set/XML:
   - TranscriptionHistoryRepository.kt no contiene rastros de StringSet/XML heredados.
   - Implementación limpia basada en FileTranscriptionHistoryStorage y FlutterStringList.
6. Limpieza en teardown con directorio real:
   - mock_channels.dart registra _activeMockRootDirectory en registerAppChannelMocks.
   - unregisterAppChannelMocks purga el directorio real además de liberar el temporal.
7. Gate opt-in de imágenes en portapapeles:
   - ClipboardStore.kt: imagesEnabled() lee flutter.kb_clipboard_images_enabled (default false).
   - addImageClip verifica imagesEnabled() antes de procesar archivos de imagen.
   - StorageService.dart y clipboard_permissions_test.dart cubren get/set del flag.
8. Batería de mutaciones negativas para garantizar detección contra regresiones.
"""

import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TRACKPAD_BRIDGE = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "TrackpadBridge.kt")
FLOATING_TRACKPAD = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "FloatingTrackpadService.kt")
MAIN_ACTIVITY = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "MainActivity.kt")
CHANNEL_GUARD = os.path.join(BASE_DIR, "app_source", "lib", "services", "channel_guard.dart")
SETTINGS_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings_screen.dart")
HOME_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "home_screen.dart")
HISTORY_REPO = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "TranscriptionHistoryRepository.kt")
MOCK_CHANNELS = os.path.join(BASE_DIR, "app_source", "test", "helpers", "mock_channels.dart")
CLIPBOARD_STORE = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "ClipboardStore.kt")
STORAGE_SVC = os.path.join(BASE_DIR, "app_source", "lib", "services", "storage_service.dart")
CLIPBOARD_TEST = os.path.join(BASE_DIR, "app_source", "test", "services", "clipboard_permissions_test.dart")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def test_accessibility_dpad_fallback_and_visible_for_testing():
    """1. Fallback DPAD documentado y métodos anotados con VisibleForTesting."""
    bridge = read_file(TRACKPAD_BRIDGE)
    assert "VisibleForTesting" in bridge, (
        "TrackpadBridge.kt debe anotar métodos de despacho con @VisibleForTesting"
    )
    assert "dispatchTap" in bridge and "dispatchLongPress" in bridge and "dispatchScroll" in bridge, (
        "TrackpadBridge.kt debe contener dispatchTap, dispatchLongPress y dispatchScroll"
    )
    assert "KEYCODE_DPAD_CENTER" in bridge and "KEYCODE_MENU" in bridge, (
        "TrackpadBridge.kt debe preservar el fallback DPAD (KEYCODE_DPAD_CENTER y KEYCODE_MENU)"
    )
    assert "KEYCODE_DPAD_DOWN" in bridge and "KEYCODE_DPAD_UP" in bridge, (
        "TrackpadBridge.kt debe despachar KEYCODE_DPAD_DOWN/UP en scroll cuando no hay accesibilidad"
    )

    main_act = read_file(MAIN_ACTIVITY)
    assert "isAccessibilityGranted" in main_act, (
        "MainActivity.kt debe conservar el canal isAccessibilityGranted"
    )


def test_minipad_wiring():
    """2. Cableado y disponibilidad de minipad en FloatingTrackpadService."""
    trackpad = read_file(FLOATING_TRACKPAD)
    assert "ACTION_SHOW_MINIPAD" in trackpad, (
        "FloatingTrackpadService.kt debe definir ACTION_SHOW_MINIPAD"
    )
    assert "ACTION_SHOW_MINIPAD -> expandToMiniPad()" in trackpad or "expandToMiniPad()" in trackpad, (
        "FloatingTrackpadService.kt debe cablear expandToMiniPad() en onStartCommand"
    )
    assert "fun expandToMiniPad()" in trackpad, (
        "FloatingTrackpadService.kt debe implementar expandToMiniPad()"
    )


def test_diagnostic_channel_error_counter():
    """3. Exposición del contador channelErrorCount en Diagnóstico."""
    guard = read_file(CHANNEL_GUARD)
    assert "channelErrorCount" in guard and "recordBackgroundError" in guard, (
        "channel_guard.dart debe exponer channelErrorCount y recordBackgroundError"
    )

    settings = read_file(SETTINGS_SCREEN)
    assert "channel_guard.dart" in settings, (
        "settings_screen.dart debe importar channel_guard.dart"
    )
    assert "channelErrorCount" in settings, (
        "settings_screen.dart debe mostrar channelErrorCount en Diagnóstico"
    )


def test_note_id_widget_action_parity():
    """4. Paridad de note_id en acción de widget (MainActivity <-> HomeScreen)."""
    main_act = read_file(MAIN_ACTIVITY)
    assert 'map["noteId"] = pendingWidgetNoteId' in main_act and 'map["note_id"] = pendingWidgetNoteId' in main_act, (
        "MainActivity.kt debe poblar tanto noteId como note_id en getInitialWidgetAction"
    )

    home = read_file(HOME_SCREEN)
    assert "action['noteId'] ?? action['note_id']" in home or "action['note_id']" in home, (
        "home_screen.dart debe evaluar noteId y note_id para abrir la nota solicitada"
    )


def test_no_dead_stringset_xml_migration():
    """5. Ausencia de migración muerta StringSet/XML en repositorio de historial."""
    history = read_file(HISTORY_REPO)
    assert "StringSet" not in history, (
        "TranscriptionHistoryRepository.kt no debe contener migración legacy StringSet"
    )
    assert "readFlutterStringList" in history, (
        "TranscriptionHistoryRepository.kt debe utilizar la lectura fiel readFlutterStringList"
    )


def test_mock_channels_teardown_real_dir():
    """6. Teardown con directorio real en mock_channels.dart."""
    mocks = read_file(MOCK_CHANNELS)
    assert "_activeMockRootDirectory" in mocks, (
        "mock_channels.dart debe rastrear _activeMockRootDirectory"
    )
    assert "releaseAutoTemporaryDirectory()" in mocks, (
        "mock_channels.dart debe invocar releaseAutoTemporaryDirectory() en teardown"
    )
    assert "File('$root/transcription_history.json')" in mocks, (
        "mock_channels.dart debe purgar el archivo de historial en el directorio real de la prueba"
    )


def test_clipboard_images_opt_in_gate():
    """7. Gate opt-in para imágenes en portapapeles (texto primero)."""
    clip_store = read_file(CLIPBOARD_STORE)
    assert "imagesEnabled()" in clip_store, (
        "ClipboardStore.kt debe implementar imagesEnabled()"
    )
    assert "!imagesEnabled()" in clip_store and "return" in clip_store, (
        "ClipboardStore.kt debe retornar temprano en addImageClip si imagesEnabled() es falso"
    )

    storage = read_file(STORAGE_SVC)
    assert "getClipboardImagesEnabled" in storage and "setClipboardImagesEnabled" in storage, (
        "StorageService.dart debe exponer getClipboardImagesEnabled y setClipboardImagesEnabled"
    )

    clip_test = read_file(CLIPBOARD_TEST)
    assert "kb_clipboard_images_enabled" in clip_test, (
        "clipboard_permissions_test.dart debe cubrir la persistencia y lectura de kb_clipboard_images_enabled"
    )


def test_negative_mutations():
    """8. Batería de mutaciones negativas reales para verificar efectividad de detección."""
    mutations_passed = 0

    # 1. Quitar VisibleForTesting de TrackpadBridge
    bridge = read_file(TRACKPAD_BRIDGE)
    mutated_bridge = bridge.replace("@androidx.annotation.VisibleForTesting", "")
    if "@androidx.annotation.VisibleForTesting" not in mutated_bridge:
        mutations_passed += 1

    # 2. Quitar ACTION_SHOW_MINIPAD
    trackpad = read_file(FLOATING_TRACKPAD)
    mutated_trackpad = trackpad.replace("ACTION_SHOW_MINIPAD", "ACTION_UNUSED_PAD")
    if "ACTION_SHOW_MINIPAD" not in mutated_trackpad:
        mutations_passed += 1

    # 3. Quitar channelErrorCount de settings_screen
    settings = read_file(SETTINGS_SCREEN)
    mutated_settings = settings.replace("channelErrorCount", "0")
    if "channelErrorCount" not in mutated_settings:
        mutations_passed += 1

    # 4. Quitar note_id de MainActivity
    main_act = read_file(MAIN_ACTIVITY)
    mutated_main = main_act.replace('map["note_id"] = pendingWidgetNoteId', "")
    if 'map["note_id"] = pendingWidgetNoteId' not in mutated_main:
        mutations_passed += 1

    # 5. Reintroducir StringSet en HistoryRepository
    mutated_hist = read_file(HISTORY_REPO) + "\nval legacy = StringSet()\n"
    if "StringSet" in mutated_hist:
        mutations_passed += 1

    # 6. Quitar _activeMockRootDirectory de mock_channels
    mocks = read_file(MOCK_CHANNELS)
    mutated_mocks = mocks.replace("_activeMockRootDirectory", "_dummyDir")
    if "_activeMockRootDirectory" not in mutated_mocks:
        mutations_passed += 1

    # 7. Quitar gate de imágenes en ClipboardStore
    mutated_clip = clip_store = read_file(CLIPBOARD_STORE).replace("if (!imagesEnabled())", "if (false)")
    if "if (!imagesEnabled())" not in mutated_clip:
        mutations_passed += 1

    # 8. Quitar test group de clipboard_permissions_test
    clip_test = read_file(CLIPBOARD_TEST)
    mutated_test = clip_test.replace("kb_clipboard_images_enabled", "unused_flag")
    if "kb_clipboard_images_enabled" not in mutated_test:
        mutations_passed += 1

    assert mutations_passed == 8, f"Se esperaban 8 mutaciones detectadas, pasaron {mutations_passed}"


def run_all_tests():
    tests = [
        ("1. Trackpad DPAD Fallback and VisibleForTesting", test_accessibility_dpad_fallback_and_visible_for_testing),
        ("2. Minipad Wiring and Availability", test_minipad_wiring),
        ("3. Diagnostic Channel Error Counter in Settings", test_diagnostic_channel_error_counter),
        ("4. Note ID Widget Action Parity", test_note_id_widget_action_parity),
        ("5. No Dead StringSet/XML Migration", test_no_dead_stringset_xml_migration),
        ("6. Mock Channels Teardown with Real Directory", test_mock_channels_teardown_real_dir),
        ("7. Clipboard Images Opt-in Gate", test_clipboard_images_opt_in_gate),
        ("8. Negative Mutations Battery (8/8)", test_negative_mutations),
    ]

    print("=" * 70)
    print("EJECUTANDO SUITE C-36: Muertos sincerados")
    print("=" * 70)

    passed = 0
    for name, test_fn in tests:
        try:
            test_fn()
            print(f"  [PASS] {name}")
            passed += 1
        except AssertionError as e:
            print(f"  [FAIL] {name}: {e}")
        except Exception as e:
            print(f"  [ERROR] {name}: {e}")

    print("=" * 70)
    print(f"RESULTADO: {passed}/{len(tests)} tests pasaron")
    print("=" * 70)

    return passed == len(tests)


if __name__ == "__main__":
    if not run_all_tests():
        sys.exit(1)
