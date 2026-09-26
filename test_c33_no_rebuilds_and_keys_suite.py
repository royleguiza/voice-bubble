#!/usr/bin/env python3
"""
test_c33_no_rebuilds_and_keys_suite.py
======================================
Auditoría C-33: Settings/Home sin rebuilds + keys [D]

Verifica:
1. Fila de sensibilidad de trackpad desacoplada (trackpad_tab.dart):
   - TrackpadSensitivitySection como StatefulWidget con estado local (_current).
   - Debouncer interno (150 ms) para respuesta táctil instantánea sin lag y
     persistencia diferida.
   - Conserva ValueKey('kb-trackpad-sensitivity-slider') en Slider.
2. SettingsScreen sin rebuilds globales en slider (settings_screen.dart):
   - _onTrackpadSensitivitySlider actualiza _trackpadSensitivity y persiste sin setState().
3. Identidad de elementos y ValueKey en listas (notes_screen.dart, history_list.dart):
   - Transcription.id para estabilidad de keys.
   - ValueKey(t.id) en ListTile de HistoryList.
   - ValueKey(n.id) en NoteCard dentro del ListView de NotesScreen.
4. Identidad en filas de audio asociadas (note_card.dart):
   - ValueKey('audio_${note.id}') en NoteAudioRow para reasociación correcta al borrar/editar.
5. Extracción de RecordingController de HomeScreen:
   - Controlador ChangeNotifier en app_source/lib/controllers/recording_controller.dart.
   - Encapsula máquina de estados, umbral minAudioBytes (>= 8000), temporales y burbuja.
   - Integrado en HomeScreen como controlador desacoplado.
6. Batería de mutaciones negativas para garantizar detección contra regresiones.
"""

import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TRACKPAD_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "trackpad_tab.dart")
SETTINGS_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings_screen.dart")
NOTES_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "notes_screen.dart")
NOTE_CARD = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "note_card.dart")
HISTORY_LIST = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "history_list.dart")
TRANSCRIPTION_MODEL = os.path.join(BASE_DIR, "app_source", "lib", "models", "transcription.dart")
RECORDING_CONTROLLER = os.path.join(BASE_DIR, "app_source", "lib", "controllers", "recording_controller.dart")
HOME_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "home_screen.dart")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def test_trackpad_sensitivity_section_stateful_and_debounced():
    """1. TrackpadSensitivitySection como StatefulWidget con Debouncer y estado local."""
    src = read_file(TRACKPAD_TAB)

    assert "class TrackpadSensitivitySection extends StatefulWidget" in src, (
        "TrackpadSensitivitySection debe ser un StatefulWidget con estado propio"
    )
    assert "_TrackpadSensitivitySectionState" in src, (
        "TrackpadSensitivitySection debe tener su clase State correspondiente"
    )
    assert "Debouncer(" in src or "late final Debouncer _debouncer" in src, (
        "TrackpadSensitivitySection debe contener un Debouncer interno"
    )
    assert "Slider(" in src and "kb-trackpad-sensitivity-slider" in src, (
        "Slider debe conservar la clave 'kb-trackpad-sensitivity-slider'"
    )

    # Verificar que el slider actualiza _current de forma local y pasa por debouncer
    state_match = re.search(
        r"class _TrackpadSensitivitySectionState\s+extends State<TrackpadSensitivitySection>.*",
        src,
        re.DOTALL,
    )
    assert state_match, "No se encontró el cuerpo de _TrackpadSensitivitySectionState"
    state_body = state_match.group(0)

    assert "double _current" in state_body or "late double _current" in state_body, (
        "_TrackpadSensitivitySectionState debe gestionar _current localmente"
    )
    assert "_debouncer.run(" in state_body, (
        "La notificación onSensitivityChanged debe ejecutarse mediante _debouncer.run()"
    )
    assert "_debouncer.dispose()" in state_body, (
        "_TrackpadSensitivitySectionState debe liberar el debouncer en dispose()"
    )


def test_settings_screen_no_global_rebuild_on_slider():
    """2. _onTrackpadSensitivitySlider en settings_screen.dart no invoca setState()."""
    src = read_file(SETTINGS_SCREEN)

    handler_match = re.search(
        r"void _onTrackpadSensitivitySlider\s*\([^)]*\)\s*\{([^}]+)\}",
        src,
    )
    assert handler_match, "_onTrackpadSensitivitySlider no encontrado en settings_screen.dart"
    handler_body = handler_match.group(1)

    assert "setState" not in handler_body, (
        "_onTrackpadSensitivitySlider no debe llamar a setState(): reconstruiría toda la pantalla de Ajustes"
    )
    assert "_trackpadSensitivity = " in handler_body, (
        "_onTrackpadSensitivitySlider debe actualizar el valor de configuración"
    )
    assert "setTrackpadSensitivity" in handler_body, (
        "_onTrackpadSensitivitySlider debe persistir la sensibilidad en storageService"
    )


def test_value_keys_on_notes_and_history():
    """3. ValueKey en NoteCard y en HistoryList con id estable."""
    model_src = read_file(TRANSCRIPTION_MODEL)
    history_src = read_file(HISTORY_LIST)
    notes_src = read_file(NOTES_SCREEN)

    # Transcription id
    assert re.search(r"String\s+get\s+id\s*=>", model_src), (
        "Transcription debe exponer un getter id único/estable para keys de widget"
    )

    # HistoryList ListTile key
    assert re.search(r"ListTile\s*\([^)]*key:\s*ValueKey\([^)]*id\)", history_src), (
        "HistoryList debe asignar key: ValueKey(t.id) en cada ListTile"
    )

    # NotesScreen NoteCard key
    assert re.search(r"NoteCard\s*\([^)]*key:\s*ValueKey\([^)]*id\)", notes_src), (
        "NotesScreen debe asignar key: ValueKey(n.id) en cada NoteCard para estabilidad ante borrado"
    )


def test_value_key_on_note_audio_row():
    """4. ValueKey en NoteAudioRow dentro de NoteCard."""
    nc_src = read_file(NOTE_CARD)

    assert re.search(r"NoteAudioRow\s*\([^)]*key:\s*ValueKey\([^)]*id[^)]*\)", nc_src), (
        "NoteCard debe asignar ValueKey que incluya note.id en NoteAudioRow para reasociación correcta de audio"
    )


def test_recording_controller_extracted():
    """5. RecordingController desacoplado con ChangeNotifier y máquina de estados."""
    assert os.path.isfile(RECORDING_CONTROLLER), (
        "app_source/lib/controllers/recording_controller.dart debe existir"
    )
    ctrl_src = read_file(RECORDING_CONTROLLER)
    hs_src = read_file(HOME_SCREEN)

    # Invariantes de clase
    assert "class RecordingController extends ChangeNotifier" in ctrl_src, (
        "RecordingController debe extender ChangeNotifier"
    )
    assert "static const int minAudioBytes = 8000;" in ctrl_src, (
        "RecordingController debe declarar umbral minAudioBytes = 8000"
    )
    assert "hasUsableAudio" in ctrl_src, (
        "RecordingController debe implementar hasUsableAudio"
    )
    assert "toggleRecording" in ctrl_src, (
        "RecordingController debe implementar toggleRecording"
    )
    assert "startRecording" in ctrl_src, (
        "RecordingController debe implementar startRecording"
    )
    assert "stopRecording" in ctrl_src, (
        "RecordingController debe implementar stopRecording"
    )
    assert "retryPending" in ctrl_src, (
        "RecordingController debe implementar retryPending"
    )

    # Integración en HomeScreen
    assert "RecordingController" in hs_src, (
        "HomeScreen debe importar o referenciar RecordingController"
    )
    assert "recordingController" in hs_src, (
        "HomeScreen debe aceptar o inicializar recordingController"
    )


def test_negative_mutations():
    """6. Batería de mutaciones negativas reales contra los invariantes de C-33."""
    mutations = [
        (
            "TrackpadSensitivitySection como StatelessWidget sin Debouncer",
            TRACKPAD_TAB,
            lambda s: s.replace("extends StatefulWidget", "extends StatelessWidget"),
            test_trackpad_sensitivity_section_stateful_and_debounced,
        ),
        (
            "Debouncer removido de TrackpadSensitivitySection",
            TRACKPAD_TAB,
            lambda s: s.replace("_debouncer.run(", "widget.onSensitivityChanged(value); //"),
            test_trackpad_sensitivity_section_stateful_and_debounced,
        ),
        (
            "setState() reintroducido en _onTrackpadSensitivitySlider de Ajustes",
            SETTINGS_SCREEN,
            lambda s: s.replace("_trackpadSensitivity = value;", "setState(() => _trackpadSensitivity = value);"),
            test_settings_screen_no_global_rebuild_on_slider,
        ),
        (
            "ValueKey removido de NoteCard en NotesScreen",
            NOTES_SCREEN,
            lambda s: re.sub(r"key:\s*ValueKey\([^)]+\),?", "", s),
            test_value_keys_on_notes_and_history,
        ),
        (
            "ValueKey removido de ListTile en HistoryList",
            HISTORY_LIST,
            lambda s: re.sub(r"key:\s*ValueKey\([^)]+\),?", "", s),
            test_value_keys_on_notes_and_history,
        ),
        (
            "ValueKey removido de NoteAudioRow en NoteCard",
            NOTE_CARD,
            lambda s: re.sub(r"key:\s*ValueKey\([^)]+\),?", "", s),
            test_value_key_on_note_audio_row,
        ),
        (
            "minAudioBytes roto en RecordingController",
            RECORDING_CONTROLLER,
            lambda s: s.replace("minAudioBytes = 8000;", "minAudioBytes = 500;"),
            test_recording_controller_extracted,
        ),
    ]

    for desc, filepath, mutator, test_func in mutations:
        orig = read_file(filepath)
        mutated = mutator(orig)
        assert mutated != orig, f"La mutación '{desc}' no modificó el archivo"
        try:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(mutated)
            failed = False
            try:
                test_func()
            except AssertionError:
                failed = True
            assert failed, f"La mutación negativa falló en ser detectada: {desc}"
        finally:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(orig)


def run_all_tests():
    tests = [
        ("C-33.1: TrackpadSensitivitySection stateful y con Debouncer", test_trackpad_sensitivity_section_stateful_and_debounced),
        ("C-33.2: SettingsScreen sin rebuild global en slider", test_settings_screen_no_global_rebuild_on_slider),
        ("C-33.3: ValueKey en NoteCard y HistoryList con id estable", test_value_keys_on_notes_and_history),
        ("C-33.4: ValueKey en NoteAudioRow", test_value_key_on_note_audio_row),
        ("C-33.5: RecordingController extraído con ChangeNotifier y umbral 8000B", test_recording_controller_extracted),
        ("C-33.6: Detección de 7 mutaciones negativas", test_negative_mutations),
    ]

    passed = 0
    print("=" * 65)
    print(" 🚀 INICIANDO AUDITORÍA C-33: Settings/Home sin rebuilds + keys")
    print("=" * 65)

    for name, test_func in tests:
        try:
            test_func()
            print(f"  ▶ {name}... ✅ PASS")
            passed += 1
        except AssertionError as e:
            print(f"  ▶ {name}... ❌ FAIL: {e}")
        except Exception as e:
            print(f"  ▶ {name}... 💥 ERROR: {type(e).__name__}: {e}")

    print("=" * 65)
    print(f" RESULTADO C-33: {passed}/{len(tests)} pruebas pasadas.")
    print("=" * 65)

    if passed == len(tests):
        print("✨ Todos los invariantes de C-33 verificados correctamente.")
        return 0
    else:
        print("⚠️ Fallos detectados en contrato C-33.")
        return 1


if __name__ == "__main__":
    sys.exit(run_all_tests())
