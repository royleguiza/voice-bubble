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


# ---------------------------------------------------------------------------
# l10n (etapa 4, tanda B): los textos de Kotlin y de los layouts XML viven en
# `res/values-es/strings.xml` de cada módulo (app y complemento). Al abrir un .kt o
# un layout .xml bajo `.../src/main`, `getString(R.string.x[, args])`,
# `R.string.x` y `@string/x` se sustituyen por el texto de su strings.xml (del
# mismo módulo). Las aserciones siguen comprobando lo mismo: que el texto exista
# en strings.xml y que el archivo use su clave. strings.xml no se expande.
# ---------------------------------------------------------------------------
import xml.etree.ElementTree as _ET

_ANDROID_MODULES = (
    os.path.join(WORKSPACE, "voice_bubble_stt", "android", "app", "src", "main"),
    os.path.join(WORKSPACE, "puntero_android", "app", "src", "main"),
)
_ANDROID_RES_CACHE = {}


def _android_unescape(text):
    """Texto de un <string> de Android tal como lo ve la persona."""
    text = text or ""
    if len(text) >= 2 and text.startswith('"') and text.endswith('"'):
        text = text[1:-1]
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            n = text[i + 1]
            if n == "u" and i + 5 < len(text) + 0:
                out.append(chr(int(text[i + 2:i + 6], 16)))
                i += 6
                continue
            out.append({"n": "\n", "t": "\t"}.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _android_strings(module_root):
    """({nombre: texto}, {plural: {cantidad: texto}}) de values-es/strings.xml (el español; el inglés es el default en values/)."""
    if module_root not in _ANDROID_RES_CACHE:
        tree = _ET.parse(os.path.join(module_root, "res", "values-es", "strings.xml"))
        strings, plurals = {}, {}
        for el in tree.getroot():
            if el.tag == "string":
                strings[el.get("name")] = _android_unescape("".join(el.itertext()))
            elif el.tag == "plurals":
                plurals[el.get("name")] = {
                    it.get("quantity"): _android_unescape("".join(it.itertext()))
                    for it in el.findall("item")
                }
        _ANDROID_RES_CACHE[module_root] = (strings, plurals)
    return _ANDROID_RES_CACHE[module_root]


def _android_module_of(path):
    for root in _ANDROID_MODULES:
        if path.startswith(root + os.sep):
            return root
    return None


def _kt_quote(text, args=()):
    """Literal Kotlin con `%N$s` sustituido por `${argumento}`."""
    out = text.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("\n", "\\n")
    for idx, a in enumerate(args, 1):
        simple = _re.fullmatch(r"[A-Za-z_]\w*", a) is not None
        for spec in ("%%%d\\$s" % idx, "%%%d\\$d" % idx):
            out = _re.sub(_re.escape(spec) + r"(\w?)",
                          lambda m: ("$" + a if simple and not m.group(1) else "${%s}" % a) + m.group(1), out)
    return '"' + out.replace("%%", "%") + '"'


def _split_args(src):
    """Parte `a, b(c, d), e` por comas de primer nivel."""
    args, depth, cur = [], 0, ""
    for ch in src:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            args.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        args.append(cur.strip())
    return args


def _expand_kotlin(src, module_root):
    strings, plurals = _android_strings(module_root)
    # 1) llamadas con receptor opcional: x.getString(R.string.k, a, b)
    call = _re.compile(r"(?:[\w.?]+\.)?(?:getString|getQuantityString)\(R\.(string|plurals)\.(\w+)")
    out, pos = [], 0
    while True:
        m = call.search(src, pos)
        if not m:
            out.append(src[pos:])
            break
        depth, j = 1, m.end()
        while j < len(src) and depth:
            depth += {"(": 1, ")": -1}.get(src[j], 0)
            j += 1
        args = [_expand_kotlin(a, module_root)
                for a in _split_args(src[m.end():j - 1].lstrip(", \n"))]
        kind, key = m.group(1), m.group(2)
        if kind == "string" and key in strings:
            rep = _kt_quote(strings[key], args)
        elif kind == "plurals" and key in plurals and args:
            n, rest = args[0], args[1:]
            rep = "if (%s == 1) %s else %s" % (
                n, _kt_quote(plurals[key]["one"].replace("%d", "1"), rest),
                _kt_quote(plurals[key]["other"].replace("%d", "%1$d"), rest))
        else:
            rep = src[m.start():j]
        out.append(src[pos:m.start()])
        out.append(rep)
        pos = j
    src = "".join(out)
    # 2) ids sueltos: R.string.k
    return _re.sub(r"\bR\.string\.(\w+)",
                   lambda m: _kt_quote(strings[m.group(1)]) if m.group(1) in strings else m.group(0), src)


def _expand_layout(src, module_root):
    strings, _ = _android_strings(module_root)
    def repl(m):
        k = m.group(1)
        if k not in strings:
            return m.group(0)
        return strings[k].replace("&", "&amp;").replace("<", "&lt;").replace('"', "&quot;")
    return _re.sub(r"@string/(\w+)", repl, src)


def expand_android(path, src):
    """Expande los recursos de texto de un .kt o de un layout .xml del módulo."""
    root = _android_module_of(path)
    if root is None:
        return src
    if path.endswith(".kt"):
        return _expand_kotlin(src, root)
    if path.endswith(".xml") and os.sep + "layout" + os.sep in path:
        return _expand_layout(src, root)
    return src


_REAL_OPEN = open


def raw_read(path):
    """Lee el archivo tal cual está en disco, sin expandir textos. Usarlo
    siempre que lo leído se vaya a volver a escribir (mutaciones que
    restauran el original): con el lector expandido, restaurar pegaría los
    textos dentro del código y borraría las claves."""
    with _REAL_OPEN(path, "r", encoding="utf-8") as f:
        return f.read()


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
        if ("b" not in mode and "r" in mode and path.endswith((".kt", ".xml"))
                and _android_module_of(path) and not path.endswith("strings.xml")):
            with real_open(path, "r", encoding="utf-8") as f:
                return io.StringIO(expand_android(path, f.read()))
        return real_open(file, mode, *args, **kwargs)

    builtins.open = patched

    import pathlib
    real_read_text = pathlib.Path.read_text

    def patched_read_text(self, encoding=None, errors=None):
        path = os.path.abspath(str(self))
        if (path.endswith(".dart") and path.startswith(lib_dir + os.sep)
                and os.sep + "l10n" + os.sep not in path):
            return expand_l10n(real_read_text(self, encoding="utf-8"))
        if (path.endswith((".kt", ".xml")) and _android_module_of(path)
                and not path.endswith("strings.xml")):
            return expand_android(path, real_read_text(self, encoding="utf-8"))
        return real_read_text(self, encoding=encoding, errors=errors)

    pathlib.Path.read_text = patched_read_text
