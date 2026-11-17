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


# ---------------------------------------------------------------------------
# l10n (etapa 4, tanda A): los textos de la UI viven en app_es.arb y el código
# Dart usa `context.l10n.clave`. Las suites que buscaban el literal en español
# dentro de un .dart ahora leen la fuente "expandida": cada uso de una clave se
# reemplaza por su texto del ARB entre comillas simples. Así la aserción sigue
# comprobando lo mismo (el texto existe en app_es.arb Y el archivo usa su clave).
# ---------------------------------------------------------------------------
import json as _json
import re as _re

_ARB_PATH = os.path.join(WORKSPACE, "app_source", "lib", "l10n", "app_es.arb")
_L10N_USE = _re.compile(
    r"(?:\b\w+\.)?l10n\.(\w+)(\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\))?"
)


def _dart_quote(text):
    out = (text.replace("\\", "\\\\").replace("'", "\\'")
           .replace("$", "\\$").replace("\n", "\\n"))
    return "'" + out + "'"


def expand_l10n(src):
    """Reemplaza `context.l10n.clave[(...)]` por el texto es del ARB."""
    with open(_ARB_PATH, "r", encoding="utf-8") as f:
        arb = _json.load(f)

    def repl(m):
        key = m.group(1)
        if key in arb and isinstance(arb[key], str):
            return _dart_quote(arb[key])
        return m.group(0)

    return _L10N_USE.sub(repl, src)


def read_dart(rel):
    """Lee un .dart del repo con los textos l10n expandidos."""
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return expand_l10n(f.read())


def install_l10n_reader():
    """Hace que `open()` de un .dart bajo app_source/lib (salvo l10n/) devuelva
    la fuente con los textos l10n expandidos (ver `expand_l10n`)."""
    import builtins
    import io

    real_open = builtins.open
    lib_dir = os.path.join(WORKSPACE, "app_source", "lib")

    def patched(file, mode="r", *args, **kwargs):
        try:
            path = os.path.abspath(os.fspath(file))
        except TypeError:
            return real_open(file, mode, *args, **kwargs)
        if ("b" not in mode and "r" in mode and path.endswith(".dart")
                and path.startswith(lib_dir + os.sep)
                and os.sep + "l10n" + os.sep not in path):
            with real_open(path, "r", encoding="utf-8") as f:
                return io.StringIO(expand_l10n(f.read()))
        return real_open(file, mode, *args, **kwargs)

    builtins.open = patched

    import pathlib
    real_read_text = pathlib.Path.read_text

    def patched_read_text(self, encoding=None, errors=None):
        path = os.path.abspath(str(self))
        if (path.endswith(".dart") and path.startswith(lib_dir + os.sep)
                and os.sep + "l10n" + os.sep not in path):
            return expand_l10n(real_read_text(self, encoding="utf-8"))
        return real_read_text(self, encoding=encoding, errors=errors)

    pathlib.Path.read_text = patched_read_text
