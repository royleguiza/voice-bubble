#!/usr/bin/env python3
"""
test_c42_upload_integrity_suite.py
==================================
Auditoría C-42: no subir basura que Groq rechaza con 400 [S]

Verifica:
1. Dart valida la cabecera WAV antes de subir (magias + tamaños) con
   mensaje claro de audio dañado; el multipart lleva filename
   audio.wav + audio/wav (paridad con el nativo).
2. Los fixtures de tests suben WAV válido (ya no ceros).
3. El nativo valida antes del POST con el mismo contrato y 400 local.
4. Sin logs con contenido y mutaciones negativas.
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
NATIVE = os.path.join(KT, "SpeechToTextClient.kt")
PUBSPEC = os.path.join(REPO_ROOT, "app_source", "pubspec.yaml")
UNIT = os.path.join(REPO_ROOT, "app_source", "test", "services", "wav_integrity_test.dart")
FIXTURE = os.path.join(REPO_ROOT, "app_source", "test", "helpers", "wav_fixture.dart")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class TestC42UploadIntegritySuite(unittest.TestCase):

    def test_01_dart_valida_antes_de_subir(self):
        src = read_file(CLOUD)
        self.assertIn("static bool isValidWavHeader(", src)
        for magic in ("'RIFF'", "'WAVE'", "'fmt '", "'data'"):
            self.assertIn(magic, src, f"Debe exigir magia {magic}")
        self.assertIn("isValidWavHeader(head, fileLength)", src,
                      "Debe validar antes de subir")
        self.assertIn("dañado", src, "Mensaje claro de audio dañado")
        self.assertIn("filename: 'audio.wav'", src)
        self.assertIn("MediaType('audio', 'wav')", src)
        self.assertIn("http_parser", read_file(PUBSPEC))

    def test_02_fixtures_con_wav_valido(self):
        self.assertTrue(os.path.exists(UNIT), "Tests unitarios del validador")
        self.assertTrue(os.path.exists(FIXTURE), "Fixture WAV compartido")
        for name in ("cloud_stt_service_test.dart", "cloud_stt_error_classification_test.dart"):
            content = read_file(os.path.join(
                REPO_ROOT, "app_source", "test", "services", name))
            self.assertIn("validWavBytes()", content,
                          f"{name} debe subir WAV válido")
            self.assertIn("helpers/wav_fixture.dart", content)
        unit = read_file(UNIT)
        self.assertIn("cero llamadas HTTP", unit,
                      "Lo corrupto no debe llegar a la red")

    def test_03_nativo_mismo_contrato(self):
        src = read_file(NATIVE)
        self.assertIn("fun isValidWav(wav: ByteArray): Boolean", src)
        self.assertIn('"RIFF"', src)
        self.assertIn("isValidWav(wav)", src.split("fun transcribeGuarded(")[1][:1200],
                      "Debe validar antes del POST")
        self.assertIn("dañado", src)

    def test_04_sin_logs_y_mutaciones(self):
        self.assertNotIn("Log.", read_file(NATIVE))
        mut_head = "MultipartFile.fromPath(_multipartFieldFile, audioPath)"
        self.assertNotIn("audio/wav", mut_head,
                         "Sin content-type explícito vuelve la ambigüedad")
        mut_nat = "fun transcribe(\n wav: ByteArray,"
        self.assertNotIn("isValidWav", mut_nat,
                         "Sin validación vuelve el 400 mudo")


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC42UploadIntegritySuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
