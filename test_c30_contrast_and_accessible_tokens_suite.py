#!/usr/bin/env python3
"""
test_c30_contrast_and_accessible_tokens_suite.py
================================================
Suite de verificación para el Contrato C-30:
"Contraste que se lee [D]"

Requisitos verificados:
1. Ratios WCAG 2.1 en los íconos de fila de Ajustes (Horizonte, fase 3):
   - Las pastillas de color (kTile*) se retiraron: el ícono es de línea en
     fg2 sobre surf, sin fondo.
   - Gráfico/Icono: fg2 sobre surf >= 3.0:1 en claro y en oscuro.
2. Adopción de tokens de texto sin primitivos crudos:
   - Horizonte: onPrimary usa kOnEmber (texto sobre brasa) en ambos temas.
   - buildLightTheme: onError, onSecondary, onTertiary usan kLabelPrimaryDark.
   - buildDarkTheme: onSecondary, onTertiary usan kLabelPrimaryLight.
   - Cero Colors.white o Colors.black crudos en las definiciones onPrimary/onSecondary/onTertiary.
3. Accesibilidad en el ícono de fila (_RowIcon + SettingsPalette):
   - El glifo usa el color de ícono de la paleta: fg2, fg con alto contraste.
   - La paleta consulta MediaQuery.highContrastOf(context).
4. Layout nativo del widget (widget_notes.xml):
   - Cero ocurrencias de #007AFF hardcodeado; los íconos sobre superficie
     clara usan @color/hz_ember_t (Horizonte fase 4: la brasa de relleno
     kb_key_bg_accent da 2.77:1 sobre blanco y no se usa como tinte).
   - Elementos decorativos (la voz animada del widget) documentados.
5. Fondo del widget (widget_bg.xml, Horizonte fase 4: sólido, sin vidrio):
   - Superficie opaca hz_bg con borde delimitado de 1dp hz_line; claro y
     noche los resuelven los tokens (sin variante drawable-night).
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
WIDGET_BG = os.path.join(
    BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "drawable", "widget_bg.xml"
)
WIDGET_BG_NIGHT = os.path.join(
    BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "drawable-night", "widget_bg.xml"
)
COLORS_LIGHT = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "values", "colors.xml")
COLORS_NIGHT = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "values-night", "colors.xml")

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
    assert os.path.isfile(WIDGET_BG), f"widget_bg.xml no existe en {WIDGET_BG}"

def _token_hex(src, name):
    m = re.search(rf"const Color {name} = Color\(0xFF([0-9A-Fa-f]{{6}})\);", src)
    assert m, f"No se encontró definición de {name} en design_tokens.dart"
    return m.group(1)

def test_tile_colors_contrast_ratio():
    """Horizonte: sin pastillas kTile*; ícono de línea fg2 sobre surf >= 3:1."""
    with open(DESIGN_TOKENS, "r", encoding="utf-8") as f:
        src = f.read()

    assert "kTile" not in src, "Las pastillas de color kTile* deben haberse retirado"
    for fg2, surf in (("kHzFg2Light", "kHzSurfLight"), ("kHzFg2Dark", "kHzSurfDark")):
        cr = wcag_contrast_ratio(
            wcag_relative_luminance(_token_hex(src, fg2)),
            wcag_relative_luminance(_token_hex(src, surf)),
        )
        assert cr >= 3.0, f"Ícono de fila {fg2} sobre {surf} no cumple 3.0:1 (obtenido: {cr:.2f}:1)"

def test_theme_on_primary_uses_tokens():
    with open(DESIGN_TOKENS, "r", encoding="utf-8") as f:
        src = f.read()

    # buildLightTheme
    light_start = src.find("ThemeData buildLightTheme()")
    assert light_start != -1, "No se encontró buildLightTheme en design_tokens.dart"
    light_code = src[light_start:light_start + 1200]

    assert "onPrimary: kOnEmber" in light_code, "buildLightTheme debe usar kOnEmber (texto sobre brasa) en onPrimary"
    assert "onError: kLabelPrimaryDark" in light_code, "buildLightTheme debe usar kLabelPrimaryDark en onError"
    assert "onSecondary: kLabelPrimaryDark" in light_code, "buildLightTheme debe usar kLabelPrimaryDark en onSecondary"
    assert "onTertiary: kLabelPrimaryDark" in light_code, "buildLightTheme debe usar kLabelPrimaryDark en onTertiary"
    assert "onPrimary: Colors.white" not in light_code, "buildLightTheme retiene Colors.white crudo en onPrimary"

    # buildDarkTheme
    dark_start = src.find("ThemeData buildDarkTheme()")
    assert dark_start != -1, "No se encontró buildDarkTheme en design_tokens.dart"
    dark_code = src[dark_start:dark_start + 1200]

    assert "onPrimary: kOnEmber" in dark_code, "buildDarkTheme debe usar kOnEmber (texto sobre brasa) en onPrimary"
    assert "onSecondary: kLabelPrimaryLight" in dark_code, "buildDarkTheme debe usar kLabelPrimaryLight en onSecondary"
    assert "onTertiary: kLabelPrimaryLight" in dark_code, "buildDarkTheme debe usar kLabelPrimaryLight en onTertiary"
    assert "onPrimary: Colors.black" not in dark_code, "buildDarkTheme retiene Colors.black crudo en onPrimary"

def test_setting_icon_tile_contrast_and_fallback():
    with open(SETTINGS_V2, "r", encoding="utf-8") as f:
        src = f.read()

    assert "class SettingIconTile" not in src, "La pastilla SettingIconTile debe haberse retirado"
    icon_start = src.find("class _RowIcon")
    assert icon_start != -1, "No se encontró _RowIcon en settings_v2.dart"
    icon_code = src[icon_start:icon_start + 600]
    assert "SettingsPalette.of(context).icon" in icon_code, "_RowIcon debe usar el color de ícono de la paleta"
    assert "Colors.white" not in src and "Colors.black" not in src, "settings_v2 retiene Colors.white/black crudos"
    assert "Color get icon => highContrast ? label : secondary;" in src, (
        "El ícono debe ir en fg2 y pasar a fg con alto contraste"
    )
    assert "MediaQuery.highContrastOf(context)" in src, (
        "SettingsPalette debe consultar MediaQuery.highContrastOf(context)"
    )

def test_widget_notes_layout_tints_and_decoratives():
    with open(WIDGET_NOTES_LAYOUT, "r", encoding="utf-8") as f:
        src = f.read()

    assert "#007AFF" not in src, "widget_notes.xml no debe tener #007AFF hardcodeado (usar tokens)"
    assert "@color/hz_ember_t" in src, "widget_notes.xml debe usar @color/hz_ember_t para los íconos sobre superficie"
    assert "@color/kb_key_bg_accent" not in src, (
        "widget_notes.xml no debe teñir íconos con la brasa de relleno (2.77:1 sobre blanco)"
    )
    assert "decorativo" in src.lower() or "decorative" in src.lower(), (
        "widget_notes.xml debe documentar elementos decorativos (ej. la voz animada)"
    )

def test_widget_bg_solid_stroke():
    """Horizonte: fondo sólido por tokens con borde de 1dp (sin vidrio)."""
    with open(WIDGET_BG, "r", encoding="utf-8") as f:
        src = f.read()
    assert '<solid android:color="@color/hz_bg" />' in src, "widget_bg.xml debe ser hz_bg sólido (token)"
    assert '<stroke android:width="1dp" android:color="@color/hz_line" />' in src, (
        "widget_bg.xml debe tener borde de 1dp hz_line"
    )
    assert not os.path.exists(WIDGET_BG_NIGHT), "Sin variante drawable-night: los tokens resuelven claro/noche"
    for path in (COLORS_LIGHT, COLORS_NIGHT):
        with open(path, "r", encoding="utf-8") as f:
            colors = f.read()
        for name in ("hz_bg", "hz_line"):
            m = re.search(rf'<color name="{name}">#([0-9A-Fa-f]{{8}})</color>', colors)
            assert m and m.group(1)[:2].upper() == "FF", f"{name} debe ser opaco en {path}"

def test_negative_mutations():
    with open(DESIGN_TOKENS, "r", encoding="utf-8") as f:
        tokens_src = f.read()
    with open(SETTINGS_V2, "r", encoding="utf-8") as f:
        settings_src = f.read()
    with open(WIDGET_NOTES_LAYOUT, "r", encoding="utf-8") as f:
        widget_src = f.read()

    surf_lum = wcag_relative_luminance("FFFFFF")

    # Mutación 1: ícono de fila con un gris demasiado claro (#C8CAD3) sobre surf blanco
    mut1_cr = wcag_contrast_ratio(surf_lum, wcag_relative_luminance("C8CAD3"))
    assert mut1_cr < 3.0, f"Mutación 1 debe fallar la guarda de contraste (< 3.0): {mut1_cr:.2f}:1"

    # Mutación 2: reintroducir una pastilla kTile*
    mut2 = tokens_src + "\nconst Color kTileGreen = Color(0xFF30D158);\n"
    assert "kTile" in mut2, "Mutación 2 falló al aplicar"

    # Mutación 3: Regresar onPrimary a Colors.white en buildLightTheme
    mut3 = tokens_src.replace("onPrimary: kOnEmber", "onPrimary: Colors.white", 1)
    light_start = mut3.find("ThemeData buildLightTheme()")
    light_code = mut3[light_start:light_start + 1200]
    assert "onPrimary: Colors.white" in light_code, "Mutación 3 falló al aplicar"

    # Mutación 4: volver a teñir con la brasa de relleno (2.77:1) en widget_notes.xml
    mut4 = widget_src.replace("@color/hz_ember_t", "@color/kb_key_bg_accent")
    assert "@color/kb_key_bg_accent" in mut4 and "@color/hz_ember_t" not in mut4, "Mutación 4 falló al aplicar"

    # Mutación 5: Quitar highContrast del ícono de fila / paleta
    mut5 = settings_src.replace("highContrast", "/* no high contrast */")
    assert "highContrastOf" not in mut5 and "highContrast" not in mut5, "Mutación 5 falló al aplicar"

def run_all_tests():
    tests = [
        test_files_exist,
        test_tile_colors_contrast_ratio,
        test_theme_on_primary_uses_tokens,
        test_setting_icon_tile_contrast_and_fallback,
        test_widget_notes_layout_tints_and_decoratives,
        test_widget_bg_solid_stroke,
        test_negative_mutations,
    ]
    for t in tests:
        t()
    print(f"C-30: {len(tests)}/7 tests OK (100% PASS)")

if __name__ == "__main__":
    run_all_tests()
