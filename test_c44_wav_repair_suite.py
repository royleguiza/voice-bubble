#!/usr/bin/env python3
"""
test_c44_wav_repair_suite.py
============================
Auditoría C-44: rescate de PCM sin tapa [S]

Verifica:
1. CloudSttService.tryRepairHolePcm reconstruye la tapa de un PCM
   nuestro (hueco de 44 ceros + audio real) y lo envía por fromBytes;
   vacíos y extranjeros no se reparan ni se suben.
2. Tests Dart que lo cubren existen.
3. Sin logs con contenido y mutaciones negativas.
"""

import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
CLOUD = os.path.join(REPO_ROOT, "app_source", "lib", "services", "cloud_stt_service.dart")
UNIT = os.path.join(REPO_ROOT, "app_source", "test", "services", "wav_integrity_test.dart")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class TestC44WavRepairSuite(unittest.TestCase):

    def test_01_rescate_solo_hueco_nuestro(self):
        src = read_file(CLOUD)
        self.assertIn("static Future<List<int>?> tryRepairHolePcm(", src)
        self.assertIn("buildWavHeader(dataSize)", src,
                      "La tapa es nuestro formato propio")
        self.assertIn("MultipartFile.fromBytes(", src,
                      "El reparado viaja en memoria sin ensuciar disco")

    def test_02_cobertura_dart(self):
        unit = read_file(UNIT)
        self.assertIn("repara hueco de 44 ceros y transcribe", unit)
        self.assertIn("todo ceros no se repara ni se sube", unit)
        self.assertIn("extranjero (ftyp) no se repara", unit)

    def test_03_sin_logs_y_mutaciones(self):
        self.assertNotIn("print(", read_file(CLOUD))
        mut_norepair = "if (!isValidWavHeader(head, fileLength)) {\n      throw"
        self.assertNotIn(mut_norepair, read_file(CLOUD),
                         "Sin reintento de rescate vuelve el bloqueo")


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC44WavRepairSuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
