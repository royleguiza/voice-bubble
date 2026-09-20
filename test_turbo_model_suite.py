#!/usr/bin/env python3
"""
TEST SUITE: MODELO WHISPER-LARGE-V3-TURBO
Verifica sobre el código REAL que el cambio de modelo no rompe nada:
1. Dart: CloudSttService.model es whisper-large-v3-turbo (fuente única que
   viaja en el multipart + se republica al puente kb_stt_model).
2. Kotlin: default y fallback de loadConfig son turbo; resolveModel migra
   el legado whisper-large-v3 (prefs de versiones viejas) a turbo.
3. Sin restos funcionales del modelo viejo fuera de la migración y archivos
   históricos (docs/archive, laboratorio_ui).
4. Docs vivos (README, AGENTS, PRODUCT) nombran turbo.
"""

import os
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


print("\n============================================================")
print(" INICIANDO TEST SUITE: MODELO TURBO")
print("============================================================\n")

dart = read("app_source/lib/services/cloud_stt_service.dart")
stt = read("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/SpeechToTextClient.kt")

# --- 1. Dart: fuente única turbo ---
check("Dart usa whisper-large-v3-turbo",
      "static const String _model = 'whisper-large-v3-turbo';" in dart)
check("Dart expone model al puente", "static const String model = _model;" in dart or "static const String model =" in dart)
check("Dart envía model en el multipart",
      'request.fields[_multipartFieldModel] = _model;' in dart)
check("Dart: sin literal del modelo viejo",
      "whisper-large-v3'" not in dart and 'whisper-large-v3"' not in dart)

# --- 2. Kotlin: default + migración ---
check("Kotlin default turbo en prefs",
      'prefs.getString("flutter.kb_stt_model", "whisper-large-v3-turbo")' in stt)
check("Kotlin tiene resolveModel", "fun resolveModel(" in stt)
check("Kotlin migra legado large-v3 a turbo",
      'if (raw == "whisper-large-v3") "whisper-large-v3-turbo"' in stt)
check("Kotlin blank cae a turbo", "isNullOrBlank" in stt)
check("Kotlin loadConfig usa resolveModel", "model = resolveModel(" in stt)
check("Kotlin: endpoint Groq intacto",
      "https://api.groq.com/openai/v1/audio/transcriptions" in stt)
check("Kotlin: idioma es intacto", '"es"' in stt)

# --- 3. Sin restos del modelo viejo en código vivo ---
old_in_dart_lib = [l for l in dart.splitlines()
                   if "whisper-large-v3" in l and "turbo" not in l]
check("Sin modelo viejo en CloudSttService", not old_in_dart_lib, str(old_in_dart_lib[:2]))
old_in_stt = [l for l in stt.splitlines()
              if "whisper-large-v3" in l and "turbo" not in l]
check("Modelo viejo en Kotlin solo como legado a migrar",
      all("whisper-large-v3`" in l or '== "whisper-large-v3"' in l for l in old_in_stt),
      str(old_in_stt[:3]))

# --- 4. Docs vivos ---
for doc in ["README.md", "AGENTS.md", "PRODUCT.md"]:
    content = read(doc)
    check(f"{doc} nombra turbo", "whisper-large-v3-turbo" in content)

print("\n============================================================")
print(f" RESULTADO SUITE TURBO: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
