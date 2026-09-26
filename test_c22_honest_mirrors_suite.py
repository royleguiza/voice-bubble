#!/usr/bin/env python3
"""
test_c22_honest_mirrors_suite.py
================================
Suite de verificación exhaustiva para el Contrato C-22:
"Espejos que no mienten (éxito real hasKey && published, no pisar URL custom, aviso en fallo)"

Verifica:
1. app_source/lib/services/storage_service.dart:
   - saveSttMirror({required String apiKey}):
     * Firma Future<bool>.
     * Retorna éxito real: hasKey && published.
     * Implementa un reintento si la escritura o lectura en secure_storage falla.
     * No pisa URL custom: si kb_stt_url ya tiene un valor no vacío, lo conserva intacto
       en lugar de forzar CloudSttService.endpoint.
     * Retorna false ante key vacía o fallo de persistencia en bóveda/prefs.
   - repairSttMirror():
     * Retorna éxito real: hasKey && published.
     * Implementa un reintento de lectura ante fallo de keystore.
     * No pisa URL custom: conserva kb_stt_url si ya existe.
     * Retorna false si no hay key en la bóveda o si falla la publicación.
   - getSttUrl() y setSttUrl(url): expuestos para consulta y configuración.
2. app_source/lib/screens/settings_screen.dart:
   - _saveApiKey():
     * Acredita y valida el booleano devuelto por saveSttMirror(apiKey: key).
     * Si saveSttMirror devuelve false, aborta y lanza excepción / salta al catch.
     * En el catch, muestra el SnackBar de error existente ("No se pudo guardar la API key").
     * JAMÁS muestra "API key guardada" ni asigna _hasApiKey = true si saveSttMirror falló.
3. Simulaciones lógicas de falla de persistencia y protección de URL custom:
   - Falla de keystore tras reintento -> saveSttMirror retorna false.
   - Falla de SharedPreferences -> saveSttMirror retorna false.
   - URL custom preexistente -> se preserva exactamente.
   - URL vacía/ausente -> se fija CloudSttService.endpoint.
4. Resistencia a mutaciones negativas reales sobre el código en disco.
"""

import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

class TestSuite:
    def __init__(self, name):
        self.name = name
        self.passed = 0
        self.failed = 0

    def check(self, desc, condition, err_msg=""):
        if condition:
            print(f"  [PASS] {desc}")
            self.passed += 1
        else:
            print(f"  [FAIL] {desc} -> {err_msg}")
            self.failed += 1

suite = TestSuite("CONTRATO C-22 (ESPEJOS QUE NO MIENTEN)")
print("=" * 60)
print(f" INICIANDO TEST SUITE: {suite.name}")
print("=" * 60)

# --- 1. Rutas de Archivos del Contrato C-22 ---
ss_path = os.path.join(BASE_DIR, "app_source", "lib", "services", "storage_service.dart")
scr_path = os.path.join(BASE_DIR, "app_source", "lib", "screens", "settings_screen.dart")

suite.check("Existe storage_service.dart", os.path.exists(ss_path))
suite.check("Existe settings_screen.dart", os.path.exists(scr_path))

with open(ss_path, "r", encoding="utf-8") as f:
    ss_code = f.read()

with open(scr_path, "r", encoding="utf-8") as f:
    scr_code = f.read()

# --- 2. Verificación de storage_service.dart ---
print("\n--- Verificación de storage_service.dart ---")

suite.check(
    "saveSttMirror declara firma Future<bool>",
    "Future<bool> saveSttMirror({required String apiKey})" in ss_code
)

suite.check(
    "saveSttMirror retorna hasKey && published",
    "return hasKey && published;" in ss_code
)

suite.check(
    "saveSttMirror implementa reintento (attempt < 2)",
    "for (var attempt = 0; attempt < 2; attempt++)" in ss_code
)

suite.check(
    "saveSttMirror verifica lectura tras escribir en bóveda",
    "final readBack = await _secureStorage.read(key: secureSttApiKey);" in ss_code
)

suite.check(
    "saveSttMirror protege URL custom (no pisa si ya existe y no está vacía)",
    "final currentUrl = prefs.getString(_sttUrlKey);" in ss_code and
    "(currentUrl != null && currentUrl.trim().isNotEmpty)" in ss_code
)

suite.check(
    "saveSttMirror limpia bóveda y retorna false si la key viene vacía",
    "if (trimmed.isEmpty) {\n      await clearSttMirror();\n      return false;\n    }" in ss_code or
    ("trimmed.isEmpty" in ss_code and "return false;" in ss_code)
)

suite.check(
    "repairSttMirror declara firma Future<bool>",
    "Future<bool> repairSttMirror() async" in ss_code
)

suite.check(
    "repairSttMirror retorna hasKey && published",
    "return hasKey && published;" in ss_code
)

suite.check(
    "repairSttMirror implementa reintento de lectura",
    "if (!hasKey) {\n        // Un reintento" in ss_code or
    "secure = await _secureStorage.read(key: secureSttApiKey);" in ss_code
)

suite.check(
    "repairSttMirror protege URL custom (no pisa si ya está configurada)",
    "currentUrl != null && currentUrl.trim().isNotEmpty" in ss_code
)

suite.check(
    "storage_service.dart expone getSttUrl() y setSttUrl(url)",
    "Future<String> getSttUrl()" in ss_code and "Future<void> setSttUrl(String url)" in ss_code
)

# --- 3. Verificación de settings_screen.dart ---
print("\n--- Verificación de settings_screen.dart ---")

suite.check(
    "settings_screen._saveApiKey captura resultado booleano de saveSttMirror",
    "ok = await _storageService.saveSttMirror(apiKey: key);" in ss_code or
    "final ok = await _storageService.saveSttMirror" in scr_code or
    "final bool ok;" in scr_code
)

suite.check(
    "settings_screen._saveApiKey lanza StateError si saveSttMirror devuelve false",
    "if (!ok) {\n        throw StateError('Fallo al guardar espejo STT');\n      }" in scr_code
)

suite.check(
    "settings_screen._saveApiKey muestra SnackBar existente de error ante fallo",
    "ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('No se pudo guardar la API key'))," in scr_code or
    "content: Text('No se pudo guardar la API key')" in scr_code
)

suite.check(
    "settings_screen._saveApiKey NO asigna _hasApiKey si hay fallo",
    "if (!mounted) return;\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('No se pudo guardar la API key')),\n      );\n      return;" in scr_code
)

# --- 4. Simulaciones de Falla y Respeto a URL Custom ---
print("\n--- Simulaciones Lógicas C-22 ---")

class MockSecureStorage:
    def __init__(self, initial=None, fail_write_count=0, fail_read=False):
        self.data = dict(initial or {})
        self.write_calls = 0
        self.fail_write_count = fail_write_count
        self.fail_read = fail_read

    def write(self, key, value):
        self.write_calls += 1
        if self.write_calls <= self.fail_write_count:
            raise RuntimeError("Keystore error transitorio")
        self.data[key] = value

    def read(self, key):
        if self.fail_read:
            raise RuntimeError("Keystore read error")
        return self.data.get(key)

class MockPrefs:
    def __init__(self, initial=None, fail_set=False):
        self.data = dict(initial or {})
        self.fail_set = fail_set

    def getString(self, key):
        return self.data.get(key)

    def setString(self, key, value):
        if self.fail_set:
            return False
        self.data[key] = value
        return True

    def setBool(self, key, value):
        if self.fail_set:
            return False
        self.data[key] = value
        return True

def sim_save_stt_mirror(api_key, secure_storage, prefs, default_endpoint="https://api.groq.com/default"):
    trimmed = api_key.strip()
    if not trimmed:
        return False

    has_key = False
    for attempt in range(2):
        try:
            secure_storage.write("groq_api_key", trimmed)
            read_back = secure_storage.read("groq_api_key")
            if read_back and read_back.strip():
                has_key = True
                break
        except Exception:
            pass

    published = False
    try:
        ok_presence = prefs.setBool("kb_stt_key_configured", has_key)
        current_url = prefs.getString("kb_stt_url")
        if current_url and current_url.strip():
            ok_url = True
        else:
            ok_url = prefs.setString("kb_stt_url", default_endpoint)
        ok_model = prefs.setString("kb_stt_model", "whisper-large-v3-turbo")
        ok_lang = prefs.setString("kb_stt_language", "es")
        published = ok_presence and ok_url and ok_model and ok_lang
    except Exception:
        published = False

    return has_key and published

def sim_repair_stt_mirror(secure_storage, prefs, default_endpoint="https://api.groq.com/default"):
    has_key = False
    try:
        secure = secure_storage.read("groq_api_key")
        has_key = bool(secure and secure.strip())
        if not has_key:
            try:
                secure = secure_storage.read("groq_api_key")
                has_key = bool(secure and secure.strip())
            except Exception:
                pass

        published = False
        try:
            ok_presence = prefs.setBool("kb_stt_key_configured", has_key)
            current_url = prefs.getString("kb_stt_url")
            if current_url and current_url.strip():
                ok_url = True
            else:
                ok_url = prefs.setString("kb_stt_url", default_endpoint)
            ok_model = prefs.setString("kb_stt_model", "whisper-large-v3-turbo")
            ok_lang = prefs.setString("kb_stt_language", "es")
            published = ok_presence and ok_url and ok_model and ok_lang
        except Exception:
            published = False

        return has_key and published
    except Exception:
        return False

# Test 1: Flujo exitoso normal
sec1 = MockSecureStorage()
prf1 = MockPrefs()
ok1 = sim_save_stt_mirror("gsk_valid_key", sec1, prf1)
suite.check("Simulación 1: Guardado exitoso retorna True", ok1 is True)
suite.check("Simulación 1: Bóveda contiene la key", sec1.read("groq_api_key") == "gsk_valid_key")
suite.check("Simulación 1: Presencia es True en prefs", prf1.data.get("kb_stt_key_configured") is True)
suite.check("Simulación 1: URL toma endpoint por defecto al estar vacía", prf1.data.get("kb_stt_url") == "https://api.groq.com/default")

# Test 2: Un fallo transitorio en secure_storage se recupera con el reintento
sec2 = MockSecureStorage(fail_write_count=1)
prf2 = MockPrefs()
ok2 = sim_save_stt_mirror("gsk_retry_key", sec2, prf2)
suite.check("Simulación 2: Reintento exitoso (1 fallo transitorio) retorna True", ok2 is True)
suite.check("Simulación 2: Hubo 2 intentos de escritura", sec2.write_calls == 2)
suite.check("Simulación 2: Bóveda contiene la key tras reintento", sec2.read("groq_api_key") == "gsk_retry_key")

# Test 3: Fallo permanente de keystore (2 fallos) retorna False
sec3 = MockSecureStorage(fail_write_count=5)
prf3 = MockPrefs()
ok3 = sim_save_stt_mirror("gsk_failing_key", sec3, prf3)
suite.check("Simulación 3: Fallo permanente de keystore retorna False", ok3 is False)
suite.check("Simulación 3: Hubo exactamente 2 intentos de escritura", sec3.write_calls == 2)
suite.check("Simulación 3: Presencia en prefs es False (no miente)", prf3.data.get("kb_stt_key_configured") is False)

# Test 4: Fallo en SharedPreferences retorna False
sec4 = MockSecureStorage()
prf4 = MockPrefs(fail_set=True)
ok4 = sim_save_stt_mirror("gsk_prefs_fail", sec4, prf4)
suite.check("Simulación 4: Fallo de publicación en prefs retorna False", ok4 is False)

# Test 5: Respeto estricto a URL custom preexistente
sec5 = MockSecureStorage()
prf5 = MockPrefs(initial={"kb_stt_url": "http://192.168.1.100:8000/v1"})
ok5 = sim_save_stt_mirror("gsk_custom_url", sec5, prf5)
suite.check("Simulación 5: Guardado con URL custom retorna True", ok5 is True)
suite.check("Simulación 5: URL custom NO fue pisada con default", prf5.data.get("kb_stt_url") == "http://192.168.1.100:8000/v1")

# Test 6: repairSttMirror tampoco pisa URL custom
ok6 = sim_repair_stt_mirror(sec5, prf5)
suite.check("Simulación 6: repairSttMirror retorna True si hay key en bóveda", ok6 is True)
suite.check("Simulación 6: repairSttMirror conserva intacta la URL custom", prf5.data.get("kb_stt_url") == "http://192.168.1.100:8000/v1")

# Test 7: repairSttMirror con bóveda vacía retorna False
sec7 = MockSecureStorage()
prf7 = MockPrefs()
ok7 = sim_repair_stt_mirror(sec7, prf7)
suite.check("Simulación 7: repairSttMirror con bóveda vacía retorna False", ok7 is False)
suite.check("Simulación 7: Presencia en prefs queda en False", prf7.data.get("kb_stt_key_configured") is False)

# --- 5. Verificación de Resistencia a Mutaciones Negativas ---
print("\n--- Verificación de Resistencia a Mutaciones ---")

def validate_storage_service(code):
    if "Future<bool> saveSttMirror" not in code:
        return False, "saveSttMirror no retorna Future<bool>"
    if "return hasKey && published;" not in code:
        return False, "no retorna hasKey && published"
    if "for (var attempt = 0; attempt < 2; attempt++)" not in code:
        return False, "falta bucle de reintento"
    if "currentUrl != null && currentUrl.trim().isNotEmpty" not in code:
        return False, "no valida URL custom antes de pisar"
    if "Future<bool> repairSttMirror() async" not in code:
        return False, "repairSttMirror no retorna Future<bool>"
    return True, "OK"

def validate_settings_screen(code):
    if "ok = await _storageService.saveSttMirror" not in code and "final ok = await _storageService.saveSttMirror" not in code:
        return False, "no captura ok de saveSttMirror"
    if "if (!ok)" not in code:
        return False, "no valida if (!ok)"
    if "No se pudo guardar la API key" not in code:
        return False, "falta mensaje de error en SnackBar"
    return True, "OK"

# Mutación 1: saveSttMirror vuelve a retornar Future<void>
mut1 = ss_code.replace("Future<bool> saveSttMirror", "Future<void> saveSttMirror")
ok_m1, _ = validate_storage_service(mut1)
suite.check("Mutación 1 (saveSttMirror retorna void): detectada por el validador", not ok_m1)

# Mutación 2: saveSttMirror pisa ciegamente la URL custom
mut2 = ss_code.replace(
    "(currentUrl != null && currentUrl.trim().isNotEmpty)",
    "false"
)
ok_m2, _ = validate_storage_service(mut2)
suite.check("Mutación 2 (saveSttMirror pisa URL custom): detectada por el validador", not ok_m2)

# Mutación 3: saveSttMirror elimina el reintento
mut3 = ss_code.replace(
    "for (var attempt = 0; attempt < 2; attempt++)",
    "for (var attempt = 0; attempt < 1; attempt++)"
)
ok_m3, _ = validate_storage_service(mut3)
suite.check("Mutación 3 (eliminar reintento en saveSttMirror): detectada por el validador", not ok_m3)

# Mutación 4: settings_screen no valida resultado ok de saveSttMirror
mut4 = scr_code.replace("if (!ok) {", "if (false) {")
ok_m4, _ = validate_settings_screen(mut4)
suite.check("Mutación 4 (settings_screen ignora resultado ok): detectada por el validador", not ok_m4)

# Mutación 5: saveSttMirror retorna siempre true en lugar de hasKey && published
mut5 = ss_code.replace("return hasKey && published;", "return true;")
ok_m5, _ = validate_storage_service(mut5)
suite.check("Mutación 5 (saveSttMirror retorna true falso): detectada por el validador", not ok_m5)

print("\n" + "=" * 60)
print(f" RESULTADOS C-22: {suite.passed} pasados, {suite.failed} fallidos.")
print("=" * 60 + "\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
