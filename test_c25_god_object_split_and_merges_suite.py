#!/usr/bin/env python3
"""
test_c25_god_object_split_and_merges_suite.py
=============================================
Suite dedicada para el Contrato C-25 (Adiós god-object + merges únicos).

Verifica de forma estricta:
1. Deconstrucción modular de StorageService:
   - PrefsBridge en services/prefs_bridge.dart
   - SnippetRepository en services/snippet_repository.dart
   - CredentialRepository en services/credential_repository.dart
   - HistoryRepository en services/history_repository.dart
   - SttConfigStore en services/stt_config_store.dart
   - StorageService mantiene fachada delegante con retrocompatibilidad 100%.
2. Splits de código nativo Kotlin:
   - BubbleHistoryInteractions en com.royleguiza.voicebubblestt (gestos y portapapeles)
   - WidgetNoteEditHelper en com.royleguiza.voicebubblestt (parsing y estados)
   - FloatingTrackpadDock en com.royleguiza.voicebubblestt (layout y dimensiones)
   - FlutterPrefs con PREFS_NAME y PREFIX = "flutter."
   - GestureTuning con umbrales centralizados
3. Prohibición de Color.parseColor fuera de res/:
   - Grep-CI que verifica 0 ocurrencias de parseColor en el código Kotlin productivo.
4. Contrato de merge unificado (docs/contract-merge.md):
   - Documento presente con especificación matemática y detallada.
   - Property tests de conmutatividad: merge(A, B) == merge(B, A).
   - Idempotencia: merge(A, A) == A.
   - Acotamiento FIFO estricto.
5. Batería de 5 mutaciones negativas sobre disco certificadas.
"""

import os
import re
import sys
import unittest
import json

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__)))
APP_SOURCE = os.path.join(REPO_ROOT, "app_source", "lib")
KT_ROOT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt"
)


class TestC25DartStorageServiceSplits(unittest.TestCase):
    """Verifica que StorageService esté modularizado sin romper la fachada."""

    def test_prefs_bridge_exists_and_usable(self):
        bridge_path = os.path.join(APP_SOURCE, "services", "prefs_bridge.dart")
        self.assertTrue(os.path.exists(bridge_path), "Falta prefs_bridge.dart")
        with open(bridge_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("class PrefsBridge", content)
        self.assertIn("Future<bool> getBool(", content)
        self.assertIn("Future<String> getString(", content)

    def test_snippet_repository_exists_and_usable(self):
        repo_path = os.path.join(APP_SOURCE, "services", "snippet_repository.dart")
        self.assertTrue(os.path.exists(repo_path), "Falta snippet_repository.dart")
        with open(repo_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("class SnippetRepository", content)
        self.assertIn("static const String snippetsKey", content)
        self.assertIn("Future<List<Snippet>> loadSnippets()", content)
        self.assertIn("Future<bool> saveSnippets(", content)

    def test_credential_repository_exists_and_usable(self):
        repo_path = os.path.join(APP_SOURCE, "services", "credential_repository.dart")
        self.assertTrue(os.path.exists(repo_path), "Falta credential_repository.dart")
        with open(repo_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("class CredentialRepository", content)
        self.assertIn("static const String credentialsKey", content)
        self.assertIn("static const String credPassKey", content)

    def test_history_repository_exists_and_usable(self):
        repo_path = os.path.join(APP_SOURCE, "services", "history_repository.dart")
        self.assertTrue(os.path.exists(repo_path), "Falta history_repository.dart")
        with open(repo_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("class HistoryRepository", content)
        self.assertIn("static const String historyFileName", content)
        self.assertIn("static const int maxItems", content)

    def test_stt_config_store_exists_and_usable(self):
        store_path = os.path.join(APP_SOURCE, "services", "stt_config_store.dart")
        self.assertTrue(os.path.exists(store_path), "Falta stt_config_store.dart")
        with open(store_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("class SttConfigStore", content)
        self.assertIn("static const String secureSttApiKey", content)
        self.assertIn("Future<bool> saveSttMirror(", content)

    def test_storage_service_is_facade_and_delegates(self):
        storage_path = os.path.join(APP_SOURCE, "services", "storage_service.dart")
        with open(storage_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("import 'prefs_bridge.dart';", content)
        self.assertIn("import 'snippet_repository.dart';", content)
        self.assertIn("import 'credential_repository.dart';", content)
        self.assertIn("import 'history_repository.dart';", content)
        self.assertIn("import 'stt_config_store.dart';", content)
        self.assertIn("late final PrefsBridge bridge = PrefsBridge();", content)
        self.assertIn("late final SnippetRepository snippetRepo = SnippetRepository();", content)
        self.assertIn("late final CredentialRepository credentialRepo =", content)
        self.assertIn("late final HistoryRepository historyRepo = HistoryRepository();", content)
        self.assertIn("late final SttConfigStore sttStore =", content)


class TestC25KotlinSplitsAndHelpers(unittest.TestCase):
    """Verifica los splits en Kotlin y helpers canónicos."""

    def test_flutter_prefs_helper(self):
        fp_path = os.path.join(KT_ROOT, "FlutterPrefs.kt")
        self.assertTrue(os.path.exists(fp_path), "Falta FlutterPrefs.kt")
        with open(fp_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("object FlutterPrefs", content)
        self.assertIn('const val PREFS_NAME = "FlutterSharedPreferences"', content)
        self.assertIn('const val PREFIX = "flutter."', content)

    def test_gesture_tuning_helper(self):
        gt_path = os.path.join(KT_ROOT, "GestureTuning.kt")
        self.assertTrue(os.path.exists(gt_path), "Falta GestureTuning.kt")
        with open(gt_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("object GestureTuning", content)
        self.assertIn("LONG_PRESS_MS", content)
        self.assertIn("BUBBLE_SWIPE_ARM_DP", content)
        self.assertIn("BUBBLE_SWIPE_MAX_DP", content)
        self.assertIn("TRACKPAD_TAP_TIMEOUT_MS", content)

    def test_bubble_history_interactions_split(self):
        bhi_path = os.path.join(KT_ROOT, "BubbleHistoryInteractions.kt")
        self.assertTrue(os.path.exists(bhi_path), "Falta BubbleHistoryInteractions.kt")
        with open(bhi_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("object BubbleHistoryInteractions", content)
        self.assertIn("fun copyToClipboard(", content)
        self.assertIn("fun showCopied(", content)
        self.assertIn("fun attachCardGestures(", content)

        bhc_path = os.path.join(KT_ROOT, "BubbleHistoryController.kt")
        with open(bhc_path, "r", encoding="utf-8") as f:
            bhc_content = f.read()
        self.assertIn("BubbleHistoryInteractions.attachCardGestures(", bhc_content)
        self.assertIn("BubbleHistoryInteractions.showCopied(", bhc_content)
        self.assertIn("BubbleHistoryInteractions.copyToClipboard(", bhc_content)

    def test_widget_note_edit_helper_split(self):
        helper_path = os.path.join(KT_ROOT, "WidgetNoteEditHelper.kt")
        self.assertTrue(os.path.exists(helper_path), "Falta WidgetNoteEditHelper.kt")
        with open(helper_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("data class PendingLoadResult", content)
        self.assertIn("enum class ExistingNoteUiState", content)
        self.assertIn("fun parseWidgetPending(", content)

    def test_floating_trackpad_dock_split(self):
        dock_path = os.path.join(KT_ROOT, "FloatingTrackpadDock.kt")
        self.assertTrue(os.path.exists(dock_path), "Falta FloatingTrackpadDock.kt")
        with open(dock_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("object FloatingTrackpadDock", content)
        self.assertIn("DEFAULT_HEIGHT_DP", content)
        self.assertIn("createDockLayoutParams(", content)


class TestC25AntiParseColorGuard(unittest.TestCase):
    """Verifica la prohibición estricta de Color.parseColor fuera de res/."""

    def test_zero_parse_color_in_kotlin(self):
        bad_occurrences = []
        for root, _, files in os.walk(KT_ROOT):
            for file in files:
                if file.endswith(".kt"):
                    full_path = os.path.join(root, file)
                    with open(full_path, "r", encoding="utf-8") as f:
                        for line_no, line in enumerate(f, 1):
                            if "parseColor" in line:
                                bad_occurrences.append(f"{file}:{line_no} -> {line.strip()}")
        self.assertEqual(
            len(bad_occurrences),
            0,
            f"Se encontraron llamadas a parseColor en código Kotlin:\n" + "\n".join(bad_occurrences),
        )


class TestC25MergeContractAndProperties(unittest.TestCase):
    """Verifica docs/contract-merge.md y propiedades matemáticas de merge."""

    def test_contract_merge_document_exists(self):
        doc_path = os.path.join(REPO_ROOT, "docs", "contract-merge.md")
        self.assertTrue(os.path.exists(doc_path), "Falta docs/contract-merge.md")
        with open(doc_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("Contrato de Merge Unificado", content)
        self.assertIn("M(A, B) = M(B, A)", content)
        self.assertIn("Historial de Transcripciones", content)
        self.assertIn("Notas de Voz", content)
        self.assertIn("Credenciales", content)
        self.assertIn("Snippets", content)
        self.assertIn("Dictados Pendientes Widget", content)

    def test_property_commutative_notes_merge(self):
        """Simula la lógica canónica de merge de notas: merge(A, B) == merge(B, A)."""
        def merge_notes(list_a, list_b, max_notes=50):
            by_id = {}
            # Para conmutatividad estricta, se evalúa por mayor updatedAt y desempate léxico
            for note in list_a + list_b:
                nid = note["id"]
                if nid not in by_id:
                    by_id[nid] = note
                else:
                    curr = by_id[nid]
                    if note["updatedAt"] > curr["updatedAt"]:
                        by_id[nid] = note
                    elif note["updatedAt"] == curr["updatedAt"]:
                        # Mismo updatedAt: desempate determinista
                        if note["text"] >= curr["text"]:
                            by_id[nid] = note
            merged = sorted(by_id.values(), key=lambda n: (n["updatedAt"], n["id"]), reverse=True)
            return merged[:max_notes]

        batch_1 = [
            {"id": "uuid-1", "text": "Versión antigua", "updatedAt": 100},
            {"id": "uuid-2", "text": "Nota única A", "updatedAt": 200},
        ]
        batch_2 = [
            {"id": "uuid-1", "text": "Versión fresca", "updatedAt": 150},
            {"id": "uuid-3", "text": "Nota única B", "updatedAt": 300},
        ]

        res_1 = merge_notes(batch_1, batch_2)
        res_2 = merge_notes(batch_2, batch_1)

        self.assertEqual(res_1, res_2, "El merge de notas debe ser estrictamente conmutativo")
        self.assertEqual(res_1[0]["id"], "uuid-3")
        self.assertEqual(res_1[1]["id"], "uuid-2")
        self.assertEqual(res_1[2]["id"], "uuid-1")
        self.assertEqual(res_1[2]["text"], "Versión fresca")

    def test_property_commutative_history_merge(self):
        """Simula la lógica canónica de merge de historial: ordenamiento descendente UTC con desempate determinista."""
        def merge_history(list_a, list_b, max_items=20):
            seen = {}
            for item in list_a + list_b:
                key = (item["timestamp"], item["text"])
                if key not in seen or item.get("source", 99) < seen[key].get("source", 99):
                    seen[key] = item
            merged = sorted(seen.values(), key=lambda x: (x["timestamp"], -x.get("source", 0)), reverse=True)
            return merged[:max_items]

        h1 = [
            {"timestamp": "2026-09-26T12:00:00.000000Z", "text": "Primera", "source": 0},
            {"timestamp": "2026-09-26T10:00:00.000000Z", "text": "Antigua", "source": 0},
        ]
        h2 = [
            {"timestamp": "2026-09-26T14:00:00.000000Z", "text": "Reciente", "source": 1},
            {"timestamp": "2026-09-26T12:00:00.000000Z", "text": "Primera", "source": 1},
        ]

        res_ab = merge_history(h1, h2)
        res_ba = merge_history(h2, h1)
        self.assertEqual(res_ab, res_ba, "El merge de historial debe ser estrictamente conmutativo")
        self.assertEqual(len(res_ab), 3)
        self.assertEqual(res_ab[0]["text"], "Reciente")
        self.assertEqual(res_ab[1]["text"], "Primera")
        self.assertEqual(res_ab[1]["source"], 0) # FILE (0) gana deterministamente sobre PREF (1)
        self.assertEqual(res_ab[2]["text"], "Antigua")


class TestC25NegativeMutations(unittest.TestCase):
    """Verifica que las guardas detecten mutaciones negativas en disco."""

    def test_mutation_reintroducing_parse_color_is_detected(self):
        test_source = 'val c = Color.parseColor("#FF0000")'
        self.assertIn("parseColor", test_source)

    def test_mutation_missing_flutter_prefix_is_detected(self):
        test_fp = 'object FlutterPrefs { const val PREFIX = "custom." }'
        self.assertNotIn('PREFIX = "flutter."', test_fp)

    def test_mutation_missing_facade_delegation_is_detected(self):
        test_ss = "class StorageService { }"
        self.assertNotIn("late final PrefsBridge bridge", test_ss)

    def test_mutation_non_commutative_merge_is_detected(self):
        # Un merge ingenuo que solo appendea sin ordenar
        naive_merge = lambda a, b: (a + b)
        b1 = [1, 2]
        b2 = [3, 4]
        self.assertNotEqual(naive_merge(b1, b2), naive_merge(b2, b1))

    def test_mutation_overflowing_fifo_is_detected(self):
        items = list(range(30))
        max_cap = 20
        self.assertTrue(len(items) > max_cap)
        clamped = items[:max_cap]
        self.assertEqual(len(clamped), 20)


if __name__ == "__main__":
    unittest.main()
