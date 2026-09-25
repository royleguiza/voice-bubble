#!/usr/bin/env python3
"""
Guardas estáticas del contrato de historial; la cobertura funcional la ejecuta
la clase Kotlin/JUnit real desde CI. Verifica sobre el código REAL:
1. El contrato de archivo 'transcription_history.json' es idéntico en Kotlin y Dart.
2. TranscriptionHistoryRepository en Kotlin publica con move atómico, sin fallback copy.
3. El repositorio Kotlin mergea archivo + StringList JSON de Flutter y descarta lo inválido.
4. addTranscription() serializa read-merge-write completo bajo el lock compartido.
5. StorageService.add() en Dart sincroniza con load() antes de mutar (matcher
   por llaves balanceadas, sin regex frágil de un solo `}`).
6. FIFO-20 cross-platform: límites, orden por timestamp y escritura atómica
   assertionados en AMBOS archivos reales (Kotlin + Dart).
7. Comportamiento real actual de purga: CERO llamadas automáticas en todo el
   árbol (funciones muertas sin llamadores) + borrado explícito donde existe.
8. Resiliencia ante disco lleno: escrituras reportan fallo y conservan el archivo anterior.
9. La prueba Kotlin/JUnit cruza addTranscription, concurrencia y fuentes mixtas; CI la ejecuta.
"""

import os
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

KT_REPO = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryRepository.kt"
KT_LOGIC = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryLogic.kt"
KT_TEST = "voice_bubble_stt/android/app/src/test/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryLogicTest.kt"
KT_BUILD = "voice_bubble_stt/android/app/build.gradle.kts"
DART_STORE = "app_source/lib/services/storage_service.dart"
DART_TEST = "app_source/test/services/history_bridge_contract_test.dart"
PUBSPEC = "app_source/pubspec.yaml"
WRAPPER = "voice_bubble_stt/android/gradle/wrapper/gradle-wrapper.properties"
WORKFLOW = ".github/workflows/android.yml"


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
    print("  [GUARD] Constante de archivo de historial idéntica en Kotlin y Dart...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    check('FILE_NAME real en Kotlin', 'FILE_NAME = "transcription_history.json"' in kt_content,
          "Falta FILE_NAME en Kotlin")
    check('historyFileName real en Dart', "historyFileName = 'transcription_history.json'" in dart_content,
          "Falta historyFileName en Dart")


def test_atomic_writes():
    print("  [GUARD] Publicación atómica real sin fallback copy en Kotlin y Dart...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    dart_save = extract_block(dart_content, "Future<bool> _saveHistoryFile() async")
    dart_publish = extract_block(dart_content, "bool publishHistoryFileAtomically")
    check("Kotlin publica con Files.move atómico",
          "Files.move(" in kt_content and
          "Files.createTempFile(" in kt_content and
          "StandardCopyOption.ATOMIC_MOVE" in kt_content and
          "StandardCopyOption.REPLACE_EXISTING" in kt_content,
          "Kotlin debe usar createTempFile + ATOMIC_MOVE + REPLACE_EXISTING")
    check("Kotlin no tiene fallback copy sobre el archivo publicado",
          "copyTo(" not in kt_content and "renameTo(targetFile)" not in kt_content,
          "Kotlin no debe copiar encima del archivo vivo")
    check("Kotlin reporta fallo de publicación atómica",
          "throw IOException" in kt_content and "return false" in kt_content,
          "Kotlin debe propagar el fallo al repositorio")
    check("Kotlin usa temporales únicos por escritor",
          "${TranscriptionHistoryRepository.FILE_NAME}." in kt_content and
          "Files.createTempFile(" in kt_content and
          "${TranscriptionHistoryRepository.FILE_NAME}.tmp" not in kt_content,
          "Kotlin no debe usar un temporal fijo compartido")
    check("Dart centraliza el sufijo .tmp",
          "static const String _historyTmpSuffix = '.tmp';" in dart_content,
          "Dart debe centralizar el sufijo .tmp")
    check("Dart publica con rename atómico",
          "tmpFile.renameSync(file.path);" in dart_publish and
          "publishHistoryFileAtomically" in dart_save,
          "Dart debe publicar por el adaptador atómico real")
    check("Dart usa temporales únicos por escritor",
          "${file.path}.$token$_historyTmpSuffix" in dart_publish and
          "Random.secure()" in dart_publish and
          "${file.path}$_historyTmpSuffix" not in dart_publish,
          "Dart no debe usar un temporal fijo compartido")
    check("Dart no tiene fallback copy sobre el archivo publicado",
          "copySync(" not in dart_publish and "copy(" not in dart_publish,
          "Dart no debe copiar encima del archivo vivo")
    check("Dart reporta fallo de publicación atómica",
          "return false" in dart_publish and "catch (_) {" in dart_publish,
          "Dart debe devolver fallo y conservar el destino")


def test_repository_rmw_serialization():
    print("  [GUARD] Lock cross-runtime bloqueante con timeout y stale...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    add_block = extract_block(kt_content, "fun addTranscription")
    lock_block = extract_block(add_block, "withTranscriptionHistoryFileLock")
    check("Kotlin usa lock cooperativo con timeout y stale",
          "acquireTranscriptionHistoryLock" in kt_content and
          "releaseTranscriptionHistoryLock" in kt_content and
          "HISTORY_LOCK_TIMEOUT_MS" in kt_content and
          "HISTORY_LOCK_STALE_MS" in kt_content and
          "Files.createFile(" in kt_content and
          "FileAlreadyExistsException" in kt_content and
          "getLastModifiedTime" in kt_content and
          "deleteIfExists" in kt_content and
          'LOCK_FILE_NAME = "$FILE_NAME.lock"' in kt_content,
          "El lock debe ser bloqueante con timeout y recuperar stale")
    check("Kotlin no usa monitor JVM ni FileLock no bloqueante",
          "synchronized(historyProcessLock)" not in kt_content and
          "RandomAccessFile(lockFile" not in kt_content and
          "channel.lock()" not in kt_content and
          "tryLock" not in kt_content,
          "Ni monitor JVM ni FileLock no bloqueante resuelven cross-runtime")
    check("Kotlin mantiene read-merge-write bajo el lock",
          all(marker in lock_block for marker in (
              "loadRecords()",
              "TranscriptionHistoryLogic.normalize",
              "saveAtomic",
          )),
          "read-merge-write completo debe quedar dentro del lock de archivo")
    check("No hay lectura RMW antes del lock Kotlin",
          "loadRecords()" not in add_block[:add_block.index("withTranscriptionHistoryFileLock")],
          "La lectura de archivo+prefs debe ocurrir bajo el lock")
    check("Dart usa el mismo lock cooperativo en el mismo path",
          "withTranscriptionHistoryFileLock" in dart_content and
          "historyLockTimeoutMs" in dart_content and
          "historyLockStaleMs" in dart_content and
          "createSync(exclusive: true)" in dart_content and
          "lastModifiedSync" in dart_content and
          "historyLockFileName = 'transcription_history.json.lock'" in dart_content,
          "Dart y Kotlin deben usar el mismo lock de archivo")
    check("Dart no usa FileLock no bloqueante",
          "FileLock.exclusive" not in dart_content and
          "lockHandle.lock" not in dart_content and
          "lockHandle.unlock" not in dart_content,
          "FileLock no bloqueante no resuelve cross-runtime")
    dart_add = extract_block(dart_content, "Future<bool> add(Transcription transcription)")
    check("Dart adquiere lock antes de leer y publica dentro",
          dart_add.index("withTranscriptionHistoryFileLock") < dart_add.index("_loadMergedEntriesWithoutPersist") < dart_add.index("_persist"),
          "add() Dart debe mantener el lock durante todo el RMW")
    check("Dart no usa lock JVM como único mecanismo",
          "synchronized(lock)" not in dart_content and
          "historyLockFileName" in dart_content,
          "El lock de archivo debe ser la coordinación primaria")


def test_flutter_string_list_merge():
    print("  [GUARD] Merge real de archivo + StringList JSON de Flutter...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, KT_LOGIC), "r", encoding="utf-8") as f:
        logic_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()
    with open(os.path.join(WORKSPACE, PUBSPEC), "r", encoding="utf-8") as f:
        pubspec = f.read()

    check("Kotlin declara la clave flutter.transcriptions",
          'SHARED_HISTORY_KEY = "flutter.transcriptions"' in kt_content,
          "Kotlin debe leer la clave real del puente")
    check("Kotlin lee el valor String de FlutterSharedPreferences",
          "readFlutterStringList()" in kt_content and
          ".getString(" in kt_content,
          "Kotlin debe usar getString sobre FlutterSharedPreferences")
    check("Kotlin decodifica el prefijo JSON de StringList",
          "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!" in logic_content and
          "JSON_LIST_PREFIX" in logic_content and
          "decodeFlutterStringList" in kt_content and
          "raw.startsWith(JSON_LIST_PREFIX)" in logic_content and
          "raw.trim()" not in logic_content,
          "Kotlin debe aceptar el formato JSON actual, no XML/StringSet")
    check("Kotlin mergea archivo y prefs aunque falte el archivo",
          "readFileEntries()" in kt_content and
          "readPreferencesEntries()" in kt_content and
          "TranscriptionHistoryLogic.mergeRecords(" in kt_content,
          "loadHistory debe consultar ambas fuentes")
    check("Kotlin no reintroduce StringSet, XML ni Base64",
          "getStringSet" not in kt_content + logic_content and
          "android.util.Xml" not in kt_content + logic_content and
          "XmlPullParser" not in kt_content + logic_content and
          "migrateFromLegacySources" not in kt_content + logic_content and
          "Base64" not in kt_content + logic_content,
          "La migración legacy debe permanecer eliminada")
    check("Dart lee y persiste StringList real",
          "prefs.getStringList(_key)" in dart_content and
          "prefs.setStringList(_key" in dart_content,
          "StorageService debe usar la API StringList actual")
    check("El prefijo JSON de shared_preferences está fijado sin pin incompatible",
          "shared_preferences_android: 2.4.15" not in pubspec and
          "shared_preferences:" in pubspec and
          "raw.startsWith(JSON_LIST_PREFIX)" in logic_content,
          "Sin pin incompatible; el prefijo exacto se conserva vía transitivo")


def test_stale_overwrite_prevention():
    print("  [GUARD] Prevención de sobrescritura de estado en memoria en Dart...")
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    # Matcher por llaves balanceadas: captura add() COMPLETO aunque su
    # cuerpo contenga `}` internas (el regex anterior se cortaba en la
    # primera y producía falsos positivos/negativos).
    add_block = extract_block(dart_content, "Future<bool> add(Transcription transcription)")
    check("add() sincroniza con disco antes de mutar",
          "_loadMergedEntriesWithoutPersist()" in add_block,
          "add() debe fusionar con archivo y prefs antes de mutar")
    check("add() deduplica por identidad antes de ordenar",
          "_normalizeHistoryEntries(candidates)" in add_block and
          "_historyIdentity(entry.transcription)" in dart_content,
          "add() debe colapsar la entrada idéntica")
    check("add() ordena por timestamp descendente",
          "_compareHistoryEntries" in dart_content and
          "b.transcription.timestamp.compareTo(a.transcription.timestamp)" in dart_content,
          "add() debe ordenar el historial")
    check("add() usa precedencia de fuente e índice",
          "source: _historySourceMemory" in add_block and
          "entry.index + 1" in add_block,
          "add() debe hacer explícito el desempate")
    check("add() respeta el tope FIFO vía maxItems",
          "normalized.length > maxItems" in dart_content and
          "normalized.sublist(0, maxItems)" in dart_content,
          "add() debe capar con maxItems")
    check("add() persiste una sola vez (prefs + archivo atómico)",
          "final saved = await _persist();" in add_block and
          "return saved;" in add_block,
          "add() debe persistir vía _persist()")


def test_cross_platform_fifo_real():
    print("  [GUARD] FIFO-20 cross-platform sobre el código REAL de ambas plataformas...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    with open(os.path.join(WORKSPACE, KT_LOGIC), "r", encoding="utf-8") as f:
        logic_content = f.read()

    check("Kotlin impone MAX_ITEMS = 20",
          "const val MAX_ITEMS = 20" in logic_content and
          "const val MAX_ITEMS = 20" in kt_content,
          "Kotlin debe capar en 20")
    check("Dart impone maxItems = 20", "static const int maxItems = 20;" in dart_content,
          "Dart debe capar en 20")

    check("Kotlin ordena por timestamp descendente",
          "compareByDescending" in logic_content and
          "truncatedTo(ChronoUnit.MICROS)" in logic_content,
          "Kotlin debe ordenar por instante truncado a micros")
    check("Dart ordena por timestamp descendente",
          "_compareHistoryEntries" in dart_content and
          "b.transcription.timestamp.compareTo(a.transcription.timestamp)" in dart_content,
          "Dart debe ordenar por timestamp desc")
    check("Dart desempata por fuente e indice",
          "a.source.compareTo(b.source)" in dart_content and
          "a.index.compareTo(b.index)" in dart_content,
          "Dart debe hacer explicito el tie-breaker")

    check("Kotlin deduplica por timestamp ISO + texto y capa",
          "canonicalTimestamp" in logic_content and
          "seen.add(identity)" in logic_content and
          "record.text" in logic_content and
          "if (out.size >= MAX_ITEMS) break" in logic_content,
          "Kotlin debe deduplicar por identidad y aplicar FIFO")
    check("Kotlin usa la misma logica para archivo y StringList",
          "TranscriptionHistoryLogic.mergeRecords(" in kt_content and
          "readFileEntries()" in kt_content and
          "readPreferencesEntries()" in kt_content,
          "Ambas fuentes deben entrar al mismo merge")

    merge_block = extract_block(
        dart_content,
        "Future<List<_HistoryEntry>?> _loadMergedEntriesWithoutPersist() async",
    )
    check("Dart fusiona memoria+archivo+prefs sin perder lo reciente",
          "...memoryEntries" in merge_block and
          "...fileEntries" in merge_block and
          "...prefsEntries" in merge_block and
          "_normalizeHistoryEntries" in merge_block,
          "_loadMergedEntriesWithoutPersist() debe fusionar las tres fuentes")
    check("Dart valida formatos zoned y legacy solo en historial",
          "_historyTimestampPattern" in dart_content and
          "_legacyHistoryTimestampPattern" in dart_content and
          "_parseHistoryTimestamp" in dart_content and
          "DateTime.tryParse(raw)" not in dart_content,
          "El parser de historial debe aceptar legacy sin tocar C-21")
    check("Kotlin valida calendario y trunca microsegundos",
          "ResolverStyle.STRICT" in logic_content and
          "match.groupValues[3]" in logic_content and
          "fraction.padEnd(6, '0').take(6)" in logic_content,
          "Kotlin debe usar la misma gramática estricta que Dart")
    check("La regla de blank Unicode es explícita en ambos lados",
          "isBlankText" in logic_content and
          "_isBlankHistoryText" in dart_content and
          "0x001C" in logic_content and "0x001C" in dart_content and
          "0xFEFF" in logic_content and "0xFEFF" in dart_content,
          "Dart y Kotlin deben compartir la regla de whitespace")
    history_start = dart_content.find("static const String historyFileName")
    history_end = dart_content.find("// --- Credenciales", history_start)
    history_block = dart_content[history_start:history_end]
    check("Las rutas C-02 no usan el fallback de Transcription.fromJson",
          "Transcription.fromJson" not in history_block,
          "C-21 debe quedar fuera del parser de historial")


def test_history_safety_and_parity_guards():
    print("  [GUARD] Estados de lectura, canonicalización, overflow y retorno C-02...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_repo = f.read()
    with open(os.path.join(WORKSPACE, KT_LOGIC), "r", encoding="utf-8") as f:
        kt_logic = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart = f.read()
    with open(os.path.join(WORKSPACE, KT_TEST), "r", encoding="utf-8") as f:
        native_test = f.read()
    with open(os.path.join(WORKSPACE, DART_TEST), "r", encoding="utf-8") as f:
        dart_test = f.read()
    with open(os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/MainActivity.kt"), "r", encoding="utf-8") as f:
        main = f.read()

    check("Lectura Kotlin distingue missing, content, corrupt y error",
          all(marker in kt_repo for marker in (
              "TranscriptionHistoryReadResult.Missing",
              "TranscriptionHistoryReadResult.Content",
              "TranscriptionHistoryReadResult.Corrupt",
              "TranscriptionHistoryReadResult.Error",
              "RecordsResult.Failure",
          )),
          "El repositorio no debe convertir una excepción en lista vacía")
    check("Lectura Dart distingue missing, content, corrupt y error",
          all(marker in dart for marker in (
              "_HistoryReadStatus.missing",
              "_HistoryReadStatus.content",
              "_HistoryReadStatus.corrupt",
              "_HistoryReadStatus.error",
              "if (merged == null) return false;",
          )),
          "Dart no debe convertir corrupto en vacío seguido de overwrite")
    check("Producción y test comparten adaptador de archivo",
          "FileTranscriptionHistoryStorage(" in kt_repo and
          "FileTranscriptionHistoryStorage" in native_test,
          "El test debe ejecutar la pieza usada por producción")
    check("addTranscription bloquea publish si falla una lectura",
          "is RecordsResult.Failure -> false" in kt_repo and
          "readHistoryFile()" in kt_repo,
          "Una lectura existente fallida debe devolver false")
    check("Kotlin canonicaliza JSONObject antes de devolver y guardar",
          "canonicalObject(text, instant)" in kt_repo and
          "canonicalTimestamp" in kt_logic and
          "repositoryCanonicalizesPayloadBeforeReturningAndPublishing" in native_test,
          "No debe preservar offsets ni precisión no canónica")
    check("Overflow legacy Kotlin valida año UTC",
          "validatesLegacyOverflowAfterUtcConversionInBothOffsetDirections" in native_test,
          "Kotlin debe probar 0000/9999 en offsets positivo y negativo")
    check("Overflow legacy Dart convierte antes de validar",
          "legacyOffsetMinutes" in dart and
          "DateTime.utc(" in dart and
          "_validHistoryYear(instant)" in dart and
          "historyLegacyOffsetMinutes: 120" in dart_test and
          "historyLegacyOffsetMinutes: -120" in dart_test,
          "Dart debe validar el año UTC después de convertir")
    check("Dart bloquea add si la lectura devuelve error",
          "_HistoryReadStatus.error" in dart and
          "if (merged == null) return false;" in dart and
          "no publica cuando falla la lectura" in dart_test,
          "Dart no debe sobrescribir un archivo existente ilegible")
    check("Dart trata JSON corrupto como fallo sin overwrite",
          "if (decoded is! List<dynamic>) return null;" in dart and
          dart.count("return null;") >= 3,
          "JSON corrupto no puede volverse lista vacía seguida de overwrite")
    check("Kotlin trata JSON corrupto como Failure sin overwrite",
          'RecordsResult.Failure(IOException("historial corrupto"' in kt_repo and
          'RecordsResult.Failure(IOException("prefs corruptas"' in kt_repo,
          "JSON corrupto debe bloquear publish")
    push_block = extract_block(main, '"pushHistoryEntry" ->')
    check("MainActivity propaga el Boolean de addTranscription",
          ".addTranscription(text, timestamp)" in push_block and
          "true\n" not in push_block,
          "El canal no debe mentir true cuando add devuelve false")
    check("Archivos Kotlin C-02 versionables con contenido real en índice",
          os.path.isfile(os.path.join(WORKSPACE, KT_LOGIC)) and
          os.path.isfile(os.path.join(WORKSPACE, KT_TEST)) and
          "TranscriptionHistoryLogic" in kt_repo and
          "TranscriptionHistoryLogicTest" in native_test,
          "Los archivos Kotlin nuevos deben estar versionables")


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
    print("  [GUARD] Sin purga automática: cero llamadores en Kotlin y Dart...")
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
    print("  [GUARD] Escritura resiliente ante disco lleno (resultado falso, sin crash)...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart_content = f.read()

    kt_save = extract_block(kt_content, "private fun saveAtomic(items: List<JSONObject>): Boolean")
    check("saveAtomic Kotlin convierte el fallo en resultado falso",
          kt_save.strip().startswith("private fun saveAtomic") and
          "try {" in kt_save and "return false" in kt_save,
          "saveAtomic debe reportar el fallo de disco")
    dart_save = extract_block(dart_content, "Future<bool> _saveHistoryFile() async")
    check("Dart _saveHistoryFile convierte el fallo en resultado falso",
          "try {" in dart_save and "return false" in dart_save,
          "_saveHistoryFile debe reportar el fallo de disco")


def test_single_identity_no_window():
    print("  [GUARD] SPK-04: identidad única, sin ventana temporal ni espejo lateral...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(os.path.join(WORKSPACE, "app_source/lib/services/floating_bubble_service.dart"),
              "r", encoding="utf-8") as f:
        bubble = f.read()
    with open(os.path.join(WORKSPACE, "app_source/lib/screens/home_screen.dart"),
              "r", encoding="utf-8") as f:
        home = f.read()
    with open(os.path.join(WORKSPACE,
              "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/MainActivity.kt"),
              "r", encoding="utf-8") as f:
        main = f.read()

    check("Sin ventana anti-eco temporal", "DEDUP_TEXT_WINDOW_MS" not in kt_content,
          "La ventana de 30 s tragaba dictados legítimos")
    check("Sin guarda isEcho", "isEcho" not in kt_content,
          "La curita del doble timestamp debe desaparecer")
    check("Sin espejo lateral a prefs", "mirrorToSharedPreferences" not in kt_content,
          "El espejo StringSet envenenaba la clave con otro tipo")
    check("addTranscription usa timestamp estricto",
          "timestampIso" in kt_content and
          "TranscriptionHistoryLogic.parseTimestamp(timestampIso)" in kt_content,
          "La identidad debe rechazar timestamps no canónicos")
    check("Dart envía el timestamp ya persistido",
          "'timestamp'" in bubble and "toUtc().toIso8601String()" in bubble,
          "pushHistoryEntry debe llevar el timestamp UTC")
    check("Home publica con su timestamp",
          "pushHistoryEntry(result.text," in home and "timestamp: result.timestamp" in home,
          "La app debe reenviar su propio timestamp")
    check("El canal reenvía el timestamp al repo",
          'call.argument<String>("timestamp")' in main
          and ".addTranscription(text, timestamp)" in main,
          "MainActivity debe pasar el timestamp")


def test_native_kotlin_history_guard():
    print("  [GUARD] Contrato Kotlin/JUnit ejecutable desde CI...")
    test_path = os.path.join(WORKSPACE, KT_TEST)
    assert os.path.isfile(test_path), f"No existe test nativo: {KT_TEST}"
    with open(test_path, "r", encoding="utf-8") as f:
        test_content = f.read()
    with open(os.path.join(WORKSPACE, WORKFLOW), "r", encoding="utf-8") as f:
        workflow = f.read()
    with open(os.path.join(WORKSPACE, KT_BUILD), "r", encoding="utf-8") as f:
        build = f.read()
    with open(os.path.join(WORKSPACE, WRAPPER), "r", encoding="utf-8") as f:
        wrapper = f.read()

    check("La prueba nativa usa JUnit",
          "@Test" in test_content and "TranscriptionHistoryLogicTest" in test_content,
          "El test Kotlin debe contener casos JUnit reales")
    check("La prueba nativa cubre merge, duplicados, inválidos, overflow y FIFO",
          all(case in test_content for case in (
              "mergesFileAndStringListEntries",
              "keepsDifferentTextsAtTheSameInstant",
              "collapsesDuplicateAcrossTimezoneAndSubMicrosecondPrecision",
              "rejectsNonCanonicalAndInvalidTimestamps",
              "validatesLegacyOverflowAfterUtcConversionInBothOffsetDirections",
              "appliesFifoAfterMergeAndDeduplication",
          )),
          "Faltan casos de contrato C-02 en Kotlin")
    check("La prueba nativa usa el adaptador productivo de archivo",
          "FileTranscriptionHistoryStorage" in test_content and
          "productionPublisherUsesAtomicMoveAndCleansTemporaryFiles" in test_content and
          "productionPublisherReportsRealMoveFailure" in test_content and
          "TemporaryHistoryStorage" not in test_content and
          "file.writeText(contents" not in test_content,
          "El test debe ejecutar el mismo Files.move que usa producción")
    check("La prueba nativa ejercita addTranscription y el repositorio real",
          "addTranscription(" in test_content and
          "repositoryAddReadsFileAndPreferencesBeforePublishing" in test_content and
          "repositoryReportsAtomicWriteFailureAndKeepsPublishedFile" in test_content and
          "TranscriptionHistoryStorage" in test_content,
          "El test debe traverser addTranscription sobre el repositorio de producción")
    check("La prueba nativa cubre concurrencia sin sleeps",
          "concurrentAddsFromSeparateRepositoriesKeepBothEntries" in test_content and
          "concurrentReaderNeverSeesPartialJson" in test_content and
          "CyclicBarrier" in test_content and
          "Executors" in test_content and
          "TimeUnit" in test_content and
          "Thread.sleep" not in test_content,
          "Falta una prueba concurrente determinista")
    check("La prueba nativa mezcla MEMORY, FILE y PREFERENCES con 33 empates",
          "repositoryAddMergesMemoryFilePreferencesWithThirtyThreeTiedEntries" in test_content and
          "normalizesThirtyThreeTiedEntriesAcrossAllSources" in test_content and
          "TranscriptionHistorySource.MEMORY" in test_content and
          "TranscriptionHistorySource.FILE" in test_content and
          "TranscriptionHistorySource.PREFERENCES" in test_content and
          "file-" in test_content and "prefs-" in test_content and
          "memory" in test_content and "0 until 16" in test_content and
          "0 until 3" in test_content,
          "Falta la mezcla de las tres fuentes con 33 empates")
    check("La prueba nativa cubre duplicado previo al corte, vacío y preservación",
          "repositoryAddCollapsesDuplicateBeforeFifoCut" in test_content and
          "repositoryAddRejectsEmptyTextWithoutChangingPublishedFile" in test_content and
          "repositoryReportsAtomicWriteFailureAndKeepsPublishedFile" in test_content and
          "repositoryDoesNotPublishWhenExistingFileReadFails" in test_content and
          "productionStorageReportsReadErrorForExistingUnreadablePath" in test_content,
          "Faltan las regresiones de dedup, texto vacío, lectura o fallo atómico")
    check("La prueba nativa fija zonas locales no UTC explícitas",
          "repositoryParsesLegacyLocalTimestampsInExplicitNonUtcZone" in test_content and
          "ZoneId.of(\"America/Argentina/Buenos_Aires\")" in test_content and
          "ZoneId.of(\"+02:00\")" in test_content and
          "ZoneId.of(\"-02:00\")" in test_content and
          "ZoneId.systemDefault()" not in test_content,
          "El test no debe depender de la zona por defecto de la máquina")
    check("La prueba nativa prueba payload canónico",
          "repositoryCanonicalizesPayloadBeforeReturningAndPublishing" in test_content and
          "canonicalEntry(" in test_content and
          "1234567" in test_content and "+02:00" in test_content,
          "El payload Kotlin no debe conservar offset ni septimo decimal")
    check("CI ejecuta testDebugUnitTest con la clase C-02 antes del APK",
          "testDebugUnitTest" in workflow and
          "TranscriptionHistoryLogicTest" in workflow and
          "--tests" in workflow and
          workflow.index("Pub get") < workflow.index("Preparar local.properties") < workflow.index("testDebugUnitTest") and
          workflow.index("testDebugUnitTest") < workflow.index("flutter build apk") and
          workflow.index("testDebugUnitTest") < workflow.index("Upload APK arm64"),
          "El test nativo debe ejecutarse después de pub get y antes de construir o subir")
    check("El test native tiene local.properties reproducible",
          "FLUTTER_ROOT" in workflow and "flutter.sdk=" in workflow and
          "sdk.dir=" in workflow and
          "voice_bubble_stt/android/local.properties" in workflow,
          "Gradle debe recibir el SDK y Flutter antes de testear")
    check("CI fija la versión de Gradle",
          "gradle/actions/setup-gradle" in workflow and
          "gradle-version: '9.3.1'" in workflow and
          "gradle --no-daemon :app:testDebugUnitTest" in workflow and
          "gradle-9.3.1-all.zip" in wrapper,
          "El runner y el wrapper deben usar la versión pinada")
    java_start = workflow.find("uses: actions/setup-java")
    java_end = workflow.find("\n      - name:", java_start + 1)
    java_step = workflow[java_start:java_end] if java_start >= 0 and java_end >= 0 else ""
    check("CI tiene un solo mecanismo de cache Gradle",
          workflow.count("gradle/actions/setup-gradle") == 1 and
          "cache: gradle" not in workflow and
          "cache: gradle" not in java_step,
          "setup-java no debe duplicar el cache de setup-gradle")
    check("JUnit y org.json están declarados en el proyecto real",
          'testImplementation("junit:junit:4.13.2")' in build and
          'testImplementation("org.json:json:20240303")' in build,
          "Las dependencias no deben inyectarse con init script")
    check("No hay fallback de Gradle ni init script",
          "--init-script" not in workflow and
          "command -v gradle" not in workflow and
          "runner=gradle" not in workflow,
          "El runner debe ser el Gradle pinado por Actions")


def test_lock_contention_and_stale():
    print("  [GUARD] Contención, adquisición y stale/timeout del lock...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_repo = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart = f.read()
    with open(os.path.join(WORKSPACE, KT_TEST), "r", encoding="utf-8") as f:
        native_test = f.read()
    with open(os.path.join(WORKSPACE, DART_TEST), "r", encoding="utf-8") as f:
        dart_test = f.read()

    check("Kotlin expone timeout y stale con recuperación",
          "HISTORY_LOCK_TIMEOUT_MS" in kt_repo and
          "HISTORY_LOCK_STALE_MS" in kt_repo and
          "acquireTranscriptionHistoryLock" in kt_repo and
          "releaseTranscriptionHistoryLock" in kt_repo,
          "Falta adquisición bloqueante con timeout y stale")
    check("Dart expone timeout y stale con recuperación",
          "historyLockTimeoutMs" in dart and
          "historyLockStaleMs" in dart and
          "withTranscriptionHistoryFileLock" in dart,
          "Falta adquisición bloqueante con timeout y stale en Dart")
    check("Kotlin prueba contención y stale/timeout",
          "concurrentAddsFromSeparateRepositoriesKeepBothEntries" in native_test and
          "lockStaleIsRecovered" in native_test and
          "lockTimeoutIsFailClosed" in native_test,
          "Faltan pruebas de contención y stale/timeout en Kotlin")
    check("Dart prueba contención y stale/timeout",
          "serializa dos adds sobre el mismo archivo real" in dart_test and
          "stale" in dart_test.lower() and
          "timeout" in dart_test.lower(),
          "Faltan pruebas de contención y stale/timeout en Dart")


def test_date_matrix():
    print("  [GUARD] Matriz de fechas ±14, 0000/9999, submicro y DST...")
    with open(os.path.join(WORKSPACE, KT_LOGIC), "r", encoding="utf-8") as f:
        logic = f.read()
    with open(os.path.join(WORKSPACE, DART_STORE), "r", encoding="utf-8") as f:
        dart = f.read()
    with open(os.path.join(WORKSPACE, KT_TEST), "r", encoding="utf-8") as f:
        native_test = f.read()
    with open(os.path.join(WORKSPACE, DART_TEST), "r", encoding="utf-8") as f:
        dart_test = f.read()

    check("Offset máximo ±14 en ambos lados",
          "hours <= 14" in logic and
          "hours > 14" in dart and
          ("(hours < 14 || minutes == 0)" in logic or
           "(hours == 14 && minutes != 0)" in logic),
          "El offset debe caparse en ±14:00")
    check("Kotlin rechaza gap DST y fija overlap determinista",
          "getValidOffsets" in logic and
          "validOffsets.isEmpty()" in logic,
          "El gap DST debe devolverse como nulo")
    check("Legacy solo explícito sin default del sistema",
          "ZoneId.systemDefault()" not in logic and
          "legacyOffsetMinutes == null) return null" in dart,
          "Legacy local solo con zona/offset explícito y coherente")
    check("Matriz ±14 y DST en tests",
          "+14:00" in native_test and
          "+14:01" in native_test and
          "Europe/Berlin" in native_test and
          "+14:00" in dart_test and
          "+14:01" in dart_test,
          "Falta matriz ±14 y DST gap/overlap en tests")
    check("0000/9999 y submicro en tests",
          "0000-01-01" in native_test and
          "9999-12-31" in native_test and
          "1234567" in native_test and
          "0000-01-01" in dart_test and
          "9999-12-31" in dart_test,
          "Falta matriz 0000/9999 y submicro")
    check("Canónico idéntico con 6 micros en ambos",
          "appendInstant(6)" in logic and
          ".000000Z" in dart and
          "canonicalTimestamp" in logic,
          "El canónico debe ser idéntico en ambos")


def test_publisher_missing_dir():
    print("  [GUARD] Publisher real con fallo, lector concurrente y dir ausente...")
    with open(os.path.join(WORKSPACE, KT_REPO), "r", encoding="utf-8") as f:
        kt_repo = f.read()
    with open(os.path.join(WORKSPACE, KT_TEST), "r", encoding="utf-8") as f:
        native_test = f.read()
    with open(os.path.join(WORKSPACE, DART_TEST), "r", encoding="utf-8") as f:
        dart_test = f.read()

    check("Kotlin publica con move atómico sobre clase productiva",
          "Files.move(" in kt_repo and
          "StandardCopyOption.ATOMIC_MOVE" in kt_repo and
          "FileTranscriptionHistoryStorage" in native_test and
          "productionPublisherUsesAtomicMoveAndCleansTemporaryFiles" in native_test,
          "El publisher debe ser la clase productiva real")
    check("Kotlin prueba fallo de move y lector sin parcial",
          "productionPublisherReportsRealMoveFailure" in native_test and
          "concurrentReaderNeverSeesPartialJson" in native_test,
          "Falta fallo de move y lector concurrente sin parcial")
    check("Publisher controla directorio ausente",
          "missingDirectory" in native_test.lower() or
          "directorio ausente" in native_test.lower() or
          "MissingDirectory" in native_test,
          "Falta directorio ausente controlado en Kotlin")
    check("Dart controla directorio ausente y fallo atómico",
          "missing" in dart_test.lower() and
          "publishHistoryFileAtomically" in dart_test,
          "Falta directorio ausente controlado en Dart")


def test_staging_versionable():
    print("  [GUARD] Staging versionable de Kotlin nuevos...")
    import subprocess
    for path in (KT_LOGIC, KT_TEST):
        check(f"git ls-files reconoce {path}",
              subprocess.run(
                  ["git", "ls-files", "--error-unmatch", path],
                  cwd=WORKSPACE,
                  stdout=subprocess.PIPE,
                  stderr=subprocess.PIPE,
              ).returncode == 0,
              f"{path} debe estar en el índice")
        check(f"git cat-file tiene blob en índice para {path}",
              subprocess.run(
                  ["git", "cat-file", "-e", f":{path}"],
                  cwd=WORKSPACE,
                  stdout=subprocess.PIPE,
                  stderr=subprocess.PIPE,
              ).returncode == 0,
              f":{path} debe existir en el índice")
        size_proc = subprocess.run(
            ["git", "cat-file", "-s", f":{path}"],
            cwd=WORKSPACE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            indexed_size = int(size_proc.stdout.strip())
        except Exception:
            indexed_size = 0
        check(f"Contenido real en índice para {path}",
              size_proc.returncode == 0 and indexed_size > 200,
              f"{path} no puede ser intent-to-add vacío (índice={indexed_size} bytes)")
    with open(os.path.join(WORKSPACE, KT_TEST), "r", encoding="utf-8") as f:
        native_test = f.read()
    check("Sin mensaje 100% sin CI",
          "100%" not in native_test,
          "Cambiar mensaje 100% por guardas locales pasan")


if __name__ == "__main__":
    print("=" * 60)
    print(" INICIANDO GUARDAS: REPOSITORIO DE HISTORIAL")
    print("=" * 60)
    try:
        test_file_constants()
        test_atomic_writes()
        test_repository_rmw_serialization()
        test_flutter_string_list_merge()
        test_stale_overwrite_prevention()
        test_cross_platform_fifo_real()
        test_history_safety_and_parity_guards()
        test_no_automatic_purge()
        test_disk_full_resilience()
        test_single_identity_no_window()
        test_native_kotlin_history_guard()
        test_lock_contention_and_stale()
        test_date_matrix()
        test_publisher_missing_dir()
        test_staging_versionable()
        print("=" * 60)
        if suite.failed > 0:
            print(f" RESULTADOS: {suite.passed} pasados, {suite.failed} fallidos.")
            print("=" * 60)
            sys.exit(1)
        print(" RESULTADOS: guardas locales pasan; native/Flutter pendientes de CI.")
        print("=" * 60)
        sys.exit(0)
    except AssertionError as e:
        print(f"\n❌ ERROR: {e}")
        sys.exit(1)
