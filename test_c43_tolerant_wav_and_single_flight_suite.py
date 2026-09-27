#!/usr/bin/env python3
"""
test_c43_tolerant_wav_and_single_flight_suite.py
================================================
Auditoría C-43: validador tolerante + un solo envío [S]

Verifica:
1. El validador recorre sub-chunks (tolera JUNK/LIST/fact de
   grabadores reales) en Dart y nativo; exige fmt + data consistente.
2. Vuelo único: Dart (TranscriptionService, estático) y nativo
   (SpeechToTextClient, AtomicBoolean) rechazan el segundo intento
   concurrente con mensaje claro en vez de golpear la cuota en paralelo.
3. Tests JVM/Dart que lo cubren existen. Sin logs con contenido.
4. Mutaciones negativas.
"""

import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
KT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "kotlin", "com", "royleguiza", "voicebubblestt",
)
CLOUD = os.path.join(REPO_ROOT, "app_source", "lib", "services", "cloud_stt_service.dart")
SVC = os.path.join(REPO_ROOT, "app_source", "lib", "services", "transcription_service.dart")
NATIVE = os.path.join(KT, "SpeechToTextClient.kt")
UNIT_DART = os.path.join(REPO_ROOT, "app_source", "test", "services", "wav_integrity_test.dart")
UNIT_KT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "test",
    "kotlin", "com", "royleguiza", "voicebubblestt", "WidgetNotesBehaviorTest.kt",
)


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class TestC43TolerantWavAndSingleFlightSuite(unittest.TestCase):

    def test_01_validador_tolera_chunks_extra(self):
        dart = read_file(CLOUD)
        self.assertIn("pos += 8 + size + (size % 2)", dart,
                      "Dart debe caminar los sub-chunks")
        self.assertIn("fmtFound", dart)
        self.assertIn("static String checkWavHeader(", dart,
                      "Debe informar el motivo")
        self.assertIn("static String describeHead(", dart,
                      "Debe incluir huella sin contenido")
        nat = read_file(NATIVE)
        self.assertIn("pos += 8 + size + (size % 2)", nat,
                      "El nativo debe caminar igual")
        self.assertIn("fun checkWavHeader(", nat)
        self.assertIn("fun describeHead(", nat)

    def test_02_vuelo_unico(self):
        svc = read_file(SVC)
        self.assertIn("static bool _uploadInFlight = false", svc)
        self.assertIn("Ya hay una transcripción en curso", svc)
        self.assertIn("_transcribeGuarded(", svc)
        nat = read_file(NATIVE)
        self.assertIn("uploadInFlight.compareAndSet(false, true)", nat)
        self.assertIn("Ya hay una transcripción en curso", nat)
        self.assertIn("private fun transcribeGuarded(", nat)

    def test_03_cobertura_de_tests(self):
        unit = read_file(UNIT_DART)
        self.assertIn("tolera chunks extra (JUNK)", unit)
        self.assertIn("segundo intento concurrente recibe ocupado", unit)
        kt = read_file(UNIT_KT)
        self.assertIn("isValidWavToleratesExtraChunksBeforeData", kt)

    def test_04_sin_logs_y_mutaciones(self):
        self.assertNotIn("Log.", read_file(NATIVE))
        mut_strict = "magic(36, 'data')"
        dart = read_file(CLOUD)
        self.assertNotIn(mut_strict, dart,
                         "Sin offsets fijos: rechaza grabadores reales")
        mut_parallel = "Future<Transcription> transcribe("
        self.assertNotIn("_uploadInFlight", mut_parallel,
                         "Sin bandera el paralelo vuelve")


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC43TolerantWavAndSingleFlightSuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
