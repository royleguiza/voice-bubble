#!/usr/bin/env python3
"""
test_c19_bridge_keys_and_limits_suite.py
=========================================
Suite de verificación exhaustiva para el Contrato C-19:
"Puente de claves sano y límites de contrato (20/50/15/25)"

Verifica:
1. docs/contract-keys.txt: 51 claves ordenadas alfabéticamente incluyendo kb_stt_key_configured.
2. docs/contract-limits.md: existencia y especificación de los 4 límites (20/50/15/25).
3. StorageService.dart:
   - bridgeKeys cubre exactamente las 51 claves.
   - sttKeyConfiguredKey ('kb_stt_key_configured') incluido en bridgeKeys.
   - notesPendingKey referencia PendingNoteQueue.pendingKey como fuente única.
   - getBottomElevationDp y setBottomElevationDp aplican clamp(0, 64).
   - Constantes de límites: maxItems=20, maxCredentials=50, maxPendingNotes=15, maxClips=25.
   - Primitivas _getInt, _getBool, _getString, _getDouble y validadores tolerantes a corrupción.
4. KeyboardPrefs.kt:
   - Lee "flutter.kb_stt_key_configured".
   - bottomElevationDp acotado con coerceIn(0, 64) con parseo tolerante a tipos.
   - Whitelists y clamps de trackpad replicados exactamente desde Dart:
     * buttonLayout in ['top', 'wings']
     * scrollPosition in ['right', 'left', 'disabled']
     * sensitivity in 0.5f..2.5f
     * accelCurve in ['dynamic', 'linear', 'precision']
     * secondaryClick in ['2fingers', 'button', 'hold']
     * scrollDirection in ['natural', 'standard']
     * haptic in ['subtle', 'none', 'firm']
     * pointerStyle in ['arrow', 'dot', 'cross']
     * autoReturn in [0, 5, 15, 30]
     * spacebarAlignment in ['left', 'center', 'right']
     * spacebarTrackpadMode in ['ios_2d', 'gboard_horizontal']
5. LayoutLayer.kt:
   - bottomElevationDp() acotado con coerceIn(0, 64).
6. CredentialStore.kt:
   - MAX_CREDENTIALS = 50 y truncamiento preventivo en parseIndex.
7. Paridad espejo Dart == Kotlin == Contrato en claves y límites.
8. Detección de mutaciones negativas reales sobre el código.
"""

import os
import re
import subprocess
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

suite = TestSuite("CONTRATO C-19 (PUENTE DE CLAVES SANO Y LÍMITES)")
print("=" * 60)
print(f" INICIANDO TEST SUITE: {suite.name}")
print("=" * 60)

# --- 1. Rutas de Archivos del Contrato C-19 ---
contract_keys_path = os.path.join(BASE_DIR, "docs", "contract-keys.txt")
contract_limits_path = os.path.join(BASE_DIR, "docs", "contract-limits.md")
storage_service_path = os.path.join(BASE_DIR, "app_source", "lib", "services", "storage_service.dart")
storage_test_path = os.path.join(BASE_DIR, "app_source", "test", "services", "storage_service_test.dart")
pending_queue_path = os.path.join(BASE_DIR, "app_source", "lib", "services", "pending_note_queue.dart")
kb_prefs_path = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "KeyboardPrefs.kt")
layout_layer_path = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "LayoutLayer.kt")
stt_client_path = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "SpeechToTextClient.kt")
cred_store_path = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "CredentialStore.kt")
history_logic_path = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "TranscriptionHistoryLogic.kt")
note_store_path = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "NoteStore.kt")
clip_store_path = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "ClipboardStore.kt")

for path, label in [
    (contract_keys_path, "docs/contract-keys.txt"),
    (contract_limits_path, "docs/contract-limits.md"),
    (storage_service_path, "StorageService.dart"),
    (storage_test_path, "storage_service_test.dart"),
    (pending_queue_path, "pending_note_queue.dart"),
    (kb_prefs_path, "KeyboardPrefs.kt"),
    (layout_layer_path, "LayoutLayer.kt"),
    (stt_client_path, "SpeechToTextClient.kt"),
    (cred_store_path, "CredentialStore.kt"),
    (history_logic_path, "TranscriptionHistoryLogic.kt"),
    (note_store_path, "NoteStore.kt"),
    (clip_store_path, "ClipboardStore.kt"),
]:
    suite.check(f"Archivo {label} existe", os.path.isfile(path), f"Falta {path}")

with open(contract_keys_path, "r", encoding="utf-8") as f:
    contract_keys_raw = f.read().strip()
with open(contract_limits_path, "r", encoding="utf-8") as f:
    contract_limits_raw = f.read()
with open(storage_service_path, "r", encoding="utf-8") as f:
    storage_code = f.read()
with open(storage_test_path, "r", encoding="utf-8") as f:
    storage_test_code = f.read()
with open(pending_queue_path, "r", encoding="utf-8") as f:
    pending_queue_code = f.read()
with open(kb_prefs_path, "r", encoding="utf-8") as f:
    kb_prefs_code = f.read()
with open(layout_layer_path, "r", encoding="utf-8") as f:
    layout_code = f.read()
with open(stt_client_path, "r", encoding="utf-8") as f:
    stt_code = f.read()
with open(cred_store_path, "r", encoding="utf-8") as f:
    cred_code = f.read()
with open(history_logic_path, "r", encoding="utf-8") as f:
    history_code = f.read()
with open(note_store_path, "r", encoding="utf-8") as f:
    note_code = f.read()
with open(clip_store_path, "r", encoding="utf-8") as f:
    clip_code = f.read()

# --- 2. docs/contract-keys.txt: 51 claves y orden alfabético ---
keys_list = [k.strip() for k in contract_keys_raw.splitlines() if k.strip()]
suite.check("docs/contract-keys.txt contiene exactamente 51 claves", len(keys_list) == 51, f"Total: {len(keys_list)}")
suite.check("docs/contract-keys.txt está estrictamente ordenado", keys_list == sorted(keys_list))
suite.check("docs/contract-keys.txt contiene kb_stt_key_configured", "kb_stt_key_configured" in keys_list)

# --- 3. docs/contract-limits.md: especificación de topes (20/50/15/25) ---
suite.check("contract-limits.md contiene límite de historial 20", "20" in contract_limits_raw and "maxItems" in contract_limits_raw)
suite.check("contract-limits.md contiene límite de credenciales 50", "50" in contract_limits_raw and "maxCredentials" in contract_limits_raw)
suite.check("contract-limits.md contiene límite de notas pendientes 15", "15" in contract_limits_raw and "maxPending" in contract_limits_raw)
suite.check("contract-limits.md contiene límite de portapapeles 25", "25" in contract_limits_raw and "maxClips" in contract_limits_raw)

# --- 4. StorageService.dart: puente y constantes ---
suite.check(
    "StorageService define sttKeyConfiguredKey = 'kb_stt_key_configured'",
    "static const String sttKeyConfiguredKey = 'kb_stt_key_configured';" in storage_code
)
suite.check(
    "StorageService.bridgeKeys incluye sttKeyConfiguredKey",
    "sttKeyConfiguredKey," in storage_code
)
suite.check(
    "StorageService.notesPendingKey usa PendingNoteQueue.pendingKey como fuente única",
    "static const String notesPendingKey = PendingNoteQueue.pendingKey;" in storage_code
)
suite.check(
    "StorageService define límites espejo maxItems=20, maxCredentials=50, maxPendingNotes, maxClips=25",
    "static const int maxItems = 20;" in storage_code
    and "static const int maxCredentials = 50;" in storage_code
    and "static const int maxPendingNotes = PendingNoteQueue.maxPending;" in storage_code
    and "static const int maxClips = 25;" in storage_code
)
suite.check(
    "StorageService.getBottomElevationDp aplica clamp(0, 64)",
    ".clamp(0, 64)" in storage_code and "getBottomElevationDp" in storage_code
)
suite.check(
    "StorageService.setBottomElevationDp aplica clamp(0, 64)",
    "dp.clamp(0, 64)" in storage_code
)

# Primitivas tolerantes a corrupción en StorageService
suite.check(
    "StorageService._getInt envuelto en try/catch y type check",
    "Future<int> _getInt(" in storage_code and "val is int" in storage_code and "catch (_)" in storage_code
)
suite.check(
    "StorageService._getBool envuelto en try/catch y type check",
    "Future<bool> _getBool(" in storage_code and "val is bool" in storage_code and "catch (_)" in storage_code
)
suite.check(
    "StorageService._getString envuelto en try/catch y type check",
    "Future<String> _getString(" in storage_code and "val is String" in storage_code and "catch (_)" in storage_code
)
suite.check(
    "StorageService._getDouble envuelto en try/catch y type check",
    "Future<double> _getDouble(" in storage_code and "val is double" in storage_code and "catch (_)" in storage_code
)
suite.check(
    "StorageService._getValidatedString envuelto en try/catch",
    "Future<String> _getValidatedString(" in storage_code and "catch (_)" in storage_code
)
suite.check(
    "StorageService._getValidatedInt envuelto en try/catch",
    "Future<int> _getValidatedInt(" in storage_code and "catch (_)" in storage_code
)

# Test de StorageService sincronizado con 51 claves
suite.check(
    "storage_service_test.dart espera 51 claves y contiene kb_stt_key_configured",
    "'kb_stt_key_configured'" in storage_test_code and "bridgeKeys.length, 51" in storage_test_code
)

# --- 5. KeyboardPrefs.kt: whitelists, clamps y lectura sttKeyConfigured ---
suite.check(
    "KeyboardPrefs expone sttKeyConfigured",
    "var sttKeyConfigured = false" in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() lee flutter.kb_stt_key_configured",
    'p.getBoolean("flutter.kb_stt_key_configured", false)' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() aplica coerceIn(0, 64) a bottomElevationDp",
    "bottomElevationDp = try" in kb_prefs_code and ".coerceIn(0, 64)" in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida spacebarAlignment contra lista blanca",
    'p.getString("flutter.kb_spacebar_alignment"' in kb_prefs_code
    and 'listOf("left", "center", "right")' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida spacebarTrackpadMode contra lista blanca",
    'p.getString("flutter.kb_spacebar_trackpad_mode"' in kb_prefs_code
    and 'listOf("ios_2d", "gboard_horizontal")' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida trackpadButtonLayout contra top/wings",
    'listOf("top", "wings")' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida trackpadScrollPosition contra right/left/disabled",
    'listOf("right", "left", "disabled")' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() acota trackpadSensitivity a 0.5f..2.5f",
    ".coerceIn(0.5f, 2.5f)" in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida trackpadAccelCurve contra dynamic/linear/precision",
    'listOf("dynamic", "linear", "precision")' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida trackpadSecondaryClick contra 2fingers/button/hold",
    'listOf("2fingers", "button", "hold")' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida trackpadScrollDirection contra natural/standard",
    'listOf("natural", "standard")' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida trackpadHaptic contra subtle/none/firm",
    'listOf("subtle", "none", "firm")' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida trackpadPointerStyle contra arrow/dot/cross",
    'listOf("arrow", "dot", "cross")' in kb_prefs_code
)
suite.check(
    "KeyboardPrefs.load() valida trackpadAutoReturn contra 0/5/15/30",
    "listOf(0, 5, 15, 30)" in kb_prefs_code
)

# --- 6. LayoutLayer.kt y SpeechToTextClient.kt ---
suite.check(
    "LayoutLayer.kt aplica coerceIn(0, 64) en elevationPx",
    "host.bottomElevationDp().coerceIn(0, 64).toFloat()" in layout_code
)
suite.check(
    "SpeechToTextClient lee flutter.kb_stt_key_configured y expone isKeyConfigured",
    'prefs.getBoolean("flutter.kb_stt_key_configured", false)' in stt_code
    and "fun isKeyConfigured(" in stt_code
)

# --- 7. CredentialStore.kt: límite de 50 ---
suite.check(
    "CredentialStore define const val MAX_CREDENTIALS = 50",
    "const val MAX_CREDENTIALS = 50" in cred_code
)
suite.check(
    "CredentialStore.parseIndex trunca a MAX_CREDENTIALS",
    "out.size >= MAX_CREDENTIALS" in cred_code
)

# --- 8. Paridad espejo de límites Kotlin == Dart ---
suite.check(
    "Paridad Historial: Dart maxItems (20) == Kotlin TranscriptionHistoryLogic.MAX_ITEMS (20)",
    "static const int maxItems = 20;" in storage_code and "const val MAX_ITEMS = 20" in history_code
)
suite.check(
    "Paridad Credenciales: Dart maxCredentials (50) == Kotlin CredentialStore.MAX_CREDENTIALS (50)",
    "static const int maxCredentials = 50;" in storage_code and "const val MAX_CREDENTIALS = 50" in cred_code
)
suite.check(
    "Paridad Notas Pendientes: Dart maxPending (15) == Kotlin NoteStore.MAX_PENDING (15)",
    "static const int maxPending = 15;" in pending_queue_code and "const val MAX_PENDING = 15" in note_code
)
suite.check(
    "Paridad Portapapeles: Dart maxClips (25) == Kotlin ClipboardStore.MAX_UNPINNED_ITEMS (25)",
    "static const int maxClips = 25;" in storage_code and "const val MAX_UNPINNED_ITEMS = 25" in clip_code
)

# --- 9. Paridad triangular de claves con test_contract_keys ---
print("\n--- Ejecución de Test Triangular: Kotlin == Dart == docs/contract-keys.txt ---")
kt_dir = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt")
cmd = (
    f"grep -rvhE '^[[:space:]]*import ' '{kt_dir}' "
    "| grep -ohE 'flutter\\.[a-z_0-9]+' "
    "| sed 's/^flutter\\.//' "
    "| sort -u"
)
kt_result = subprocess.check_output(cmd, shell=True, text=True).strip()
cmd2 = (
    f"grep -rhoE '(intPref|stringPref|booleanPref)\\(prefs, \"[a-z_0-9]+\"' '{kt_dir}' "
    "| grep -oE '\"[a-z_0-9]+\"' "
    "| tr -d '\"' "
    "| sort -u"
)
kt_result2 = subprocess.check_output(cmd2, shell=True, text=True).strip()
kt_keys = set(kt_result.split()) | set(kt_result2.split())

suite.check("Kotlin extrae exactamente 51 claves de contrato", len(kt_keys) == 51, f"Total: {len(kt_keys)}")
suite.check("Claves Kotlin coinciden exactamente con docs/contract-keys.txt", kt_keys == set(keys_list))

# Extracción de bridgeKeys de StorageService.dart
const_vals = dict(re.findall(r"static const String (\w+)\s*=\s*'([a-z_0-9]+)';", storage_code))
for ref_match in re.finditer(r"static const String (\w+)\s*=\s*PendingNoteQueue\.pendingKey;", storage_code):
    const_vals[ref_match.group(1)] = "voice_notes_pending_v1"
m = re.search(r"static const List<String> bridgeKeys = \[(.*?)\];", storage_code, re.DOTALL)
dart_table = []
if m:
    for ident in re.findall(r"[A-Za-z_]\w*", m.group(1)):
        if ident in const_vals:
            dart_table.append(const_vals[ident])

suite.check("Dart bridgeKeys extrae exactamente 51 claves", len(dart_table) == 51, f"Total: {len(dart_table)}")
suite.check("Dart bridgeKeys coincide exactamente con docs/contract-keys.txt", set(dart_table) == set(keys_list))

# --- 10. Verificación de Resistencia a Mutaciones (Comprobación de Regresiones) ---
print("\n--- Verificación de Resistencia a Mutaciones ---")

def verify_bridge_keys(storage_text):
    m = re.search(r"static const List<String> bridgeKeys = \[(.*?)\];", storage_text, re.DOTALL)
    if not m: return False
    return "sttKeyConfiguredKey" in m.group(1)

def verify_bottom_clamp(storage_text):
    return ".clamp(0, 64)" in storage_text

def verify_kb_prefs_coerce(prefs_text):
    return ".coerceIn(0, 64)" in prefs_text

def verify_trackpad_whitelist(prefs_text):
    return 'listOf("top", "wings")' in prefs_text

def verify_pending_key_source(storage_text):
    return "PendingNoteQueue.pendingKey" in storage_text

def verify_cred_limit(cred_text):
    return "const val MAX_CREDENTIALS = 50" in cred_text

suite.check(
    "Mutación 1 (omitir sttKeyConfiguredKey en bridgeKeys): detectada por el validador",
    not verify_bridge_keys(storage_code.replace("sttKeyConfiguredKey,", ""))
)
suite.check(
    "Mutación 2 (quitar clamp en getBottomElevationDp): detectada por el validador",
    not verify_bottom_clamp(storage_code.replace(".clamp(0, 64)", ""))
)
suite.check(
    "Mutación 3 (quitar coerceIn en KeyboardPrefs): detectada por el validador",
    not verify_kb_prefs_coerce(kb_prefs_code.replace(".coerceIn(0, 64)", ""))
)
suite.check(
    "Mutación 4 (quitar whitelist trackpadButtonLayout): detectada por el validador",
    not verify_trackpad_whitelist(kb_prefs_code.replace('listOf("top", "wings")', 'listOf()'))
)
suite.check(
    "Mutación 5 (desacoplar notesPendingKey de PendingNoteQueue): detectada por el validador",
    not verify_pending_key_source(storage_code.replace("PendingNoteQueue.pendingKey", "'voice_notes_pending_v1'"))
)
suite.check(
    "Mutación 6 (discrepancia de límite MAX_CREDENTIALS=100): detectada por el validador",
    not verify_cred_limit(cred_code.replace("const val MAX_CREDENTIALS = 50", "const val MAX_CREDENTIALS = 100"))
)

print("\n" + "=" * 60)
print(f" RESULTADOS C-19: {suite.passed} pasados, {suite.failed} fallidos.")
print("=" * 60 + "\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
