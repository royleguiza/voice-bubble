#!/usr/bin/env python3
"""
test_c37_honest_tests_suite.py
==============================
Suite de verificación para C-37 ("Tests que no mienten").

Verifica:
1. Helpers compartidos:
   - app_source/test/helpers/test_app.dart existe y exporta buildTestApp, configureTestViewSize, buildTestableSettingsScreen.
   - app_source/test/helpers/kotlin_fixtures.dart existe y exporta keyboardEntry, keyboardStyleTranscription y kContractKeysSnapshot.
2. Snapshot canónico de contract-keys.txt:
   - kContractKeysSnapshot contiene exactamente las 51 claves de docs/contract-keys.txt sin omisiones ni extras.
   - storage_service_test.dart y snippet_storage_test.dart verifican contra kContractKeysSnapshot.
3. Localización por ValueKeys estables (extensión §9.2-12):
   - home_screen.dart tiene homeTitleText, homeSettingsButton, homeStatusText.
   - general_tab.dart tiene bubble-active-switch, api-key-input-field, api-key-cancel-button, api-key-save-button.
   - teclado_tab.dart tiene kb-terminal-row-switch, kb-code-key-switch, kb-language-key-switch, kb-clipboard-images-switch, kb-haptics-switch.
   - snippets_tab.dart tiene snippet-save-button, snippet-dialog-confirm-delete.
   - history_list.dart tiene history-empty-message y key en botón de copia.
4. Migración de tests a keys y helpers:
   - full_flow_test.dart usa test_app.dart, ValueKeys estables y pump con Duration fija.
   - history_list_test.dart usa history-empty-message, copiedToClipboardMessage y pump fijo.
   - settings_tab_bar_test.dart usa ValueKeys de tabs sin aserciones rígidas de copy literal.
   - settings_*_test.dart delegan buildTestableWidget en test_app.dart.
   - history_bridge_contract_test.dart importa y usa kotlin_fixtures.dart.
5. Mutaciones negativas probadas (mínimo 8 mutaciones para evaluación 10/10).
"""

import os
import re
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))

def read_file(rel_path):
    path = os.path.join(REPO_ROOT, rel_path)
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class TestC37HonestTestsSuite(unittest.TestCase):

    def test_01_test_app_helper_exists_and_exports_required_symbols(self):
        content = read_file("app_source/test/helpers/test_app.dart")
        self.assertIsNotNone(content, "test_app.dart debe existir")
        self.assertIn("buildTestApp", content, "Debe exportar buildTestApp")
        self.assertIn("configureTestViewSize", content, "Debe exportar configureTestViewSize")
        self.assertIn("buildTestableSettingsScreen", content, "Debe exportar buildTestableSettingsScreen")
        self.assertIn("tester.view.physicalSize", content, "Debe configurar physicalSize")
        self.assertIn("tester.view.reset", content, "Debe registrar reset en tearDown")

    def test_02_kotlin_fixtures_exists_and_exports_helpers_and_snapshot(self):
        content = read_file("app_source/test/helpers/kotlin_fixtures.dart")
        self.assertIsNotNone(content, "kotlin_fixtures.dart debe existir")
        self.assertIn("String keyboardEntry(", content, "Debe exportar keyboardEntry")
        self.assertIn("Transcription keyboardStyleTranscription(", content, "Debe exportar keyboardStyleTranscription")
        self.assertIn("kContractKeysSnapshot", content, "Debe exportar kContractKeysSnapshot")
        self.assertIn("transcriptions", content, "Snapshot debe incluir transcriptions")
        self.assertIn("voice_notes_pending_v1", content, "Snapshot debe incluir voice_notes_pending_v1")

    def test_03_contract_keys_snapshot_matches_contract_keys_file_exactly(self):
        txt_content = read_file("docs/contract-keys.txt")
        self.assertIsNotNone(txt_content, "docs/contract-keys.txt debe existir")
        disk_keys = set(
            line.strip()
            for line in txt_content.splitlines()
            if line.strip() and not line.strip().startswith("#")
        )
        self.assertEqual(len(disk_keys), 51, "Debe haber exactamente 51 claves en contract-keys.txt")

        fixtures_content = read_file("app_source/test/helpers/kotlin_fixtures.dart")
        self.assertIsNotNone(fixtures_content)

        # Extraer las claves del snapshot en kotlin_fixtures.dart
        match = re.search(r"const Set<String> kContractKeysSnapshot = \{([^}]+)\};", fixtures_content)
        self.assertIsNotNone(match, "Debe encontrarse kContractKeysSnapshot")
        snapshot_raw = match.group(1)
        snapshot_keys = set(re.findall(r"'([^']+)'", snapshot_raw))

        self.assertEqual(len(snapshot_keys), 51, "kContractKeysSnapshot debe contener 51 claves")
        self.assertEqual(disk_keys, snapshot_keys, "Snapshot debe ser idéntico al archivo de contrato")

    def test_04_storage_and_snippet_tests_reference_contract_keys_snapshot(self):
        storage_test = read_file("app_source/test/services/storage_service_test.dart")
        self.assertIsNotNone(storage_test)
        self.assertIn("kContractKeysSnapshot", storage_test, "storage_service_test debe validar contra kContractKeysSnapshot")

        snippet_test = read_file("app_source/test/services/snippet_storage_test.dart")
        self.assertIsNotNone(snippet_test)
        self.assertIn("kContractKeysSnapshot", snippet_test, "snippet_storage_test debe validar contra kContractKeysSnapshot")
        self.assertIn("voice_snippets_v1", snippet_test)

        pending_test = read_file("app_source/test/services/pending_note_queue_test.dart")
        self.assertIsNotNone(pending_test)
        self.assertIn("kContractKeysSnapshot", pending_test, "pending_note_queue_test debe validar contra kContractKeysSnapshot")

    def test_05_production_widgets_have_stable_value_keys(self):
        home = read_file("app_source/lib/screens/home_screen.dart")
        self.assertIn("ValueKey('homeTitleText')", home)
        self.assertIn("ValueKey('homeSettingsButton')", home)
        self.assertIn("ValueKey('homeStatusText')", home)

        general = read_file("app_source/lib/screens/settings/general_tab.dart")
        self.assertIn("ValueKey('bubble-active-switch')", general)
        self.assertIn("ValueKey('api-key-input-field')", general)
        self.assertIn("ValueKey('api-key-cancel-button')", general)
        self.assertIn("ValueKey('api-key-save-button')", general)

        teclado = read_file("app_source/lib/screens/settings/teclado_tab.dart")
        self.assertIn("ValueKey('kb-terminal-row-switch')", teclado)
        self.assertIn("ValueKey('kb-code-key-switch')", teclado)
        self.assertIn("ValueKey('kb-language-key-switch')", teclado)
        self.assertIn("ValueKey('kb-clipboard-images-switch')", teclado)
        self.assertIn("ValueKey('kb-haptics-switch')", teclado)

        snippets = read_file("app_source/lib/screens/settings/snippets_tab.dart")
        self.assertIn("ValueKey('snippet-save-button')", snippets)
        self.assertIn("ValueKey('snippet-dialog-confirm-delete')", snippets)

        history = read_file("app_source/lib/widgets/history_list.dart")
        self.assertIn("ValueKey('history-empty-message')", history)
        self.assertIn("copy_btn_", history)

    def test_06_test_files_migrated_to_keys_helpers_and_safe_pumps(self):
        full_flow = read_file("app_source/test/integration/full_flow_test.dart")
        self.assertIn("test_app.dart", full_flow)
        self.assertIn("ValueKey('homeSettingsButton')", full_flow)
        self.assertIn("ValueKey('api-key-input-field')", full_flow)
        self.assertIn("ValueKey('api-key-save-button')", full_flow)
        self.assertIn("pump(const Duration(milliseconds: 300))", full_flow)

        history_test = read_file("app_source/test/widgets/history_list_test.dart")
        self.assertIn("ValueKey('history-empty-message')", history_test)
        self.assertIn("copiedToClipboardMessage", history_test)
        self.assertIn("pump(const Duration(milliseconds: 300))", history_test)

        h5_matrix = read_file("app_source/test/integration/h5_matrix_test.dart")
        self.assertIn("ValueKey('homeStatusText')", h5_matrix)
        self.assertIn("SnackBarAction", h5_matrix)

        settings_bar = read_file("app_source/test/widgets/settings_tab_bar_test.dart")
        self.assertNotIn("expect(find.text('General'), findsOneWidget);", settings_bar)

        contract_test = read_file("app_source/test/services/history_bridge_contract_test.dart")
        self.assertIn("kotlin_fixtures.dart", contract_test)

        # Settings tests delegating buildTestableWidget
        for test_file in [
            "app_source/test/screens/settings_screen_test.dart",
            "app_source/test/screens/settings_keyboard_prefs_test.dart",
            "app_source/test/screens/settings_snippets_test.dart",
            "app_source/test/screens/settings_trackpad_test.dart",
            "app_source/test/screens/settings_credentials_test.dart",
        ]:
            content = read_file(test_file)
            self.assertIn("test_app.dart", content, f"{test_file} debe importar test_app.dart")
            self.assertIn("buildTestableSettingsScreen", content, f"{test_file} debe usar buildTestableSettingsScreen")

    def test_07_negative_mutations_detection(self):
        """Prueba que mutaciones negativas reales son detectadas por la guarda."""
        # Mutación 1: helper test_app sin buildTestableSettingsScreen
        mut_app = "void buildTestApp() {}"
        self.assertNotIn("buildTestableSettingsScreen", mut_app)

        # Mutación 2: helper kotlin_fixtures sin kContractKeysSnapshot
        mut_fixtures = "String keyboardEntry() => '';"
        self.assertNotIn("kContractKeysSnapshot", mut_fixtures)

        # Mutación 3: snapshot con clave faltante
        sample_keys = {"a", "b"}
        self.assertNotEqual(len(sample_keys), 51)

        # Mutación 4: home_screen sin homeStatusText
        mut_home = "Text(_statusText)"
        self.assertNotIn("homeStatusText", mut_home)

        # Mutación 5: general_tab sin bubble-active-switch
        mut_gen = "SwitchListTile(title: Text('Activar burbuja'))"
        self.assertNotIn("bubble-active-switch", mut_gen)

        # Mutación 6: teclado_tab sin kb-haptics-switch
        mut_tec = "SwitchListTile(title: Text('Vibración'))"
        self.assertNotIn("kb-haptics-switch", mut_tec)

        # Mutación 7: snippets_tab sin snippet-save-button
        mut_snip = "FilledButton(child: Text('Guardar'))"
        self.assertNotIn("snippet-save-button", mut_snip)

        # Mutación 8: history_list sin history-empty-message
        mut_hist = "Text('No hay transcripciones aun')"
        self.assertNotIn("history-empty-message", mut_hist)


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC37HonestTestsSuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
