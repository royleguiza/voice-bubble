#!/usr/bin/env python3
"""
Test Suite: Transcription History Repository & Cross-Process Synchronization.
Verifica sobre el código REAL (cero simulaciones locales):
1. El contrato de archivo 'transcription_history.json' es idéntico en Kotlin y Dart.
2. TranscriptionHistoryRepository en Kotlin implementa escritura atómica (.tmp + rename).
3. TranscriptionHistoryRepository en Kotlin soporta migración con prefijos Base64 de Flutter.
4. StorageService.add() en Dart sincroniza con load() antes de mutar (matcher
   por llaves balanceadas, sin regex frágil de un solo `}`).
5. FIFO-20 cross-platform: límites, orden por timestamp y escritura atómica
   assertionados en AMBOS archivos reales (Kotlin + Dart).
6. Comportamiento real actual de purga: CERO llamadas automáticas en todo el
   árbol (funciones muertas sin llamadores) + borrado explícito donde existe.
7. Resiliencia ante disco lleno: escrituras envueltas en try/catch.
"""

import os
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

KT_REPO = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryRepository.kt"
DART_STORE = "app_source/lib/services/storage_service.dart"


def extract_block(content, start_marker):
    """Extrae el bloque balanceado desde start_marker hasta su `}` de cierre.

    Cuenta llaves `{`/`}` ignorando strings "..." y comentarios // y /* */,
    así que el cuerpo de add()/load() se captura completo aunque contenga
    `}` internas (el regex anterior de un solo `}` se cortaba antes).
    """
    start = content.find(start_marker)
    assert start != -1, f"No se encontró el marcador: {start_marker}"
    brace = content.find("{", start)
    assert brace != -1, f"Sin llave de apertura tras: {start_marker}"
    depth = 0
    i = brace
    in_str = False
    in_line_comment = False
    in_block_comment = False
    while i < len(content):
        c = content[i]
        nxt = content[i + 1] if i + 1 < len(content) else ""
        if in_line_comment:
            if c == "\n":
                in_line_comment = False
        elif in_block_comment:
            if c == "*" and nxt == "/":
                in_block_comment = False
                i += 1
        elif in_str:
            if c == "\\":
                i += 1
            elif c == '"':
                in_str = False
        else:
            if c == "/" and nxt == "/":
                in_line_comment = True
                i += 1
            elif c == "/" and nxt == "*":
                in_block_comment = True
                i += 1
            elif c == '"':
                in_str = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return content[start:i + 1]
        i += 1
    raise AssertionError(f"Llaves desbalanceadas desde: {start_marker}")


def test_file_constants():
    print("  [TEST] Constante de archivo de historial idéntica en Kotlin y Dart...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    check('FILE_NAME real en Kotlin', 'FILE_NAME = "transcription_history.json"' in kt_content,
          "Falta FILE_NAME en Kotlin")
    check('historyFileName real en Dart', "historyFileName = 'transcription_history.json'" in dart_content,
          "Falta historyFileName en Dart")


def test_atomic_writes():
    print("  [TEST] Escritura atómica (.tmp + rename) implementada en Kotlin y Dart...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    check("Kotlin escribe a .tmp primero", "$FILE_NAME.tmp" in kt_content,
          "Kotlin debe escribir a .tmp primero")
    check("Kotlin usa renameTo con fallback a copyTo",
          "tmp.renameTo(targetFile)" in kt_content and "tmp.copyTo(targetFile, overwrite = true)" in kt_content,
          "Kotlin debe usar renameTo con fallback")
    check("Dart centraliza el sufijo .tmp",
          "static const String _historyTmpSuffix = '.tmp';" in dart_content,
          "Dart debe centralizar el sufijo .tmp")
    check("Dart escribe a .tmp primero",
          "'${file.path}$_historyTmpSuffix'" in dart_content,
          "Dart debe escribir a .tmp primero")
    check("Dart usa rename con fallback a copy",
          ("tmpFile.renameSync(file.path);" in dart_content
           or "await tmpFile.rename(file.path);" in dart_content)
          and ("tmpFile.copySync(file.path);" in dart_content
               or "await tmpFile.copy(file.path);" in dart_content),
          "Dart debe usar rename con fallback")


def test_flutter_prefix_handling():
    print("  [TEST] Manejo de prefijos Base64 de Flutter (VGhpcy...)...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()

    check("Kotlin busca corchete para ignorar prefijos", "indexOf('[')" in kt_content,
          "Kotlin debe buscar corchete para ignorar prefijos")
    check("Kotlin busca fin de array", "lastIndexOf(']')" in kt_content,
          "Kotlin debe buscar fin de array")


def test_stale_overwrite_prevention():
    print("  [TEST] Prevención de sobrescritura de estado en memoria en Dart...")
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    # Matcher por llaves balanceadas: captura add() COMPLETO aunque su
    # cuerpo contenga `}` internas (el regex anterior se cortaba en la
    # primera y producía falsos positivos/negativos).
    add_block = extract_block(dart_content, "Future<void> add(Transcription transcription)")
    check("add() sincroniza con disco antes de insertar",
          "_loadMergedWithoutPersist()" in add_block, "add() debe fusionar con disco antes de insertar")
    check("add() inserta al tope (índice 0)",
          "_transcriptions.insert(0, transcription);" in add_block,
          "add() debe insertar al tope")
    check("add() respeta el tope FIFO vía maxItems",
          "_transcriptions.sublist(0, maxItems)" in add_block,
          "add() debe capar con maxItems")
    check("add() persiste una sola vez (prefs + archivo atómico)",
          "await _persist();" in add_block,
          "add() debe persistir vía _persist()")


def test_cross_platform_fifo_real():
    print("  [TEST] FIFO-20 cross-platform sobre el código REAL de ambas plataformas...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    # Límites idénticos en ambos lados.
    check("Kotlin impone MAX_ITEMS = 20", "const val MAX_ITEMS = 20" in kt_content,
          "Kotlin debe capar en 20")
    check("Dart impone maxItems = 20", "static const int maxItems = 20;" in dart_content,
          "Dart debe capar en 20")

    # Orden temporal descendente en ambos lados.
    check("Kotlin ordena por timestamp descendente",
          "items.sortedByDescending { parseInstant(it) }" in kt_content,
          "Kotlin debe ordenar por timestamp desc")
    check("Dart ordena por timestamp descendente",
          "..sort((a, b) => b.timestamp.compareTo(a.timestamp));" in dart_content,
          "Dart debe ordenar por timestamp desc")

    # Deduplicación y tope en Kotlin.
    check("Kotlin deduplica por timestamp y capa en MAX_ITEMS",
          "dedupAndSort" in kt_content and "if (out.size >= MAX_ITEMS) break" in kt_content,
          "Kotlin debe deduplicar y capar")

    # Merge conservador en Dart: lo recién dictado en memoria sobrevive
    # aunque el disco aún no lo tenga (no pisa transcripción nueva).
    merge_block = extract_block(dart_content, "Future<List<Transcription>> _loadMergedWithoutPersist() async")
    check("Dart fusiona memoria+disco sin perder lo recién añadido",
          "Merge conservador" in merge_block and "putIfAbsent" in merge_block
          and "_historyIdentity" in merge_block,
          "_loadMergedWithoutPersist() debe fusionar sin pérdida")


def _call_sites(path, names, definition_markers):
    """Líneas que llaman a names, excluyendo sus definiciones y tests.

    También excluye la línea de continuación de una definición multilínea
    (p. ej. el `clearPreviousHistoryOnStartup();` del alias
    `purgePreviousSessionHistory() => ...`), detectada por la línea previa.
    """
    hits = []
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    for no, line in enumerate(lines, 1):
        stripped = line.strip()
        if any(d in line for d in definition_markers):
            continue
        prev = lines[no - 2] if no >= 2 else ""
        if any(d in prev for d in definition_markers) or "=>" in prev:
            continue
        for n in names:
            if n + "(" not in stripped:
                continue
            # Filtro fino: debe parecer invocación, no definición.
            if ("fun " + n in line) or ("Future<void> " + n in line) or "=>" in line:
                continue
            if "//" in line and line.index("//") < line.index(n):
                continue
            hits.append(f"{os.path.basename(path)}:{no} -> {stripped}")
    return hits


def test_no_automatic_purge():
    # Comportamiento real actual (2026-09-05, dueño): historial PERSISTENTE
    # FIFO-20. Las funciones de purga existen como código muerto (cero
    # llamadores): ningún arranque las invoca. NO hay UI de "borrar
    # historial" en Settings ni Home (solo borrado de snippets y de API
    # key, verificados por separado): el borrado explícito de historial
    # por usuario NO existe, así que no se exige.
    print("  [TEST] Sin purga automática: cero llamadores en Kotlin y Dart...")
    kt_files = []
    for root_dir, _, files in os.walk(os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin")):
        for f in files:
            if f.endswith(".kt"):
                kt_files.append(os.path.join(root_dir, f))
    dart_files = []
    for root_dir, _, files in os.walk(os.path.join(WORKSPACE, "app_source/lib")):
        for f in files:
            if f.endswith(".dart"):
                dart_files.append(os.path.join(root_dir, f))

    names = ["purgePreviousSessionHistory", "clearPreviousHistoryOnStartup"]
    callers = []
    for p in kt_files + dart_files:
        callers.extend(_call_sites(p, names, ["fun purgePreviousSessionHistory", "fun clearPreviousHistoryOnStartup",
                                              "Future<void> clearPreviousHistoryOnStartup",
                                              "Future<void> purgePreviousSessionHistory"]))
    check("CERO llamadas automáticas a purga en Kotlin/Dart",
          len(callers) == 0, f"Llamadores encontrados: {callers}")

    with open(os.path.join(WORKSPACE, "app_source/lib/main.dart"), "r", encoding="utf-8") as f:
        main_content = f.read()
    check("main.dart NO purga al arrancar",
          "clearPreviousHistoryOnStartup()" not in main_content
          and "purgePreviousSessionHistory()" not in main_content,
          "main.dart no debe purgar (persistente FIFO-20)")

    with open(os.path.join(WORKSPACE, "app_source/lib/screens/settings_screen.dart"), "r", encoding="utf-8") as f:
        settings = f.read()
    with open(os.path.join(WORKSPACE, "app_source/lib/screens/home_screen.dart"), "r", encoding="utf-8") as f:
        home = f.read()
    check("Sin botón de borrado de historial en Settings/Home (no se promete lo que no existe)",
          "clearHistory" not in settings and "deleteHistory" not in settings
          and "clearHistory" not in home and "deleteHistory" not in home
          and "borrar historial" not in settings.lower() and "borrar historial" not in home.lower(),
          "Apareció UI de borrado de historial no registrada")


def test_disk_full_resilience():
    print("  [TEST] Escritura resiliente ante disco lleno (excepción tragada, sin crash)...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    kt_save = extract_block(kt_content, "private fun saveAtomic(items: List<JSONObject>)")
    check("saveAtomic Kotlin envuelto en try/catch",
          kt_save.strip().startswith("private fun saveAtomic") and "try {" in kt_save and "catch (_: Exception) {}" in kt_save,
          "saveAtomic debe tragar el fallo de disco")
    dart_save = extract_block(dart_content, "Future<void> _saveHistoryFile() async")
    check("Dart _saveHistoryFile envuelto en try/catch",
          "try {" in dart_save and "} catch (_) {}" in dart_save,
          "_saveHistoryFile debe tragar el fallo de disco")


if __name__ == "__main__":
    print("=" * 60)
    print(" INICIANDO TEST SUITE: REPOSITORIO DE HISTORIAL PROFESIONAL")
    print("=" * 60)
    try:
        test_file_constants()
        test_atomic_writes()
        test_flutter_prefix_handling()
        test_stale_overwrite_prevention()
        test_cross_platform_fifo_real()
        test_no_automatic_purge()
        test_disk_full_resilience()
        print("=" * 60)
        if suite.failed > 0:
            print(f" RESULTADOS: {suite.passed} pasados, {suite.failed} fallidos.")
            print("=" * 60)
            sys.exit(1)
        print(" RESULTADOS: Todos los tests pasaron exitosamente.")
        print("=" * 60)
        sys.exit(0)
    except AssertionError as e:
        print(f"\n❌ ERROR: {e}")
        sys.exit(1)
