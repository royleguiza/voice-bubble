#!/usr/bin/env python3
"""
TEST SUITE: AJUSTES 2026 (prototipo "VoiceBubble · Ajustes 2026", aprobado
por el dueño el 2026-10-30; reemplaza a settings-redesign-v2).
Verifica sobre el código REAL:
1. Estructura: lista raíz estilo iOS + subpáginas (sin dock de pestañas).
2. Kit único: 5 tipos de fila (nav, interruptor, menú, acción, valor).
3. Contrato intacto: theme_mode solo-Dart (fuera de bridgeKeys y contrato).
4. Tokens UI: sin Colors.green/TextStyle sueltos, iconos 18/22/28.
5. Keys de conducta preservadas (las que verifican los tests Dart).
6. Acerca de con textos de contrato; Apariencia Sistema/Claro/Oscuro.
7. Navegación: Back del sistema sube un nivel (PopScope), sin AppBar.
8. Rendimiento: solo se construye la página visible; carga en 2 fases.
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
print(" INICIANDO TEST SUITE: AJUSTES 2026")
print("============================================================\n")

LIB = "app_source/lib"
screen = read(f"{LIB}/screens/settings_screen.dart")
kit = read(f"{LIB}/widgets/settings_v2.dart")
pages = screen + read(f"{LIB}/screens/settings/general_tab.dart") \
    + read(f"{LIB}/screens/settings/teclado_tab.dart") \
    + read(f"{LIB}/screens/settings/trackpad_tab.dart")

# --- 1. Estructura ---
check("Dock de pestañas eliminado",
      not os.path.isfile(os.path.join(WORKSPACE, f"{LIB}/widgets/settings_tab_bar.dart")))
check("Sin restos de SettingsTabBar en lib", "SettingsTabBar" not in pages)
for gone in ["tab-general", "tab-teclado", "tab-trackpad", "tab-snippets",
             "tab-credenciales", "_builtTabs", "IndexedStack("]:
    check(f"Sin restos de '{gone}'", gone not in pages, f"quedó {gone}")
check("SettingsScreen sin AppBar", "AppBar(" not in screen)
check("SettingsScreen con SafeArea", "SafeArea(" in screen)
check("Raíz con título grande 'Ajustes'", "SettingsLargeTitle('Ajustes')" in screen)
for page in ["root", "transcripcion", "ia", "teclado", "sonido", "burbuja",
             "trackpad", "snippets", "claves", "notas", "acerca"]:
    check(f"Página {page} en el enum", f"  {page}," in screen)
for nav in ["transcripcion", "ia", "teclado", "burbuja", "trackpad",
            "snippets", "claves", "notas"]:
    check(f"Fila raíz nav-{nav}", f"ValueKey('nav-{nav}')" in screen)
check("Las páginas son part de la misma librería",
      all(f"part 'settings/{p}';" in screen
          for p in ["general_tab.dart", "teclado_tab.dart", "trackpad_tab.dart"]))

# --- 2. Kit único ---
for cls in ["SettingsSection", "SettingsNavRow", "SettingsSwitchRow",
            "SettingsMenuRow", "SettingsActionRow", "SettingsValueRow",
            "SettingsGlassButton", "SettingsSheetFrame", "SettingsGroupLabel"]:
    check(f"Kit define {cls}", f"class {cls}" in kit)
# Horizonte: íconos de línea en fg2, sin pastillas de color.
check("Sin pastillas de ícono (SettingIconTile)", "SettingIconTile" not in kit)
check("Ícono de fila en un solo color (fg2 / fg en alto contraste)",
      "class _RowIcon" in kit and "highContrast ? label : secondary" in kit)
check("Interruptor estilo iOS (CupertinoSwitch)", "CupertinoSwitch(" in kit)
check("Menú desplegable con check (MenuAnchor)", "MenuAnchor(" in kit
      and "Icons.check_rounded" in kit)
check("Sin SegmentedButton en Ajustes", "SegmentedButton" not in pages + kit)
check("Sin SwitchListTile en Ajustes", "SwitchListTile" not in pages + kit)
check("Sin tarjetas expandibles", "ExpandableSettingsCard" not in pages + kit)

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
tokens = read(f"{LIB}/ui/design_tokens.dart")
for tok in ["kSettingsGroupRadius", "kSettingsGroupGap", "kSettingsLargeTitle",
            "kSettingsNavTitle", "kSettingsSectionHeader", "kSettingsSecondaryLight",
            "kSettingsSecondaryDark", "kSwitchOn", "kTintTextLight", "kTintTextDark",
            "kSettingRowMinHeight", "kSettingIconSize", "kRadiusField", "kTextGroupLabel"]:
    check(f"Token {tok}", tok in tokens, f"falta {tok}")
check("Sin tokens kTile* (pastillas retiradas)", "kTile" not in tokens)

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
    "about-open-button", "theme-selector", "api-key-row", "api-key-input-field",
    "api-key-save-button", "api-key-cancel-button", "api-key-delete-button",
    "gemini-key-row", "geminiActionsSwitch", "geminiTestButton",
    "record-mode-selector", "bubble-active-switch", "bubble-history-switch",
    "burbuja-overlay-permission-row", "notes-deferred-queue-switch",
    "widget-mic-position-selector", "kb-preview", "kb-picker-button",
    "kb-open-settings-button", "kb-height-profile-selector",
    "kb-key-spacing-selector", "kb-bottom-elevation-selector",
    "kb-terminal-row-switch", "kb-code-key-switch", "kb-language-key-switch",
    "credenciales-key-visible-switch", "kb-spacebar-trackpad-mode-selector",
    "kb-spacebar-alignment-selector", "kb-invert-toolbar-switch",
    "kb-long-press-symbols-switch", "kb-long-press-delay-selector",
    "kb-clipboard-images-switch", "kb-haptics-switch", "kb-haptic-style-selector",
    "kb-mic-haptics-enabled", "kb-mic-sounds-enabled", "kb-mic-start-style",
    "kb-mic-stop-style", "kb-trackpad-enabled-switch", "kb-trackpad-toolbar-switch",
    "kb-trackpad-sensitivity-slider", "kb-trackpad-accel-curve-selector",
    "kb-trackpad-secondary-click-selector", "kb-trackpad-button-layout-selector",
    "kb-trackpad-scroll-position-selector", "kb-trackpad-scroll-direction-selector",
    "kb-trackpad-pointer-style-selector", "kb-trackpad-haptic-selector",
    "kb-trackpad-auto-return-selector", "snippets-add-button",
    "snippets-search-field", "snippets-reorder-button", "snippet-name-field",
    "snippet-content-field", "snippet-save-button", "snippet-delete-button",
    "credenciales-open-add", "credenciales-add-nombre", "credenciales-add-usuario",
    "credenciales-add-password", "credenciales-add-button", "credenciales-show-user",
    "settings-back-button",
]
blob = " ".join(open(f, encoding="utf-8").read() for f in dart_files)
for k in need_keys:
    check(f"Key preservada {k}", f"'{k}'" in blob, f"falta {k}")

# --- 6. Acerca de + apariencia ---
check("Acerca de con descripción de contrato",
      "Transcripción de voz a texto con Groq Whisper." in screen)
check("Acerca de muestra versión y diagnóstico",
      "'1.0.0'" in screen and "channelErrorCount" in screen)
for mode in ["'sistema'", "'claro'", "'oscuro'"]:
    check(f"Apariencia ofrece modo {mode}", mode in screen)

# --- 7. Navegación ---
check("Back del sistema sube un nivel (PopScope)",
      "PopScope(" in screen and "canPop: _stack.length == 1" in screen)
check("Respeta Reduced Motion en la transición",
      "MediaQuery.disableAnimationsOf(context)" in screen)
flow = read("app_source/test/integration/full_flow_test.dart")
check("Flujo usa Back del sistema (sin AppBar)", "handlePopRoute()" in flow)
check("Sin arrow_back en flujo", "arrow_back" not in flow)

# --- 8. Rendimiento ---
check("Solo se construye la página visible",
      "_buildPage(context, page)" in screen and "_stack.last" in screen)
check("Carga en dos fases (prefs al instante, bóveda en paralelo)",
      "_loadPrefsState()" in screen and "_loadSlowState()" in screen)
check("Espejo STT solo se repara si falta",
      "isSttMirrorConfigured()" in screen)

print("\n============================================================")
print(f" RESULTADO SUITE AJUSTES 2026: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")
sys.exit(suite.exit_code())
