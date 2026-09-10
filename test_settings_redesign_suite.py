#!/usr/bin/env python3
"""
TEST SUITE: REDISENO SETTINGS V2 (laboratorio_ui/settings-redesign-v2.html)
Verifica al 100% de certeza sobre el código REAL:
1. Estructura 5 tabs: General fusiona Inicio+Burbuja; sin inicio_tab/burbuja_tab.
2. Tab bar crystal con las 5 keys (sin tab-inicio/tab-burbuja).
3. Contrato intacto: theme_mode solo-Dart (fuera de bridgeKeys y contrato).
4. Tokens UI: sin Colors.green/TextStyle sueltos, iconos 18/22/28, crystal.
5. Keys de conducta preservadas en lib (las que verifican los tests Dart).
6. About sheet con selector de tema Sistema/Claro/Oscuro.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


print("\n============================================================")
print(" INICIANDO TEST SUITE: REDISENO SETTINGS V2")
print("============================================================\n")

LIB = "app_source/lib"

# --- 1. Estructura 5 tabs ---
check("GeneralTab existe",
      os.path.isfile(os.path.join(WORKSPACE, f"{LIB}/screens/settings/general_tab.dart")))
check("inicio_tab.dart eliminado",
      not os.path.isfile(os.path.join(WORKSPACE, f"{LIB}/screens/settings/inicio_tab.dart")))
check("burbuja_tab.dart eliminado",
      not os.path.isfile(os.path.join(WORKSPACE, f"{LIB}/screens/settings/burbuja_tab.dart")))
screen = read(f"{LIB}/screens/settings_screen.dart")
check("SettingsScreen sin AppBar (v2)", "AppBar(" not in screen)
check("SettingsScreen con SafeArea", "SafeArea(" in screen)
check("Sin InicioTab/BurbujaTab en lib",
      "InicioTab(" not in screen and "BurbujaTab(" not in screen)
for gone in ["tab-inicio", "tab-burbuja", "inicio-go-burbuja", "inicio-go-teclado"]:
    check(f"Sin restos de '{gone}' en lib",
          gone not in read(f"{LIB}/widgets/settings_tab_bar.dart") and gone not in screen,
          f"quedó {gone}")

# --- 2. Tab bar 5 tabs + crystal ---
tabbar = read(f"{LIB}/widgets/settings_tab_bar.dart")
for key in ["tab-general", "tab-teclado", "tab-trackpad", "tab-snippets", "tab-credenciales"]:
    check(f"Tab bar con key {key}", f"'{key}'" in tabbar, f"falta {key}")
check("Tab bar usa glass crystal", "crystal: true" in tabbar)
glass = read(f"{LIB}/ui/glass_container.dart")
check("GlassContainer con variante crystal", "crystal" in glass and "_blurCrystal" in glass)
tokens = read(f"{LIB}/ui/design_tokens.dart")
for tok in ["kSettingsPageTitle", "kSettingsGroupTitle", "kSettingRowTitle",
            "kSettingRowMinHeight", "kSettingIconSize", "kTileBlue", "kTileGreen",
            "kTileOrange", "kTileRed", "kTilePurple", "kTileGray", "kTilePink",
            "kGlassBlurCrystal", "kGlassFillCrystalLight", "kGlassFillCrystalDark",
            "kGlassBorderCrystalLight", "kGlassBorderCrystalDark", "kWarning"]:
    check(f"Token v2 {tok}", tok in tokens, f"falta {tok}")

# --- 3. Contrato intacto (theme solo-Dart) ---
contract = read("docs/contract-keys.txt")
check("theme_mode fuera del contrato", "theme_mode" not in contract)
storage = read(f"{LIB}/services/storage_service.dart")
m = re.search(r"static const List<String> bridgeKeys = \[(.*?)\];", storage, re.DOTALL)
check("bridgeKeys existe", m is not None)
if m:
    check("theme_mode fuera del puente", "theme_mode" not in m.group(1))
check("theme_mode con dominio validado",
      "themeModes" in storage and "defaultThemeMode" in storage)

# --- 4. Tokens UI (mirror del job CI) ---
dart_files = []
for root, _, files in os.walk(os.path.join(WORKSPACE, LIB)):
    for f in files:
        if f.endswith(".dart"):
            dart_files.append(os.path.join(root, f))
green = [f for f in dart_files
         if "design_tokens.dart" not in f
         and "Colors.green" in open(f, encoding="utf-8").read()]
check("Sin Colors.green fuera de tokens", not green, f"en: {green}")
bad_ts = []
for f in dart_files:
    if "design_tokens.dart" in f:
        continue
    src = open(f, encoding="utf-8").read()
    if re.search(r"(?<![A-Za-z_])TextStyle\(", src):
        bad_ts.append(os.path.relpath(f, os.path.join(WORKSPACE, LIB)))
check("Sin TextStyle( fuera de tokens", not bad_ts, f"en: {bad_ts}")
bad_size = []
for f in dart_files:
    for line in open(f, encoding="utf-8").read().splitlines():
        mm = re.search(r"size:\s*(\d+)", line)
        if mm and mm.group(1) not in ("18", "22", "28"):
            bad_size.append(f"{os.path.relpath(f, os.path.join(WORKSPACE, LIB))}: {line.strip()[:60]}")
check("Iconos solo 18/22/28", not bad_size, f"fuera de tabla: {bad_size[:5]}")

# --- 5. Keys de conducta preservadas ---
need_keys = [
    "api-cta-button", "api-loaded-button", "about-open-button",
    "bubble-history-switch", "burbuja-overlay-permission-row",
    "kb-height-profile-selector", "kb-key-spacing-selector",
    "kb-spacebar-trackpad-mode-selector", "kb-bottom-elevation-selector",
    "kb-haptic-style-selector", "teclado-go-trackpad",
    "kb-trackpad-sensitivity-slider", "kb-trackpad-accel-curve-selector",
    "kb-trackpad-secondary-click-selector", "kb-trackpad-button-layout-selector",
    "kb-trackpad-scroll-position-selector", "kb-trackpad-scroll-direction-selector",
    "kb-trackpad-pointer-style-selector", "kb-trackpad-haptic-selector",
    "kb-trackpad-auto-return-selector", "snippets-add-button",
    "snippets-search-field", "snippet-name-field", "snippet-content-field",
    "credenciales-add-nombre", "credenciales-add-usuario",
    "credenciales-add-password", "credenciales-add-button",
    "credenciales-show-user", "experimental-banner-claves",
    "about-theme-selector",
]
blob = " ".join(open(f, encoding="utf-8").read() for f in dart_files)
for k in need_keys:
    check(f"Key preservada {k}", f"'{k}'" in blob, f"falta {k}")

# --- 6. About con tema + textos de contrato ---
check("About con selector de tema", "about-theme-selector" in screen)
for txt in ["VoiceBubble STT v1.0.0", "Transcripción de voz a texto con Groq Whisper."]:
    check(f"Contrato About '{txt[:30]}...'", txt in screen)
for mode in ["'sistema'", "'claro'", "'oscuro'"]:
    check(f"About ofrece modo {mode}", mode in screen)

# --- 7. Navegación v2: sin AppBar, Back del sistema ---
flow = read("app_source/test/integration/full_flow_test.dart")
check("Flujo usa Back del sistema (sin AppBar)", "pageBack()" in flow)
check("Sin arrow_back en flujo", "arrow_back" not in flow)

print("\n============================================================")
print(f" RESULTADO SUITE SETTINGS-V2: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
