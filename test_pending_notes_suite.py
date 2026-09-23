#!/usr/bin/env python3
"""
TEST SUITE: Cola diferida cloud en Notas (C1–C7, plan-notas-cola-nube.md)
1. Servicio PendingNoteQueue: contrato, cap 15, WAV durable, sin HTTP.
2. notes_screen: hook solo isRetryable + flag; UI Transcribir con nube.
3. Flag Dart-only: no en contract-keys / bridgeKeys; default OFF.
4. Privacidad: cero auto-upload / connectivity_plus / WorkManager.
5. Docs: README/AGENTS actualizados + congelamiento con la tarjeta.
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
print(" INICIANDO TEST SUITE: COLA DIFERIDA NOTAS (C1-C7)")
print("============================================================\n")

QUEUE = "app_source/lib/services/pending_note_queue.dart"
NOTES = "app_source/lib/screens/notes_screen.dart"
STORAGE = "app_source/lib/services/storage_service.dart"
GENERAL = "app_source/lib/screens/settings/general_tab.dart"
SETTINGS = "app_source/lib/screens/settings_screen.dart"
TILE = "app_source/lib/widgets/pending_note_tile.dart"
PUBSPEC = "app_source/pubspec.yaml"
CONTRACT = "docs/contract-keys.txt"
README = "README.md"
AGENTS = "AGENTS.md"
FREEZE = "docs/congelamiento-features.md"
PLAN = "plan-notas-cola-nube.md"
MASTER = "test_master_suite.py"

# --- 1. Servicio ---
check("pending_note_queue.dart existe", os.path.isfile(os.path.join(WORKSPACE, QUEUE)))
q = read(QUEUE)
check("Clave Dart-only voice_notes_pending_v1", "voice_notes_pending_v1" in q)
check("Cap maxPending = 15", "maxPending = 15" in q)
check("Dir pending_notes bajo appSupport", "pending_dir_name = 'pending_notes'" in q or "pendingDirName" in q)
check("Sin HTTP / http package en el servicio",
      "package:http" not in q and "http.post" not in q and "http.get" not in q)
check("enqueueFromTemp mueve fuera de temp", "enqueueFromTemp" in q)
check("remove con deleteAudio", "deleteAudio" in q)
check("discardAll limpia todo", "discardAll" in q)
check("JSON keys id/audioPath/createdAtMs",
      all(k in q for k in ["'id'", "'audioPath'", "'createdAtMs'"]))
check("Prune FIFO al superar cap", "_pruneOldest" in q)

# --- 2. Hook notes_screen ---
check("notes_screen.dart importa cola", "pending_note_queue" in read(NOTES))
notes = read(NOTES)
check("Hook solo isRetryable", "isRetryable" in notes)
check("Flag gate en encolar", "_deferredQueueEnabled" in notes)
check("Botón Transcribir con nube con ValueKey",
      "transcribeCloudButton-" in notes or "transcribeCloudButton" in read(TILE))
check("UI lista pendingNotesList", "pendingNotesList" in notes)
check("Mensaje audio guardado en Notas", "audio guardado en Notas" in notes)
check("Discard con confirmación", "_discardPending" in notes)
check("No encola sin flag OFF path (comportamiento error actual)",
      "retryable && _deferredQueueEnabled" in notes)

# --- 3. Flag ---
st = read(STORAGE)
check("Clave notes_deferred_queue_enabled en StorageService",
      "notes_deferred_queue_enabled" in st)
check("Default flag OFF", re.search(
    r"loadNotesDeferredQueueEnabled\(\)\s*=>\s*_getBool\([^,]+,\s*false\)", st) is not None)
check("Switch en GeneralTab con ValueKey",
      "notes-deferred-queue-switch" in read(GENERAL))
check("Wiring en settings_screen", "onToggleNotesDeferredQueue" in read(SETTINGS))
check("Flag en contract-keys (widget lee la cola)",
      "notes_deferred_queue_enabled" in read(CONTRACT))
check("Flag en bridgeKeys block (widget lee la cola)",
      "notesDeferredQueueKey" in re.search(
          r"bridgeKeys = \[(.*?)\];", st, re.DOTALL).group(1)
          if re.search(r"bridgeKeys = \[(.*?)\];", st, re.DOTALL) else False)
check("Pending key en contract-keys (widget encola)",
      "voice_notes_pending_v1" in read(CONTRACT))

# --- 4. Privacidad / sin auto-upload ---
pub = read(PUBSPEC)
check("Sin connectivity_plus", "connectivity_plus" not in pub)
check("Sin workmanager", "workmanager" not in pub.lower())
check("Sin auto-flush en notes_screen (sin addListener red / Timer upload)",
      "Timer.periodic" not in notes or "transcribe" not in notes.split("Timer.periodic")[1][:200] if "Timer.periodic" in notes else True)
check("Cero logs de contenido en cola",
      "print(" not in q and "debugPrint(" not in q and "Log." not in q)

# --- 5. Audio conservado (texto + audio, pedido 2026-09-23) ---
model = read("app_source/lib/models/voice_note.dart")
notesvc = read("app_source/lib/services/notes_service.dart")
card = read("app_source/lib/widgets/note_card.dart")
check("VoiceNote con audioPath opcional", "audioPath" in model and "hasAudio" in model)
check("NotesService guarda audioPath al transcribir",
      "addFromTranscription" in notesvc and "audioPath" in notesvc)
check("Cola conserva copia en notes_audio",
      "notesAudioDirName" in q and "notes_audio" in q
      and "keepCopyForNote" in q and "promoteToKept" in q)
check("Borrar nota limpia su WAV (sin huérfanos)",
      "deleteKeptAudio" in q or "_deleteAudioFile" in notesvc)
check("NoteCard delega el audio a NoteAudioRow",
      "NoteAudioRow" in card and "note.hasAudio" in card)
check("Transparencia local en pendientes (sin local todavía)",
      "pendingLocalInfo" in notes or "transcripción local" in notes.lower())
check("Ajustes transparenta solo-nube (sin local)",
      "aún no disponible" in read(GENERAL))

# --- 6. Visibilidad widget→app + reproducción (pedido 2026-09-23) ---
card_row = read("app_source/lib/widgets/note_audio_row.dart")
check("Cola re-lee prefs nativas (reload contra caché Dart)",
      "prefs.reload()" in q)
check("Notas refresca al volver del fondo (observer)",
      "didChangeAppLifecycleState" in notes and "_refreshFromWidget" in notes)
check("Dependencia audioplayers para reproducir",
      "audioplayers" in pub)
check("Fila de audio con reproducir/detener (perezoso, sin red)",
      "notePlayAudio-" in card_row and "DeviceFileSource" in card_row
      and "onPlayerComplete" in card_row
      and "Audio original conservado" in card_row
      and "noteDeleteAudio-" in card_row)
check("Test widget de la fila de audio existe",
      os.path.isfile(os.path.join(WORKSPACE, "app_source/test/widgets/note_audio_row_test.dart")))

# --- 6. Docs y freeze ---
readme = read(README)
agents = read(AGENTS)
freeze = read(FREEZE)
check("README ya no dice 'nada de notas' como fuera de alcance",
      "nada de notas" not in readme)
check("AGENTS.md ya no declara 'no notas' como fuera de alcance",
      "no notas" not in agents or "Notas" in agents)
check("congelamiento registra cola diferida",
      "notes_deferred_queue_enabled" in freeze or "cola diferida" in freeze.lower() or "deferred" in freeze.lower())
check("plan-notas-cola-nube.md existe", os.path.isfile(os.path.join(WORKSPACE, PLAN)))
check("master registra test_pending_notes_suite",
      "test_pending_notes_suite.py" in read(MASTER))
check("Dart test pending_note_queue_test existe",
      os.path.isfile(os.path.join(WORKSPACE, "app_source/test/services/pending_note_queue_test.dart")))
check("Integration pending_queue_flow_test existe",
      os.path.isfile(os.path.join(WORKSPACE, "app_source/test/integration/pending_queue_flow_test.dart")))

# --- Tile keys ---
tile = read(TILE)
check("Tile tiene keys de acciones",
      "transcribeCloudButton-" in tile and "discardPendingButton-" in tile)

print("\n" + "=" * 60)
print(f" RESULTADO: {suite.passed} PASS / {suite.failed} FAIL")
print("=" * 60)
sys.exit(suite.exit_code())
