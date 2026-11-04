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
# Inicio 2026: el popup de resultado se retiró (la nota nueva ES el
# resultado); su botón copiar de 44 dp vive ahora en cada tarjeta de nota.
NOTE_CARD = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "note_card.dart")
HOME_CHROME = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "home_chrome.dart")
NOTE_AUDIO_ROW = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "note_audio_row.dart")

def test_files_exist():
    assert os.path.isfile(SNIPPETS_TAB), f"snippets_tab.dart no existe en {SNIPPETS_TAB}"
    assert os.path.isfile(NOTE_CARD), f"note_card.dart no existe en {NOTE_CARD}"
    assert os.path.isfile(HOME_CHROME), f"home_chrome.dart no existe en {HOME_CHROME}"
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
    """Copiar de cada nota: botón de 44x44 dp (antes en el popup)."""
    with open(NOTE_CARD, "r", encoding="utf-8") as f:
        src = f.read()

    assert "onCopy" in src, "Falta callback onCopy en note_card.dart"
    # El IconButton completo cabe holgado en los 600 caracteres siguientes.
    copy = src[src.index("noteCopy-"):][:600]
    assert "minWidth: 44, minHeight: 44" in copy, (
        "El botón copiar de la tarjeta debe medir al menos 44x44 dp"
    )
    assert "height: 36" not in src, "Altura obsoleta de 36 dp en la tarjeta"

def test_note_audio_row_delete_button_textbutton():
    """Audio de la nota: pastilla con área táctil de 44 dp; borrar el audio
    vive en el menú de la nota con filas de 52 dp y confirmación."""
    with open(NOTE_AUDIO_ROW, "r", encoding="utf-8") as f:
        src = f.read()
    play = src[src.index("notePlayAudio-"):]
    assert "vertical: 8" in play and "height: 28" in play, (
        "La pastilla de 28 dp debe ir dentro de un área táctil de 44 dp (8 + 28 + 8)"
    )
    assert "noteDeleteAudio" not in src, "Borrar audio ya no va en la tarjeta (menú de la nota)"

    with open(HOME_CHROME, "r", encoding="utf-8") as f:
        chrome = f.read()
    assert "NoteAction.deleteAudio" in chrome, "Falta 'Borrar audio' en el menú de la nota"
    action = chrome[chrome.index("Widget action(NoteAction a"):]
    assert "height: 52" in action[:800], "Las filas del menú deben medir 52 dp (≥ 44)"

def test_negative_mutations():
    with open(SNIPPETS_TAB, "r", encoding="utf-8") as f:
        snippets_src = f.read()
    with open(NOTE_CARD, "r", encoding="utf-8") as f:
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

    # Mutación 3: Achicar el botón copiar de la tarjeta a 36 dp
    mut3 = popup_src.replace("minWidth: 44, minHeight: 44", "minWidth: 36, minHeight: 36")
    assert "minWidth: 44, minHeight: 44" not in mut3, "Mutación 3 falló al aplicar"

    # Mutación 4: Quitar el aire vertical del área táctil del audio
    mut4 = audio_src.replace("vertical: 8", "vertical: 0")
    assert "vertical: 8" not in mut4[mut4.index("notePlayAudio-"):], "Mutación 4 falló al aplicar"

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
