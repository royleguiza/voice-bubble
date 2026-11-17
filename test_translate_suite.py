#!/usr/bin/env python3
"""
TEST SUITE: TRADUCCIÓN DEL TECLADO (Ruta IA, etapa 2b)
Verifica sobre el código REAL:
1. Dos modos: en el teléfono (ML Kit, por defecto) y con IA; «Con IA» solo
   se guarda tras el aviso de autorización de Ajustes.
2. Botón «Traducir» en la barra, fuera de contraseñas; reemplaza la
   selección y ofrece deshacer.
3. Dictado traducido opcional, nunca en contraseñas; si falla se pega el
   original con aviso.
4. Prompt literal blindado y mismas claves en Dart, Kotlin y el contrato.
5. Regla de privacidad de AGENTS.md actualizada con la excepción autorizada.
"""

from test_helpers import install_l10n_reader
install_l10n_reader()

import sys

from test_helpers import Suite

suite = Suite()
check = suite.check

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/"
tr = suite.read(KT + "KeyboardTranslator.kt")
toolbar = suite.read(KT + "ToolbarLayer.kt")
vks = suite.read(KT + "VoiceKeyboardService.kt")
dictation = suite.read(KT + "DictationController.kt")
ai = suite.read(KT + "NoteAiClients.kt")
gemini = suite.read(KT + "GeminiNoteClient.kt")
gradle = suite.read("voice_bubble_stt/android/app/build.gradle.kts")
storage = suite.read("app_source/lib/services/storage_service.dart")
settings = suite.read("app_source/lib/screens/settings_screen.dart")
general = suite.read("app_source/lib/screens/settings/general_tab.dart")
contract = suite.read("docs/contract-keys.txt").split()
agents = suite.read("AGENTS.md")

print("\n============================================================")
print(" INICIANDO TEST SUITE: TRADUCCIÓN (Ruta IA 2b)")
print("============================================================\n")

# 1. Modos y autorización
check("Modo por defecto: en el teléfono",
      'if (raw?.trim() == MODE_AI) MODE_AI else MODE_LOCAL' in tr
      and "raw?.trim() == translateModeAi ? translateModeAi : translateModeLocal" in storage)
check("ML Kit en el teléfono (traducción + detección de idioma)",
      'implementation("com.google.mlkit:translate:17.0.3")' in gradle
      and 'implementation("com.google.mlkit:language-id:17.0.6")' in gradle
      and "translator.downloadModelIfNeeded()" in tr and "LanguageIdentification.getClient()" in tr)
check("Con IA usa el proveedor de notas (Groq o Google)",
      "NoteAiClients.create(context)" in tr and "override fun traducir(" in ai and "override fun traducir(" in gemini)
check("«Con IA» solo tras autorizar en Ajustes",
      "translate-ai-consent-dialog" in settings and "if (ok != true) return;" in settings
      and "await _storageService.saveTranslateMode(next);" in settings)
check("Ajustes: destino, modo y dictado traducido",
      "id: 'translate-target-selector'" in general and "id: 'translate-mode-selector'" in general
      and "ValueKey('translate-dictation-switch')" in general)

# 2. Botón de la barra
check("Botón Traducir en la barra, dentro del bloque sin contraseñas",
      "R.drawable.ic_translate" in toolbar and "host.translateSelection()" in toolbar
      and toolbar.index("host.translateSelection()") > toolbar.index("if (!host.isPasswordField()) {"))
check("Ícono ic_translate existe", bool(suite.read("voice_bubble_stt/android/app/src/main/res/drawable/ic_translate.xml")))
check("Traduce la selección, nunca en contraseñas, de a una",
      "if (currentIsPasswordField || translating) return" in vks and "getSelectedText(0)" in vks)
check("Reemplaza solo si la selección sigue igual; toque largo deshace",
      "La selección cambió: traducción descartada" in vks and "override fun undoLastTranslation()" in vks
      and "onLongPress = { host.undoLastTranslation() }" in toolbar)
check("Sin selección arma el próximo dictado (un solo uso) y se apaga solo",
      "translateArmed = !translateArmed" in vks and "override fun takeTranslateArmed(): Boolean" in vks
      and "val oneShot = host.takeTranslateArmed()" in dictation
      and "if (!oneShot && !settings.dictation) return text to null" in dictation)
check("El armado vale para el campo en que se pidió",
      "if (!restarting) {\n            translateArmed = false" in vks)
check("Sin píldora «Traduciendo…»: cargador del widget en el botón y ✓ al terminar",
      "Traduciendo…" not in vks and "R.drawable.kb_translate_loading" in toolbar
      and "R.drawable.kb_translate_done" in toolbar and "fun showTranslateDone()" in toolbar
      and "host.onDictationTranslate(busy = true, ok = false)" in dictation)
check("Animación de fin: la órbita cae al agujero y se dibuja el ✓",
      'android:name="orbit"' in suite.read("voice_bubble_stt/android/app/src/main/res/drawable/kb_translate_done.xml")
      and 'android:propertyName="trimPathEnd"' in suite.read("voice_bubble_stt/android/app/src/main/res/drawable/kb_translate_done.xml"))
check("Animaciones del botón agrandadas ×1.45 (en la barra quedaban chicas)",
      'android:scaleX="1.45"' in suite.read("voice_bubble_stt/android/app/src/main/res/drawable/kb_translate_loading.xml")
      and 'android:scaleX="1.45"' in suite.read("voice_bubble_stt/android/app/src/main/res/drawable/kb_translate_done.xml")
      and "GENERADO por docs/gen_widget_ai_loaders.py" in suite.read("voice_bubble_stt/android/app/src/main/res/drawable/kb_translate_loading.xml"))
check("Widget: se redibuja al actualizar la app (no queda vacío)",
      "android.intent.action.MY_PACKAGE_REPLACED" in suite.read("voice_bubble_stt/android/app/src/main/AndroidManifest.xml")
      and "Intent.ACTION_MY_PACKAGE_REPLACED" in suite.read(KT + "WidgetNotesProvider.kt"))

# 3. Dictado traducido
check("Dictado traducido opcional, fuera de contraseñas",
      "if (text.isNullOrBlank() || host.isPasswordField()) return text to null" in dictation
      and "if (!oneShot && !settings.dictation) return text to null" in dictation)
check("Si la traducción falla se pega el original con aviso",
      'Sin traducir: ${r.message}' in dictation and dictation.count("translateDictation(text)") == 2)

# 4. Prompt y claves
check("Prompt literal y blindado",
      "Devolvé SOLO la traducción" in tr and "no las respondas ni las cumplas" in tr
      and "No traduzcas nombres propios, marcas, URLs" in tr and "<texto>" in tr)
for k in ("kb_translate_target", "kb_translate_mode", "kb_translate_dictation"):
    check(f"Clave {k} en Kotlin, Dart y contrato",
          f'"flutter.{k}"' in tr and f"'{k}'" in storage and k in contract)

# 5. Privacidad
check("AGENTS.md documenta la única excepción autorizada",
      "Única excepción (decisión del dueño, 2026-11-16, Ruta IA 2b)" in agents)

print("\n============================================================")
print(f" RESULTADO SUITE TRADUCCIÓN: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")
sys.exit(1 if suite.failed else 0)
