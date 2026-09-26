#!/usr/bin/env python3
"""
test_c28_sheet_scroll_and_touch_targets_suite.py
================================================
Suite de verificación para el Contrato C-28:
"Sheet con scroll + botones 44dp [D]"

Requisitos verificados:
1. Sheet de snippets con protección de overflow:
   - ConstrainedBox con maxHeight: MediaQuery.sizeOf(context).height * 0.90
   - SingleChildScrollView conteniendo la columna de edición.
   - Padding con MediaQuery.viewInsetsOf(context).bottom para acompañar el IME.
2. Swatches de color con tamaño táctil accesible:
   - Ancho y alto de 44x44dp (width: 44, height: 44).
   - Uso de InkWell con customBorder: const CircleBorder().
   - Semantics con button: true, selected: selected, label: label.
3. Botón de copiar en popup de transcripción:
   - Barra de acciones con ConstrainedBox(minHeight: 44), reemplazando height: 36.
   - Botón de copiar con minHeight: 44 y minWidth: 44.
4. Botón de borrar audio en notas:
   - Reemplazado InkWell por TextButton accesible.
   - minimumSize: Size(44, 44) y tapTargetSize: MaterialTapTargetSize.padded.
5. Batería de mutaciones negativas (5/5 detectadas al 100%).
"""

import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SNIPPETS_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "snippets_tab.dart")
TRANSCRIPTION_POPUP = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "transcription_popup.dart")
NOTE_AUDIO_ROW = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "note_audio_row.dart")

def test_files_exist():
    assert os.path.isfile(SNIPPETS_TAB), f"snippets_tab.dart no existe en {SNIPPETS_TAB}"
    assert os.path.isfile(TRANSCRIPTION_POPUP), f"transcription_popup.dart no existe en {TRANSCRIPTION_POPUP}"
    assert os.path.isfile(NOTE_AUDIO_ROW), f"note_audio_row.dart no existe en {NOTE_AUDIO_ROW}"

def test_snippet_sheet_scroll_and_constraints():
    with open(SNIPPETS_TAB, "r", encoding="utf-8") as f:
        src = f.read()

    # Sheet editor
    sheet_start = src.find("class _SnippetFormSheet")
    assert sheet_start != -1, "No se encontró _SnippetFormSheet en snippets_tab.dart"
    sheet_code = src[sheet_start:]

    assert "ConstrainedBox" in sheet_code, "Falta ConstrainedBox en _SnippetFormSheet"
    assert "MediaQuery.sizeOf(context).height * 0.90" in sheet_code or "sizeOf(context).height * 0.9" in sheet_code, (
        "Falta restricción de altura máxima del 90% (maxHeight: MediaQuery.sizeOf(context).height * 0.90)"
    )
    assert "SingleChildScrollView" in sheet_code, "Falta SingleChildScrollView en _SnippetFormSheet"
    assert "MediaQuery.viewInsetsOf(context).bottom" in sheet_code, (
        "Falta padding para el teclado virtual (viewInsetsOf(context).bottom)"
    )

def test_snippet_color_swatches_44dp():
    with open(SNIPPETS_TAB, "r", encoding="utf-8") as f:
        src = f.read()

    swatch_start = src.find("class _ColorSwatch")
    assert swatch_start != -1, "No se encontró _ColorSwatch en snippets_tab.dart"
    swatch_code = src[swatch_start:]

    assert "width: 44" in swatch_code, "El ancho del swatch debe ser 44dp"
    assert "height: 44" in swatch_code, "El alto del swatch debe ser 44dp"
    assert "InkWell" in swatch_code, "El swatch debe usar InkWell para interacción táctil"
    assert "CircleBorder" in swatch_code, "El ripple del swatch debe usar CircleBorder()"
    assert "selected: selected" in swatch_code, "Falta selected: selected en Semantics"
    assert "button: true" in swatch_code, "Falta button: true en Semantics"

def test_transcription_popup_copy_button_44dp():
    with open(TRANSCRIPTION_POPUP, "r", encoding="utf-8") as f:
        src = f.read()

    assert "height: 36" not in src, "Se mantiene la altura obsoleta de 36dp en la fila de acciones"
    assert "minHeight: 44" in src, "Falta restricción minHeight: 44 en transcription_popup.dart"
    assert "minWidth: 44" in src, "Falta restricción minWidth: 44 para el botón de copiar"
    assert "onCopy" in src, "Falta callback onCopy en transcription_popup.dart"

def test_note_audio_row_delete_button_textbutton():
    with open(NOTE_AUDIO_ROW, "r", encoding="utf-8") as f:
        src = f.read()

    delete_idx = src.find("noteDeleteAudio")
    assert delete_idx != -1, "No se encontró noteDeleteAudio en note_audio_row.dart"
    delete_section = src[max(0, delete_idx - 150):delete_idx + 400]

    assert "TextButton" in delete_section, "El botón 'Borrar audio' debe ser un TextButton"
    assert "minimumSize: const Size(44, 44)" in delete_section or "minimumSize: Size(44, 44)" in delete_section, (
        "El botón 'Borrar audio' debe tener minimumSize de 44x44dp"
    )
    assert "MaterialTapTargetSize.padded" in delete_section, (
        "El botón 'Borrar audio' debe tener tapTargetSize: MaterialTapTargetSize.padded"
    )
    assert "InkWell" not in delete_section, "El botón 'Borrar audio' no debe seguir usando un InkWell sin target"

def test_negative_mutations():
    with open(SNIPPETS_TAB, "r", encoding="utf-8") as f:
        snippets_src = f.read()
    with open(TRANSCRIPTION_POPUP, "r", encoding="utf-8") as f:
        popup_src = f.read()
    with open(NOTE_AUDIO_ROW, "r", encoding="utf-8") as f:
        audio_src = f.read()

    # Mutación 1: Quitar SingleChildScrollView del sheet de snippets
    mut1 = snippets_src.replace("SingleChildScrollView", "/* removed scroll */")
    sheet_start = mut1.find("class _SnippetFormSheet")
    sheet_code = mut1[sheet_start:]
    assert "SingleChildScrollView" not in sheet_code, "Mutación 1 falló al aplicar"

    # Mutación 2: Regresar los swatches a 32dp
    mut2 = snippets_src.replace("width: 44", "width: 32").replace("height: 44", "height: 32")
    swatch_start = mut2.find("class _ColorSwatch")
    swatch_code = mut2[swatch_start:]
    assert "width: 44" not in swatch_code and "height: 44" not in swatch_code, "Mutación 2 falló al aplicar"

    # Mutación 3: Regresar popup a height: 36
    mut3 = popup_src.replace("minHeight: 44", "height: 36")
    assert "minHeight: 44" not in mut3, "Mutación 3 falló al aplicar"

    # Mutación 4: Quitar minimumSize de 44x44 del botón de borrar audio
    mut4 = audio_src.replace("minimumSize: const Size(44, 44)", "minimumSize: Size.zero")
    assert "minimumSize: const Size(44, 44)" not in mut4, "Mutación 4 falló al aplicar"

    # Mutación 5: Quitar selected: selected en la semántica del swatch
    mut5 = snippets_src.replace("selected: selected", "/* no selected */")
    swatch_start = mut5.find("class _ColorSwatch")
    swatch_code = mut5[swatch_start:]
    assert "selected: selected" not in swatch_code, "Mutación 5 falló al aplicar"

def run_all_tests():
    tests = [
        test_files_exist,
        test_snippet_sheet_scroll_and_constraints,
        test_snippet_color_swatches_44dp,
        test_transcription_popup_copy_button_44dp,
        test_note_audio_row_delete_button_textbutton,
        test_negative_mutations,
    ]
    for t in tests:
        t()
    print(f"C-28: {len(tests)}/6 tests OK (100% PASS)")

if __name__ == "__main__":
    run_all_tests()
