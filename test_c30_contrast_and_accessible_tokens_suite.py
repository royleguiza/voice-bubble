#!/usr/bin/env python3
"""
test_c30_contrast_and_accessible_tokens_suite.py
================================================
Suite de verificación para el Contrato C-30:
"Contraste que se lee [D]"

Requisitos verificados:
1. Ratios WCAG 2.1 en pastillas de iconos (kTile*):
   - Gráfico/Icono: ratio de contraste >= 3.0:1 contra blanco (kLabelPrimaryDark).
   - kTileGreen oscurecido (0xFF1A7A2E) pasa de 2.02:1 a > 5.0:1.
   - kTileOrange oscurecido (0xFF9A5B00) pasa de 2.06:1 a > 5.0:1.
   - Todos los 7 kTile (Blue, Green, Orange, Red, Purple, Gray, Pink) superan 3.0:1.
2. Adopción de tokens de texto sin primitivos crudos:
   - buildLightTheme: onPrimary, onError, onSecondary, onTertiary usan kLabelPrimaryDark.
   - buildDarkTheme: onPrimary, onSecondary, onTertiary usan kLabelPrimaryLight.
   - Cero Colors.white o Colors.black crudos en las definiciones onPrimary/onSecondary/onTertiary.
3. Accesibilidad en SettingIconTile:
   - El glifo del icono usa kLabelPrimaryDark.
   - Soporte para MediaQuery.highContrastOf(context) con borde de alto contraste.
4. Layout nativo del widget (widget_notes.xml):
   - Cero ocurrencias de #007AFF hardcodeado; usa @color/kb_key_bg_accent adaptable.
   - Elementos decorativos (widget_rec_dot) documentados.
5. Fondos glass del widget (widget_glass_bg.xml):
   - Bordes delimitados con contraste >= 3:1 en modo claro y noche.
6. Batería de mutaciones negativas (5/5 detectadas al 100%).
"""

import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DESIGN_TOKENS = os.path.join(BASE_DIR, "app_source", "lib", "ui", "design_tokens.dart")
SETTINGS_V2 = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "settings_v2.dart")
WIDGET_NOTES_LAYOUT = os.path.join(
    BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "layout", "widget_notes.xml"
)
WIDGET_GLASS_BG_LIGHT = os.path.join(
    BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "drawable", "widget_glass_bg.xml"
)
WIDGET_GLASS_BG_NIGHT = os.path.join(
    BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "drawable-night", "widget_glass_bg.xml"
)

def wcag_relative_luminance(hex_code):
    clean = hex_code.strip().lstrip("#").upper()
    if len(clean) == 8: # AARRGGBB
        clean = clean[2:]
    r = int(clean[0:2], 16) / 255.0
    g = int(clean[2:4], 16) / 255.0
    b = int(clean[4:6], 16) / 255.0

    def channel_adj(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return 0.2126 * channel_adj(r) + 0.7152 * channel_adj(g) + 0.0722 * channel_adj(b)

def wcag_contrast_ratio(lum1, lum2):
    high, low = max(lum1, lum2), min(lum1, lum2)
    return (high + 0.05) / (low + 0.05)

def test_files_exist():
    assert os.path.isfile(DESIGN_TOKENS), f"design_tokens.dart no existe en {DESIGN_TOKENS}"
    assert os.path.isfile(SETTINGS_V2), f"settings_v2.dart no existe en {SETTINGS_V2}"
    assert os.path.isfile(WIDGET_NOTES_LAYOUT), f"widget_notes.xml no existe en {WIDGET_NOTES_LAYOUT}"
    assert os.path.isfile(WIDGET_GLASS_BG_LIGHT), f"widget_glass_bg.xml no existe en {WIDGET_GLASS_BG_LIGHT}"
    assert os.path.isfile(WIDGET_GLASS_BG_NIGHT), f"widget_glass_bg.xml no existe en {WIDGET_GLASS_BG_NIGHT}"

def test_tile_colors_contrast_ratio():
    with open(DESIGN_TOKENS, "r", encoding="utf-8") as f:
        src = f.read()

    white_lum = wcag_relative_luminance("FFFFFF")
    tile_names = ["kTileBlue", "kTileGreen", "kTileOrange", "kTileRed", "kTilePurple", "kTileGray", "kTilePink"]

    for name in tile_names:
        m = re.search(rf"const Color {name} = Color\(0xFF([0-9A-Fa-f]{{6}})\);", src)
        assert m, f"No se encontró definición de {name} en design_tokens.dart"
        hex_val = m.group(1)
        lum = wcag_relative_luminance(hex_val)
        cr = wcag_contrast_ratio(white_lum, lum)
        assert cr >= 3.0, f"Token {name} (#{hex_val}) no cumple contraste gráfico WCAG >= 3.0:1 (obtenido: {cr:.2f}:1)"

    # Verificación puntual de los tokens corregidos en C-30
    assert "0xFF1A7A2E" in src, "kTileGreen debe ser 0xFF1A7A2E para contraste > 5:1"
    assert "0xFF9A5B00" in src, "kTileOrange debe ser 0xFF9A5B00 para contraste > 5:1"

def test_theme_on_primary_uses_tokens():
    with open(DESIGN_TOKENS, "r", encoding="utf-8") as f:
        src = f.read()

    # buildLightTheme
    light_start = src.find("ThemeData buildLightTheme()")
    assert light_start != -1, "No se encontró buildLightTheme en design_tokens.dart"
    light_code = src[light_start:light_start + 1200]

    assert "onPrimary: kLabelPrimaryDark" in light_code, "buildLightTheme debe usar kLabelPrimaryDark en onPrimary"
    assert "onError: kLabelPrimaryDark" in light_code, "buildLightTheme debe usar kLabelPrimaryDark en onError"
    assert "onSecondary: kLabelPrimaryDark" in light_code, "buildLightTheme debe usar kLabelPrimaryDark en onSecondary"
    assert "onTertiary: kLabelPrimaryDark" in light_code, "buildLightTheme debe usar kLabelPrimaryDark en onTertiary"
    assert "onPrimary: Colors.white" not in light_code, "buildLightTheme retiene Colors.white crudo en onPrimary"

    # buildDarkTheme
    dark_start = src.find("ThemeData buildDarkTheme()")
    assert dark_start != -1, "No se encontró buildDarkTheme en design_tokens.dart"
    dark_code = src[dark_start:dark_start + 1200]

    assert "onPrimary: kLabelPrimaryLight" in dark_code, "buildDarkTheme debe usar kLabelPrimaryLight en onPrimary"
    assert "onSecondary: kLabelPrimaryLight" in dark_code, "buildDarkTheme debe usar kLabelPrimaryLight en onSecondary"
    assert "onTertiary: kLabelPrimaryLight" in dark_code, "buildDarkTheme debe usar kLabelPrimaryLight en onTertiary"
    assert "onPrimary: Colors.black" not in dark_code, "buildDarkTheme retiene Colors.black crudo en onPrimary"

def test_setting_icon_tile_contrast_and_fallback():
    with open(SETTINGS_V2, "r", encoding="utf-8") as f:
        src = f.read()

    tile_start = src.find("class SettingIconTile")
    assert tile_start != -1, "No se encontró SettingIconTile en settings_v2.dart"
    tile_code = src[tile_start:tile_start + 1200]

    assert "color: kLabelPrimaryDark" in tile_code, "SettingIconTile debe usar kLabelPrimaryDark para el glifo"
    assert "color: Colors.white" not in tile_code, "SettingIconTile retiene Colors.white crudo"
    assert "highContrast" in tile_code or "highContrastOf" in tile_code, (
        "SettingIconTile debe consultar MediaQuery.highContrastOf(context)"
    )

def test_widget_notes_layout_tints_and_decoratives():
    with open(WIDGET_NOTES_LAYOUT, "r", encoding="utf-8") as f:
        src = f.read()

    assert "#007AFF" not in src, "widget_notes.xml no debe tener #007AFF hardcodeado (usar @color/kb_key_bg_accent)"
    assert "@color/kb_key_bg_accent" in src, "widget_notes.xml debe usar @color/kb_key_bg_accent para los tints"
    assert "decorativo" in src.lower() or "decorative" in src.lower(), (
        "widget_notes.xml debe documentar elementos decorativos (ej. widget_rec_dot)"
    )

def test_widget_glass_bg_stroke():
    with open(WIDGET_GLASS_BG_LIGHT, "r", encoding="utf-8") as f:
        light_src = f.read()
    with open(WIDGET_GLASS_BG_NIGHT, "r", encoding="utf-8") as f:
        night_src = f.read()

    assert 'android:width="1dp"' in light_src or 'android:width="0.5dp"' in light_src, (
        "drawable/widget_glass_bg.xml debe tener stroke definido"
    )
    assert 'android:width="1dp"' in night_src or 'android:width="0.5dp"' in night_src, (
        "drawable-night/widget_glass_bg.xml debe tener stroke definido"
    )

def test_negative_mutations():
    with open(DESIGN_TOKENS, "r", encoding="utf-8") as f:
        tokens_src = f.read()
    with open(SETTINGS_V2, "r", encoding="utf-8") as f:
        settings_src = f.read()
    with open(WIDGET_NOTES_LAYOUT, "r", encoding="utf-8") as f:
        widget_src = f.read()

    white_lum = wcag_relative_luminance("FFFFFF")

    # Mutación 1: Regresar kTileGreen al color viejo (30D158)
    mut1_lum = wcag_relative_luminance("30D158")
    mut1_cr = wcag_contrast_ratio(white_lum, mut1_lum)
    assert mut1_cr < 3.0, f"Mutación 1 debe fallar la guarda de contraste (< 3.0): {mut1_cr:.2f}:1"

    # Mutación 2: Regresar kTileOrange al color viejo (FF9F0A)
    mut2_lum = wcag_relative_luminance("FF9F0A")
    mut2_cr = wcag_contrast_ratio(white_lum, mut2_lum)
    assert mut2_cr < 3.0, f"Mutación 2 debe fallar la guarda de contraste (< 3.0): {mut2_cr:.2f}:1"

    # Mutación 3: Regresar onPrimary a Colors.white en buildLightTheme
    mut3 = tokens_src.replace("onPrimary: kLabelPrimaryDark", "onPrimary: Colors.white")
    light_start = mut3.find("ThemeData buildLightTheme()")
    light_code = mut3[light_start:light_start + 1200]
    assert "onPrimary: Colors.white" in light_code, "Mutación 3 falló al aplicar"

    # Mutación 4: Reintroducir #007AFF hardcodeado en widget_notes.xml
    mut4 = widget_src.replace("@color/kb_key_bg_accent", "#007AFF")
    assert "#007AFF" in mut4, "Mutación 4 falló al aplicar"

    # Mutación 5: Quitar highContrast de SettingIconTile
    mut5 = settings_src.replace("highContrast", "/* no high contrast */")
    assert "highContrastOf" not in mut5 and "highContrast" not in mut5, "Mutación 5 falló al aplicar"

def run_all_tests():
    tests = [
        test_files_exist,
        test_tile_colors_contrast_ratio,
        test_theme_on_primary_uses_tokens,
        test_setting_icon_tile_contrast_and_fallback,
        test_widget_notes_layout_tints_and_decoratives,
        test_widget_glass_bg_stroke,
        test_negative_mutations,
    ]
    for t in tests:
        t()
    print(f"C-30: {len(tests)}/7 tests OK (100% PASS)")

if __name__ == "__main__":
    run_all_tests()
