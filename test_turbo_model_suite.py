#!/usr/bin/env python3
"""
TEST SUITE: MODELO DE TRANSCRIPCIÓN ELEGIBLE (Ruta IA, etapa 1)
Verifica sobre el código REAL:
1. Dart: turbo es el modelo por defecto; whisper-large-v3 (preciso) se puede
   elegir; normalizeModel acepta solo esos dos; el multipart manda el elegido.
2. Ajustes › Transcripción ofrece el menú de modelo y lo guarda en el puente
   kb_stt_model; los espejos de la clave NO pisan la elección.
3. Kotlin: resolveModel ya NO migra large-v3 a turbo; acepta los dos; lo
   desconocido o vacío cae a turbo; getConfig relee el modelo en cada dictado.
4. Docs vivos (README, AGENTS, PRODUCT) nombran turbo.
"""

from test_helpers import install_l10n_reader
install_l10n_reader()

import os
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


print("\n============================================================")
print(" INICIANDO TEST SUITE: MODELO DE TRANSCRIPCIÓN ELEGIBLE")
print("============================================================\n")

dart = read("app_source/lib/services/cloud_stt_service.dart")
stt = read("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/SpeechToTextClient.kt")

storage = read("app_source/lib/services/storage_service.dart")
config_store = read("app_source/lib/services/stt_config_store.dart")
transcription = read("app_source/lib/services/transcription_service.dart")
general = read("app_source/lib/screens/settings/general_tab.dart")
settings = read("app_source/lib/screens/settings_screen.dart")

# --- 1. Dart: turbo por defecto, preciso elegible ---
check("Dart: turbo es el modelo por defecto",
      "static const String _model = 'whisper-large-v3-turbo';" in dart
      and "static const String model = _model;" in dart)
check("Dart: modelo preciso whisper-large-v3 elegible",
      "static const String preciseModel = 'whisper-large-v3';" in dart
      and "static const List<String> models = [_model, preciseModel];" in dart)
check("Dart: normalizeModel cae a turbo si no es válido",
      "static String normalizeModel(String? raw)" in dart and "models.contains(value)" in dart)
check("Dart: el multipart manda el modelo elegido",
      "request.fields[_multipartFieldModel] = normalizeModel(sttModel);" in dart)
check("Dart: la transcripción lee el modelo en cada dictado",
      "await _storageService.loadSttModel()" in transcription
      and "if (model != _cloudService.sttModel ||" in transcription
      and "_cloudService.copyWith(sttModel: model, sttLanguage: language)" in transcription)

# --- 2. Ajustes + puente ---
check("Ajustes: menú de modelo en Transcripción",
      "id: 'stt-model-selector'" in general and "CloudSttService.preciseModel" in general
      and "onSelected: _saveSttModel" in general)
check("Ajustes: carga y guarda el modelo",
      "await s.loadSttModel()" in settings and "saveSttModel(model)" in settings)
check("Storage: loadSttModel / saveSttModel sobre kb_stt_model",
      "Future<String> loadSttModel()" in storage and "Future<void> saveSttModel(String model)" in storage)
check("Espejos de la clave respetan la elección (no pisan con turbo)",
      "prefs.setString(_sttModelKey, CloudSttService.model)" not in storage
      and "prefs.setString(sttModelKey, CloudSttService.model)" not in config_store
      and storage.count("CloudSttService.normalizeModel(prefs.getString(_sttModelKey))") == 2
      and config_store.count("CloudSttService.normalizeModel(prefs.getString(sttModelKey))") == 2)

# --- 3. Kotlin ---
check("Kotlin: default turbo y preciso declarados",
      'const val DEFAULT_MODEL = "whisper-large-v3-turbo"' in stt
      and 'const val PRECISE_MODEL = "whisper-large-v3"' in stt
      and "val MODELS = listOf(DEFAULT_MODEL, PRECISE_MODEL)" in stt)
check("Kotlin: resolveModel ya no migra large-v3 a turbo",
      'if (raw == "whisper-large-v3") "whisper-large-v3-turbo"' not in stt
      and "value in MODELS" in stt)
check("Kotlin: loadConfig usa resolveModel con turbo por defecto",
      'model = resolveModel(prefs.getString("flutter.kb_stt_model", DEFAULT_MODEL))' in stt)
check("Kotlin: getConfig relee el modelo (cambio en vivo)",
      "cached.copy(model = model, language = language)" in stt)
check("Kotlin: endpoint Groq intacto",
      "https://api.groq.com/openai/v1/audio/transcriptions" in stt)
check("Kotlin: idioma es intacto", '"es"' in stt)

# --- 3b. «Idioma en que hablo» (Ruta IA, etapa 4) ---
import re as _re
gtab = read("app_source/lib/screens/settings/general_tab.dart")
check("Dart: idiomas elegibles auto/es/en/pt",
      "autoLanguage, 'es', 'en', 'pt', 'fr'" in dart and "autoLanguage = 'auto'" in dart)
check("Dart: automático no manda language",
      "if (spokenLanguage != autoLanguage)" in dart and "normalizeLanguage(sttLanguage)" in dart)
check("Dart: el idioma se relee en cada dictado", "loadSttLanguage()" in transcription and "sttLanguage: language" in transcription)
check("Dart: los espejos de la clave NO pisan el idioma elegido",
      "CloudSttService.language);" not in storage and "CloudSttService.language);" not in config_store
      and storage.count("normalizeLanguage(prefs.getString(_sttLanguageKey))") == 2
      and config_store.count("normalizeLanguage(prefs.getString(sttLanguageKey))") == 2)
check("Ajustes: menú «Idioma en que hablo»", "stt-language-selector" in gtab and "_saveSttLanguage" in gtab)
import re as _re
_kt_langs = _re.findall(r'"([a-z]{2})"', stt.split("val LANGUAGES = listOf(")[1].split(")")[0]) if "val LANGUAGES = listOf(" in stt else []
_dart_langs = _re.findall(r"'([a-z]{2})'", dart.split("static const List<String> languages = [")[1].split("];")[0]) if "static const List<String> languages = [" in dart else []
check("Kotlin: mismos idiomas que Dart (mismo orden)", _kt_langs == _dart_langs and len(_kt_langs) >= 3
      and 'AUTO_LANGUAGE = "auto"' in stt)
check("Kotlin: automático no manda language", 'if (config.language != AUTO_LANGUAGE) field("language", config.language)' in stt)
check("Kotlin: getConfig relee el idioma", "resolveLanguage(prefs.getString(\"flutter.kb_stt_language\", DEFAULT_LANGUAGE))" in stt
      and "language == cached.language" in stt)

# --- 4. Docs vivos ---
for doc in ["README.md", "AGENTS.md", "PRODUCT.md"]:
    content = read(doc)
    check(f"{doc} nombra turbo", "whisper-large-v3-turbo" in content)

print("\n============================================================")
print(f" RESULTADO SUITE MODELO STT: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
