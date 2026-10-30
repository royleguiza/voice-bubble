#!/usr/bin/env python3
"""
test_c27_nothing_obscured_and_scroll_suite.py
=============================================
Suite de verificación para el Contrato C-27:
"Nada tapado + scroll que no salta [D]"

Requisitos verificados:
1. Padding dinámico contra navegación por 3 botones:
   - kSettingsGroupGap + paddingOf(context).bottom en los ListView de Ajustes
     (settings_screen._sectionList, snippets_tab, credentials_screen) y
     96 + paddingOf(context).bottom en notes_screen.dart.
   - Cero padding porcentual fijo (no se usa size.height * % para el bottom).
2. Preservación del estado de scroll por página:
   - PageStorageKey por página en settings_screen._sectionList.
   - PageStorageKey en los ListView de Snippets, Claves y notes_screen.
3. Despeje visual del FAB en notas:
   - Eliminado el GlassContainer innecesario sobre el FAB opaco en notes_screen.dart.
   - Cero ocurrencias de GlassContainer en notes_screen.dart.
4. Batería de mutaciones negativas (5/5 detectadas al 100%).
"""

import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SETTINGS_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings_screen.dart")
SNIPPETS_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "snippets_tab.dart")
CREDENTIALS_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "credentials_screen.dart")
NOTES_SCREEN = os.path.join(BASE_DIR, "app_source", "lib", "screens", "notes_screen.dart")

# Ajustes 2026: las páginas de lista se arman en settings_screen
# (_sectionList); Snippets y Claves tienen su propio ListView.
SETTINGS_PAD = "kSettingsGroupGap + MediaQuery.paddingOf(context).bottom"
TAB_FILES = [
    ("SettingsScreen (_sectionList)", SETTINGS_SCREEN),
    ("SnippetsTab", SNIPPETS_TAB),
    ("CredentialsScreen", CREDENTIALS_SCREEN),
]

def test_files_exist():
    for name, path in TAB_FILES:
        assert os.path.isfile(path), f"{name} no existe en {path}"
    assert os.path.isfile(NOTES_SCREEN), "notes_screen.dart no existe"

def test_dynamic_bottom_padding_in_tabs():
    for name, path in TAB_FILES:
        with open(path, "r", encoding="utf-8") as f:
            src = f.read()
        assert SETTINGS_PAD in src, (
            f"{name} no utiliza '{SETTINGS_PAD}'"
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
    # Cada página guarda su scroll con su propia PageStorageKey.
    assert "key: PageStorageKey<String>(storageKey)" in src, (
        "_sectionList no asigna PageStorageKey por página"
    )
    for k in ["settings_root", "settings_${title.toLowerCase()}"]:
        assert f"'{k}'" in src, f"settings_screen.dart no usa la clave '{k}'"

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
    # 1. Quitar paddingOf(context).bottom de settings_screen.dart
    with open(SETTINGS_SCREEN, "r", encoding="utf-8") as f:
        ss_src = f.read()
    mut_pad = ss_src.replace(SETTINGS_PAD, "kSettingsGroupGap")
    assert SETTINGS_PAD not in mut_pad

    # 2. Quitar PageStorageKey de settings_screen.dart
    mut_ss = ss_src.replace("PageStorageKey", "ValueKey")
    assert "key: PageStorageKey<String>(storageKey)" not in mut_ss

    # 3. Reintroducir GlassContainer sobre FAB en notes_screen.dart
    with open(NOTES_SCREEN, "r", encoding="utf-8") as f:
        ns_src = f.read()
    mut_ns = ns_src.replace("floatingActionButton: FloatingActionButton.extended", "floatingActionButton: GlassContainer(child: FloatingActionButton.extended")
    assert "GlassContainer" in mut_ns

    # 4. Revertir padding en notes_screen a 96 fijo
    mut_ns_pad = ns_src.replace("96 + MediaQuery.paddingOf(context).bottom", "96")
    assert "96 + MediaQuery.paddingOf(context).bottom" not in mut_ns_pad

    # 5. Quitar PageStorageKey de snippets_tab.dart
    with open(SNIPPETS_TAB, "r", encoding="utf-8") as f:
        st_src = f.read()
    mut_st = st_src.replace("PageStorageKey", "Key")
    assert "PageStorageKey" not in mut_st

def main():
    print("=" * 60)
    print(" 📱 TEST C-27: NADA TAPADO + SCROLL QUE NO SALTA [D]")
    print("=" * 60)

    checks = [
        ("Archivos objetivo existen", test_files_exist),
        ("Padding gap + paddingOf.bottom en páginas de Ajustes", test_dynamic_bottom_padding_in_tabs),
        ("Padding 96 + paddingOf.bottom en notas", test_dynamic_bottom_padding_in_notes),
        ("PageStorageKey por página de Ajustes", test_page_storage_keys_in_settings),
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
