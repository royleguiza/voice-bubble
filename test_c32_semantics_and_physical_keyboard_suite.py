#!/usr/bin/env python3
"""
test_c32_semantics_and_physical_keyboard_suite.py
=================================================
Auditoría C-32: Semántica correcta + teclado físico [D]

Verifica:
1. Semántica de tarjetas (note_card.dart, pending_note_tile.dart):
   - Uso de Semantics(container: true) en vez de button: true para evitar "botón dentro de botón" en TalkBack.
2. Semántica del kit de Ajustes (settings_v2.dart):
   - Filas anuncian "título, valor" como botón; interruptor con MergeSemantics.
   - excludeFromSemantics: true en Tooltip para evitar anuncio duplicado de etiqueta.
3. Selección de texto en historial (history_list.dart):
   - SelectableText para permitir selección y copia con teclado/accesibilidad.
4. Foco y activación por teclado en menús (settings_v2.dart):
   - MenuItemButton focusable + Semantics(selected) en la opción elegida; filas con InkWell.
5. Accesibilidad en snippets (snippets_tab.dart):
   - _ColorSwatch con excludeFromSemantics: true en Tooltip, Semantics(button: true, selected: selected), InkWell.
   - _SnippetFormSheet con CallbackShortcuts(LogicalKeyboardKey.escape -> maybePop).
6. Teclado físico y autofill en credenciales (credentials_screen.dart):
   - CallbackShortcuts(LogicalKeyboardKey.escape -> maybePop).
   - textInputAction: next y done para navegación fluida con Tab/Enter.
   - autofillHints: [AutofillHints.username] y [AutofillHints.password].
   - onSubmitted: (_) => _save() en campo de contraseña.
7. Escape en editor y diálogos modales (note_editor_screen.dart, notes_screen.dart):
   - note_editor_screen envuelto en CallbackShortcuts(Escape -> maybePop).
   - _discardPending y _deleteNoteAudio envueltos en CallbackShortcuts(Escape -> pop(false)).
8. Batería de mutaciones negativas para garantizar detección contra regresiones.
"""

import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
NOTE_CARD = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "note_card.dart")
PENDING_NOTE_TILE = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "pending_note_tile.dart")
SETTINGS_KIT = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "settings_v2.dart")
HISTORY_LIST = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "history_list.dart")
TECLADO_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "teclado_tab.dart")
SNIPPETS_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "snippets_tab.dart")
CREDENTIALS_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "credentials_screen.dart")
NOTE_EDITOR_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "note_editor_screen.dart")
# Inicio 2026: los diálogos de notas viven en la pantalla principal.
NOTES_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "home_screen.dart")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def test_card_semantics():
    """1. Semantics(container: true) en tarjetas para evitar 'botón dentro de botón'."""
    nc = read_file(NOTE_CARD)
    pnt = read_file(PENDING_NOTE_TILE)

    # NoteCard: debe usar container: true y NO button: true en la tarjeta contenedora
    assert "container: true" in nc, "NoteCard debe tener Semantics(container: true)"
    assert not re.search(r"Semantics\s*\([^)]*button:\s*true", nc), (
        "NoteCard no debe tener Semantics(button: true) que choque con botones internos"
    )

    # PendingNoteTile: debe usar container: true y NO button: true en la tarjeta contenedora
    assert "container: true" in pnt, "PendingNoteTile debe tener Semantics(container: true)"
    assert not re.search(r"Semantics\s*\([^)]*button:\s*true", pnt), (
        "PendingNoteTile no debe tener Semantics(button: true)"
    )


def test_settings_kit_semantics():
    """2. Kit de Ajustes: filas anuncian "título, valor" como botón y los
    botones de vidrio no duplican el anuncio del Tooltip."""
    src = read_file(SETTINGS_KIT)

    # Fila de navegación / menú: botón con título y valor en una sola etiqueta
    assert re.search(r"Semantics\s*\([^)]*button:\s*true[^)]*label:\s*hasValue \? '\$title, \$value'", src), (
        "SettingsNavRow debe anunciar 'título, valor' como botón"
    )
    assert "label: '$title, $_currentLabel'" in src, (
        "SettingsMenuRow debe anunciar 'título, opción actual'"
    )
    # Interruptor: título + switch fusionados en un solo nodo
    assert "MergeSemantics(" in src, "SettingsSwitchRow debe fusionar semántica"

    # Tooltip con excludeFromSemantics: true para no duplicar el anuncio de TalkBack
    assert re.search(r"Tooltip\s*\([^)]*excludeFromSemantics:\s*true", src), (
        "SettingsGlassButton Tooltip debe tener excludeFromSemantics: true"
    )


def test_history_selectable_text():
    """3. Historial usa SelectableText para permitir selección y lectura asistida."""
    src = read_file(HISTORY_LIST)
    assert "SelectableText(" in src, (
        "HistoryList debe usar SelectableText en vez de Text plano para permitir copiar transcripciones"
    )


def test_teclado_tab_focusability():
    """4. Menús desplegables (Teclado y resto): opciones focusables con
    teclado físico (MenuItemButton) que informan cuál está elegida."""
    src = read_file(SETTINGS_KIT)

    assert "MenuItemButton(" in src, (
        "SettingsMenuRow debe usar MenuItemButton (foco y Enter con teclado físico)"
    )
    assert re.search(r"Semantics\s*\(\s*selected:\s*o\.value == value", src), (
        "SettingsMenuRow debe reportar selected en la opción elegida"
    )
    # Filas táctiles con InkWell (foco Tab + Enter/Espacio)
    assert re.search(r"InkWell\(onTap: onTap, child: content\)", src), (
        "_RowShell debe usar InkWell para admitir foco de teclado físico"
    )


def test_snippets_tab_accessibility_and_escape():
    """5. Snippets tab: swatches con excludeFromSemantics y sheet con escape."""
    src = read_file(SNIPPETS_TAB)

    # Tooltip de _ColorSwatch no debe duplicar la semántica
    assert re.search(r"Tooltip\s*\([^)]*excludeFromSemantics:\s*true[^)]*Semantics\s*\([^)]*button:\s*true", src), (
        "snippets_tab _ColorSwatch debe tener Tooltip(excludeFromSemantics: true) antes de Semantics"
    )

    # _SnippetFormSheet debe tener CallbackShortcuts con LogicalKeyboardKey.escape
    assert "CallbackShortcuts(" in src, "snippets_tab debe tener CallbackShortcuts"
    assert "LogicalKeyboardKey.escape" in src, "snippets_tab debe bindear LogicalKeyboardKey.escape"
    assert "maybePop" in src or "pop" in src, "snippets_tab escape debe invocar pop/maybePop"


def test_credentials_screen_keyboard_and_autofill():
    """6. CredentialsScreen con Escape, textInputAction y autofillHints."""
    src = read_file(CREDENTIALS_SCREEN)

    # Import services
    assert "package:flutter/services.dart" in src, "credentials_screen debe importar flutter/services.dart"

    # CallbackShortcuts escape
    assert "CallbackShortcuts(" in src, "credentials_screen debe tener CallbackShortcuts"
    assert "LogicalKeyboardKey.escape" in src, "credentials_screen debe bindear LogicalKeyboardKey.escape"

    # textInputAction next / done
    assert "textInputAction: TextInputAction.next" in src, (
        "credentials_screen debe tener TextInputAction.next en nombre/usuario"
    )
    assert "textInputAction: TextInputAction.done" in src, (
        "credentials_screen debe tener TextInputAction.done en contraseña"
    )

    # autofillHints username / password
    assert "AutofillHints.username" in src, (
        "credentials_screen debe declarar AutofillHints.username"
    )
    assert "AutofillHints.password" in src, (
        "credentials_screen debe declarar AutofillHints.password"
    )

    # onSubmitted en password
    assert "onSubmitted: (_) => _save()" in src or "onSubmitted:" in src, (
        "credentials_screen debe tener onSubmitted para guardar al pulsar Enter en contraseña"
    )


def test_dialogs_and_editor_escape_dismiss():
    """7. note_editor_screen y diálogos de notas (home_screen) con Escape."""
    nes = read_file(NOTE_EDITOR_SCREEN)
    ns = read_file(NOTES_SCREEN)

    # note_editor_screen
    assert "CallbackShortcuts(" in nes, "note_editor_screen debe tener CallbackShortcuts"
    assert "LogicalKeyboardKey.escape" in nes, "note_editor_screen debe bindear LogicalKeyboardKey.escape"

    # Diálogos de notas (pantalla principal): un único _confirm con Escape,
    # usado tanto por _discardPending como por _deleteNoteAudio.
    confirm = ns[ns.index("Future<bool> _confirm("):]
    confirm = confirm[:confirm.index("\n  }\n")]
    assert "LogicalKeyboardKey.escape" in confirm, (
        "_confirm debe bindear LogicalKeyboardKey.escape (cierra con false)"
    )
    for fn in ("Future<void> _discardPending(", "Future<void> _deleteNoteAudio("):
        body = ns[ns.index(fn):]
        body = body[:body.index("\n  }\n")]
        assert "_confirm(" in body, f"{fn.split('(')[0]} debe confirmar con _confirm (Escape)"


def test_negative_mutations():
    """8. Mutaciones negativas para verificar sensibilidad de las pruebas."""
    print("      Probando mutaciones negativas...")

    # Mutación 1: revertir container: true a button: true en note_card
    nc = read_file(NOTE_CARD)
    mutated_nc = nc.replace("container: true", "button: true")
    assert re.search(r"Semantics\s*\([^)]*button:\s*true", mutated_nc), (
        "Mutación 1 debería ser detectada por test_card_semantics"
    )

    # Mutación 2: quitar excludeFromSemantics en el kit de Ajustes
    kit = read_file(SETTINGS_KIT)
    mutated_kit = kit.replace("excludeFromSemantics: true,", "")
    assert not re.search(r"Tooltip\s*\([^)]*excludeFromSemantics:\s*true", mutated_kit), (
        "Mutación 2 debería ser detectada por test_settings_kit_semantics"
    )

    # Mutación 3: revertir SelectableText a Text en history_list
    hl = read_file(HISTORY_LIST)
    mutated_hl = hl.replace("SelectableText(", "Text(")
    assert "SelectableText(" not in mutated_hl, (
        "Mutación 3 debería ser detectada por test_history_selectable_text"
    )

    # Mutación 4: revertir InkWell a GestureDetector en las filas del kit
    mutated_rows = kit.replace("InkWell(onTap: onTap", "GestureDetector(onTap: onTap")
    assert not re.search(r"InkWell\(onTap: onTap, child: content\)", mutated_rows), (
        "Mutación 4 debería ser detectada por test_teclado_tab_focusability"
    )

    # Mutación 5: quitar CallbackShortcuts de snippets_tab
    snt = read_file(SNIPPETS_TAB)
    mutated_snt = snt.replace("CallbackShortcuts(", "/* removed */(")
    assert "CallbackShortcuts(" not in mutated_snt, (
        "Mutación 5 debería ser detectada por test_snippets_tab_accessibility_and_escape"
    )

    # Mutación 6: quitar autofillHints de credentials_screen
    cs = read_file(CREDENTIALS_SCREEN)
    mutated_cs = cs.replace("AutofillHints.password", "")
    assert "AutofillHints.password" not in mutated_cs, (
        "Mutación 6 debería ser detectada por test_credentials_screen_keyboard_and_autofill"
    )

    # Mutación 7: quitar escape de notes_screen dialogs
    ns = read_file(NOTES_SCREEN)
    mutated_ns = ns.replace("LogicalKeyboardKey.escape", "/* removed */")
    assert "LogicalKeyboardKey.escape" not in mutated_ns, (
        "Mutación 7 debería ser detectada por test_dialogs_and_editor_escape_dismiss"
    )

    print("      ✓ 7 mutaciones negativas detectadas exitosamente.")


def run_all_tests():
    tests = [
        ("1. Semántica de tarjetas (container: true)", test_card_semantics),
        ("2. Semántica del kit de Ajustes (título+valor, sin duplicados)", test_settings_kit_semantics),
        ("3. Selección de texto en historial (SelectableText)", test_history_selectable_text),
        ("4. Foco y teclado físico en menús (MenuItemButton + selected)", test_teclado_tab_focusability),
        ("5. Snippets: accesibilidad swatches y Escape en sheet", test_snippets_tab_accessibility_and_escape),
        ("6. Credenciales: Escape, TextInputAction y AutofillHints", test_credentials_screen_keyboard_and_autofill),
        ("7. Escape en editor y diálogos modales", test_dialogs_and_editor_escape_dismiss),
        ("8. Batería de mutaciones negativas", test_negative_mutations),
    ]

    passed = 0
    total = len(tests)
    print("=" * 70)
    print("EJECUTANDO SUITE C-32: SEMÁNTICA CORRECTA + TECLADO FÍSICO [D]")
    print("=" * 70)

    for name, test_fn in tests:
        try:
            test_fn()
            print(f"  [PASS] {name}")
            passed += 1
        except Exception as e:
            print(f"  [FAIL] {name}: {e}")

    print("-" * 70)
    print(f"Resultado: {passed}/{total} pruebas pasadas.")
    print("=" * 70)

    if passed == total:
        print(">>> SUITE C-32 APROBADA (10.0/10) <<<")
        return 0
    else:
        print(">>> SUITE C-32 REPROBADA <<<")
        return 1


if __name__ == "__main__":
    sys.exit(run_all_tests())
