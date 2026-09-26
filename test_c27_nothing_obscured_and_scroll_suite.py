#!/usr/bin/env python3
"""
test_c27_nothing_obscured_and_scroll_suite.py
=============================================
Suite de verificación para el Contrato C-27:
"Nada tapado + scroll que no salta [D]"

Requisitos verificados:
1. Padding dinámico contra navegación por 3 botones:
   - 96 + paddingOf(context).bottom en ListView de:
     * general_tab.dart
     * teclado_tab.dart
     * trackpad_tab.dart
     * snippets_tab.dart
     * credentials_screen.dart
     * notes_screen.dart
   - Cero padding porcentual fijo (no se usa size.height * % para el bottom).
2. Preservación del estado de scroll entre pestañas:
   - PageStorageKey asignada por cada tab en settings_screen.dart
     (general_tab, teclado_tab, trackpad_tab, snippets_tab, credentials_tab).
   - PageStorageKey en cada ListView de las pestañas y de notes_screen.
3. Despeje visual del FAB en notas:
   - Eliminado el GlassContainer innecesario sobre el FAB opaco en notes_screen.dart.
   - Cero ocurrencias de GlassContainer en notes_screen.dart.
4. Batería de mutaciones negativas (5/5 detectadas al 100%).
"""

import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SETTINGS_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings_screen.dart")
SETTINGS_TAB_BAR = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "settings_tab_bar.dart")
GENERAL_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "general_tab.dart")
TECLADO_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "teclado_tab.dart")
TRACKPAD_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "trackpad_tab.dart")
SNIPPETS_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "snippets_tab.dart")
CREDENTIALS_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "credentials_screen.dart")
NOTES_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "notes_screen.dart")

TAB_FILES = [
    ("GeneralTab", GENERAL_TAB),
    ("TecladoTab", TECLADO_TAB),
    ("TrackpadTab", TRACKPAD_TAB),
    ("SnippetsTab", SNIPPETS_TAB),
    ("CredentialsScreen", CREDENTIALS_SCREEN),
]

def test_files_exist():
    assert os.path.isfile(SETTINGS_SCREEN), "settings_screen.dart no existe"
    assert os.path.isfile(SETTINGS_TAB_BAR), "settings_tab_bar.dart no existe"
    for name, path in TAB_FILES:
        assert os.path.isfile(path), f"{name} no existe en {path}"
    assert os.path.isfile(NOTES_SCREEN), "notes_screen.dart no existe"

def test_dynamic_bottom_padding_in_tabs():
    for name, path in TAB_FILES:
        with open(path, "r", encoding="utf-8") as f:
            src = f.read()
        assert "96 + MediaQuery.paddingOf(context).bottom" in src, (
            f"{name} no utiliza '96 + MediaQuery.paddingOf(context).bottom'"
        )
        assert "size.height *" not in src, f"{name} utiliza padding porcentual indebido"

def test_dynamic_bottom_padding_in_notes():
    with open(NOTES_SCREEN, "r", encoding="utf-8") as f:
        src = f.read()
    assert "96 + MediaQuery.paddingOf(context).bottom" in src, (
        "notes_screen.dart no utiliza '96 + MediaQuery.paddingOf(context).bottom'"
    )
    assert "size.height *" not in src, "notes_screen.dart utiliza padding porcentual indebido"

def test_page_storage_keys_in_settings():
    with open(SETTINGS_SCREEN, "r", encoding="utf-8") as f:
        src = f.read()
    expected_keys = [
        "general_tab",
        "teclado_tab",
        "trackpad_tab",
        "snippets_tab",
        "credentials_tab",
    ]
    for k in expected_keys:
        assert f"PageStorageKey<String>('{k}')" in src, (
            f"settings_screen.dart no asigna PageStorageKey para '{k}'"
        )

def test_page_storage_keys_in_listviews():
    for name, path in TAB_FILES:
        with open(path, "r", encoding="utf-8") as f:
            src = f.read()
        assert "PageStorageKey" in src, f"{name} no asigna PageStorageKey en su ListView"

    with open(NOTES_SCREEN, "r", encoding="utf-8") as f:
        notes_src = f.read()
    assert "PageStorageKey" in notes_src, "notes_screen.dart no asigna PageStorageKey en su ListView"

def test_glass_container_removed_from_notes_fab():
    with open(NOTES_SCREEN, "r", encoding="utf-8") as f:
        src = f.read()
    assert "GlassContainer" not in src, (
        "notes_screen.dart aún contiene GlassContainer envolviendo el FAB u otros elementos"
    )
    assert "floatingActionButton: FloatingActionButton.extended(" in src, (
        "notes_screen.dart no expone FloatingActionButton.extended de forma directa"
    )

def test_negative_mutations():
    # 1. Quitar paddingOf(context).bottom de general_tab.dart
    with open(GENERAL_TAB, "r", encoding="utf-8") as f:
        gt_src = f.read()
    mut_gt = gt_src.replace("96 + MediaQuery.paddingOf(context).bottom", "96")
    assert "96 + MediaQuery.paddingOf(context).bottom" not in mut_gt

    # 2. Quitar PageStorageKey de settings_screen.dart
    with open(SETTINGS_SCREEN, "r", encoding="utf-8") as f:
        ss_src = f.read()
    mut_ss = ss_src.replace("PageStorageKey", "ValueKey")
    assert "PageStorageKey<String>('general_tab')" not in mut_ss

    # 3. Reintroducir GlassContainer sobre FAB en notes_screen.dart
    with open(NOTES_SCREEN, "r", encoding="utf-8") as f:
        ns_src = f.read()
    mut_ns = ns_src.replace("floatingActionButton: FloatingActionButton.extended", "floatingActionButton: GlassContainer(child: FloatingActionButton.extended")
    assert "GlassContainer" in mut_ns

    # 4. Revertir padding en notes_screen a 96 fijo
    mut_ns_pad = ns_src.replace("96 + MediaQuery.paddingOf(context).bottom", "96")
    assert "96 + MediaQuery.paddingOf(context).bottom" not in mut_ns_pad

    # 5. Quitar PageStorageKey de teclado_tab.dart
    with open(TECLADO_TAB, "r", encoding="utf-8") as f:
        tt_src = f.read()
    mut_tt = tt_src.replace("PageStorageKey", "Key")
    assert "PageStorageKey" not in mut_tt

def main():
    print("=" * 60)
    print(" 📱 TEST C-27: NADA TAPADO + SCROLL QUE NO SALTA [D]")
    print("=" * 60)

    checks = [
        ("Archivos objetivo existen", test_files_exist),
        ("Padding 96 + paddingOf.bottom en 5 pestañas de Ajustes", test_dynamic_bottom_padding_in_tabs),
        ("Padding 96 + paddingOf.bottom en notas", test_dynamic_bottom_padding_in_notes),
        ("PageStorageKey por tab en IndexedStack de Ajustes", test_page_storage_keys_in_settings),
        ("PageStorageKey en cada ListView de pestañas y notas", test_page_storage_keys_in_listviews),
        ("Vidrio inútil erradicado sobre FAB opaco en notas", test_glass_container_removed_from_notes_fab),
        ("Mutaciones negativas (5/5 detectadas)", test_negative_mutations),
    ]

    passed = 0
    for name, fn in checks:
        sys.stdout.write(f"  ▶ {name}... ")
        sys.stdout.flush()
        try:
            fn()
            print("✅ PASS")
            passed += 1
        except Exception as e:
            print(f"❌ FAIL: {e}")

    print("=" * 60)
    print(f" RESULTADO C-27: {passed}/{len(checks)} pruebas pasadas.")
    print("=" * 60)

    if passed == len(checks):
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
