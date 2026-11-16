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
check("prompt resumen: corto (<=30%)", "<= 30%" in service)
check("prompt resumen: no inventar", "NO inventes" in service)
check("sin investigar en el servicio", "investigar" not in service)
check("system instruction presente", "systemInstruction" in service)
check("modelo vigente y rápido (gemini-3.5-flash-lite, Ruta IA etapa 1)", "'gemini-3.5-flash-lite'" in service)
check("NO usa gemini-2.5-flash (404 nuevos usuarios)", "gemini-2.5-flash" not in service)
check("sin sampling params deprecados (temperature)", "temperature" not in service)
check("error con detalle de body copiable", "_bodyDetail" in service)

# 3b. Ruta IA etapa 2a: proveedor de notas elegible (Groq por defecto)
ai = suite.read("app_source/lib/services/note_ai_service.dart")
kt_ai = suite.read("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/NoteAiClients.kt")
storage_ai = suite.read("app_source/lib/services/storage_service.dart")
general_ai = suite.read("app_source/lib/screens/settings/general_tab.dart")
editor_ai = suite.read("app_source/lib/screens/note_editor_screen.dart")
check("Groq notas: gpt-oss-20b con razonamiento corto (Dart)",
      "static const String model = 'openai/gpt-oss-20b';" in ai and "'reasoning_effort': 'low'" in ai)
check("Groq notas: mismos prompts que Gemini (Dart)",
      "GeminiNoteService.promptTitulo" in ai and "GeminiNoteService.promptResumen" in ai
      and "GeminiNoteService.systemInstruction" in ai)
check("Groq notas: clave en Authorization, nunca en la URL",
      "'Authorization': 'Bearer $_apiKey'" in ai and "?key=" not in ai)
check("Gemini implementa la misma interfaz", "class GeminiNoteService implements NoteAiService" in service)
check("Resolver: preferido, si no el otro, sin claves null",
      "if (wanted == groq && hasGroq) return groq;" in ai and "if (hasGoogle) return google;" in ai)
check("Preferencia kb_ai_notes_provider en el puente (Groq por defecto)",
      "static const String aiNotesProviderKey = 'kb_ai_notes_provider';" in storage_ai
      and "aiNotesProviderKey," in storage_ai)
check("Ajustes: menú de proveedor de notas", "id: 'ai-notes-provider-selector'" in general_ai)
check("Editor: usa el proveedor resuelto", "NoteAiResolver().create()" in editor_ai
      and "NoteAiResolver().effectiveProvider()" in editor_ai)
check("Widget: mismo modelo y elección que Dart",
      'const val MODEL = "openai/gpt-oss-20b"' in kt_ai and 'PROVIDER_PREF = "flutter.kb_ai_notes_provider"' in kt_ai
      and '.put("reasoning_effort", "low")' in kt_ai)
check("Groq: nota demasiado larga (413) con mensaje claro en app y widget",
      "if (code == 413)" in ai and "tooLongMessage" in ai
      and "code == 413 -> GeminiNoteClient.GeminiError(" in kt_ai and "TOO_LONG_MESSAGE" in kt_ai)
check("Widget: el listado se vuelve a pedir al salir del editor (launchers que ignoran el aviso)",
      "override fun onStop()" in suite.read("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/WidgetNoteEditActivity.kt")
      and "if (context === this) listDirty = true" in suite.read("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/WidgetNoteEditActivity.kt"))
check("Widget: lector y editor usan NoteAiClients",
      "NoteAiClients.create(context, WIDGET_AI_TIMEOUT_MS)" in suite.read("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/WidgetReader.kt")
      and "NoteAiClients.create(this)" in suite.read("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/WidgetNoteEditActivity.kt"))

# 4. Editor
check("editor: icono título", "geminiTituloIcon" in editor)
check("editor: botón resumir", "geminiResumirButton" in editor)
check("editor: sin botón investigar", "geminiInvestigarButton" not in editor)
check("editor: preview con Reemplazar/Descartar", "Descartar" in editor and "Reemplazar" in editor)
check("servicio: thinkingLevel minimal (evita respuesta vacía)", "thinkingLevel" in service)
check("widget: slot resumir en layout nativo", "btn_gemini_resumir" in suite.read("voice_bubble_stt/android/app/src/main/res/layout/activity_widget_note_edit.xml"))
check("widget: sin slot investigar", "btn_gemini_investigar" not in suite.read("voice_bubble_stt/android/app/src/main/res/layout/activity_widget_note_edit.xml"))
check("cuerpo con tope amplio (200k)", "maxCuerpoLength = 200000" in suite.read("app_source/lib/services/notes_service.dart"))
check("editor: no muestra botones sin key", "_geminiReady" in editor and "_loadGeminiState" in editor)

# 4b. Widget: IA directa desde el widget, sin abrir la app
KT_DIR = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/"
kt_client = suite.read(KT_DIR + "GeminiNoteClient.kt")
kt_widget = suite.read(KT_DIR + "WidgetNoteEditActivity.kt")
check("widget: cliente Gemini nativo existe", bool(kt_client))
check("widget: header x-goog-api-key", "x-goog-api-key" in kt_client)
check("widget: key nunca en la URL", "?key=" not in kt_client)
check("widget: misma clave segura que Dart", 'SECURE_KEY = "kb_gemini_api_key_v1"' in kt_client)
check("widget: mismo modelo que Dart", 'MODEL = "gemini-3.5-flash-lite"' in kt_client and "'gemini-3.5-flash-lite'" in service)
check("widget: timeout 30s", "TIMEOUT_MS = 30_000" in kt_client)
check("widget: thinkingLevel minimal", "thinkingLevel" in kt_client)
check("widget: sin temperature", "temperature" not in kt_client)
for frase in ["Máximo 6 palabras y 60 caracteres", "Sin comillas, sin punto final, sin emojis",
              "Si la nota no tiene tema claro", "<= 30%", "NO inventes datos ni conclusiones",
              "Usá viñetas cortas para los puntos clave"]:
    check(f"widget: prompt espejo de Dart ({frase[:24]})", frase in kt_client and frase in service)
check("widget: no abre la app para IA", "gemini_$action" not in kt_widget and "widget_action" not in kt_widget)
check("widget: título y resumen corren en el widget", "runGemini(GEMINI_TITULO)" in kt_widget and "runGemini(GEMINI_RESUMIR)" in kt_widget)
check("widget: resumen con Descartar/Reemplazar", '"Descartar", "Reemplazar"' in kt_widget)
check("widget: indicador de carga en botones IA", "progress_gemini_titulo" in kt_widget and "progress_gemini_resumir" in kt_widget)
check("widget: sin claves reales en Kotlin", re.search(r"AQ\.[A-Za-z0-9_-]{20,}", kt_client) is None)

# 5. Ajustes
check("general: segunda ApiKeyCard gemini", "geminiHasApiKey" in general)
check("general: fila de clave Google AI", "ValueKey('gemini-key-row')" in general)
check("general: sheet de clave con keys estables", all(k in general for k in [
    "ValueKey('gemini-key-input-field')", "ValueKey('gemini-key-save-button')",
    "ValueKey('gemini-key-cancel-button')", "ValueKey('gemini-key-delete-button')"]))
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
