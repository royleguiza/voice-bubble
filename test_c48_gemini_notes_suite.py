#!/usr/bin/env python3
"""TEST SUITE: CONTRATO C-48 (ACCIONES IA GEMINI EN NOTAS)"""

import os
import re

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

print("\n============================================================")
print(" INICIANDO TEST SUITE: CONTRATO C-48 (GEMINI IA EN NOTAS)")
print("============================================================\n")

STORE = "app_source/lib/services/gemini_key_store.dart"
SERVICE = "app_source/lib/services/gemini_note_service.dart"
EDITOR = "app_source/lib/screens/note_editor_screen.dart"
GENERAL = "app_source/lib/screens/settings/general_tab.dart"
SETTINGS = "app_source/lib/screens/settings_screen.dart"

for rel in [STORE, SERVICE, EDITOR, GENERAL, SETTINGS]:
    check(f"Archivo {rel} existe", os.path.isfile(os.path.join(WORKSPACE, rel)))

if not os.path.isfile(os.path.join(WORKSPACE, SERVICE)):
    import sys
    sys.exit(suite.exit_code())

store = suite.read(STORE)
service = suite.read(SERVICE)
editor = suite.read(EDITOR)
general = suite.read(GENERAL)
settings = suite.read(SETTINGS)

# 1. Key segura
check("store: usa FlutterSecureStorage", "FlutterSecureStorage" in store)
check("store: clave de prefs con kb_", "kb_gemini_api_key_v1" in store)
check("store: flag actionsEnabled", "actionsEnabledKey" in store)

# 2. Servicio
check("servicio: endpoint generativelanguage", "generativelanguage.googleapis.com" in service)
check("servicio: header x-goog-api-key", "x-goog-api-key" in service)
check("servicio: NO expone key en URL", "?key=" not in service)
check("servicio: timeout 30s", "Duration(seconds: 30)" in service)
check("servicio: error auth clasificado", "GeminiErrorKind.auth" in service)
check("servicio: error network", "GeminiErrorKind.network" in service)
check("servicio: una sola petición por llamada (1 POST)", service.count(".post(") == 1)

# 3. Prompts
check("prompt título: límite palabras", "Máximo 6 palabras y 60 caracteres" in service)
check("prompt título: sin emojis", "Sin comillas, sin punto final, sin emojis" in service)
check("prompt reestructurar: no inventar", "NO agregues información" in service)
check("prompt reestructurar: ambiguo [?]", "[?]" in service)
check("prompt investigar: sin verificar", "[sin verificar]" in service)
check("prompt investigar: 5 secciones", all(f"{i}. " in service for i in range(1, 6)))
check("system instruction presente", "systemInstruction" in service)
check("modelo GA 2026 (gemini-3.5-flash)", "gemini-3.5-flash" in service)
check("NO usa gemini-2.5-flash (404 nuevos usuarios)", "gemini-2.5-flash" not in service)
check("sin sampling params deprecados (temperature)", "temperature" not in service)
check("error con detalle de body copiable", "_bodyDetail" in service)

# 4. Editor
check("editor: icono título", "geminiTituloIcon" in editor)
check("editor: botón reestructurar", "geminiReestructurarButton" in editor)
check("editor: botón investigar", "geminiInvestigarButton" in editor)
check("editor: preview con Aplicar/Descartar", "Descartar" in editor and "Aplicar" in editor)
check("servicio: thinkingLevel minimal (evita respuesta vacía)", "thinkingLevel" in service)
check("widget: slots gemini en layout nativo", "btn_gemini_investigar" in suite.read("voice_bubble_stt/android/app/src/main/res/layout/activity_widget_note_edit.xml"))
check("editor: no muestra botones sin key", "_geminiReady" in editor and "_loadGeminiState" in editor)

# 5. Ajustes
check("general: segunda ApiKeyCard gemini", "geminiHasApiKey" in general)
check("general: GeminiApiKeyCard", "GeminiApiKeyCard" in general)
check("general: keys gemini preservadas", "ValueKey('gemini-cta-button')" in general)
check("general: toggle acciones", "geminiActionsSwitch" in general)
check("general: botón probar conexión", "geminiTestButton" in general)
check("settings: saveGeminiApiKey", "_saveGeminiApiKey" in settings)
check("settings: clearGeminiApiKey", "_clearGeminiApiKey" in settings)
check("settings: testGeminiConnection", "_testGeminiConnection" in settings)

# 6. Sin secretos ni literales de key real
joined = store + service + editor + general + settings
check("sin clave real AQ. pegada", re.search(r"AQ\.[A-Za-z0-9_-]{20,}", joined) is None)
check("sin clave real gsk_ pegada", re.search(r"gsk_[A-Za-z0-9]{20,}", joined) is None)
check("sin claves hardcodeadas tipo gemini_key =", re.search(r"apiKey\s*=\s*['\"][^'\"]{10,}", joined) is None)

print(f"\nC-48: {suite.passed} PASS / {suite.failed} FAIL\n")
import sys
sys.exit(suite.exit_code())
