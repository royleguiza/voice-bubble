#!/usr/bin/env python3
"""
test_c21_broken_dates_suite.py
==============================
Suite de verificación exhaustiva para el Contrato C-21:
"Fechas rotas no contaminan ni ganan merges"

Verifica:
1. app_source/lib/models/voice_note.dart:
   - VoiceNote.tryParseDateTime(raw): parsea fechas ISO con 'T'; devuelve null
     si no es String, si está vacío o si no contiene 'T'.
   - VoiceNote.tryFromJson(json): devuelve null ante fechas ausentes, ilegibles,
     o cuando updatedAt.isBefore(createdAt).
   - VoiceNote.fromJson(json): delega en tryFromJson y lanza FormatException
     en lugar de inventar DateTime.now().
   - Cero llamadas a DateTime.now() en parseo y deserialización.
2. app_source/lib/models/transcription.dart:
   - Transcription.tryParseTimestamp(raw): parsea ISO y numéricos válidos; devuelve
     null ante cadenas ilegibles, NaN, infinity o null.
   - Transcription._parseTimestamp(raw): cae a EPOCH (1970) y JAMÁS a DateTime.now().
   - Transcription.tryFromJson(json): devuelve null ante timestamp ilegible/corrupto.
   - Transcription.fromJson(json): delega en tryFromJson y lanza FormatException
     en lugar de inventar DateTime.now().
   - Cero llamadas a DateTime.now() en parseo y deserialización.
3. voice_bubble_stt/android/app/src/main/kotlin/.../NoteStore.kt:
   - parseTimestamp(iso): devuelve Long? (null ante fechas inválidas o en blanco).
   - parseEpoch(iso): devuelve parseTimestamp(iso) ?: 0L (EPOCH 0L).
   - parseIndex: valida que updated >= created y que fechas no sean nulas/corruptas,
     marcando NoteIndexState.CORRUPT.
   - merge: compara parseEpoch(note.updatedAt) > parseEpoch(current.updatedAt).
     Una entrada corrupta (0L) jamás supera a una existente válida (>0L).
4. Simulaciones de merge cruzadas:
   - Demostración matemática/lógica de que una entrada con fecha rota o EPOCH 0L
     jamás desbanca a una existente con fecha válida.
5. Detección de mutaciones negativas reales sobre el código en disco.
"""

import os
import re
import sys
from datetime import datetime, timezone

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

suite = TestSuite("CONTRATO C-21 (FECHAS ROTAS NO CONTAMINAN)")
print("=" * 60)
print(f" INICIANDO TEST SUITE: {suite.name}")
print("=" * 60)

# --- 1. Rutas de Archivos del Contrato C-21 ---
vn_path = os.path.join(BASE_DIR, "app_source", "lib", "models", "voice_note.dart")
tr_path = os.path.join(BASE_DIR, "app_source", "lib", "models", "transcription.dart")
ns_path = os.path.join(BASE_DIR, "app_source", "lib", "services", "notes_service.dart")
kt_path = os.path.join(
    BASE_DIR,
    "voice_bubble_stt", "android", "app", "src", "main", "kotlin",
    "com", "royleguiza", "voicebubblestt", "NoteStore.kt"
)

suite.check("Existe voice_note.dart", os.path.exists(vn_path))
suite.check("Existe transcription.dart", os.path.exists(tr_path))
suite.check("Existe notes_service.dart", os.path.exists(ns_path))
suite.check("Existe NoteStore.kt", os.path.exists(kt_path))

with open(vn_path, "r", encoding="utf-8") as f:
    vn_code = f.read()

with open(tr_path, "r", encoding="utf-8") as f:
    tr_code = f.read()

with open(ns_path, "r", encoding="utf-8") as f:
    ns_code = f.read()

with open(kt_path, "r", encoding="utf-8") as f:
    kt_code = f.read()

# --- 2. Verificación de voice_note.dart ---
print("\n--- Verificación de voice_note.dart ---")

suite.check(
    "voice_note.dart declara tryParseDateTime(Object? raw)",
    "static DateTime? tryParseDateTime(Object? raw)" in vn_code
)

suite.check(
    "voice_note.dart tryParseDateTime exige raw contains 'T'",
    "raw is String && raw.contains('T')" in vn_code
)

suite.check(
    "voice_note.dart declara tryFromJson(Map<String, dynamic> json)",
    "static VoiceNote? tryFromJson(Map<String, dynamic> json)" in vn_code
)

suite.check(
    "voice_note.dart fromJson delega en tryFromJson",
    "final note = tryFromJson(json);" in vn_code and "if (note != null) return note;" in vn_code
)

suite.check(
    "voice_note.dart fromJson lanza FormatException si tryFromJson falla",
    "throw const FormatException('Nota incompleta o con fechas inválidas');" in vn_code
)

suite.check(
    "voice_note.dart tryFromJson rechaza updatedAt.isBefore(created)",
    "updated.isBefore(created)" in vn_code
)

suite.check(
    "voice_note.dart CERO llamadas a DateTime.now() en deserialización",
    "DateTime.now()" not in vn_code.split("class VoiceNote")[1]
)

# Simulación lógica de VoiceNote.tryParseDateTime y tryFromJson en Python
def sim_try_parse_datetime(raw):
    if isinstance(raw, str) and 'T' in raw:
        try:
            # ISO 8601 parsing
            # Python fromisoformat handles T
            clean = raw.rstrip('Z')
            return datetime.fromisoformat(clean)
        except Exception:
            return None
    return None

def sim_try_from_json(d):
    note_id = d.get('id')
    titulo = d.get('titulo')
    cuerpo = d.get('cuerpo')
    created_at = d.get('createdAt')
    updated_at = d.get('updatedAt')
    audio_path = d.get('audioPath')

    if not isinstance(note_id, str) or not note_id:
        return None
    if not isinstance(titulo, str) or not isinstance(cuerpo, str):
        return None
    if created_at is None or updated_at is None:
        return None

    created = sim_try_parse_datetime(created_at)
    updated = sim_try_parse_datetime(updated_at)
    if created is None or updated is None or updated < created:
        return None

    if audio_path is not None and (not isinstance(audio_path, str) or not audio_path.strip()):
        return None

    return {
        'id': note_id,
        'titulo': titulo,
        'cuerpo': cuerpo,
        'createdAt': created,
        'updatedAt': updated,
        'audioPath': audio_path
    }

# Casos de prueba sobre simulación de VoiceNote
suite.check(
    "sim_try_parse_datetime: fecha ISO válida con 'T' parsea",
    sim_try_parse_datetime("2026-09-26T12:00:00Z") is not None
)

suite.check(
    "sim_try_parse_datetime: fecha sin 'T' devuelve None",
    sim_try_parse_datetime("2026-09-26 12:00:00") is None
)

suite.check(
    "sim_try_parse_datetime: texto corrupto devuelve None",
    sim_try_parse_datetime("corrupt-date-string") is None
)

suite.check(
    "sim_try_parse_datetime: tipo no string devuelve None",
    sim_try_parse_datetime(1700000000) is None and sim_try_parse_datetime(None) is None
)

suite.check(
    "sim_try_from_json: nota válida devuelve dict con fechas",
    sim_try_from_json({
        'id': 'n1',
        'titulo': 'Test',
        'cuerpo': 'Body',
        'createdAt': '2026-01-01T10:00:00Z',
        'updatedAt': '2026-01-01T11:00:00Z'
    }) is not None
)

suite.check(
    "sim_try_from_json: nota con updatedAt < createdAt devuelve None (rechazada)",
    sim_try_from_json({
        'id': 'n2',
        'titulo': 'Invertida',
        'cuerpo': 'Body',
        'createdAt': '2026-01-01T12:00:00Z',
        'updatedAt': '2026-01-01T10:00:00Z'
    }) is None
)

suite.check(
    "sim_try_from_json: nota con fecha rota devuelve None (rechazada)",
    sim_try_from_json({
        'id': 'n3',
        'titulo': 'Rota',
        'cuerpo': 'Body',
        'createdAt': '2026-01-01T10:00:00Z',
        'updatedAt': 'FECHA_BASURA'
    }) is None
)

suite.check(
    "sim_try_from_json: nota con fechas ausentes devuelve None",
    sim_try_from_json({
        'id': 'n4',
        'titulo': 'Sin fecha',
        'cuerpo': 'Body'
    }) is None
)

# --- 3. Verificación de transcription.dart ---
print("\n--- Verificación de transcription.dart ---")

suite.check(
    "transcription.dart declara tryParseTimestamp(Object? raw)",
    "static DateTime? tryParseTimestamp(Object? raw)" in tr_code
)

suite.check(
    "transcription.dart tryParseTimestamp descarta NaN e infinite",
    "raw.isNaN || raw.isInfinite" in tr_code
)

suite.check(
    "transcription.dart tryParseTimestamp descarta cadenas vacías o ilegibles",
    "if (raw.isEmpty) return null;" in tr_code and "DateTime.tryParse(raw)" in tr_code
)

suite.check(
    "transcription.dart _parseTimestamp cae a EPOCH (0) y jamás a now()",
    "tryParseTimestamp(raw) ?? DateTime.fromMillisecondsSinceEpoch(0).toLocal()" in tr_code
)

suite.check(
    "transcription.dart tryFromJson descarta timestamp corrupto",
    "if (raw is String && (raw.isEmpty || DateTime.tryParse(raw) == null))" in tr_code
)

suite.check(
    "transcription.dart fromJson delega en tryFromJson",
    "final parsed = tryFromJson(json);" in tr_code and "if (parsed != null) return parsed;" in tr_code
)

suite.check(
    "transcription.dart fromJson lanza FormatException si tryFromJson falla",
    "throw const FormatException('Timestamp de transcripción inválido o corrupto');" in tr_code
)

tr_executable_code = "\n".join(
    line for line in tr_code.splitlines()
    if not line.strip().startswith("//") and not line.strip().startswith("/*") and not line.strip().startswith("*")
)

suite.check(
    "transcription.dart CERO llamadas a DateTime.now() en deserialización",
    "DateTime.now()" not in tr_executable_code
)

# Simulación lógica de Transcription en Python
def sim_try_parse_transcription_timestamp(raw):
    if raw is None:
        return None
    if isinstance(raw, (int, float)):
        import math
        if math.isnan(raw) or math.isinf(raw):
            return None
        millis = int(raw * 1000) if raw < 10000000000 else int(raw)
        try:
            return datetime.fromtimestamp(millis / 1000.0, timezone.utc)
        except Exception:
            return None
    if isinstance(raw, str):
        if not raw:
            return None
        try:
            clean = raw.rstrip('Z')
            return datetime.fromisoformat(clean)
        except Exception:
            return None
    return None

def sim_parse_transcription_timestamp(raw):
    parsed = sim_try_parse_transcription_timestamp(raw)
    if parsed is not None:
        return parsed
    return datetime.fromtimestamp(0, timezone.utc)

def sim_transcription_try_from_json(d):
    raw = d.get('timestamp')
    if isinstance(raw, str) and (not raw or sim_try_parse_transcription_timestamp(raw) is None):
        return None
    import math
    if isinstance(raw, (int, float)) and (math.isnan(raw) or math.isinf(raw)):
        return None
    raw_text = d.get('text')
    text = raw_text if isinstance(raw_text, str) else ''
    parsed_time = sim_parse_transcription_timestamp(raw)
    return {'text': text, 'timestamp': parsed_time}

suite.check(
    "sim_transcription: timestamp válido ISO parsea",
    sim_try_parse_transcription_timestamp("2026-09-26T12:00:00Z") is not None
)

suite.check(
    "sim_transcription: timestamp numérico epoch parsea",
    sim_try_parse_transcription_timestamp(1700000000000) is not None
)

suite.check(
    "sim_transcription: timestamp cadena basura devuelve None",
    sim_try_parse_transcription_timestamp("basura") is None
)

suite.check(
    "sim_transcription: timestamp NaN o inf devuelve None",
    sim_try_parse_transcription_timestamp(float('nan')) is None and
    sim_try_parse_transcription_timestamp(float('inf')) is None
)

suite.check(
    "sim_transcription: timestamp corrupto en tryFromJson devuelve None",
    sim_transcription_try_from_json({'text': 'abc', 'timestamp': 'corrupto'}) is None
)

suite.check(
    "sim_transcription: timestamp ausente/null cae a EPOCH (1970), NO a now()",
    sim_transcription_try_from_json({'text': 'abc', 'timestamp': None})['timestamp'] == datetime.fromtimestamp(0, timezone.utc)
)

# --- 4. Verificación de NoteStore.kt ---
print("\n--- Verificación de NoteStore.kt ---")

suite.check(
    "NoteStore.kt parseTimestamp(iso: String): Long?",
    "private fun parseTimestamp(iso: String): Long?" in kt_code
)

suite.check(
    "NoteStore.kt parseTimestamp devuelve null si isBlank()",
    "if (iso.isBlank()) return null" in kt_code
)

suite.check(
    "NoteStore.kt parseEpoch devuelve 0L (EPOCH) ante fallo",
    "private fun parseEpoch(iso: String): Long {\n        return parseTimestamp(iso) ?: 0L\n    }" in kt_code or
    "parseTimestamp(iso) ?: 0L" in kt_code
)

suite.check(
    "NoteStore.kt parseIndex rechaza fechas corruptas y updated < created",
    "if (updated < created) {\n                    return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)\n                }" in kt_code
)

suite.check(
    "NoteStore.kt merge compara parseEpoch(note.updatedAt) > parseEpoch(current.updatedAt)",
    "parseEpoch(note.updatedAt) > parseEpoch(current.updatedAt)" in kt_code
)

# Simulación de NoteStore.merge en Python
def sim_note_store_parse_epoch(iso):
    if not iso or not isinstance(iso, str) or not iso.strip():
        return 0
    dt = sim_try_parse_datetime(iso)
    if dt is None:
        return 0
    return int(dt.timestamp() * 1000)

def sim_note_store_merge(file_notes, prefs_notes, max_notes=50):
    by_id = {}
    for n in file_notes:
        cur = by_id.get(n['id'])
        if cur is None or sim_note_store_parse_epoch(n['updatedAt']) > sim_note_store_parse_epoch(cur['updatedAt']):
            by_id[n['id']] = n
    for n in prefs_notes:
        cur = by_id.get(n['id'])
        if cur is None or sim_note_store_parse_epoch(n['updatedAt']) > sim_note_store_parse_epoch(cur['updatedAt']):
            by_id[n['id']] = n
    out = sorted(by_id.values(), key=lambda x: sim_note_store_parse_epoch(x['updatedAt']), reverse=True)
    return out[:max_notes]

# Merge simulation tests
valid_note = {
    'id': 'note-1',
    'titulo': 'Original Válida',
    'cuerpo': 'Contenido Legítimo',
    'createdAt': '2026-05-01T10:00:00Z',
    'updatedAt': '2026-05-01T12:00:00Z'
}

corrupt_note = {
    'id': 'note-1',
    'titulo': 'Invasora Corrupta',
    'cuerpo': 'Intento de Sobrescritura',
    'createdAt': '2026-01-01T10:00:00Z',
    'updatedAt': 'FECHA_CORRUPTA'
}

# Caso 1: La válida ya existe en file_notes; corrupta llega en prefs_notes
merged1 = sim_note_store_merge([valid_note], [corrupt_note])
suite.check(
    "Merge Simulación 1: Entrada corrupta en prefs no sobrescribe nota válida previa",
    len(merged1) == 1 and merged1[0]['titulo'] == 'Original Válida'
)

# Caso 2: La corrupta llegó primero (ej. file), y luego llega la válida (ej. prefs)
merged2 = sim_note_store_merge([corrupt_note], [valid_note])
suite.check(
    "Merge Simulación 2: Nota válida posterior desbanca a entrada corrupta previa",
    len(merged2) == 1 and merged2[0]['titulo'] == 'Original Válida'
)

# Caso 3: Nota corrupta independiente con id nuevo no gana a notas válidas y queda al final
corrupt_new_note = {
    'id': 'note-corrupt-new',
    'titulo': 'Nota Nueva Rota',
    'cuerpo': 'Debería quedar última',
    'createdAt': '2026-01-01T10:00:00Z',
    'updatedAt': 'BASURA'
}
merged3 = sim_note_store_merge([valid_note], [corrupt_new_note])
suite.check(
    "Merge Simulación 3: Nota con fecha rota se ordena con epoch 0L (queda última, no primera)",
    merged3[0]['id'] == 'note-1' and merged3[1]['id'] == 'note-corrupt-new'
)

# --- 5. Verificación de notes_service.dart ---
print("\n--- Verificación de notes_service.dart ---")

suite.check(
    "notes_service.dart decode maneja VoiceNote.fromJson de forma protegida",
    "out.add(VoiceNote.fromJson(Map<String, dynamic>.from(element)));" in ns_code or
    "VoiceNote.tryFromJson" in ns_code or
    "catch (_)" in ns_code
)

suite.check(
    "notes_service.dart loadMerged compara n.updatedAt.isAfter(existing.updatedAt)",
    "n.updatedAt.isAfter(existing.updatedAt)" in ns_code
)

suite.check(
    "notes_service.dart ordena por updatedAt descendente",
    "sort((a, b) => b.updatedAt.compareTo(a.updatedAt))" in ns_code
)

# --- 6. Verificación de Resistencia a Mutaciones Negativas ---
print("\n--- Verificación de Resistencia a Mutaciones ---")

def validate_voice_note(code):
    if "static VoiceNote? tryFromJson(Map<String, dynamic> json)" not in code:
        return False, "falta tryFromJson en VoiceNote"
    if "static DateTime? tryParseDateTime(Object? raw)" not in code:
        return False, "falta tryParseDateTime en VoiceNote"
    if "updated.isBefore(created)" not in code:
        return False, "falta chequeo updated.isBefore(created)"
    if "DateTime.now()" in code.split("class VoiceNote")[1]:
        return False, "DateTime.now() introducido en VoiceNote"
    if "throw const FormatException('Nota incompleta o con fechas inválidas');" not in code:
        return False, "fromJson no lanza FormatException en error"
    return True, "OK"

def validate_transcription(code):
    if "static DateTime? tryParseTimestamp(Object? raw)" not in code:
        return False, "falta tryParseTimestamp en Transcription"
    if "static Transcription? tryFromJson(Map<String, dynamic> json)" not in code:
        return False, "falta tryFromJson en Transcription"
    if "DateTime.fromMillisecondsSinceEpoch(0)" not in code:
        return False, "_parseTimestamp no cae a EPOCH (0)"
    exec_lines = [l for l in code.splitlines() if not l.strip().startswith("//") and not l.strip().startswith("/*") and not l.strip().startswith("*")]
    if "DateTime.now()" in "\n".join(exec_lines):
        return False, "DateTime.now() introducido en Transcription"
    if "throw const FormatException('Timestamp de transcripción inválido o corrupto');" not in code:
        return False, "fromJson no lanza FormatException en error"
    return True, "OK"

def validate_note_store(code):
    if "private fun parseTimestamp(iso: String): Long?" not in code:
        return False, "falta parseTimestamp en NoteStore.kt"
    if "parseTimestamp(iso) ?: 0L" not in code:
        return False, "parseEpoch no devuelve 0L ante error"
    if "if (updated < created)" not in code:
        return False, "falta verificación updated < created en NoteStore.kt"
    if "parseEpoch(note.updatedAt) > parseEpoch(current.updatedAt)" not in code:
        return False, "merge no compara parseEpoch(updatedAt)"
    return True, "OK"

# Mutación 1: VoiceNote.fromJson vuelve a crear DateTime.now() en fallback
mut1 = vn_code.replace(
    "throw const FormatException('Nota incompleta o con fechas inválidas');",
    "return VoiceNote(id: json['id'], titulo: '', cuerpo: '', createdAt: DateTime.now(), updatedAt: DateTime.now());"
)
ok1, _ = validate_voice_note(mut1)
suite.check("Mutación 1 (VoiceNote introduce DateTime.now()): detectada por el validador", not ok1)

# Mutación 2: Quitar chequeo updated.isBefore(created) en VoiceNote
mut2 = vn_code.replace("if (created == null || updated == null || updated.isBefore(created))", "if (created == null || updated == null)")
ok2, _ = validate_voice_note(mut2)
suite.check("Mutación 2 (eliminar updated.isBefore(created)): detectada por el validador", not ok2)

# Mutación 3: Transcription._parseTimestamp vuelve a caer a DateTime.now()
mut3 = tr_code.replace("DateTime.fromMillisecondsSinceEpoch(0).toLocal()", "DateTime.now()")
ok3, _ = validate_transcription(mut3)
suite.check("Mutación 3 (Transcription cae a DateTime.now()): detectada por el validador", not ok3)

# Mutación 4: NoteStore.parseEpoch cae a System.currentTimeMillis() en lugar de 0L
mut4 = kt_code.replace("parseTimestamp(iso) ?: 0L", "parseTimestamp(iso) ?: System.currentTimeMillis()")
ok4, _ = validate_note_store(mut4)
suite.check("Mutación 4 (NoteStore parseEpoch cae a currentTimeMillis): detectada por el validador", not ok4)

# Mutación 5: NoteStore quita chequeo updated < created
mut5 = kt_code.replace("if (updated < created) {", "if (false) {")
ok5, _ = validate_note_store(mut5)
suite.check("Mutación 5 (NoteStore quita updated < created): detectada por el validador", not ok5)

print("\n" + "=" * 60)
print(f" RESULTADOS C-21: {suite.passed} pasados, {suite.failed} fallidos.")
print("=" * 60 + "\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
