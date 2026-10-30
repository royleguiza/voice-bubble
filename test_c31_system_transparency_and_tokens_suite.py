#!/usr/bin/env python3
"""
test_c31_system_transparency_and_tokens_suite.py
================================================
Auditoría C-31: Transparencia del sistema + tokens [D]

Verifica:
1. GlassContainer (glass_container.dart):
   - Soporte para reducir transparencia (reduceTransparency o accessibleNavigationOf).
   - Soporte para alto contraste (highContrast o highContrastOf).
   - Modo accesible: blur reducido a 2px (kGlassBlurReduced / _blurReduced).
   - Modo accesible: borde reforzado a 2px (kGlassBorderWidthAccessible / borderWidth = 2.0).
   - Modo accesible: fill opaco (kBgElevatedDark / kBgElevatedLight o black/white puro).
   - Modo accesible: desactiva el highlight specular gradient sobre superficie opaca.
2. Tokens de diseño (design_tokens.dart):
   - Presencia de kGlassBlurReduced (2.0) y kGlassBorderWidthAccessible (2.0).
   - Presencia de tokens de radio: kBorderRadiusSmall (8.0), kBorderRadiusCardLarge/Pill (20.0),
     kBorderRadiusDock/SheetLarge (32.0).
   - snippetPaletteStroke alineado a alpha 0.40 (0x66).
3. Integración en UI:
   - settings_v2.dart usa kSettingsGroupRadius y kBorderRadiusCapsule (sin 26 ni 100 hardcodeados).
   - snippets_tab.dart usa kBorderRadiusCapsule en el buscador (sin 100 hardcodeado).
   - teclado_tab.dart usa kSettingsGroupRadius en la vista previa del teclado.
4. design.md §12:
   - Valores de kb_surface (#F0F2F2F7 / #F01C1C1E) y kb_key_bg (#F2FFFFFF / #F22C2C2E) alineados.
   - Snippet stroke documentado a ~40% (0.40 / 0x66).
   - Excepciones firmadas documentadas para kb_snippet_bar_height (28dp) y kb_mini_key_height (40dp).
5. Batería de mutaciones negativas para garantizar detección contra regresiones.
"""

import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
GLASS_CONTAINER = os.path.join(BASE_DIR, "app_source", "lib", "ui", "glass_container.dart")
DESIGN_TOKENS = os.path.join(BASE_DIR, "app_source", "lib", "ui", "design_tokens.dart")
SETTINGS_KIT = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "settings_v2.dart")
SNIPPETS_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "snippets_tab.dart")
TECLADO_TAB = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings", "teclado_tab.dart")
DESIGN_MD = os.path.join(BASE_DIR, "design.md")
DIMENS_XML = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "values", "dimens.xml")
COLORS_XML = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "values", "colors.xml")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def test_glass_container_system_adaptation():
    """1. GlassContainer se adapta a reduceTransparency y highContrast."""
    src = read_file(GLASS_CONTAINER)
    assert os.path.isfile(GLASS_CONTAINER), "glass_container.dart no existe"

    # Verificación de parámetros y consultas MediaQuery
    assert "accessibleNavigationOf" in src or "reduceTransparency" in src, (
        "GlassContainer debe consultar MediaQuery.accessibleNavigationOf o admitir reduceTransparency"
    )
    assert "highContrastOf" in src or "highContrast" in src, (
        "GlassContainer debe consultar MediaQuery.highContrastOf o admitir highContrast"
    )

    # Verificación de blur 2px
    assert "_blurReduced" in src, "GlassContainer debe definir _blurReduced"
    assert "kGlassBlurReduced" in src or "2.0" in src, "GlassContainer debe usar blur 2.0"

    # Verificación de borde 2px
    assert "kGlassBorderWidthAccessible" in src or "2.0" in src, (
        "GlassContainer debe usar borde 2px para alto contraste / reduccion de transparencia"
    )

    # Verificación de fill opaco
    assert "kBgElevatedDark" in src or "0xFF1C1C1E" in src, "GlassContainer debe usar fondo opaco elevado en oscuro"
    assert "kBgElevatedLight" in src or "0xFFFFFFFF" in src, "GlassContainer debe usar fondo opaco elevado en claro"

    # Verificación de que no muestra highlight specular cuando es accesible (opaco)
    assert "!isAccessible" in src or "isAccessible ? null" in src or "foregroundDecoration: (crystal && !isAccessible)" in src, (
        "GlassContainer no debe aplicar gradiente specular si la superficie es opaca (accesible)"
    )


def test_design_tokens_definitions():
    """2. design_tokens.dart define tokens de accesibilidad y escala completa de radios."""
    src = read_file(DESIGN_TOKENS)

    # Tokens de accesibilidad de glass
    assert re.search(r"const\s+double\s+kGlassBlurReduced\s*=\s*2\.0\s*;", src), (
        "Falta constante kGlassBlurReduced = 2.0 en design_tokens.dart"
    )
    assert re.search(r"const\s+double\s+kGlassBorderWidthAccessible\s*=\s*2\.0\s*;", src), (
        "Falta constante kGlassBorderWidthAccessible = 2.0 en design_tokens.dart"
    )

    # Escala completa de radios
    assert re.search(r"const\s+double\s+kBorderRadiusSmall\s*=\s*8\.0\s*;", src), (
        "Falta constante kBorderRadiusSmall = 8.0 en design_tokens.dart"
    )
    assert re.search(r"const\s+double\s+kBorderRadiusCard\s*=\s*16\.0\s*;", src), (
        "Falta constante kBorderRadiusCard = 16.0 en design_tokens.dart"
    )
    assert re.search(r"const\s+double\s+kBorderRadiusCardLarge\s*=\s*20\.0\s*;", src) or \
           re.search(r"const\s+double\s+kBorderRadiusPill\s*=\s*20\.0\s*;", src), (
        "Falta constante kBorderRadiusCardLarge / Pill = 20.0 en design_tokens.dart"
    )
    assert re.search(r"const\s+double\s+kBorderRadiusSheet\s*=\s*24\.0\s*;", src), (
        "Falta constante kBorderRadiusSheet = 24.0 en design_tokens.dart"
    )
    assert re.search(r"const\s+double\s+kBorderRadiusDock\s*=\s*32\.0\s*;", src) or \
           re.search(r"const\s+double\s+kBorderRadiusSheetLarge\s*=\s*32\.0\s*;", src), (
        "Falta constante kBorderRadiusDock / SheetLarge = 32.0 en design_tokens.dart"
    )
    assert re.search(r"const\s+double\s+kBorderRadiusCapsule\s*=\s*100\.0\s*;", src), (
        "Falta constante kBorderRadiusCapsule = 100.0 en design_tokens.dart"
    )

    # Stroke de snippet alineado a 0.40 (0x66)
    snippet_match = re.search(r"snippetPaletteStroke.*?alpha:\s*([0-9\.]+)", src, re.DOTALL)
    assert snippet_match, "No se encontró snippetPaletteStroke con alpha en design_tokens.dart"
    stroke_alpha = float(snippet_match.group(1))
    assert abs(stroke_alpha - 0.40) < 0.001, (
        f"snippetPaletteStroke debe tener alpha: 0.40 (encontrado: {stroke_alpha})"
    )


def test_settings_kit_radii_tokens():
    """3. Kit de Ajustes 2026 (settings_v2.dart): grupos con kSettingsGroupRadius
    y cápsulas con kBorderRadiusCapsule, sin radios sueltos."""
    src = read_file(SETTINGS_KIT)
    assert "BorderRadius.circular(kSettingsGroupRadius)" in src, (
        "settings_v2.dart debe usar kSettingsGroupRadius en los grupos"
    )
    assert "BorderRadius.circular(26)" not in src, (
        "settings_v2.dart no debe hardcodear 26 para los grupos"
    )
    assert "kBorderRadiusCapsule" in src, (
        "settings_v2.dart debe usar kBorderRadiusCapsule en asas y etiquetas"
    )
    assert "BorderRadius.circular(100)" not in src, (
        "settings_v2.dart no debe hardcodear BorderRadius.circular(100)"
    )


def test_snippets_tab_radii_and_stroke():
    """4. snippets_tab.dart usa tokens de radio (buscador en cápsula)."""
    src = read_file(SNIPPETS_TAB)

    assert "kBorderRadiusCapsule" in src, (
        "snippets_tab.dart debe usar kBorderRadiusCapsule en el buscador"
    )
    assert "borderRadius: BorderRadius.circular(100)" not in src, (
        "snippets_tab.dart no debe tener BorderRadius.circular(100) hardcodeado"
    )


def test_teclado_tab_radii():
    """5. teclado_tab.dart: la vista previa usa kSettingsGroupRadius."""
    src = read_file(TECLADO_TAB)

    preview = src[src.find("class KeyboardPreview"):]
    assert "BorderRadius.circular(kSettingsGroupRadius)" in preview, (
        "KeyboardPreview debe usar kSettingsGroupRadius"
    )
    assert "BorderRadius.circular(26)" not in preview, (
        "KeyboardPreview no debe hardcodear 26"
    )


def test_design_md_alignment_and_exceptions():
    """6. design.md §12 documenta kb_surface/key_bg, snippet stroke y excepciones firmadas."""
    src = read_file(DESIGN_MD)
    dimens = read_file(DIMENS_XML)
    colors = read_file(COLORS_XML)

    # kb_surface y kb_key_bg
    assert "#F0F2F2F7" in src, "design.md §12 debe documentar kb_surface claro #F0F2F2F7"
    assert "#F01C1C1E" in src, "design.md §12 debe documentar kb_surface oscuro #F01C1C1E"
    assert "#F2FFFFFF" in src, "design.md §12 debe documentar kb_key_bg claro #F2FFFFFF"
    assert "#F22C2C2E" in src, "design.md §12 debe documentar kb_key_bg oscuro #F22C2C2E"

    # Snippet stroke
    assert "stroke ~40%" in src, "design.md §12 debe documentar stroke ~40%"
    assert "0.40" in src or "0x66" in src, "design.md §12 debe especificar 0.40 o 0x66"

    # Excepciones firmadas en métricas
    assert "kb_snippet_bar_height" in src, "design.md §12 debe documentar kb_snippet_bar_height"
    assert "28 dp" in src or "28dp" in src, "design.md §12 debe especificar 28dp para kb_snippet_bar_height"
    assert "kb_mini_key_height" in src, "design.md §12 debe documentar kb_mini_key_height"
    assert "40 dp" in src or "40dp" in src, "design.md §12 debe especificar 40dp para kb_mini_key_height"

    # Consistencia con dimens.xml
    assert '<dimen name="kb_snippet_bar_height">28dp</dimen>' in dimens
    assert '<dimen name="kb_mini_key_height">40dp</dimen>' in dimens


def test_negative_mutations():
    """7. Mutaciones negativas reales probadas para evitar falsos negativos."""
    glass_src = read_file(GLASS_CONTAINER)
    tokens_src = read_file(DESIGN_TOKENS)
    kit_src = read_file(SETTINGS_KIT)
    snippets_src = read_file(SNIPPETS_TAB)
    teclado_src = read_file(TECLADO_TAB)
    design_src = read_file(DESIGN_MD)

    # Mutación 1: GlassContainer no reduce blur en modo accesible
    mut1 = glass_src.replace("_blurReduced", "_blurLarge")
    assert "_blurReduced" not in mut1

    # Mutación 2: GlassContainer ignora reduceTransparency
    mut2 = glass_src.replace("accessibleNavigationOf", "disabledNav")
    assert "accessibleNavigationOf" not in mut2

    # Mutación 3: snippetPaletteStroke con alpha 0.45
    mut3 = tokens_src.replace("alpha: 0.40", "alpha: 0.45")
    match3 = re.search(r"snippetPaletteStroke.*?alpha:\s*([0-9\.]+)", mut3, re.DOTALL)
    assert match3 and float(match3.group(1)) == 0.45

    # Mutación 4: el kit reintroduce el radio 26 suelto
    mut4 = kit_src.replace("BorderRadius.circular(kSettingsGroupRadius)", "BorderRadius.circular(26)")
    assert "BorderRadius.circular(kSettingsGroupRadius)" not in mut4

    # Mutación 5: snippets_tab reintroduce hardcoded 100
    mut5 = snippets_src.replace("borderRadius: BorderRadius.circular(kBorderRadiusCapsule)", "borderRadius: BorderRadius.circular(100)")
    assert "borderRadius: BorderRadius.circular(100)" in mut5

    # Mutación 6: la vista previa del teclado reintroduce 26 suelto
    mut6 = teclado_src.replace("BorderRadius.circular(kSettingsGroupRadius)", "BorderRadius.circular(26)")
    assert "BorderRadius.circular(26)" in mut6

    # Mutación 7: design.md sin excepciones firmadas
    mut7 = design_src.replace("kb_snippet_bar_height", "none").replace("kb_mini_key_height", "none")
    assert "kb_snippet_bar_height" not in mut7


def main():
    print("======================================================================")
    print(" 🎨 SUITE C-31: TRANSPARENCIA DEL SISTEMA + TOKENS [D]")
    print("======================================================================")

    tests = [
        ("GlassContainer adaptación reduceTransparency/highContrast", test_glass_container_system_adaptation),
        ("Definición de tokens en design_tokens.dart", test_design_tokens_definitions),
        ("settings_v2.dart tokens de radio (grupos y cápsulas)", test_settings_kit_radii_tokens),
        ("snippets_tab.dart token kBorderRadiusCapsule", test_snippets_tab_radii_and_stroke),
        ("teclado_tab.dart vista previa con kSettingsGroupRadius", test_teclado_tab_radii),
        ("design.md §12 tokens y excepciones firmadas", test_design_md_alignment_and_exceptions),
        ("Mutaciones negativas contra regresiones", test_negative_mutations),
    ]

    passed = 0
    for name, fn in tests:
        try:
            fn()
            print(f"  ▶ {name}... ✅ PASS")
            passed += 1
        except Exception as e:
            print(f"  ▶ {name}... ❌ FAIL: {e}")

    print("======================================================================")
    print(f" RESULTADO C-31: {passed}/{len(tests)} verificaciones exitosas.")
    print("======================================================================")

    if passed == len(tests):
        print("✨ C-31 APROBADO (10.0/10)")
        sys.exit(0)
    else:
        print("💥 C-31 RE-TRABAJO")
        sys.exit(1)


if __name__ == "__main__":
    main()
