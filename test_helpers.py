#!/usr/bin/env python3
"""
Helpers compartidos de las suites Python de VoiceBubble STT.

Extrae la duplicación exacta que existía en test_clipboard_suite.py,
test_trackpad_suite.py y test_bubble_history_suite.py: el contador
global PASSED/FAILED y la función `check(name, condition, error_msg)`.

Formato de salida idéntico al original para no romper ningún parser:
  "  [PASS] <nombre>"
  "  [FAIL] <nombre> -> <detalle>"

Uso:
    from test_helpers import Suite
    suite = Suite()
    suite.check("algo existe", cond, "detalle si falla")
    ...
    sys.exit(suite.exit_code())
"""

import os

WORKSPACE = os.path.dirname(os.path.abspath(__file__))


class Suite:
    """Acumulador de resultados con el formato clásico de las suites."""

    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.failures = []

    def check(self, name, condition, error_msg=""):
        """Registra un assert; devuelve True/False para ramas condicionales."""
        if condition:
            print(f"  [PASS] {name}")
            self.passed += 1
            return True
        else:
            print(f"  [FAIL] {name} -> {error_msg}")
            self.failed += 1
            self.failures.append(name)
            return False

    def read(self, rel):
        """Lee un archivo del repo en UTF-8 (ruta relativa a la raíz)."""
        with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
            return f.read()

    def exit_code(self):
        """0 si todo pasó, 1 si hubo al menos un fallo (fallo real en CI)."""
        return 1 if self.failed > 0 else 0
