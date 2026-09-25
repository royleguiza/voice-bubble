#!/usr/bin/env python3
"""
MASTER VERIFICATION SUITE - VoiceBubble STT
Delega cada suite Python vía subprocess (fallo real si fallan) y conserva
inline SOLO los CI guards propios (contrato de claves, logs limpios y
retención al desinstalar). La versión NO se congela en un literal: se
exige consistencia del MISMO valor entre ambos pubspec (el bump futuro
no debe romper master).
"""

import base64
import os
import re
import subprocess
import sys

SUITES = [
    ("Snippets: subcapas ?123/Código y retención", "test_snippets_suite.py"),
    ("Onboarding: micrófono y activación modal", "test_onboarding_and_activation_suite.py"),
    ("Ergonomía: perfil de altura 'Muy alta' (1.30f)", "test_height_profile_suite.py"),
    ("Historial: repositorio atómico FIFO-20", "test_transcription_history_suite.py"),
    ("Portapapeles: suite multimodal FIFO-25", "test_clipboard_suite.py"),
    ("Trackpad: suite split wings y puntero virtual", "test_trackpad_suite.py"),
    ("Burbuja: modal de historial clásica (B1-B7)", "test_bubble_history_suite.py"),
    ("Claves: sección credenciales + llave y relleno en teclado", "test_credentials_suite.py"),
    ("Mayúsculas: ciclo de caso con Shift (MEJ-02)", "test_shift_case_suite.py"),
    ("Pulsación larga: símbolos y tildes sin cambiar de capa (MEJ-05)", "test_long_press_symbols_suite.py"),
    ("Modelo: whisper-large-v3-turbo con migración de legado", "test_turbo_model_suite.py"),
    ("Escritura: precisión dedos + gaps + targets (typing-feel)", "test_typing_feel_suite.py"),
    ("Micro-teclado: modo mini 2 filas (MEJ-12)", "test_micro_keyboard_suite.py"),
    ("Ajustes: rediseño Settings v2 (5 tabs + crystal)", "test_settings_redesign_suite.py"),
    ("Teclado: filas parejas + glyphs gruesos (layout nativo)", "test_keyboard_layout_suite.py"),
    ("Micrófono: hápticas y sonidos por evento", "test_mic_feedback_suite.py"),
    ("Notas: cola diferida cloud offline (C1-C7)", "test_pending_notes_suite.py"),
]

def run_test(name, func):
    sys.stdout.write(f"  ▶ {name}... ")
    sys.stdout.flush()
    try:
        func()
        print("✅ PASS")
        return True
    except Exception as e:
        print(f"❌ FAIL: {e}")
        return False

def test_contract_keys():
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    cmd = (
        f"grep -rvhE '^[[:space:]]*import ' '{kt_dir}' "
        "| grep -ohE 'flutter\\.[a-z_0-9]+' "
        "| sed 's/^flutter\\.//' "
        "| sort -u"
    )
    result = subprocess.check_output(cmd, shell=True, text=True).strip()
    # Lectores con "flutter.$key" interpolado (intPref/stringPref/booleanPref):
    # la clave viaja como argumento; se extrae para no dar falsos rojos.
    cmd2 = (
        f"grep -rhoE '(intPref|stringPref|booleanPref)\\(prefs, \"[a-z_0-9]+\"' '{kt_dir}' "
        "| grep -oE '\"[a-z_0-9]+\"' "
        "| tr -d '\"' "
        "| sort -u"
    )
    result2 = subprocess.check_output(cmd2, shell=True, text=True).strip()
    got = set(result.split()) | set(result2.split())
    with open("docs/contract-keys.txt", "r", encoding="utf-8") as f:
        expected = f.read().strip()
    assert "\n".join(sorted(got)) == expected, (
        f"Discrepancia en claves de contrato:\nEsperado:\n{expected}\nObtenido:\n" + "\n".join(sorted(got))
    )
    # SPK-07: la tabla Dart (StorageService.bridgeKeys) debe cubrir el
    # contrato exacto: cierra el triángulo Kotlin==contrato==Dart.
    with open("app_source/lib/services/storage_service.dart", "r", encoding="utf-8") as f:
        dart = f.read()
    const_vals = dict(re.findall(r"static const String (\w+)\s*=\s*'([a-z_0-9]+)';", dart))
    m = re.search(r"static const List<String> bridgeKeys = \[(.*?)\];", dart, re.DOTALL)
    assert m, "Falta StorageService.bridgeKeys (SPK-07)"
    table = []
    for ident in re.findall(r"[A-Za-z_]\w*", m.group(1)):
        assert ident in const_vals, f"bridgeKeys referencia const inexistente: {ident}"
        table.append(const_vals[ident])
    assert "\n".join(sorted(table)) == expected, (
        "Discrepancia tabla Dart vs contrato:\nEsperado:\n" + expected + "\nObtenido:\n" + "\n".join(sorted(table))
    )

def test_c02_history_contract():
    kt_repo = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryRepository.kt"
    kt_logic = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryLogic.kt"
    kt_test = "voice_bubble_stt/android/app/src/test/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryLogicTest.kt"
    kt_build = "voice_bubble_stt/android/app/build.gradle.kts"
    wrapper = "voice_bubble_stt/android/gradle/wrapper/gradle-wrapper.properties"
    dart_store = "app_source/lib/services/storage_service.dart"
    dart_test = "app_source/test/services/history_bridge_contract_test.dart"
    pubspec = "app_source/pubspec.yaml"
    workflow = ".github/workflows/android.yml"
    main = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/MainActivity.kt"
    paths = [kt_repo, kt_logic, kt_test, kt_build, wrapper, dart_store, dart_test, pubspec, workflow, main]
    contents = {}
    for path in paths:
        assert os.path.isfile(path), f"Falta archivo C-02: {path}"
        with open(path, "r", encoding="utf-8") as f:
            contents[path] = f.read()

    kt = contents[kt_repo]
    logic = contents[kt_logic]
    dart = contents[dart_store]
    native_test = contents[kt_test]
    build = contents[kt_build]
    wrapper_content = contents[wrapper]
    pubspec_content = contents[pubspec]
    dart_test_content = contents[dart_test]
    ci = contents[workflow]
    main_content = contents[main]
    prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
    assert base64.b64decode(prefix[:-1] + "===") == b"This is the prefix for a list."
    assert 'SHARED_HISTORY_KEY = "flutter.transcriptions"' in kt
    assert "readFlutterStringList()" in kt and ".getString(" in kt
    assert prefix in logic
    assert "JSON_LIST_PREFIX" in logic
    assert "raw.startsWith(JSON_LIST_PREFIX)" in logic
    assert "raw.trim()" not in logic
    assert "shared_preferences_android: 2.4.15" not in pubspec_content
    assert "shared_preferences:" in pubspec_content
    assert "TranscriptionHistoryLogic.mergeRecords(" in kt
    assert (
        "getStringSet" not in kt + logic
        and "android.util.Xml" not in kt + logic
        and "XmlPullParser" not in kt + logic
        and "migrateFromLegacySources" not in kt + logic
        and "Base64" not in kt + logic
    )
    assert "getStringList(_key)" in dart and "setStringList(_key" in dart
    assert "_parseHistoryTimestamp" in dart and "_legacyHistoryTimestampPattern" in dart
    assert "DateTime.tryParse(raw)" not in dart
    assert "ResolverStyle.STRICT" in logic and "truncatedTo(ChronoUnit.MICROS)" in logic
    assert "@Test" in native_test and "TranscriptionHistoryLogicTest" in native_test

    add_start = kt.index("fun addTranscription")
    lock_start = kt.index("withTranscriptionHistoryFileLock", add_start)
    load_start = kt.index("loadRecords()", lock_start)
    normalize_start = kt.index("TranscriptionHistoryLogic.normalize", lock_start)
    save_start = kt.index("saveAtomic", lock_start)
    assert "acquireTranscriptionHistoryLock" in kt
    assert "HISTORY_LOCK_TIMEOUT_MS" in kt and "HISTORY_LOCK_STALE_MS" in kt
    assert "Files.createFile(" in kt and "FileAlreadyExistsException" in kt
    assert "getLastModifiedTime" in kt
    assert "synchronized(historyProcessLock)" not in kt
    assert "RandomAccessFile(lockFile" not in kt and "channel.lock()" not in kt
    assert 'LOCK_FILE_NAME = "$FILE_NAME.lock"' in kt
    assert lock_start < load_start < normalize_start < save_start
    assert "loadRecords()" not in kt[add_start:lock_start]
    assert "withTranscriptionHistoryFileLock" in kt[kt.index("fun loadHistory()"):]
    assert "Files.move(" in kt and "Files.createTempFile(" in kt
    assert "StandardCopyOption.ATOMIC_MOVE" in kt
    assert "StandardCopyOption.REPLACE_EXISTING" in kt and "copyTo(" not in kt
    assert "TranscriptionHistoryReadResult.Missing" in kt
    assert "TranscriptionHistoryReadResult.Content" in kt
    assert "TranscriptionHistoryReadResult.Corrupt" in kt
    assert "TranscriptionHistoryReadResult.Error" in kt
    assert "canonicalObject(text, instant)" in kt
    assert "Future<bool> _saveHistoryFile() async" in dart
    assert "bool publishHistoryFileAtomically" in dart
    assert "Random.secure()" in dart
    assert "tmpFile.renameSync(file.path);" in dart
    assert "historyLockTimeoutMs" in dart and "historyLockStaleMs" in dart
    assert "createSync(exclusive: true)" in dart and "lastModifiedSync" in dart
    assert "FileLock.exclusive" not in dart and "lockHandle.unlock" not in dart
    assert "historyLockFileName = 'transcription_history.json.lock'" in dart
    assert "copySync(" not in dart and "return false" in dart
    assert "if (merged == null) return false;" in dart
    assert "legacyOffsetMinutes" in dart and "legacyOffsetMinutes == null) return null" in dart
    assert "DateTime.utc(" in dart and "_validHistoryYear(instant)" in dart
    assert ".addTranscription(text, timestamp)" in main_content

    for case in (
        "mergesFileAndStringListEntries",
        "keepsDifferentTextsAtTheSameInstant",
        "collapsesDuplicateAcrossTimezoneAndSubMicrosecondPrecision",
        "rejectsNonCanonicalAndInvalidTimestamps",
        "validatesLegacyOverflowAfterUtcConversionInBothOffsetDirections",
        "appliesFifoAfterMergeAndDeduplication",
        "repositoryReadsRealFileAndFlutterPayloadThroughProductionParsers",
        "repositoryCanonicalizesPayloadBeforeReturningAndPublishing",
        "repositoryAddReadsFileAndPreferencesBeforePublishing",
        "repositoryAddRejectsEmptyTextWithoutChangingPublishedFile",
        "repositoryReportsAtomicWriteFailureAndKeepsPublishedFile",
        "repositoryDoesNotPublishWhenExistingFileReadFails",
        "productionStorageReportsReadErrorForExistingUnreadablePath",
        "repositoryAddCollapsesDuplicateBeforeFifoCut",
        "repositoryAddMergesMemoryFilePreferencesWithThirtyThreeTiedEntries",
        "normalizesThirtyThreeTiedEntriesAcrossAllSources",
        "concurrentAddsFromSeparateRepositoriesKeepBothEntries",
        "productionPublisherUsesAtomicMoveAndCleansTemporaryFiles",
        "productionPublisherReportsRealMoveFailure",
        "concurrentReaderNeverSeesPartialJson",
        "repositoryParsesLegacyLocalTimestampsInExplicitNonUtcZone",
        "repositoryAppliesFifoToThirtyThreeTiedEntries",
        "usesTheSameUnicodeBlankRuleAsDart",
    ):
        assert case in native_test, f"Falta caso Kotlin: {case}"
    assert native_test.count("addTranscription(") >= 4
    assert "FileTranscriptionHistoryStorage" in native_test
    assert "TemporaryHistoryStorage" not in native_test
    assert "CyclicBarrier" in native_test and "Executors" in native_test
    assert "CountDownLatch" in native_test
    assert "TranscriptionHistorySource.MEMORY" in native_test
    assert "TranscriptionHistorySource.FILE" in native_test
    assert "TranscriptionHistorySource.PREFERENCES" in native_test
    assert "Thread.sleep" not in native_test
    assert "ZoneId.of(\"America/Argentina/Buenos_Aires\")" in native_test
    assert "ZoneId.of(\"+02:00\")" in native_test
    assert "ZoneId.of(\"-02:00\")" in native_test
    assert "ZoneId.systemDefault()" not in native_test
    assert "2026-02-30T10:00:00Z" in dart_test_content
    assert "2026-08-23T10:00:00.123" in dart_test_content
    assert "si falla la sustitucion atomica conserva el archivo publicado" in dart_test_content
    assert "historyLegacyOffsetMinutes: 120" in dart_test_content
    assert "historyLegacyOffsetMinutes: -120" in dart_test_content
    assert "+14:00" in native_test and "+14:01" in native_test
    assert "Europe/Berlin" in native_test
    assert "lockStaleIsRecovered" in native_test and "lockTimeoutIsFailClosed" in native_test
    assert "stale" in dart_test_content.lower() and "timeout" in dart_test_content.lower()
    assert "100%" not in native_test
    assert "testDebugUnitTest" in ci and "--tests" in ci
    assert ci.index("Pub get") < ci.index("Preparar local.properties") < ci.index("testDebugUnitTest")
    assert ci.index("testDebugUnitTest") < ci.index("flutter build apk")
    assert ci.index("testDebugUnitTest") < ci.index("Upload APK arm64")
    assert "FLUTTER_ROOT" in ci and "flutter.sdk=" in ci and "sdk.dir=" in ci
    assert "voice_bubble_stt/android/local.properties" in ci
    assert "gradle/actions/setup-gradle" in ci and "gradle-version: '9.3.1'" in ci
    assert ci.count("gradle/actions/setup-gradle") == 1
    assert "cache: gradle" not in ci
    assert "gradle-9.3.1-all.zip" in wrapper_content
    assert "gradle --no-daemon :app:testDebugUnitTest" in ci
    assert 'testImplementation("junit:junit:4.13.2")' in build
    assert 'testImplementation("org.json:json:20240303")' in build
    assert "--init-script" not in ci and "command -v gradle" not in ci


def test_clean_logs():
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin"
    pattern = re.compile(
        r"Log\.[a-z]+\(.*\b(texto|contenido|api_?key|token|password|"
        r"contraseña|passwd|otp|tecleado|coordenada)\b",
        re.IGNORECASE,
    )
    hits = []
    for root, _, files in os.walk(kt_dir):
        for name in files:
            if not name.endswith(".kt"):
                continue
            path = os.path.join(root, name)
            with open(path, "r", encoding="utf-8") as f:
                for line_no, line in enumerate(f, 1):
                    if pattern.search(line):
                        hits.append(f"{path}:{line_no}: {line.strip()}")
    assert not hits, "Filtración de contenido detectada en Logs:\n" + "\n".join(hits)

def test_no_versioned_secrets():
    """SPK-01: ningún PAT ni archivo de secretos versionado (mirror del guard CI)."""
    result = subprocess.run(
        [
            "git", "grep", "-nE",
            r"github_pat_[A-Za-z0-9_]{10,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}",
            "--", ".",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    lines = [line for line in result.stdout.splitlines() if "test_master_suite.py" not in line]
    assert not lines, "Posible secreto versionado SPK-01:\n" + "\n".join(lines)
    tracked = subprocess.run(
        ["git", "ls-files"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True,
    ).stdout.splitlines()
    forbidden = {".github_token", ".agents/secrets.env"}
    assert not forbidden.intersection(tracked), (
        "Archivo de secretos trackeado SPK-01:\n"
        + "\n".join(sorted(forbidden.intersection(tracked)))
    )

def test_secrets_vault():
    """SPK-02: secretos solo en bóveda cifrada, jamás en prefs planas ni backup."""
    kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    with open(f"{kt}/SecureStore.kt", "r", encoding="utf-8") as f:
        vault = f.read()
    assert "EncryptedSharedPreferences" in vault, "Sin ESP en la bóveda"
    assert "MasterKey.DEFAULT_MASTER_KEY_ALIAS" in vault, "Sin master key por defecto"
    with open(f"{kt}/SpeechToTextClient.kt", "r", encoding="utf-8") as f:
        stt = f.read()
    assert "SecureStore.read" in stt, "El dictado debe leer la key de la bóveda"
    pre = stt.split("migrateLegacyMirror")[0]
    assert "flutter.kb_stt_api_key" not in pre, "Lectura plana fuera de la migración prohibida"
    assert 'remove("flutter.kb_stt_api_key")' in stt, "La migración debe borrar el legado"
    with open(f"{kt}/CredentialStore.kt", "r", encoding="utf-8") as f:
        store = f.read()
    assert "SecureStore.read" in store, "Claves debe leer de la bóveda"
    with open("app_source/lib/services/storage_service.dart", "r", encoding="utf-8") as f:
        storage = f.read()
    assert "prefs.setString(sttApiKeyMirrorKey" not in storage, "Espejo plano de key prohibido"
    assert "prefs.setString(credPassKey" not in storage, "Mapa plano de passwords prohibido"
    assert "encryptedSharedPreferences: true" in storage, "La bóveda Dart debe usar ESP"
    with open("voice_bubble_stt/android/app/build.gradle.kts", "r", encoding="utf-8") as f:
        gradle = f.read()
    assert "androidx.security:security-crypto" in gradle, "Falta el pin de security-crypto"
    for xml in ("voice_bubble_stt/android/app/src/main/res/xml/backup_rules.xml",
                "voice_bubble_stt/android/app/src/main/res/xml/data_extraction_rules.xml"):
        with open(xml, "r", encoding="utf-8") as f:
            rules = f.read()
        assert '<exclude domain="sharedpref" path="FlutterSharedPreferences.xml" />' in rules, f"Sin excluir prefs en {xml}"
        assert '<exclude domain="sharedpref" path="FlutterSecureStorage.xml" />' in rules, f"Sin excluir bóveda en {xml}"

def test_dictation_contract():
    """Tope de dictado 5min con fuente única + timeouts HTTP (ciego total)."""
    kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    with open(f"{kt}/SpeechToTextClient.kt", "r", encoding="utf-8") as f:
        stt = f.read()
    assert "const val MAX_SECONDS = 300" in stt, "Tope único 5min ausente"
    assert "MAX_SECONDS * 1000L" in stt, "Deadline sin fuente única"
    assert "readTimeout = 240000" in stt, "readTimeout 240s ausente"
    assert "connectTimeout = 15000" in stt, "connectTimeout 15s ausente"
    with open(f"{kt}/DictationController.kt", "r", encoding="utf-8") as f:
        dic = f.read()
    assert "SpeechToTextClient.MAX_SECONDS * 1000L" in dic, (
        "El teclado debe armar su timeout desde la fuente única, sin literal"
    )
    assert "300000" not in dic and "300_000" not in dic, (
        "Literal duplicado del tope en el controlador"
    )

def _workflow_steps():
    """Steps REALES del workflow (YAML parseado, no busqueda de strings)."""
    import yaml
    with open(".github/workflows/android.yml", "r", encoding="utf-8") as f:
        workflow = yaml.safe_load(f)
    steps = []
    for job in workflow["jobs"].values():
        steps.extend(job.get("steps", []))
    return steps


def _body_after(source, signature):
    """Cuerpo real de un metodo: desde su firma hasta la llave que lo cierra.

    Cortar por `source[source.index(sig):]` no sirve: la DEFINICION del metodo
    cuelga despues de su unico llamador, asi que el nombre siempre aparece en
    el slice y un metodo muerto pasa por vivo. Emparejando llaves, el slice
    cubre solo lo que el metodo ejecuta.
    """
    start = source.index(signature)
    open_brace = source.index("{", start)
    depth = 0
    for i in range(open_brace, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return source[open_brace : i + 1]
    raise AssertionError(f"Llava sin cerrar en {signature!r}")


def _strip_dart_comments(source):
    """Cuerpo Dart sin comentarios: una llamada comentada no es una sentencia."""
    out = []
    i = 0
    n = len(source)
    quote = None
    while i < n:
        ch = source[i]
        if quote is not None:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(source[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in "'\"":
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and source[i + 1] == "/":
            while i < n and source[i] != "\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and source[i + 1] == "*":
            end = source.find("*/", i + 2)
            i = n if end == -1 else end + 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _statements_at_depth(body, depth):
    """Sentencias de un cuerpo que viven en la profundidad de llaves indicada.

    Lo que queda mas adentro (dentro de un if, de un try o de un bloque) es
    condicional: puede no ejecutarse nunca. Exigir la sentencia en la
    profundidad pedida es lo que separa un release real de uno nominal.
    """
    out = []
    buf = []
    d = 0
    for ch in body:
        if ch in "{};\n":
            if d == depth:
                text = "".join(buf).strip()
                if text:
                    out.append(text)
                buf = []
            if ch in "{}":
                d += 1 if ch == "{" else -1
        elif d == depth:
            buf.append(ch)
    text = "".join(buf).strip()
    if text:
        out.append(text)
    return out


def _dart_test_body(source, name):
    """Cuerpo real de un test Dart (emparejando llaves desde su nombre)."""
    start = source.index(f"'{name}'")
    open_brace = source.index("{", start)
    depth = 0
    for i in range(open_brace, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return source[open_brace : i + 1]
    raise AssertionError(f"Llava sin cerrar en el test {name!r}")


def _expr_body(source, signature):
    """Cuerpo de expresion (sin llaves): getter de Dart o = de Kotlin."""
    tail = source[source.index(signature):]
    return tail[: tail.index(";") + 1]


def test_c05_mic_exclusion_contract():
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    with open(f"{kt_dir}/DictationController.kt", "r", encoding="utf-8") as f:
        dic = f.read()
    with open(f"{kt_dir}/BackgroundWork.kt", "r", encoding="utf-8") as f:
        background = f.read()
    with open(f"{kt_dir}/MainActivity.kt", "r", encoding="utf-8") as f:
        main = f.read()
    with open(f"{kt_dir}/WidgetDictationService.kt", "r", encoding="utf-8") as f:
        widget = f.read()
    with open("app_source/lib/services/transcription_service.dart", "r", encoding="utf-8") as f:
        dart = f.read()
    with open("app_source/lib/screens/home_screen.dart", "r", encoding="utf-8") as f:
        home = f.read()
    with open("app_source/lib/screens/notes_screen.dart", "r", encoding="utf-8") as f:
        notes = f.read()
    with open(
        "voice_bubble_stt/android/app/src/test/kotlin/com/royleguiza/voicebubblestt/MicrophoneClaimTest.kt",
        "r",
        encoding="utf-8",
    ) as f:
        kt_test = f.read()
    with open("app_source/test/services/mic_exclusion_test.dart", "r", encoding="utf-8") as f:
        dart_test = f.read()
    with open(
        "app_source/test/integration/mic_exclusion_flow_test.dart", "r", encoding="utf-8"
    ) as f:
        ui_test = f.read()

    # 0) CI EJECUTA la prueba nativa (step real del workflow, no strings).
    mic_steps = [
        step for step in _workflow_steps()
        if "com.royleguiza.voicebubblestt.MicrophoneClaimTest" in str(step.get("run", ""))
    ]
    assert len(mic_steps) == 1, (
        "El workflow debe ejecutar :app:testDebugUnitTest --tests "
        "com.royleguiza.voicebubblestt.MicrophoneClaimTest exactamente una vez"
    )
    mic_step = mic_steps[0]
    assert "gradle --no-daemon :app:testDebugUnitTest" in mic_step["run"], (
        "El paso de MicrophoneClaimTest debe usar gradle --no-daemon :app:testDebugUnitTest"
    )
    assert mic_step.get("working-directory") == "voice_bubble_stt/android", (
        "El paso de MicrophoneClaimTest debe correr en voice_bubble_stt/android"
    )
    assert not mic_step.get("continue-on-error"), (
        "El paso de MicrophoneClaimTest no puede ser continue-on-error"
    )
    for neutered in ("|| true", "|| echo", "exit 0", "continue-on-error"):
        assert neutered not in mic_step["run"], f"Paso de test nativo neutralizado: {neutered}"
    kotlin_test_runs = [
        step["run"] for step in _workflow_steps()
        if ":app:testDebugUnitTest" in str(step.get("run", ""))
    ]
    for suite in ("TranscriptionHistoryLogicTest", "WidgetNotesBehaviorTest"):
        assert any(f"--tests com.royleguiza.voicebubblestt.{suite}" in run for run in kotlin_test_runs), (
            f"Regresion: el workflow dejo de correr {suite}"
        )

    # 1) Un UNICO AtomicLong es el arbitro (punto unico de atomicidad).
    assert background.count("= AtomicLong(") == 2, (
        "Solo la celda de dueno y el contador de tokens pueden ser AtomicLong"
    )
    assert "AtomicBoolean" not in background and "AtomicInteger" not in background, (
        "Ningun otro atómico: el arbitro del microfono es UNA celda"
    )
    claim_body = _body_after(background, "fun tryClaimMicrophone(): Long")
    assert "while (true)" in claim_body, "tryClaimMicrophone debe reintentar con CAS en loop"
    assert claim_body.count("compareAndSet") == 1, (
        "tryClaimMicrophone solo puede hacer CAS sobre la celda de dueno"
    )
    assert "microphoneOwner.compareAndSet(actual, claim)" in claim_body
    assert "nextMicrophoneClaim.incrementAndGet()" in claim_body, (
        "Cada intento debe tomar un token nuevo: nunca se reutiliza"
    )
    assert re.search(r"if \(actual != 0L\) return 0L", claim_body), (
        "La rama 'ya ocupada' debe devolver 0, NO el token del dueno: con "
        "'return actual' el que pierde el arbitro recibe el token ajeno, cree "
        "ser dueno y abre un segundo AudioRecord"
    )
    assert claim_body.count("return") == 2, (
        "tryClaimMicrophone solo puede retornar por la rama ocupada (0) o por "
        "el CAS ganador: un return extra es un camino que no toma el claim"
    )
    release_body = _body_after(background, "fun releaseMicrophone(claim: Long): Boolean")
    assert release_body.count("compareAndSet") == 1, (
        "releaseMicrophone debe ser un unico CAS(token, 0)"
    )
    assert "microphoneOwner.compareAndSet(claim, 0L)" in release_body
    assert "fun releaseMicrophone(claim: Long): Boolean" in background, (
        "El release debe reportar si libero de verdad (puente MethodChannel)"
    )
    assert re.search(r"if \(claim <= 0L\) return false", release_body)
    assert release_body.count("return") == 2, (
        "releaseMicrophone solo puede retornar 'false' por el token vacio o el "
        "resultado del CAS: un 'return true' antes del CAS reporta exito sin "
        "liberar la celda del arbitro"
    )
    assert re.search(
        r"return microphoneOwner\.compareAndSet\(claim, 0L\)\s*\}\s*$", release_body
    ), "El CAS(token, 0) debe ser la ultima sentencia de releaseMicrophone"
    assert "fun isMicrophoneClaimed(): Boolean = microphoneOwner.get() != 0L" in background, (
        "isMicrophoneClaimed debe leer la MISMA celda del arbitro"
    )
    by_claim = re.search(
        r"fun isMicrophoneClaimedBy\(claim: Long\): Boolean\s*=\s*([^\n;]+)", background
    )
    assert by_claim, "isMicrophoneClaimedBy debe seguir siendo legible como cuerpo"
    expresion = re.sub(r"\s+", " ", by_claim.group(1)).strip()
    assert expresion == "claim > 0L && microphoneOwner.get() == claim", (
        "isMicrophoneClaimedBy debe exigir token positivo Y que la celda lo "
        f"tenga; '{expresion}' devuelve la respuesta que espera el teclado sin "
        "mirar la celda, y ownsClaim queda siempre cierto"
    )
    for api in ("set", "getAndSet", "lazySet", "andUpdate", "accumulateAndGet", "updateAndGet"):
        assert not re.search(rf"microphoneOwner\.{api}\b", background), (
            f"La celda del arbitro jamas se escribe con microphoneOwner.{api}"
            ": en dos pasos puede pisar al dueno nuevo que ya tomo el claim. "
            "La unica escritura admisible es compareAndSet. Ojo: andUpdate y "
            "updateAndGet son lambdas y en Kotlin no llevan parentesis, por eso "
            "el nombre se busca sin exigir '(' (si no, la mutacion pasa)."
        )
    celda_ops = set(re.findall(r"microphoneOwner\.(\w+)\s*[({]", background))
    assert celda_ops <= {"get", "compareAndSet"}, (
        f"Operaciones inesperadas sobre la celda del arbitro: {sorted(celda_ops)}"
    )
    assert "keyboardRecordingActive" not in background, (
        "El claim no debe re-publicar el flag mutable del teclado"
    )
    assert "result.success(BackgroundWork.isMicrophoneClaimed())" in main
    assert '"claimMicrophone" ->' in main and "BackgroundWork.tryClaimMicrophone()" in main
    assert (
        '"releaseMicrophone" ->' in main
        and "result.success(BackgroundWork.releaseMicrophone(claim))" in main
    ), "El puente debe devolver el resultado real del CAS, no un true fijo"
    isKeyboardRecording_callers = []
    for root, _, files in os.walk("app_source/lib"):
        for name in files:
            if not name.endswith(".dart"):
                continue
            path = os.path.join(root, name)
            with open(path, "r", encoding="utf-8") as f:
                if "isKeyboardRecording" in f.read():
                    isKeyboardRecording_callers.append(path)
    assert not isKeyboardRecording_callers, (
        "El flag con nombre de teclado no debe consumirse desde Dart (miente: "
        f"el claim es de cualquier entrypoint) {isKeyboardRecording_callers}"
    )
    assert "invokeMethod<int>('claimMicrophone')" in dart
    assert "'claim': claim" in dart, "Dart y Kotlin deben compartir la clave del token"

    # 2) Teclado: foco -> chequeos -> claim atomico -> pending -> AudioRecord.
    start = dic[dic.index("private fun startDictation()"):dic.index("private fun onDictationStartResult")]
    focus = start.index("if (!gainAudioFocus())")
    bubble = start.index("if (bubbleBusy())")
    permission = start.index("if (!sttClient.hasMicPermission())")
    claim = start.index("BackgroundWork.tryClaimMicrophone()")
    pending = start.index("dictationStartPending = true")
    focus_lost = start.index("if (audioFocusLost)")
    audio_record = start.index("sttClient.startRecording()")
    assert focus < bubble < permission < claim < pending < focus_lost < audio_record, (
        "El claim atomico debe ser la ultima puerta antes del AudioRecord"
    )
    abort = _body_after(start, "if (claimToken == 0L) {")
    assert "abandonAudioFocus()" in abort and "MicState.BUSY" in abort, (
        "El claim tomado debe devolver el foco de audio y marcar ocupado"
    )
    assert re.search(r"\breturn\b", abort), (
        "El claim 0 debe ABORTAR de verdad (return) y no solo cambiar el "
        "estado: el orden de llamadas no impide seguir hacia "
        "sttClient.startRecording() con el rival como dueno"
    )
    assert "startRecording" not in abort, (
        "Ningun arranque de captura dentro de la rama de claim tomado"
    )
    assert "AUDIOFOCUS_REQUEST_GRANTED" in dic
    assert "audioFocusLost = true" in dic
    assert "micState == MicState.RECORDING || dictationStartPending" in dic
    assert "val ownsClaim = BackgroundWork.isMicrophoneClaimedBy(claimToken)" in dic
    assert "if (!serviceAlive || !started || !isCurrentStart || !ownsClaim)" in dic, (
        "El cierre del arranque debe ser un solo camino terminal: duplicarlo fue "
        "lo que llamaba dos veces a host.setRecordingActive(false) en el main"
    )
    assert "releaseMicrophoneClaim(claimToken)" in dic
    # El flag del teclado SI es @Volatile (preexistente, fuera de este diff):
    # por eso las escrituras directas desde hilos de fondo son seguras y la
    # premisa de que postMain las arreglaba era falsa. Se fija el hecho.
    with open(f"{kt_dir}/VoiceKeyboardService.kt", "r", encoding="utf-8") as f:
        vks = f.read()
    assert re.search(
        r"@Volatile\s+(\n\s+)?var keyboardRecordingActive", vks
    ), "keyboardRecordingActive debe seguir siendo @Volatile: se escribe desde hilos de fondo"
    # El camino de fondo del CIERRE DEL ARRANQUE publica por postMain, y lo
    # hace UNA sola vez. El assert acota su invariante a ese camino (las
    # escrituras directas de finish/cancel van por el campo volatil).
    cierre = dic[dic.index("private fun onDictationStartResult"):dic.index("private fun finishDictation")]
    fondo_cierre = cierre[cierre.index("BackgroundWork.execute {"):cierre.index("if (!serviceAlive) return")]
    assert fondo_cierre.count("host.setRecordingActive(false)") == 1, (
        "El cierre del arranque se publica UNA vez desde el hilo de fondo"
    )
    assert "BackgroundWork.postMain { host.setRecordingActive(false) }" in fondo_cierre, (
        "La baja de estado del host en el cierre del arranque debe pasar por postMain"
    )
    assert cierre.count("host.setRecordingActive(false)") == 2, (
        "setRecordingActive(false) se baja una sola vez por camino terminal: "
        "con !started se llamaba dos veces en el mismo main"
    )
    # Cancele/fallos liberan SIEMPRE (el release por token obsoleto es no-op).
    cancel = _body_after(dic, "private fun cancelDictation(announce: Boolean = false)")
    assert "if (!wasPending)" not in cancel, (
        "Cancelar con start pendiente tambi\u00e9n debe liberar el claim"
    )
    assert "return" not in cancel, (
        "cancelDictation no admite retornos tempranos: cualquier return antes "
        "del finally deja el claim tomado, y es justo la ruta del listener de "
        "perdida de foco con dictationStartPending en vuelo"
    )
    assert re.search(
        r"finally \{[^}]*releaseMicrophoneClaim\(claimToken\)",
        _body_after(cancel, "BackgroundWork.execute {"),
    ), "El release de cancelDictation va en el finally del corte de captura"
    teardown_teclado = _body_after(dic, "fun cancelDictationIfActive()")
    normalizado = re.sub(r"\s+", " ", teardown_teclado)
    assert (
        "if (micState == MicState.IDLE && !dictationStartPending && "
        "microphoneClaimToken == 0L && !host.isRecordingActive()) return" in normalizado
    ), (
        "El retorno temprano de cancelDictationIfActive debe afirmar las CUATRO "
        "condiciones (estado idle, sin arranque pendiente, sin token propio y "
        "host sin grabacion): si falta una, al destruirse el servicio con un "
        "arranque en vuelo el claim queda tomado para todo el proceso"
    )
    assert teardown_teclado.count("releaseMicrophoneClaim(claimToken)") == 2, (
        "Ambos caminos de cancelDictationIfActive (con cliente y sin cliente) "
        "deben liberar el claim"
    )
    assert re.search(
        r"finally \{[^}]*releaseMicrophoneClaim\(claimToken\)",
        _body_after(teardown_teclado, "if (client != null) {"),
    ), "El camino con cliente libera el claim en el finally del corte"
    assert "releaseMicrophoneClaim(claimToken)" in _body_after(
        teardown_teclado, "else {"
    ), "El camino sin cliente tambien libera el claim"

    # 3) Widget: mismo claim antes de su AudioRecord y release en cada salida.
    w_start = widget[widget.index("private fun startRecording(widgetId: Int)"):widget.index("private fun stopAndTranscribe")]
    assert w_start.index("claimMicrophoneForDictation() == 0L") < w_start.index("SpeechToTextClient(this)")
    w_visual = re.findall(r'updateWidgetsState\("recording"\)', w_start)
    assert len(w_visual) == 1, (
        f"El widget debe publicar el estado visual exactamente una vez, no {len(w_visual)}"
    )
    assert w_start.index('updateWidgetsState("recording")') < w_start.index(
        "claimMicrophoneForDictation() == 0L"
    ), (
        "El widget debe publicar el estado visual antes o en el mismo claim "
        "(mismo contrato que burbuja y Notas)"
    )
    w_start_body = _body_after(widget, "private fun startRecording(widgetId: Int)")
    assert _statements_at_depth(w_start_body, 1)[0] == "if (isRecording) return", (
        "startRecording del widget debe ser idempotente: es la unica barrera "
        "si un re-tap llega mientras isBusy todavia no esta puesto"
    )
    assert _statements_at_depth(_body_after(widget, "private fun cancelRecording()"), 1)[0] == (
        "if (!isRecording) return"
    ), "cancelRecording solo puede actuar sobre una captura viva"
    w_fondo = _body_after(w_start_body, "BackgroundWork.execute {")
    assert "val ok = try { speechClient.startRecording() } catch (_: Exception) { false }" in re.sub(
        r"\s+", " ", w_fondo
    ), (
        "El arranque del AudioRecord del widget va en try/catch -> false: "
        "BackgroundWork.execute se traga la excepcion, asi que un "
        "IllegalStateException de rec.startRecording() o un SecurityException "
        "con el permiso revocado en vuelo dejan el claim tomado, isRecording e "
        "isBusy colgados y sin stopSelf() (el microfono queda bloqueado para "
        "todo el proceso)"
    )
    arranque_fallido = _body_after(w_fondo, "if (!ok) {")
    assert "BackgroundWork.postMain" in arranque_fallido, (
        "La recuperacion del arranque fallido debe ir por postMain"
    )
    for piece in ("isRecording = false", "isBusy = false", "releaseMicrophone()", "stopSelf()"):
        assert piece in arranque_fallido, (
            f"El arranque fallido del widget debe hacer '{piece}': sin el "
            "reset de flags el re-tap queda IGNORED para siempre"
        )
    w_stop_body = _body_after(widget, "private fun stopAndTranscribe()")
    sin_client = _body_after(w_stop_body, "client ?: run")
    for nombre, cuerpo in (
        ("cancelRecording", _body_after(widget, "private fun cancelRecording()")),
        (
            "arranque sin permiso",
            _body_after(w_start_body, "if (!speechClient.hasMicPermission()) {"),
        ),
        ("arranque fallido", arranque_fallido),
        ("onDestroy", _body_after(widget, "override fun onDestroy()")),
        ("stopAndTranscribe", w_stop_body),
        ("stopAndTranscribe con client nulo", sin_client),
    ):
        assert "releaseMicrophone()" in cuerpo, (
            f"Sin releaseMicrophone() en el terminal '{nombre}': exigirlo por "
            "ventana de texto lo satisfacia la propia definicion del metodo o "
            "un release posterior"
        )
    assert "speechClient.stopRecording()" in w_stop_body
    assert re.search(r"finally \{[^}]*releaseMicrophone\(\)", w_stop_body), (
        "El widget debe liberar el claim al cerrar su AudioRecord"
    )
    assert "isBusy = false" in sin_client, (
        "updateWidgetsState(\"transcribing\") NO limpia isBusy (solo lo hacen los "
        "estados terminales): la rama client == null debe bajarlo a mano o "
        "handleToggle() queda IGNORED para toda la vida del service"
    )
    toggle = _body_after(widget, "internal fun handleToggle(): WidgetToggleOutcome")
    assert re.search(r"if \(isBusy\) return WidgetToggleOutcome\.IGNORED", toggle)
    assert "isBusy = true" in toggle, (
        "Sin isBusy = true el IGNORED del re-tap queda inerte y el widget puede "
        "abrir un segundo AudioRecord durante stopAndTranscribe"
    )
    estados = _body_after(widget, "private fun updateWidgetsState(state: String)")
    assert re.search(
        r'if \(state != "recording" && state != "transcribing"\) isBusy = false', estados
    ), (
        "Los estados terminales deben bajar isBusy: sin este reset queda "
        "IGNORED para siempre (la fuga de la rama client == null, reabierta "
        "por la otra puerta)"
    )
    # main y fondo tocan estos flags: sin @Volatile son una celda partida.
    for field in ("isRecording", "isBusy", "microphoneClaim"):
        assert re.search(rf"@Volatile\s+(\n\s+)?(private|internal) var {field}", widget), (
            f"{field} del widget se escribe desde main y desde el hilo de fondo: "
            "necesita @Volatile"
        )
    assert "WidgetToggleOutcome.IGNORED -> {}" in widget, (
        "Un re-tap durante stopAndTranscribe debe ignorarse, no mostrar error"
    )

    # 4) Dart: claim atomico (no sonda) inmediatamente antes de recorder.start.
    assert "_isMicBlocked" not in dart, "La sonda TOCTOU debe quedar eliminada"
    assert "'claimMicrophone'" in dart and "'releaseMicrophone'" in dart
    for dead in ("_kLocalClaim", "_localClaim", "_claimLocalMicrophone", "_releaseLocalMicrophone"):
        assert dead not in dart, (
            f"{dead} es un segundo arbitro que no excluye al teclado nativo (falla abierto)"
        )
    claimer = dart[dart.index("Future<int> _defaultMicClaimer()"):dart.index("Future<void> _defaultMicClaimReleaser")]
    assert "} catch (_) {\n    return 0;\n  }" in claimer, (
        "Sin canal nativo el claim debe fallar CERRADO (0), nunca devolver un "
        "claim local que no compite con el teclado"
    )
    assert "?? 0" in claimer
    releaser = dart[dart.index("Future<void> _defaultMicClaimReleaser"):dart.index("class TranscriptionService")]
    assert "if (claim == 0) return;" in releaser, (
        "El releaser solo debe ignorar el token 0 (nada tomado)"
    )
    assert "claim <= 0" not in releaser, (
        "Descartar claim <= 0 mata la liberacion de cualquier token no nativo"
    )
    d_start = dart[dart.index("Future<void> startRecording"):dart.index("Future<String?> stopRecording")]
    d_permission = d_start.index("if (!await _recorder.hasPermission())")
    d_claim = d_start.index("await _claimMicrophone()")
    recorder_start = d_start.index("await _recorder.start(")
    assert d_permission < d_claim < recorder_start
    d_publish = d_start.index("_activeClaim = claim;")
    assert d_claim < d_publish < recorder_start, (
        "El claim debe publicarse ANTES de await _recorder.start: durante el "
        "arranque el microfono ya esta tomado en nativo y hasMicrophoneClaim "
        "debe ser cierto, o el teardown y el stop no pueden liberarlo"
    )
    assert "await releaseMicrophoneClaim();" in d_start, (
        "Si recorder.start falla hay que liberar por releaseMicrophoneClaim "
        "(pone 0 y libera), no con _releaseMicrophone(claim) a secas"
    )
    d_stop = _body_after(dart, "Future<String?> stopRecording()")
    assert "await _releaseMicrophone(claim)" in d_stop
    assert any(
        s == "_activeClaim = 0" for s in _statements_at_depth(d_stop, 1)
    ), (
        "stopRecording debe BAJAR el token como sentencia directa del cuerpo: "
        "metido en un finally o en un if puede quedar sin ejecutar, "
        "hasMicrophoneClaim sigue mintiendo y un teardown posterior libera un "
        "claim ya liberado"
    )
    assert "Future<void> releaseMicrophoneClaim()" in dart
    assert any(
        s == "_activeClaim = 0" for s in _statements_at_depth(
            _body_after(dart, "Future<void> releaseMicrophoneClaim()"), 1
        )
    ), "releaseMicrophoneClaim debe bajar el token como sentencia directa"
    getter = re.sub(r"\s+", " ", _expr_body(dart, "bool get hasMicrophoneClaim")).strip()
    assert getter == "bool get hasMicrophoneClaim => _activeClaim != 0;", (
        "hasMicrophoneClaim debe LEER la celda del claim: con '=> false' (o con "
        "'=> _activeClaim == 0') el teardown de Home/Notas corta antes de "
        "liberar y el microfono queda tomado para todo el proceso"
    )
    for source, name in ((home, "home_screen"), (notes, "notes_screen")):
        assert "releaseMicrophoneClaim()" in source, (
            f"{name} debe liberar el claim en su teardown (metodo sin llamadores)"
        )
        dispose = _strip_dart_comments(_body_after(source, "void dispose()"))
        assert "unawaited(_releaseMicrophoneOnTeardown())" in _statements_at_depth(dispose, 1), (
            f"{name}: dispose() debe INVOCAR al teardown como sentencia de "
            "primer nivel: comentado o metido en un if que no se cumple nunca, "
            "el guard lo daba por vivo y el microfono quedaba tomado para "
            "todo el proceso"
        )
        teardown = _strip_dart_comments(
            _body_after(source, "Future<void> _releaseMicrophoneOnTeardown()")
        )
        sentencias = _statements_at_depth(teardown, 2)
        assert "if (!_transcriptionService.hasMicrophoneClaim) return" in sentencias, (
            f"{name}: el teardown debe cortar antes si no hay claim vivo"
        )
        assert "await _transcriptionService.releaseMicrophoneClaim()" in sentencias, (
            f"{name}: la liberacion debe ser sentencia directa del try: dentro "
            "de un if puede no ejecutarse nunca y el claim queda tomado"
        )
        parada = re.search(
            r"if \(([^()]+)\) \{\s*await _transcriptionService\.stopRecording\(\);\s*\}",
            teardown,
        )
        assert parada, (
            f"{name}: el teardown debe CERRAR la captura viva antes de liberar. "
            "Liberar el claim con el AudioRecord abierto deja un microfono "
            "huerfano que otro entrypoint puede tomar en paralelo."
        )
        condicion = re.sub(r"\s+", " ", parada.group(1)).strip()
        assert condicion in {
            "_isRecording",
            "_isStartingRecording",
            "_isRecording || _isStartingRecording",
        }, (
            f"{name}: el stopRecording del teardown debe estar atado al estado "
            f"de grabacion, no a una rama muerta (condicion real: '{condicion}')"
        )
        assert any(s.startswith("if (") and "_is" in s for s in sentencias), (
            f"{name}: la guarda del stop debe ser sentencia del teardown, no un "
            "bloque anidado que puede quedar sin ejecutar"
        )

    # 5) Estado visual publicado antes o en el mismo claim (nada obsoleto).
    h_start = home[home.index("Future<void> _startRecording"):home.index("Future<void> _cancelHoldIfTooShort")]
    assert h_start.index("updateBubbleState(BubbleVisualState.recording)") < h_start.index(
        "_transcriptionService.startRecording(path)"
    )
    assert "BubbleVisualState.idle" in h_start[h_start.index("} catch (e) {"):]
    assert h_start.index("if (!mounted)") < h_start.index("_transcriptionService.startRecording(path)"), (
        "Una pantalla destruida no puede tomar el microfono"
    )
    n_dictate = notes[notes.index("Future<void> _dictateNew"):notes.index("Future<void> _stopAndSave")]
    assert n_dictate.index("_publishBubbleState(BubbleVisualState.recording)") < n_dictate.index(
        "_transcriptionService.startRecording(path)"
    )
    assert "BubbleVisualState.idle" in n_dictate
    assert n_dictate.index("if (!mounted)") < n_dictate.index(
        "_transcriptionService.startRecording(path)"
    ), "Una pantalla destruida no puede tomar el microfono"
    n_stop = notes[notes.index("Future<void> _stopAndSave"):notes.index("Future<void> _transcribePending")]
    assert "finally {" in n_stop and "_publishBubbleState(BubbleVisualState.idle)" in n_stop
    assert "floatingBubbleService" in notes

    # 6) Pruebas de carrera reales (no solo guard estatico).
    for marker in (
        "fun concurrentClaimsHaveExactlyOneWinner",
        "fun staleTokenDoesNotFreeTheCurrentClaim",
        "fun keyboardAndWidgetRaceHasASingleWinner",
        "fun widgetDictationStaysOutWhenKeyboardHoldsTheClaim",
        "fun duplicateReleaseDuringTakeoverNeverStealsTheNewOwner",
        "fun concurrentClaimAndDuplicateReleaseNeverOverlapTwoOwners",
        "fun widgetReTapWhileBusyIsIgnoredInsteadOfClaimingAgain",
    ):
        assert marker in kt_test, f"Falta la carrera nativa {marker}"
        cuerpo = _body_after(kt_test, f"{marker}(")
        assert re.search(r"\bassert(?:True|False|Equals|Null|ArrayEquals)\(", cuerpo), (
            f"La carrera nativa {marker} debe ASERTAR su invariante: con el "
            "nombre y el cuerpo vacio el step bloqueante de CI queda verde por "
            "no comprobar nada"
        )
    assert "assumeTrue" not in kt_test and "Assume." not in kt_test, (
        "Un test nativo con Assume se salta a si mismo y el step bloqueante "
        "queda verde por no ejecutar la carrera"
    )
    for afirmacion in (
        "assertEquals(1L, maxHolders.get().toLong())",
        "assertEquals(1, winners.get())",
        "assertFalse(BackgroundWork.isMicrophoneClaimed())",
        "assertEquals(0L, widget.microphoneClaim)",
        "assertTrue(BackgroundWork.isMicrophoneClaimedBy(segundo))",
    ):
        assert afirmacion in kt_test, f"La prueba nativa debe asertar {afirmacion}"
    for marker in (
        "el claim se toma inmediatamente antes de recorder.start",
        "el claim propio ya excluye al rival en el instante del start",
        "carrera burbuja vs Notas: un solo ganador llega a recorder.start",
        "libera el claim si recorder.start lanza",
        "un token obsoleto no libera el claim de otro",
        "sin canal nativo falla cerrado: la burbuja no puede grabar sola",
        "un canal que lanza no deja un microfono irrecuperable",
    ):
        assert marker in dart_test, f"Falta la carrera Dart {marker}"
        assert re.search(
            r"\bexpect[A-Za-z]*\(", _dart_test_body(dart_test, marker)
        ), f"La carrera Dart '{marker}' debe asertar su invariante, no solo existir"
    for afirmacion in (
        "expect(recorder.startCount, 0);",
        "expect(order, ['permission', 'claim', 'start']);",
        "expect(gate.releases, 1);",
        "expect(liberaciones, [7]);",
    ):
        assert afirmacion in dart_test, f"La prueba Dart debe asertar {afirmacion}"
    for marker in (
        "Home publica el estado visual antes de tomar el claim",
        "Home no arranca con el microfono tomado y vuelve a idle",
        "Notas toma el claim tras publicar el estado visual",
        "Notas no arranca con el microfono tomado",
        "Home libera el microfono si desaparece grabando",
        "Home libera el claim aunque el recorder no pueda cerrar",
        "Notas libera el microfono si desaparece grabando",
        "Home no toma el microfono si desaparece durante el arranque",
        "Home no deja el microfono tomado si desaparece con recorder.start en vuelo",
        "Notas libera el microfono si el segundo toque llega con recorder.start en vuelo",
    ):
        assert marker in ui_test, f"Falta la prueba de UI {marker}"
        assert re.search(
            r"\bexpect[A-Za-z]*\(", _dart_test_body(ui_test, marker)
        ), f"La prueba de UI '{marker}' debe asertar su invariante, no solo existir"
    ventana = _dart_test_body(
        ui_test, "Home no deja el microfono tomado si desaparece con recorder.start en vuelo"
    )
    for afirmacion in (
        "expect(recorder.starts, 1);",
        "expect(service.hasMicrophoneClaim, isTrue);",
        "expect(gate.isClaimed, isFalse);",
        "expect(gate.claim(), isNot(0));",
    ):
        assert afirmacion in ventana, (
            "La prueba de la ventana de arranque debe asertar "
            f"{afirmacion}: es la unica que prueba que el claim se publico "
            "antes de await recorder.start"
        )
    assert "class _HangingStartRecorder" in ui_test, (
        "La prueba de teardown durante el arranque necesita un recorder cuyo "
        "start() no resuelve (los tres de teardown anteriores esperan a que el "
        "arranque termine y ninguno entra en la ventana peligrosa)"
    )
    assert "Robolectric.buildService(" in kt_test, (
        "MicrophoneClaimTest debe crear el Service con el harness de Robolectric "
        "(buildService(...).create()), no con el constructor"
    )
    assert "WidgetDictationService()" not in kt_test, (
        "MicrophoneClaimTest no debe instanciar el Service directo: el ctor de "
        "android.app.Service toca ActivityManager.getService()"
    )


def _pubspec_version(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    m = re.search(r"^version:\s*(\S+)\s*$", content, re.MULTILINE)
    assert m, f"Sin clave version en {path}"
    return m.group(1)

def test_manifest_retention():
    manifest_path = "voice_bubble_stt/android/app/src/main/AndroidManifest.xml"
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()
    assert 'android:hasFragileUserData="true"' in content, "Falta android:hasFragileUserData=\"true\""
    assert 'android:allowBackup="true"' in content, "Falta android:allowBackup=\"true\""
    assert 'android.permission.BIND_ACCESSIBILITY_SERVICE' not in content, "Falla de seguridad: AndroidManifest no debe declarar BIND_ACCESSIBILITY_SERVICE (perfil anti-Play-Protect 2026-09-05)"
    assert 'VoiceBubbleAccessibilityService' not in content, "AndroidManifest no debe registrar VoiceBubbleAccessibilityService (perfil anti-Play-Protect)"
    assert 'android:name=".FloatingTrackpadService"' in content, "ITEM-INTERFAZ: AndroidManifest debe declarar FloatingTrackpadService como servicio normal (otro agente lo declara)"
    assert os.path.isfile("voice_bubble_stt/android/app/debug.keystore"), "Falta voice_bubble_stt/android/app/debug.keystore persistente"
    # Consistencia de versión entre ambos pubspec (sin literal congelado).
    v_app = _pubspec_version("app_source/pubspec.yaml")
    v_vb = _pubspec_version("voice_bubble_stt/pubspec.yaml")
    assert v_app == v_vb, f"Versiones divergentes: app_source={v_app} vs voice_bubble_stt={v_vb}"
    with open("voice_bubble_stt/android/app/build.gradle.kts", "r", encoding="utf-8") as f:
        gradle_kts = f.read()
    assert 'debug.keystore' in gradle_kts, "build.gradle.kts debe configurar debug.keystore persistente"
    # SPK-03: release jamás firmado con debug (el bloque release no debe
    # nombrar el keystore de desarrollo ni su password pública).
    release_block = gradle_kts.split('create("release")')[1]
    assert "debug.keystore" not in release_block, "El bloque release no debe usar debug.keystore"
    assert '"android"' not in release_block, "Password pública en release prohibida"

def _delegate(script):
    def run():
        res = subprocess.run(["python3", script], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        assert res.returncode == 0, f"Fallo en {script}: {res.stderr}\n{res.stdout}"
    return run

def main():
    print("=" * 70)
    print(" 🚀 INICIANDO MASTER VERIFICATION SUITE - VOICEBUBBLE STT")
    print("=" * 70)
    tests = [
        ("CI Guard: Paridad de Claves de Contrato", test_contract_keys),
        ("C-02: Guard de StringList, parser y test nativo", test_c02_history_contract),
        ("CI Guard: Ausencia de Filtraciones en Logs", test_clean_logs),
        ("CI Guard: Sin secretos versionados (SPK-01)", test_no_versioned_secrets),
        ("Seguridad: Bóveda cifrada de secretos (SPK-02)", test_secrets_vault),
        ("Dictado: tope 5min + timeouts (fuente única)", test_dictation_contract),
        ("C-05: exclusión mutua del micrófono", test_c05_mic_exclusion_contract),
        ("Persistencia: Retención al desinstalar (hasFragileUserData)", test_manifest_retention),
    ]
    for name, script in SUITES:
        tests.append((f"{name} [{script}]", _delegate(script)))

    passed = 0
    for name, func in tests:
        if run_test(name, func):
            passed += 1

    print("=" * 70)
    print(f" RESULTADO FINAL: {passed}/{len(tests)} módulos verificados con éxito.")
    print("=" * 70)

    if passed == len(tests):
        print("✨ guardas locales pasan; native/Flutter pendientes de CI.")
        sys.exit(0)
    else:
        print("⚠️ ALGUNOS MÓDULOS PRESENTARON FALLOS.")
        sys.exit(1)

if __name__ == "__main__":
    main()
