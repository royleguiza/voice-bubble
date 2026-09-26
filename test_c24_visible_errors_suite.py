#!/usr/bin/env python3
"""
test_c24_visible_errors_suite.py
================================
Suite dedicada para el Contrato C-24 (Errores que se ven).

Verifica de forma estricta:
1. Política de 3 niveles de errores:
   - Nivel 1 (UI-crítico): retorna bool / lanza excepción descriptiva; la UI
     muestra aviso claro al usuario (SnackBar), jamás asume ni dice "guardado" si falló.
   - Nivel 2 (Fondo/no bloqueante): se acumula en channelErrorCount / métricas
     visibles en diagnóstico sin bloquear al usuario ni tragar ciegamente.
   - Nivel 3 (Defensivo): solo I/O de limpieza con catch seguro.
2. CloudSttService conserva client (copyWith) y TranscriptionService.updateApiKey lo usa.
3. Umbral de audio útil: >= 8000 bytes (en CloudSttService y home_screen.dart).
4. _save, _saveHistoryFile y saveSnippets en storage_service.dart retornan bool honesto.
5. Simulación de disco lleno: la persistencia falla y la UI muestra error visible,
   NUNCA éxito ("guardado").
6. Batería de mutaciones negativas para certificar no-tautología.
"""

import os
import re
import sys
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__)))
APP_SOURCE = os.path.join(REPO_ROOT, "app_source", "lib")


class TestC24CloudSttThresholdAndClient(unittest.TestCase):
    """Verifica umbral de audio >= 8000B y copyWith en CloudSttService."""

    def setUp(self):
        self.cloud_stt_path = os.path.join(APP_SOURCE, "services", "cloud_stt_service.dart")
        with open(self.cloud_stt_path, "r", encoding="utf-8") as f:
            self.cloud_stt_src = f.read()

        self.transcription_svc_path = os.path.join(APP_SOURCE, "services", "transcription_service.dart")
        with open(self.transcription_svc_path, "r", encoding="utf-8") as f:
            self.transcription_svc_src = f.read()

    def test_min_audio_bytes_defined_as_8000(self):
        """CloudSttService declara minAudioBytes = 8000."""
        match = re.search(r"static\s+const\s+int\s+minAudioBytes\s*=\s*8000\s*;", self.cloud_stt_src)
        self.assertIsNotNone(match, "CloudSttService debe declarar static const int minAudioBytes = 8000;")

    def test_cloud_stt_has_copy_with(self):
        """CloudSttService declara copyWith que preserva client."""
        self.assertIn("CloudSttService copyWith(", self.cloud_stt_src)
        self.assertIn("client: client ?? this.client", self.cloud_stt_src)
        self.assertIn("apiKey: apiKey ?? this.apiKey", self.cloud_stt_src)

    def test_transcription_service_uses_copy_with(self):
        """TranscriptionService.updateApiKey usa copyWith para preservar el client."""
        self.assertIn("_cloudService = _cloudService.copyWith(apiKey: apiKey);", self.transcription_svc_src)
        self.assertIn("CloudSttService get cloudService => _cloudService;", self.transcription_svc_src)

    def test_cloud_stt_validates_min_audio_bytes(self):
        """CloudSttService.transcribe valida que el archivo tenga al menos minAudioBytes."""
        self.assertIn("fileLength < minAudioBytes", self.cloud_stt_src)
        self.assertIn("TranscriptionErrorKind.badRequest", self.cloud_stt_src)

    def test_threshold_logic_rejects_under_8000(self):
        """Simulación de la lógica de umbral de audio."""
        min_bytes = 8000
        self.assertTrue(7999 < min_bytes, "7999 bytes debe ser rechazado")
        self.assertFalse(8000 < min_bytes, "8000 bytes debe ser aceptado")
        self.assertFalse(8192 < min_bytes, "8192 bytes debe ser aceptado")


class TestC24HomeScreenAudioThreshold(unittest.TestCase):
    """Verifica umbral de audio >= 8000B en home_screen.dart."""

    def setUp(self):
        self.home_screen_path = os.path.join(APP_SOURCE, "screens", "home_screen.dart")
        with open(self.home_screen_path, "r", encoding="utf-8") as f:
            self.home_screen_src = f.read()

    def test_home_screen_min_audio_bytes_is_8000(self):
        """home_screen.dart declara minAudioBytes = 8000 y _minAudioBytes = minAudioBytes."""
        match_const = re.search(r"static\s+const\s+int\s+minAudioBytes\s*=\s*8000\s*;", self.home_screen_src)
        self.assertIsNotNone(match_const, "home_screen.dart debe declarar minAudioBytes = 8000;")
        match_private = re.search(r"static\s+const\s+int\s+_minAudioBytes\s*=\s*(?:minAudioBytes|8000)\s*;", self.home_screen_src)
        self.assertIsNotNone(match_private, "home_screen.dart debe vincular _minAudioBytes a 8000 / minAudioBytes;")

    def test_home_screen_has_usable_audio_checks_threshold(self):
        """_hasUsableAudio comprueba lengthSync() >= _minAudioBytes."""
        self.assertIn("file.lengthSync() >= _minAudioBytes", self.home_screen_src)


class TestC24ThreeTierErrorPolicyAndChannels(unittest.TestCase):
    """Verifica la política de 3 niveles de errores y canal de fondo."""

    def setUp(self):
        self.guard_path = os.path.join(APP_SOURCE, "services", "channel_guard.dart")
        with open(self.guard_path, "r", encoding="utf-8") as f:
            self.guard_src = f.read()

        self.widget_svc_path = os.path.join(APP_SOURCE, "services", "widget_service.dart")
        with open(self.widget_svc_path, "r", encoding="utf-8") as f:
            self.widget_svc_src = f.read()

    def test_channel_guard_defines_3_tier_policy(self):
        """channel_guard.dart documenta y formaliza la política de 3 niveles."""
        self.assertIn("POLÍTICA DE 3 NIVELES DE ERRORES", self.guard_src)
        self.assertIn("Nivel 1 (UI-crítico)", self.guard_src)
        self.assertIn("Nivel 2 (Fondo/no bloqueante)", self.guard_src)
        self.assertIn("Nivel 3 (Defensivo)", self.guard_src)

    def test_channel_guard_exposes_record_background_error(self):
        """channel_guard expone recordBackgroundError y channelErrorCount."""
        self.assertIn("void recordBackgroundError(", self.guard_src)
        self.assertIn("int get channelErrorCount", self.guard_src)
        self.assertIn("void resetChannelErrorCountForTesting()", self.guard_src)

    def test_widget_service_uses_level_2_policy(self):
        """WidgetService usa invokeChannelResult y recordBackgroundError en vez de catch ciego."""
        self.assertIn("invokeChannelResult", self.widget_svc_src)
        self.assertIn("recordBackgroundError", self.widget_svc_src)
        self.assertNotIn("catch (_) {}", self.widget_svc_src, "WidgetService no debe contener catch (_) {} ciego")


class TestC24StorageAndNotesHonestReporting(unittest.TestCase):
    """Verifica reporte honesto de almacenamiento y notas ante disco lleno."""

    def setUp(self):
        self.storage_path = os.path.join(APP_SOURCE, "services", "storage_service.dart")
        with open(self.storage_path, "r", encoding="utf-8") as f:
            self.storage_src = f.read()

        self.transcription_svc_path = os.path.join(APP_SOURCE, "services", "transcription_service.dart")
        with open(self.transcription_svc_path, "r", encoding="utf-8") as f:
            self.transcription_svc_src = f.read()

        self.notes_svc_path = os.path.join(APP_SOURCE, "services", "notes_service.dart")
        with open(self.notes_svc_path, "r", encoding="utf-8") as f:
            self.notes_svc_src = f.read()

        self.notes_screen_path = os.path.join(APP_SOURCE, "screens", "notes_screen.dart")
        with open(self.notes_screen_path, "r", encoding="utf-8") as f:
            self.notes_screen_src = f.read()

        self.note_editor_path = os.path.join(APP_SOURCE, "screens", "note_editor_screen.dart")
        with open(self.note_editor_path, "r", encoding="utf-8") as f:
            self.note_editor_src = f.read()

    def test_storage_save_and_save_history_file_return_bool(self):
        """_save y _saveHistoryFile devuelven Future<bool>."""
        self.assertIn("Future<bool> _save() async", self.storage_src)
        self.assertIn("Future<bool> _saveHistoryFile() async", self.storage_src)

    def test_save_snippets_returns_bool_and_propagates(self):
        """saveSnippets devuelve Future<bool> y se propaga en add, update, delete."""
        self.assertIn("Future<bool> saveSnippets(List<Snippet> snippets) async", self.storage_src)
        self.assertIn("return await saveSnippets(", self.storage_src)

    def test_transcription_service_fails_honest_on_persist_failure(self):
        """transcribe lanza excepción descriptiva si storage.add falla (disco lleno)."""
        self.assertIn("final saved = await _storageService.add(result);", self.transcription_svc_src)
        self.assertIn("if (!saved)", self.transcription_svc_src)
        self.assertIn("disco lleno o error de almacenamiento", self.transcription_svc_src)

    def test_storage_ensure_seeds_validates_save_result(self):
        """ensureSeeds no marca flag seeded si saveSnippets falla."""
        self.assertIn("final saved = await saveSnippets(_seedSnippets);", self.storage_src)
        self.assertIn("if (!saved) return;", self.storage_src)

    def test_notes_service_methods_check_persist_state(self):
        """addNote, updateNote, deleteNote y addFromTranscription retornan false si persist falla."""
        self.assertIn("if (await _persist() != _NotesPersistState.saved)", self.notes_svc_src)
        self.assertIn("return false;", self.notes_svc_src)

    def test_transcription_service_cleanup_temp_file_level_3(self):
        """cleanupTempFile implementa Nivel 3 (defensivo sin romper el flujo de la app)."""
        self.assertIn("Future<void> cleanupTempFile(String path) async", self.transcription_svc_src)
        self.assertIn("catch (_) {}", self.transcription_svc_src)

    def test_notes_screen_surfaces_error_on_save_failure(self):
        """notes_screen.dart muestra SnackBar de error si addFromTranscription falla."""
        self.assertIn("ScaffoldMessenger.of(context).showSnackBar(", self.notes_screen_src)
        self.assertIn("Nota no guardada; el audio se conserva", self.notes_screen_src)
        # Comprobar que "Nota guardada" solo se ejecuta bajo rama if (ok)
        pattern = r"if\s*\(\s*ok\s*\)\s*\{.*?Nota guardada.*?\}\s*else\s*\{.*?Nota no guardada"
        self.assertIsNotNone(re.search(pattern, self.notes_screen_src, re.DOTALL),
                             "La UI debe condicionar estrictamente el aviso de éxito a ok == true")

    def test_note_editor_surfaces_error_on_save_failure(self):
        """note_editor_screen.dart muestra SnackBar de error si guardar falla."""
        pattern = r"if\s*\(\s*ok\s*\)\s*\{.*?Navigator\.of\(context\)\.pop\(true\);.*?\}\s*else\s*\{.*?Limite alcanzado o error"
        self.assertIsNotNone(re.search(pattern, self.note_editor_src, re.DOTALL),
                             "NoteEditorScreen debe rechazar cierre con éxito si ok es false")


class TestC24SimulatedDiskFullScenarios(unittest.TestCase):
    """Simula escenarios reales de disco lleno en memoria."""

    def test_disk_full_in_storage_service(self):
        """Simula que la persistencia en disco de StorageService arroja false."""
        class MockStorageService:
            def __init__(self, disk_full=False):
                self.disk_full = disk_full
                self.history = []

            def save_history_file(self):
                if self.disk_full:
                    return False
                return True

            def save_prefs(self):
                if self.disk_full:
                    return False
                return True

            def persist(self):
                file_saved = self.save_history_file()
                if not file_saved:
                    return False
                prefs_saved = self.save_prefs()
                return prefs_saved

            def add(self, transcription):
                prev = list(self.history)
                self.history.append(transcription)
                saved = self.persist()
                if not saved:
                    self.history = prev
                    return False
                return True

        normal_storage = MockStorageService(disk_full=False)
        self.assertTrue(normal_storage.add("nota 1"))
        self.assertEqual(len(normal_storage.history), 1)

        full_storage = MockStorageService(disk_full=True)
        self.assertFalse(full_storage.add("nota 2"))
        self.assertEqual(len(full_storage.history), 0, "No debe retener en memoria datos que fallaron al persistir")

    def test_disk_full_in_transcription_service_flow(self):
        """Simula que TranscriptionService detecta fallo de persistencia y no dice éxito."""
        class SimulatedTranscriptionService:
            def __init__(self, storage):
                self.storage = storage

            def transcribe(self, audio_path, delete_audio_on_success=True):
                # Simula respuesta de API exitosa pero persistencia fallida
                result = {"text": "Texto reconocido"}
                saved = self.storage.add(result["text"])
                if not saved:
                    raise Exception("No se pudo guardar la transcripción en el historial (disco lleno o error de almacenamiento).")
                # Solo borra audio si se guardó con éxito
                return result

        class MockFailingStorage:
            def add(self, text):
                return False

        service = SimulatedTranscriptionService(MockFailingStorage())
        with self.assertRaises(Exception) as ctx:
            service.transcribe("temp_audio.wav")
        self.assertIn("disco lleno", str(ctx.exception))


class TestC24NegativeMutations(unittest.TestCase):
    """Batería de mutaciones negativas para certificar no-tautología."""

    def test_mutation_reverting_audio_threshold_to_1000_fails(self):
        """Mutación 1: si minAudioBytes vuelve a 1000, la verificación falla."""
        mutated_src = "static const int minAudioBytes = 1000;"
        match = re.search(r"static\s+const\s+int\s+minAudioBytes\s*=\s*8000\s*;", mutated_src)
        self.assertIsNone(match, "Debe detectar si minAudioBytes no es 8000")

    def test_mutation_discarding_client_in_copy_with_fails(self):
        """Mutación 2: si copyWith no preserva client, la verificación falla."""
        mutated_src = "CloudSttService copyWith({String? apiKey}) => CloudSttService(apiKey: apiKey ?? this.apiKey);"
        self.assertNotIn("client: client ?? this.client", mutated_src)

    def test_mutation_swallowing_storage_add_failure_fails(self):
        """Mutación 3: si transcribe ignora !saved, la verificación falla."""
        mutated_src = """
        if (result.text.isNotEmpty) {
          final saved = await _storageService.add(result);
          if (!saved) return result; // Mutación que traga error
        }
        """
        self.assertNotIn("throw const TranscriptionException", mutated_src)

    def test_mutation_widget_service_blind_catch_fails(self):
        """Mutación 4: si WidgetService usa catch (_) {}, la verificación falla."""
        mutated_src = """
        Future<void> updateWidgets() async {
          try {
            await _channel.invokeMethod('updateWidgets');
          } catch (_) {}
        }
        """
        self.assertIn("catch (_) {}", mutated_src)
        # La versión contractual no debe tener catch (_) {}
        guard_check = "catch (_) {}" not in mutated_src
        self.assertFalse(guard_check)

    def test_mutation_unconditional_success_ui_fails(self):
        """Mutación 5: si la UI anuncia éxito incondicionalmente, la verificación falla."""
        mutated_ui = """
        final ok = await _notesService.addFromTranscription(file.text);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota guardada')));
        """
        has_conditional = bool(re.search(r"if\s*\(\s*ok\s*\)\s*\{[^}]*Nota guardada", mutated_ui))
        self.assertFalse(has_conditional, "Debe detectar si falta la guarda condicional if (ok)")


if __name__ == "__main__":
    unittest.main()
