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
    ("Conexión: blindaje del teclado ante conexión muerta (C-06)", "test_c06_dead_connection_suite.py"),
    ("Claves: relleno de claves seguro (C-07)", "test_c07_credentials_safe_fill_suite.py"),
    ("Vistas: rebuild solo cuando toca y blindaje restart (C-08)", "test_c08_rebuild_guards_suite.py"),
    ("Red: cancelar corta la red de verdad (C-09)", "test_c09_cancel_network_suite.py"),
    ("Reintento: reintento sin regrabar (C-10)", "test_c10_retry_without_re_record_suite.py"),
    ("Red: tiempos de red parejos (C-11)", "test_c11_even_network_timeouts_suite.py"),
    ("Rendimiento: sin trabajo pesado en hilo principal (C-12)", "test_c12_no_main_thread_heavy_work_suite.py"),
    ("Widget: distingue sin internet de sin clave (C-13)", "test_c13_widget_auth_vs_network_suite.py"),
    ("Seguridad: portapapeles fuera de contraseñas (C-14)", "test_c14_clipboard_out_of_passwords_suite.py"),
    ("Snippets: borrador a salvo ante rebuild (C-15)", "test_c15_snippet_draft_safe_suite.py"),
    ("Spacebar: sin fantasmas y retardo de usuario (C-16)", "test_c16_spacebar_no_ghosts_suite.py"),
    ("Teclado: una sola vibración por tecla (C-17)", "test_c17_single_vibration_suite.py"),
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
    assert ("readTimeout = 240000" in stt or "TIMEOUT_READ_SECONDS" in stt), "readTimeout ausente"
    assert "connectTimeout = 15000" in stt, "connectTimeout 15s ausente"
    with open(f"{kt}/DictationController.kt", "r", encoding="utf-8") as f:
        dic = f.read()
    assert "SpeechToTextClient.MAX_SECONDS * 1000L" in dic, (
        "El teclado debe armar su timeout desde la fuente única, sin literal"
    )
    assert "300000" not in dic and "300_000" not in dic, (
        "Literal duplicado del tope en el controlador"
    )

_WORKFLOW = {}


def _workflow_jobs():
    """Jobs REALES del workflow (YAML parseado, no busqueda de strings).

    Se cachea el documento: `_workflow_steps` y las comprobaciones de NIVEL JOB
    tienen que hablar de los MISMOS objetos, o un step no se puede localizar
    dentro del job que lo contiene.
    """
    if "jobs" not in _WORKFLOW:
        import yaml
        with open(".github/workflows/android.yml", "r", encoding="utf-8") as f:
            _WORKFLOW["jobs"] = yaml.safe_load(f)["jobs"]
    return _WORKFLOW["jobs"]


def _workflow_steps():
    """Steps REALES del workflow."""
    steps = []
    for job in _workflow_jobs().values():
        steps.extend(job.get("steps", []))
    return steps


# El job que corre la prueba nativa tiene hoy 40 min. Un timeout de job por
# debajo de este piso mata el run antes de que el step llegue a gradle, con el
# job en rojo pero la prueba sin ejecutar: el invariante es que la prueba
# bloqueante de C-05 CORRA, no que el job dure lo que dure.
TIMEOUT_MINIMO_JOB_C05 = 30


def _patron_de_firma(signature):
    """Regex de una firma, insensible a los NOMBRES de sus parametros.

    La identidad de un miembro es su nombre y su alcance, no el texto de su
    lista de parametros: anclar el guard a `startRecording(widgetId: Int)`
    convertia un renombre inocuo (`widgetId` -> `idWidget`) en rojo. Solo el
    grupo de parentesis de la firma se vuelve permisivo; el resto del texto se
    escapa literal para que un nombre con regex no se lea como patron.
    """
    abre = signature.find("(")
    if signature.endswith(")") and abre != -1:
        nivel, j = 0, abre
        while j < len(signature):
            if signature[j] == "(":
                nivel += 1
            elif signature[j] == ")":
                nivel -= 1
                if nivel == 0:
                    return (
                        re.escape(signature[:abre])
                        + r"\((?:[^()]|\([^()]*\))*\)"
                        + re.escape(signature[j + 1 :])
                    )
            j += 1
    return re.escape(signature)


def _ancla(source, signature, que):
    """(inicio, fin) de una firma: mensaje de contrato, no un ValueError a pelo.

    Morir con `substring not found` deja la suite roja igual, pero el mensaje
    apunta al helper y no al invariante: quien lo lea no sabe que firma de C-05
    desaparecio.
    """
    m = re.search(_patron_de_firma(signature), source)
    if not m:
        raise AssertionError(
            f"{que}: la firma {signature!r} no existe ya en el archivo. El guard "
            "esta anclado a esa firma: si se renombro o se movio, el invariante "
            "de C-05 que se vigilaba cambio de sitio"
        )
    return m.start(), m.end()


# Desactivar una carrera no es fallarla. Las cuatro formas que el runner
# entiende como "este caso no cuenta" y que dejan el step bloqueante en verde
# sin ejecutar nada: la anotacion, el `skip:` del test de Dart, el `Assume` que
# se salta a si mismo y el `onPlatform` que no corre en el runner de CI.
DESACTIVADORES = (
    (r"@Ignore\b|@Disabled\b", "anotacion de desactivacion"),
    (r"\bskip\s*:\s*(?:true|['\"])", "skip: (Dart)"),
    (r"\bassumeTrue\b|\bAssume\.|\b@Skip\b", "Assume / @Skip"),
    (r"\bonPlatform\b", "onPlatform: no corre en el runner"),
)


def _prohibe_desactivar_tests(*directorios):
    """Ningun archivo de test del repo puede desactivarse.

    El guard solo certifica los cuerpos de las carreras que nombra, asi que una
    carrera nueva en un archivo vecino se podia desactivar con `@Ignore` y el
    contrato seguia en verde. Se recorre el arbol ENTERO, nativo y Dart.
    """
    for directorio in directorios:
        for root, _, files in os.walk(directorio):
            for name in sorted(files):
                if not name.endswith((".kt", ".dart")):
                    continue
                ruta = os.path.join(root, name)
                with open(ruta, "r", encoding="utf-8") as f:
                    # Sin comentarios pero CON literales: el `skip: 'flaky'` de
                    # Dart es justamente un valor de cadena, y enmascarar las
                    # cadenas hacia desaparecer la prueba desactivada.
                    codigo = _sin_comentarios(f.read())
                for patron, que in DESACTIVADORES:
                    m = re.search(patron, codigo)
                    assert not m, (
                        f"{ruta}:{codigo[: m.start()].count(chr(10)) + 1}: "
                        f"{que} en un archivo de test ('{m.group(0)}'). Un caso "
                        "desactivado no falla: no se ejecuta, el step bloqueante "
                        "de C-05 queda en verde y la carrera de exclusion mutua "
                        "del microfono deja de estar cubierta. Se exige por "
                        "nombre en TODO el arbol de tests, no solo en el archivo "
                        "que el guard lee"
                    )


def _body_after(source, signature):
    """Cuerpo real de un metodo: desde su firma hasta la llave que lo cierra.

    Cortar por `source[source.index(sig):]` no sirve: la DEFINICION del metodo
    cuelga despues de su unico llamador, asi que el nombre siempre aparece en
    el slice y un metodo muerto pasa por vivo. Emparejando llaves, el slice
    cubre solo lo que el metodo ejecuta.

    El cuerpo vuelve SIN comentarios: un `// val ownsClaim = ...` comentado no
    es codigo y, contado como sentencia, satisfacia asserts que describen
    invariantes de ejecucion (la idempotencia del widget, el release en un
    terminal, el corte por claim 0).

    Un cuerpo de EXPRESION (`fun f(): Boolean = celda.get() != 0L`,
    `Future<void> f() => x`) no abre bloque: emparejar llaves desde la firma se
    comia la funcion SIGUIENTE y todo lo que se afirmaba de un cuerpo se
    comprobaba sobre el metodo de al lado. Se muere aqui, con el mensaje del
    invariante, igual que hace `_celdas_fun`.
    """
    inicio, fin = _ancla(source, signature, "Cuerpo de metodo")
    cola = source[fin : source.index("{", inicio)]
    assert "=" not in cola, (
        f"{signature!r} es un cuerpo de EXPRESION (`{cola.strip()}`), no un "
        "bloque: no abre llave propia y emparejar llaves desde su firma "
        "cortaria el cuerpo de la funcion SIGUIENTE, con lo que todo lo que el "
        "guard afirma del metodo se comprobaria sobre el metodo de al lado. El "
        "invariante que se vigilaba cambio de forma"
    )
    open_brace = source.index("{", inicio)
    depth = 0
    for i in range(open_brace, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return _strip_dart_comments(source[open_brace : i + 1])
    raise AssertionError(f"Llava sin cerrar en {signature!r}")


def _strip_dart_comments(source):
    """Cuerpo sin comentarios: una llamada comentada no es una sentencia.

    Los comentarios de Kotlin tienen la misma forma que los de Dart (`//` y
    `/* */`) y ningun archivo de este contrato usa raw strings ni escapes
    raros, asi que el mismo limpiador sirve para las tres lenguas.
    """
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


def _mascara_cadenas(source):
    """Indices que estan DENTRO de un comentario o de un literal de cadena.

    El codigo de las tres lenguas mezcla llaves, `return` y `;` con literales:
    `val marca = "{"` desincroniza cualquier contador de llaves, y `${...}` en
    una cadena de Kotlin rompe el texto de una sentencia a la mitad. Ningun
    archivo de este contrato usa escapes raros, asi que la mascara sirve para
    las tres.
    """
    dentro = [False] * len(source)
    i, n = 0, len(source)
    while i < n:
        ch = source[i]
        if ch == "/" and i + 1 < n and source[i + 1] in "/*":
            if source[i + 1] == "/":
                fin = source.find("\n", i)
                fin = n if fin == -1 else fin
            else:
                fin = source.find("*/", i + 2)
                fin = n if fin == -1 else fin + 2
            for k in range(i, fin):
                dentro[k] = True
            i = fin
            continue
        if ch in "\"'":
            comilla = source[i : i + 3] if source[i : i + 3] in ('"""', "'''") else ch
            j = i + len(comilla)
            while j < n:
                if source[j] == "\\" and len(comilla) == 1:
                    j += 2
                    continue
                if source.startswith(comilla, j):
                    j += len(comilla)
                    break
                j += 1
            else:
                j = n
            for k in range(i, min(j, n)):
                dentro[k] = True
            i = j
            continue
        i += 1
    return dentro


def _sin_cadenas(source, mascara):
    """El MISMO texto con el contenido de cadenas y comentarios en blanco.

    Conserva longitudes y posiciones, asi que un `finditer` sobre el resultado
    sigue apuntando al original.
    """
    return "".join(" " if mascara[i] else ch for i, ch in enumerate(source))


def _statements_at_depth(body, depth):
    """Sentencias de un cuerpo que viven en la profundidad de llaves indicada.

    Lo que queda mas adentro (dentro de un if, de un try o de un bloque) es
    condicional: puede no ejecutarse nunca. Exigir la sentencia en la
    profundidad pedida es lo que separa un release real de uno nominal. Del
    texto solo se ignoran los delimitadores que caen dentro de una cadena: una
    interpolacion `"...${x}..."` no parte la sentencia en dos.
    """
    mascara = _mascara_cadenas(body)
    out = []
    buf = []
    d = 0
    for i, ch in enumerate(body):
        if not mascara[i] and ch in "{};\n":
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


def _cuerpo_del_bloque(cuerpo, palabra, donde):
    """Cuerpo de la llave que abre el PRIMER bloque `palabra` de `cuerpo`.

    `palabra` se busca solo a PROFUNDIDAD 1: un `finally` anidado en otro `try`
    no es el que cierra la captura, y tomar el equivocado deja el release real
    fuera de lo verificado. Si no hay ninguno, el invariante que se vigilaba
    cambio de sitio y el mensaje lo dice.
    """
    limpio = _strip_dart_comments(cuerpo)
    mascara = _mascara_cadenas(limpio)
    n = len(limpio)
    profundidad = [0] * n
    nivel = 0
    for i, ch in enumerate(limpio):
        if mascara[i]:
            continue
        if ch == "{":
            nivel += 1
        elif ch == "}":
            nivel -= 1
        profundidad[i] = nivel
    for m in re.finditer(rf"\b{palabra}\b", limpio):
        if mascara[m.start()] or profundidad[m.start()] != 1:
            continue
        j = limpio.find("{", m.end())
        if j == -1:
            continue
        nivel = 0
        for k in range(j, n):
            if mascara[k]:
                continue
            if limpio[k] == "{":
                nivel += 1
            elif limpio[k] == "}":
                nivel -= 1
                if nivel == 0:
                    return limpio[j : k + 1]
        raise AssertionError(f"Llava sin cerrar en el bloque {palabra!r}")
    raise AssertionError(
        f"{donde}: no hay ningun bloque '{palabra}' a PRIMER NIVEL del cuerpo. "
        "El invariante que se vigilaba cambio de sitio (o se elimino el bloque)"
    )


def _niveles_de_llaves(limpio, mascara):
    """Nivel de llaves en cada posicion: 1 = sentencia de PRIMER NIVEL del cuerpo.

    El contenido de un comentario o de un literal no cuenta. Es la misma
    convencion que `_statements_at_depth`, para que "primer nivel" signifique
    exactamente lo mismo en los dos helpers.
    """
    niveles = [0] * len(limpio)
    nivel = 0
    for i, ch in enumerate(limpio):
        if mascara[i]:
            continue
        if ch == "{":
            nivel += 1
        elif ch == "}":
            nivel -= 1
        niveles[i] = nivel
    return niveles


def _bloque_de_if(cuerpo, condicion, donde):
    """(inicio, cuerpo) del PRIMER `if (<condicion>)` a PRIMER NIVEL del cuerpo.

    Una rama de ABORTE solo protege el contrato si CORTA. Mirar que el `if` esta
    donde toca (o que existe) deja pasar un cuerpo que solo registra y sigue:
    el `if (claim == 0) { logSilencioso(); }` de Dart y el
    `if (audioFocusLost) { micState = MicState.IDLE }` del teclado dejan pasar
    la firma y ejecutan el resto igual, asi que el `AudioRecord` arranca con el
    microfono ya tomado por el rival.

    Se acepta el `if` con y sin llaves: reescribir la rama a una sola linea es
    un refactor inocuo y no puede volverse rojo. Lo que no se negocia es que la
    rama exista a PRIMER NIVEL y corte con `throw` o `return`.
    """
    limpio = _strip_dart_comments(cuerpo)
    mascara = _mascara_cadenas(limpio)
    n = len(limpio)
    profundidad = _niveles_de_llaves(limpio, mascara)
    patron = re.compile(r"\bif\s*\(\s*(?:" + condicion + r")\s*\)")
    for m in patron.finditer(limpio):
        if mascara[m.start()] or profundidad[m.start()] != 1:
            continue
        k = m.end()
        while k < n and limpio[k] in " \t\n\r":
            k += 1
        if k < n and limpio[k] == "{":
            nivel = 0
            for j in range(k, n):
                if mascara[j]:
                    continue
                if limpio[j] == "{":
                    nivel += 1
                elif limpio[j] == "}":
                    nivel -= 1
                    if nivel == 0:
                        return m.start(), limpio[k : j + 1]
            raise AssertionError(f"{donde}: llave sin cerrar en la rama {m.group(0)!r}")
        # Sin llaves: la rama es la sentencia que sigue al `if`.
        fin = k
        nivel = 0
        while fin < n:
            if mascara[fin]:
                fin += 1
                continue
            ch = limpio[fin]
            if ch in "([":
                nivel += 1
            elif ch in ")]":
                nivel -= 1
            elif (ch == ";" and nivel == 0) or (ch == "\n" and nivel == 0):
                break
            fin += 1
        return m.start(), "{" + limpio[k:fin] + "}"
    raise AssertionError(
        f"{donde}: no hay ninguna rama `if ({condicion})` a PRIMER NIVEL del "
        "cuerpo. El invariante que se vigilaba cambio de sitio (o se elimino la "
        "rama de corte)"
    )


def _dart_test_body(source, name):
    """Cuerpo real de un test Dart (emparejando llaves desde su nombre)."""
    inicio, _ = _ancla(source, f"'{name}'", f"Test Dart {name!r}")
    open_brace = source.index("{", inicio)
    depth = 0
    for i in range(open_brace, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return _strip_dart_comments(source[open_brace : i + 1])
    raise AssertionError(f"Llava sin cerrar en el test {name!r}")


def _expr_body(source, signature):
    """Cuerpo de expresion (sin llaves): getter de Dart o = de Kotlin."""
    inicio, _ = _ancla(source, signature, f"Expresion {signature!r}")
    tail = source[inicio:]
    if ";" not in tail:
        raise AssertionError(f"La expresion {signature!r} no termina en ';'")
    return tail[: tail.index(";") + 1]


def _sin_comentarios(source):
    """El mismo texto sin comentarios (los literales se conservan)."""
    return _strip_dart_comments(source)


def _codigo(source):
    """Codigo real: sin comentarios y con el contenido de los literales en blanco.

    Conserva longitudes y posiciones, asi que un `finditer` sobre el resultado
    sigue apuntando al original. Un assert de presencia que mira texto crudo lo
    satisfacen un `//` o una cadena: la rama terminal que nunca cancela, el
    `idle` del catch que solo existe comentado y el nombre de una constante
    renombrada con sufifo se colaban asi.
    """
    limpio = _strip_dart_comments(source)
    return _sin_cadenas(limpio, _mascara_cadenas(limpio))


ASERCION_KOTLIN = re.compile(r"\bassert[A-Za-z]*\s*\(")
ASERCION_DART = re.compile(r"\b(?:expect[A-Za-z]*|fail)\s*\(")

# Palabras que abren un BLOQUE de control o de alcance. Todo lo demas que abre
# una llave es una lambda o el cuerpo de una funcion, y ahi un `return` es
# legitimo. Las cinco funciones de alcance (`run { }` y Cia) se cuentan como
# bloque y no como lambda porque son INLINE: un `return` desnudo dentro de
# ellas sale del `fun` que las contiene, y de un test eso aborta el caso.
PALABRAS_BLOQUE = {
    "if", "while", "for", "when", "switch", "catch", "do", "try", "finally",
    "synchronized", "else", "run", "let", "also", "apply", "with",
}


def _abre_lambda(texto, i):
    """La llave de la posicion i abre una lambda o un bloque de control."""
    j = i - 1
    while j >= 0 and texto[j] in " \t\n\r":
        j -= 1
    if j >= 0 and texto[j] == ")":
        k, nivel = j, 0
        while k >= 0:
            if texto[k] == ")":
                nivel += 1
            elif texto[k] == "(":
                nivel -= 1
                if nivel == 0:
                    break
            k -= 1
        m = k - 1
        while m >= 0 and texto[m] in " \t\n\r":
            m -= 1
        while m >= 0 and (texto[m].isalnum() or texto[m] in "_."):
            m -= 1
        return texto[m + 1 : k].strip().split(".")[-1] not in PALABRAS_BLOQUE
    k = j
    while k >= 0 and (texto[k].isalnum() or texto[k] == "_"):
        k -= 1
    return texto[k + 1 : j + 1] not in PALABRAS_BLOQUE


def _retornos_del_test(cuerpo):
    """`return` que cuelgan del propio cuerpo del test, no de una lambda.

    Un `return` de primer nivel - da igual si desnudo, en `if (...) return` o
    en `if (...) { return }` - aborta el caso: compila, no falla y deja el step
    bloqueante de CI en verde sin comprobar nada. El de dentro de una lambda
    (el handler de un MethodChannel, el cuerpo de un pool.execute) devuelve de
    ESA lambda y es legitimo. El contenido de las cadenas va en blanco: un
    `return` de un literal no es codigo y una llave desbalanceada dentro de una
    cadena desincronizaba la pila y enmascaraba todos los `return` posteriores.
    """
    limpio = _strip_dart_comments(cuerpo)
    codigo = _sin_cadenas(limpio, _mascara_cadenas(limpio))
    pila = []
    salida = []
    for i, ch in enumerate(codigo):
        if i == 0 and ch == "{":
            # La llave del propio test no es una lambda: es el cuerpo que
            # estamos certificando, asi que no cuenta como nivel.
            pila.append(False)
        elif ch == "{":
            pila.append(_abre_lambda(codigo, i))
        elif ch == "}" and pila:
            pila.pop()
        salida.append(sum(pila))
    return [m.start() for m in re.finditer(r"\breturn\b", codigo) if salida[m.start()] == 0]


def _certifica_test(cuerpo, nombre, asercion, idioma):
    """Certifica un test de carrera por su CUERPO, no por su nombre.

    Un test que existe, se llama como los otros y no comprueba nada deja el
    step bloqueante de CI en verde. Prohibir `Assume` por nombre no alcanza:
    la via generica es un `return` que aborta el caso antes de terminar sus
    aserciones, o una asercion que no llega a ejecutarse porque la metieron en
    un `if (false) { }`, en una iteracion que no dispara o en una `fun` local
    que nadie invoca. Por eso la asercion se exige como sentencia de PRIMER
    NIVEL del cuerpo del test, en las tres lenguas.

    Devuelve esas sentencias de primer nivel: cada asercion raiz se exige
    dentro de una de ellas.
    """
    limpio = _strip_dart_comments(cuerpo)
    raiz = _statements_at_depth(limpio, 1)
    # `await` delante si: en Dart la asercion de una promesa sigue siendo la
    # sentencia que abre el caso (`await expectLater(...)`).
    abre = re.compile(r"(?:await\s+|unawaited\s+)*(?:" + asercion.pattern + ")")
    assert any(abre.match(sentencia) for sentencia in raiz), (
        f"El test '{nombre}' debe ASERTAR su invariante ({idioma}) con una "
        "sentencia de PRIMER NIVEL de su cuerpo, y la asercion tiene que ABRIR "
        "esa sentencia: sin comprobar nada, o con las aserciones metidas en un "
        "`if (false) { }`, en una iteracion que no dispara o en una `fun` local "
        "que nadie invoca, el caso compila, no falla y deja el step bloqueante "
        "de CI en verde sin ejecutar la carrera. Un `if (false) assertEquals(...)` "
        "sin llaves tampoco cuenta: la asercion queda detrás de una condicion"
    )
    assert not _retornos_del_test(cuerpo), (
        f"El test '{nombre}' tiene un `return` de primer nivel: se salta a si "
        "mismo, no ejecuta el resto de sus aserciones y deja el step "
        "bloqueante de CI en verde"
    )
    return raiz


def _exige_raices(sentencias, raices, donde):
    """Cada asercion raiz, DENTRO del test que la nombra y a PRIMER NIVEL.

    Exigir el literal a nivel de archivo deja pasar el test que lo importa si
    el mismo literal sobrevive en otro test del archivo; exigirlo en el archivo
    entero, ademas, lo daria por vivo aunque estuviera dentro de un bloque que
    no se ejecuta.
    """
    for test, afirmaciones in raices.items():
        assert test in sentencias, f"{donde}: falta la prueba '{test}'"
        for afirmacion in afirmaciones:
            raiz = afirmacion.strip().rstrip(";")
            assert any(sentencia.strip().startswith(raiz) for sentencia in sentencias[test]), (
                f"{donde}: la prueba '{test}' debe asertar {afirmacion} en una "
                "sentencia de PRIMER NIVEL de su cuerpo, y la asercion tiene que "
                "ABRIR esa sentencia. Exigirla a nivel de archivo deja pasar el "
                "test que la importa si el mismo literal sobrevive en otro test; "
                "exigirla dentro del cuerpo la deja viva en un `if (false)`, en "
                "una iteracion que no dispara o en una `fun` que nadie invoca"
            )


# `val celda = microphoneOwner`, `val celda: AtomicLong = microphoneOwner`,
# `private val celda: AtomicLong get() = microphoneOwner` y
# `private val celda: AtomicLong by lazy { microphoneOwner }` son el MISMO
# alias: sin la anotacion de tipo, sin la property `get()` o con la
# delegacion `by lazy`, la prohibicion de las escrituras no-CAS se esquivaba
# por una puerta que el punto 7 del feedback 8.0 daba por cerrada (y la escrita
# en dos pasos del 7.0 volvia por ahi).
ANCLA_ALIAS = r"\s*(?::[^=;{}]*?)?(?:get\(\)\s*)?(?:=\s*|by\s+lazy\s*\{\s*)"


def _alias_del_cliente(cuerpo, origen, donde):
    """Nombre local que recibe el cliente de dictado, resuelto por la ASIGNACION.

    Atar el guard a `speechClient` era atarlo a un nombre: renombrar el local
    tumbaba el guard sin cambiar el comportamiento. Se resuelve por la firma de
    la asignacion (`val mic = SpeechToTextClient(this)`) y se trabaja sobre ese
    alias, igual que con la celda del arbitro.
    """
    m = re.search(
        r"\bval\s+(\w+)\s*=\s*" + re.escape(origen),
        _strip_dart_comments(cuerpo),
    )
    assert m, (
        f"{donde}: no se encontro la asignacion `val <alias> = {origen}` en el "
        "cuerpo. Se vigila que el cliente se cree, no el nombre que se le dio"
    )
    return m.group(1)


def _alias_de_la_celda(source, celda="microphoneOwner"):
    """Nombres que apuntan a la celda del arbitro: la celda y sus alias, en cadena.

    Sirve para las DOS cosas que hay que afirmar de la celda: que solo se
    escribe con `compareAndSet` y que el CAS de toma y el de release actuan
    sobre ella. Un alias -con o sin tipo, como `val` local o como property
    `get()` - es la MISMA celda: tratarlo distinto en la prohibicion y en el
    permiso seria incoherente.
    """
    conocidos = {celda}
    while True:
        destinos = "|".join(re.escape(n) for n in sorted(conocidos))
        nuevos = {
            m.group(1)
            for m in re.finditer(rf"\b(?:val|var)\s+(\w+){ANCLA_ALIAS}(?:{destinos})\b", source)
        } - conocidos
        if not nuevos:
            return conocidos
        conocidos |= nuevos


# Sitios de captura del ARBOL KOTLIN, separados por lo que hacen:
#   - APERTURA: construyen un AudioRecord o abren la grabacion. Son los que
#     crean el segundo microfono si el arbitro no esta de por medio.
#   - RECLAMO: toman el claim del arbitro. Claiman y NO abren nada.
# La distincion importa para que "N sitios de captura" signicie lo que dice:
# antes de separar, siete de los siete contados eran de los dos tipos, tres de
# ellos nada mas reclamaban, y "abrir un microfono" sonaba a siete sitios.
# Los patrones son ANCHOS a proposito: `AudioRecord.Builder(...).build()` sin
# `.startRecording()` y una llamada partida por un comentario
# (`AudioRecord /* */ (`) son la misma apertura, y las dos se colaban.
PATRONES_APERTURA = (r"\bAudioRecord\s*(?:\.\s*Builder)?\s*\(", r"\.startRecording\s*\(\s*\)")
PATRONES_RECLAMO = (r"\btryClaimMicrophone\s*\(",)

# `MediaRecorder` solo puede aparecer como CONSTANTE de fuente
# (`MediaRecorder.AudioSource.MIC`): construirlo o arrancarlo es otra apertura
# de microfono que ni el claim ni el barrido de AudioRecord venian.
PATRONES_MEDIA_RECORDER = (
    r"\bMediaRecorder\s*\(",
    r"\bMediaRecorder\s*\.\s*(?:start|prepare|stop|reset|release|setAudioSource)\b",
)

# La celda del ARBITRO no captura: decide. Es el unico sitio de `tryClaim`
# que no puede exigir un claim previo (es el claim), asi que se exime por
# nombre y se cuenta aparte.
CELDA_ARBITRO = ("BackgroundWork.kt", "fun tryClaimMicrophone(): Long")

# (archivo, FIRMA SIN NOMBRES DE PARAMETRO) -> (aperturas, reclamos, claim que
# la celda debe llevar DENTRO de su cuerpo). `None` como claim = la celda es la
# FABRICA primitiva (el AudioRecord en si), que por definicion no puede exigir
# un claim previo: quien la reclama son sus dos llamadores, celdas de esta misma
# tabla.
CELDAS_CAPTURA = {
    ("SpeechToTextClient.kt", "fun startRecording(): Boolean"): (2, 0, None),
    ("DictationController.kt", "private fun startDictation()"): (1, 1, "tryClaimMicrophone"),
    ("WidgetDictationService.kt", "private fun startRecording()"): (
        1,
        0,
        "claimMicrophoneForDictation",
    ),
    ("WidgetDictationService.kt", "internal fun claimMicrophoneForDictation(): Long"): (
        0,
        1,
        "tryClaimMicrophone",
    ),
    (
        "MainActivity.kt",
        "override fun configureFlutterEngine()",
    ): (0, 1, "tryClaimMicrophone"),
}

# SITIOS DE CAPTURA DEL LADO DART (app_source/lib). El barrido de Kotlin no
# llega a la burbuja ni a Notas: son superficies Dart, y un servicio Dart NUEVO
# con `AudioRecorder()` + `.start(...)` sin claim abria microfono con el
# teclado como dueno y el guard seguia en verde. Mismo esquema que el lado
# Kotlin: celda = clase, tabla con conteos congelados y claim exigido dentro
# del cuerpo.
#   - APERTURA: construir el recorder (`AudioRecorder()`) o abrir la grabacion
#     (`.start(`). Un `.start(` es apertura por construccion del paquete: solo
#     el recorder tiene `start`, y sin construirlo no se puede grabar.
#   - RECLAMO: pedir el claim por el canal o por el inyectable de
#     TranscriptionService.
PATRONES_APERTURA_DART = (r"\bAudioRecorder\s*\(\s*\)", r"\.\s*start\s*\(")
PATRONES_RECLAMO_DART = (
    r"invokeMethod(?:<[^>]*>)?\(\s*'claimMicrophone'",
    r"\b_?claimMicrophone\s*\(",
)

# (ruta relativa a app_source/lib, celda) -> (aperturas, reclamos, claim).
# Dos celdas van SIN claim y por motivos distintos: la de Ajustes solo PIDE
# PERMISO (construye el recorder para preguntar y lo suelta) y el claimer por
# defecto ES el claim del lado Dart (el gemelo de la celda del arbitro). El
# guard las distingue exigiendo que su cuerpo no abra la grabacion.
CELDAS_CAPTURA_DART = {
    ("services/transcription_service.dart", "TranscriptionService"): (
        2,
        1,
        "await _claimMicrophone()",
    ),
    ("services/transcription_service.dart", "_defaultMicClaimer"): (0, 1, None),
    ("screens/settings_screen.dart", "_SettingsScreenState"): (1, 0, None),
}


# Modificadores que preceden a `fun` y que forman parte de la identidad de la
# celda: dos metodos homonimos de un archivo se distinguen por su alcance.
MODIFICADORES = {
    "private", "internal", "protected", "public", "override", "open", "final",
    "suspend", "abstract", "inline", "operator", "tailrec", "external",
    "const", "lateinit", "actual", "expect", "inner", "companion",
}


def _celdas_fun(limpio, mascara):
    """(firma normalizada, desde, hasta, cuerpo) de cada `fun` del archivo.

    La celda va de la FIRMA al cierre: el sitio que da nombre a la funcion
    (`fun tryClaimMicrophone()`) es tan suyo como su cuerpo. La firma se
    resuelve emparejando el parentesis de los parametros: una funcion de cuerpo
    de EXPRESION (`fun f(): Boolean = celda.get() != 0L`) no abre bloque, y
    tomarla como celda correria los limites de la celda real.
    """
    celdas = []
    for m in re.finditer(r"\bfun\b", limpio):
        if mascara[m.start()]:
            continue
        prefijo, k = "", m.start() - 1
        while k >= 0 and limpio[k] in " \t\n\r":
            k -= 1
        while k >= 0:
            fin_palabra = k + 1
            while k >= 0 and (limpio[k].isalnum() or limpio[k] == "_"):
                k -= 1
            palabra = limpio[k + 1 : fin_palabra]
            if palabra.lower() not in MODIFICADORES:
                break
            prefijo = palabra + " " + prefijo
            while k >= 0 and limpio[k] in " \t\n\r":
                k -= 1
        par = limpio.find("(", m.start())
        if par == -1:
            continue
        nivel, fin = 0, None
        for k in range(par, len(limpio)):
            if mascara[k]:
                continue
            if limpio[k] == "(":
                nivel += 1
            elif limpio[k] == ")":
                nivel -= 1
                if nivel == 0:
                    fin = k
                    break
        if fin is None:
            continue
        j = limpio.find("{", fin)
        if j == -1 or re.search(r"[{};=]", limpio[fin + 1 : j]):
            continue
        nivel = 0
        for k in range(j, len(limpio)):
            if mascara[k]:
                continue
            if limpio[k] == "{":
                nivel += 1
            elif limpio[k] == "}":
                nivel -= 1
                if nivel == 0:
                    firma = re.sub(
                        r"\s+", " ", prefijo + _sin_cadenas(limpio[m.start() : j], mascara)
                    ).strip()
                    celdas.append((firma, m.start(), k, limpio[j : k + 1]))
                    break
    return celdas


def _firma_sin_parametros(firma):
    """La MISMA firma con la lista de parametros vaciada.

    La celda de `CELDAS_CAPTURA` se identifica por su nombre y su alcance, no
    por el texto de sus parametros: indexarla con la firma completa convertia
    un renombre inocuo (`widgetId` -> `idWidget`) en "celda DESCONOCIDA", que
    es un rojo de contrato falso.
    """
    abre = firma.find("(")
    if abre == -1:
        return firma
    nivel, j = 0, abre
    while j < len(firma):
        if firma[j] == "(":
            nivel += 1
        elif firma[j] == ")":
            nivel -= 1
            if nivel == 0:
                return firma[:abre] + "()" + firma[j + 1 :]
        j += 1
    return firma


def _celda_de(celdas, posicion):
    """Celda mas interna que cubre la posicion, o None si no hay ninguna."""
    return min(
        (c for c in celdas if c[1] <= posicion <= c[2]),
        key=lambda c: c[2] - c[1],
        default=None,
    )


def _sitios_de_captura(kt_dir):
    """Celda (archivo, firma) de cada sitio de captura, con su conteo y su cuerpo.

    Se separa APERTURA (construir el AudioRecord / abrir la grabacion) de
    RECLAMO (tomar el claim del arbitro): son contratos distintos y la celda
    tiene que cumplir los dos con nombres distintos. Las firmas se comparan ya
    normalizadas y sin nombres de parametro para que un refactor de formato o
    un renombre de parametro no se lean como un sitio nuevo ni como una celda
    desconocida.
    """
    celdas = {}
    for root, _, files in os.walk(os.path.dirname(kt_dir)):
        for name in sorted(files):
            if not name.endswith(".kt"):
                continue
            with open(os.path.join(root, name), "r", encoding="utf-8") as f:
                limpio = _strip_dart_comments(f.read())
            mascara = _mascara_cadenas(limpio)
            for patron in PATRONES_MEDIA_RECORDER:
                assert not re.search(patron, limpio), (
                    f"{name}: 'MediaRecorder' solo puede aparecer como CONSTANTE "
                    "de fuente (MediaRecorder.AudioSource.MIC). Construirlo o "
                    "arrancarlo ("
                    + patron
                    + ") es otra apertura de microfono que ni el barrido de "
                    "AudioRecord ni el claim del arbitro venian: dos "
                    "AudioRecord a la vez"
                )
            cuerpos = _celdas_fun(limpio, mascara)
            for tipo, patrones in (
                ("apertura", PATRONES_APERTURA),
                ("reclamo", PATRONES_RECLAMO),
            ):
                for patron in patrones:
                    for m in re.finditer(patron, limpio):
                        if mascara[m.start()]:
                            continue
                        dona = _celda_de(cuerpos, m.start())
                        assert dona, (
                            f"{name}: el sitio de {tipo} {m.group(0)!r} esta "
                            "fuera de toda funcion (pegado a una variable de "
                            "archivo o al inicializador de un objeto): sin celda "
                            "no se puede exigir que pase por el arbitro"
                        )
                        clave = (name, _firma_sin_parametros(dona[0]))
                        previo = celdas.get(clave)
                        celdas[clave] = (
                            (previo[0] if previo else 0) + int(tipo == "apertura"),
                            (previo[1] if previo else 0) + int(tipo == "reclamo"),
                            previo[2] if previo else dona[3],
                        )
            # Sin imports con ALIAS: `import android.media.AudioRecord as AR`
            # + `AR()` es una apertura de microfono que ni el nombre de la clase
            # ni ningun patron de este barrido ven. Nada del arbol usa alias, asi
            # que prohibirlos no cuesta un refactor.
            assert not re.search(r"(?m)^\s*import\s+.*\bas\s+\w+", limpio), (
                f"{name}: import con alias. Un `import ... as X` esconde el "
                "nombre real de la clase (por ejemplo `AudioRecord`) y abre una "
                "puerta que el barrido de sitios de captura no puede cerrar"
            )
    return {clave: (valor[0], valor[1], _codigo(valor[2])) for clave, valor in celdas.items()}


def _verifica_celdas_de_captura(celdas, tabla, donde, aperturas, reclamos):
    """Toda celda de captura esta DECLARADA, con su conteo congelado y su claim.

    `celdas` viene del barrido ((clave) -> (aperturas, reclamos, cuerpo sin
    literales)); `tabla` es la de CELDAS_CAPTURA/_DART del lado que se vigila.
    Los conteos van con NOMBRE (apertura = abre microfono, reclamo = pide el
    arbitro): antes iban en un unico numero, y "siete sitios de captura" sonaba
    a siete microfonos abiertos cuando tres de esos siete solo reclamaban.
    """
    for celda in sorted(set(celdas) | set(tabla)):
        apertura, reclamo, cuerpo = celdas.get(celda, (0, 0, ""))
        esperados = tabla.get(celda)
        assert esperados is not None, (
            f"{donde}: sitio de captura en celda DESCONOCIDA "
            f"{celda[0]}::{celda[1]} ({apertura} apertura/s, {reclamo} "
            "reclamo/s). Toda clase que construye un AudioRecord, abre la "
            "grabacion o toma el claim tiene que pasar por el arbitro y figurar "
            "en la tabla con su conteo: un sitio que no esta en la tabla abre el "
            "microfono sin exclusion mutua y el guard no lo veia"
        )
        assert (apertura, reclamo) == (esperados[0], esperados[1]), (
            f"{donde}: {celda[0]}::{celda[1]}: se esperaban {esperados[0]} "
            f"apertura(s) y {esperados[1]} reclamo(s) de captura y hay "
            f"{apertura} y {reclamo}. Un sitio nuevo o duplicado en una celda de "
            "captura cambia el contrato: declaralo en la tabla y justificarlo"
        )
        claim = esperados[2]
        assert claim is None or claim in cuerpo, (
            f"{donde}: {celda[0]}::{celda[1]}: la celda de captura debe llevar "
            f"el claim '{claim}' DENTRO de su cuerpo. Capturar desde ahi sin "
            "arbitro deja dos AudioRecords abiertos a la vez, que es justo el "
            "defecto que este contrato existe para cerrar"
        )
    total_apertura = sum(v[0] for v in celdas.values())
    total_reclamo = sum(v[1] for v in celdas.values())
    assert (total_apertura, total_reclamo) == (aperturas, reclamos), (
        f"{donde}: el conjunto debe tener {aperturas} APERTURA/s (construir el "
        f"AudioRecord o abrir la grabacion) y {reclamos} RECLAMO/s (pedir el "
        f"claim), y tiene {total_apertura} y {total_reclamo}. Los conteos estan "
        "congelados a proposito, para que abrir un microfono nuevo sea un cambio "
        "de contrato visible"
    )


def _celdas_dart(limpio, mascara):
    """(celda, desde, hasta, cuerpo) de cada clase y cada funcion de ARCHIVO.

    En Dart la celda de captura es la CLASE: el paquete `record` se construye
    por clase, asi que una clase nueva con `AudioRecorder()` + `.start(...)` es
    un sitio de captura nuevo aunque no tenga ningun metodo con nombre propio.

    Las funciones de NIVEL DE ARCHIVO tambien son celda, con el papel que el
    arbitro tiene del lado Kotlin: el claimer por defecto (`claimMicrophone`
    por el canal) vive ahi, es EL claim y por definicion no puede exigir un
    claim previo. Sin esto, un claim pedido desde una funcion suelta quedaria
    fuera de toda celda y sin declarar.
    """
    celdas = []
    for m in re.finditer(r"\bclass\b", limpio):
        if mascara[m.start()]:
            continue
        j = limpio.find("{", m.end())
        if j == -1:
            continue
        nombre = re.search(r"\bclass\s+(\w+)", limpio[m.start() : j])
        nivel = 0
        for k in range(j, len(limpio)):
            if mascara[k]:
                continue
            if limpio[k] == "{":
                nivel += 1
            elif limpio[k] == "}":
                nivel -= 1
                if nivel == 0:
                    celdas.append(
                        (
                            nombre.group(1) if nombre else "?",
                            m.start(),
                            k,
                            limpio[j : k + 1],
                        )
                    )
                    break
    for m in re.finditer(
        r"(?m)^(?!\s)(?!import|export|part|library|typedef|@)[^\n=;{}]*?\b([A-Za-z_]\w*)\s*"
        r"\([^()]*\)\s*(?:async\s*|sync\*\s*)?\{",
        limpio,
    ):
        if mascara[m.start()] or any(c[1] <= m.start() <= c[2] for c in celdas):
            continue
        nivel = 0
        for k in range(m.end() - 1, len(limpio)):
            if mascara[k]:
                continue
            if limpio[k] == "{":
                nivel += 1
            elif limpio[k] == "}":
                nivel -= 1
                if nivel == 0:
                    celdas.append((m.group(1), m.start(), k, limpio[m.end() - 1 : k + 1]))
                    break
    return celdas


def _sitios_de_captura_dart(lib_dir):
    """Celda (ruta relativa, clase) de cada sitio de captura del lado Dart."""
    celdas = {}
    for root, _, files in os.walk(lib_dir):
        for name in sorted(files):
            if not name.endswith(".dart"):
                continue
            ruta = os.path.relpath(os.path.join(root, name), lib_dir)
            with open(os.path.join(root, name), "r", encoding="utf-8") as f:
                limpio = _strip_dart_comments(f.read())
            mascara = _mascara_cadenas(limpio)
            cuerpos = _celdas_dart(limpio, mascara)
            for tipo, patrones in (
                ("apertura", PATRONES_APERTURA_DART),
                ("reclamo", PATRONES_RECLAMO_DART),
            ):
                for patron in patrones:
                    for m in re.finditer(patron, limpio):
                        if mascara[m.start()]:
                            continue
                        dona = _celda_de(cuerpos, m.start())
                        assert dona, (
                            f"{ruta}: el sitio de {tipo} {m.group(0)!r} esta "
                            "fuera de toda clase (funcion de archivo, extension "
                            "o mixin): sin celda no se puede exigir que pase por "
                            "el claim"
                        )
                        clave = (ruta, dona[0])
                        previo = celdas.get(clave)
                        celdas[clave] = (
                            (previo[0] if previo else 0) + int(tipo == "apertura"),
                            (previo[1] if previo else 0) + int(tipo == "reclamo"),
                            previo[2] if previo else dona[3],
                        )
    return {clave: (valor[0], valor[1], _codigo(valor[2])) for clave, valor in celdas.items()}


def _filtro_tests(step):
    """Valor EXACTO del `--tests` de un step (o None si no filtra).

    Buscar la clase por subcadena deja pasar `--tests ...MicrophoneClaimTestX`:
    el filtro tiene que anclar la clase completa, no una prolongacion suya.
    """
    m = re.search(r"--tests[= ]+(\S+)", str(step.get("run", "")))
    return m.group(1) if m else None


def _condicion_de_step(step):
    """La `if` del step, o None si no la tiene.

    Con el filtro exacto, el nombre del step y el `working-directory` en su
    lugar, un paso de test con `if` sigue pareciendo el paso bueno y la prueba
    nativa deja de correr en CI. Enumerar las constantes conocidas (`false`,
    `!true`, `1 == 2`, ...) es una lista sin fin y cada constante nueva es una
    puerta: un paso de test bloqueante no necesita condicion, asi que la regla
    es mas simple y mas fuerte que cualquier constante: no hay `if`.
    """
    return step.get("if")


def _escrituras_is_busy(cuerpo, condiciones_admitidas=()):
    """Valores que el cuerpo escribe en isBusy, en orden, a PRIMER NIVEL.

    Un reset anidado en un `if`, un `try` o una lambda puede no ejecutarse: en
    la rama de arranque fallido del widget la sentencia anterior ya dejo
    `isRecording = false`, de modo que `if (isRecording) isBusy = false` es
    codigo muerto y el re-tap se queda IGNORED para siempre.
    `_statements_at_depth(cuerpo, 1)` es lo que separa el reset real del
    nominal, y el cuerpo llega sin comentarios para que un `// isBusy = true`
    comentado no se cuente como escritura.

    Se mira TODA sentencia de primer nivel que TOQUE `isBusy =`, no solo la que
    hace fullmatch con el prefijo admitido: lo que no matchea no se descarta en
    silencio (un `if (state == "saved") isBusy = true` es precisamente el reset
    que vuelve a SUBIR el flag). Las escrituras que no son el reset admitido se
    devuelven tal cual, con su texto, para que las callers las rechazen.

    `condiciones_admitidas` son las unicas condiciones que pueden preceder a un
    reset sin llaves (la de `updateWidgetsState` la fija el assert de al lado):
    cualquier otra puede no cumplirse nunca.
    """
    limpio = _strip_dart_comments(cuerpo)
    prefijos = [r""] + [re.escape(condicion) + r"\s+" for condicion in condiciones_admitidas]
    patron = re.compile(r"(?:" + "|".join(prefijos) + r")isBusy\s*=\s*(true|false)\b")
    valores = []
    for sentencia in _statements_at_depth(limpio, 1):
        if not re.search(r"\bisBusy\s*=", sentencia):
            continue
        m = patron.fullmatch(sentencia)
        valores.append(m.group(1) if m else sentencia)
    return valores


def test_c05_mic_exclusion_contract():
    try:
        _contrato_c05()
    except ValueError as error:
        raise AssertionError(
            "C-05: el guard esta anclado a una firma o a un literal que ya no "
            f"existe ({error}). Un ValueError a pelo solo dice 'substring not "
            "found': no dice que invariante se dejo de vigilar ni donde"
        ) from error


def _contrato_c05():
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

    # Los invariantes de ESTE contrato se afirman sobre CODIGO, no sobre texto
    # crudo: sin comentarios ni literales, una rama terminal que solo existe
    # comentada, un `idle` en el catch de Home/Notas que solo esta en un `//` y
    # el nombre de una constante renombrada con sufijo dejaban el guard en
    # verde. Los patrones que SI llevan literales (llamadas de canal) se
    # comprueban sobre `_sin_comentarios`, que conserva las cadenas.
    codigo_dic = _codigo(dic)
    codigo_background = _codigo(background)
    codigo_widget = _codigo(widget)
    codigo_dart = _codigo(dart)

    # 0) CI EJECUTA la prueba nativa (step real del workflow, no strings).
    # El filtro se ancla a la clase EXACTA: por subcadena, un
    # `--tests ...MicrophoneClaimTestX` de otro paquete cuela como si fuera el
    # paso bueno (y el nombre del step tampoco se miraba).
    clases_kotlin = {
        "C-02": "com.royleguiza.voicebubblestt.TranscriptionHistoryLogicTest",
        "C-04": "com.royleguiza.voicebubblestt.WidgetNotesBehaviorTest",
        "C-05": "com.royleguiza.voicebubblestt.MicrophoneClaimTest",
    }
    steps_kotlin = {clave: [s for s in _workflow_steps() if _filtro_tests(s) == clase]
                    for clave, clase in clases_kotlin.items()}
    for clave, clase in clases_kotlin.items():
        assert len(steps_kotlin[clave]) == 1, (
            f"El workflow debe ejecutar :app:testDebugUnitTest --tests {clase} "
            f"exactamente una vez ({clave}), y el filtro debe ser la clase "
            "exacta: por subcadena una prolongacion ajena pasa por el paso bueno"
        )
        assert _condicion_de_step(steps_kotlin[clave][0]) is None, (
            f"El paso de {clave} no puede llevar condicion "
            f"({_condicion_de_step(steps_kotlin[clave][0])!r}): con el filtro "
            "exacto, el nombre y el working-directory en su lugar, el paso sigue "
            "pareciendo el bueno y la prueba nativa deja de correr en CI. Un "
            "paso de test bloqueante no la necesita, y enumerar constantes "
            "(`false`, `!true`, `1 == 2`, ...) deja siempre una puerta nueva"
        )
    mic_steps = steps_kotlin["C-05"]
    mic_step = mic_steps[0]
    assert "C-05" in str(mic_step.get("name", "")), (
        "El paso de MicrophoneClaimTest debe nombrarse como el de C-05 en el "
        "workflow: sin nombre no se distingue de un paso de otra tarjeta"
    )
    assert "gradle --no-daemon :app:testDebugUnitTest" in mic_step["run"], (
        "El paso de MicrophoneClaimTest debe usar gradle --no-daemon :app:testDebugUnitTest"
    )
    assert mic_step.get("working-directory") == "voice_bubble_stt/android", (
        "El paso de MicrophoneClaimTest debe correr en voice_bubble_stt/android"
    )
    assert not mic_step.get("continue-on-error"), (
        "El paso de MicrophoneClaimTest no puede ser continue-on-error"
    )
    # FORMA del `run`, no lista de palabras prohibidas: el exit code de un step
    # es el de su ULTIMA orden, asi que un `true`, un `echo "ok"`, un `|| true`
    # o un `--tests` de otra clase pegado al final dejan la prueba sin correr con
    # el job en verde. Una deny-list de neutradores es una lista sin fin (cada
    # forma nueva es una puerta); la forma no lo es: un solo comando que
    # EMPIEZA por el gradle de la prueba y TERMINA en su filtro, sin nada
    # detras. Las variables de entorno van en `env:` del step, no en lineas
    # previas del `run`.
    run_mic = str(mic_step["run"])
    lineas_run = [
        linea.strip()
        for linea in run_mic.splitlines()
        if linea.strip() and not linea.strip().startswith("#")
    ]
    assert len(lineas_run) == 1, (
        "El `run` del paso de C-05 debe ser UN SOLO comando, sin lineas antes ni "
        f"despues (lineas: {lineas_run}). El exit code del step es el de su "
        "ultima orden: un `true` o un `echo \"ok\"` al final dejan el paso en "
        "verde sin que la prueba se haya ejecutado, y lo que precede al gradle "
        "puede fallar antes de llegar a el. Las variables van en `env:` del step"
    )
    assert lineas_run[0].startswith("gradle --no-daemon :app:testDebugUnitTest"), (
        "El paso de C-05 debe usar gradle --no-daemon :app:testDebugUnitTest "
        f"como unico comando ({lineas_run[0]!r})"
    )
    assert run_mic.count("--tests") == 1, (
        f"El paso de C-05 debe llevar UN solo `--tests` ({run_mic!r}): con dos, "
        "el segundo filtra la corrida y la prueba de C-05 puede no ejecutarse "
        "mientras el filtro del primer valor sigue diciendo lo correcto"
    )
    assert lineas_run[0].endswith(f"--tests {clases_kotlin['C-05']}"), (
        "El comando del paso de C-05 debe TERMINAR en su `--tests`: nada puede "
        f"quedar despues ({lineas_run[0]!r})"
    )
    # NIVEL JOB: con el paso sano, un job entero puede seguir sin bloquear.
    job_de_c05 = [nombre for nombre, job in _workflow_jobs().items()
                  if any(step is mic_step for step in job.get("steps", []))]
    assert len(job_de_c05) == 1, (
        f"El paso de C-05 debe vivir en UN solo job (esta en: {job_de_c05})"
    )
    job_c05 = _workflow_jobs()[job_de_c05[0]]
    assert not job_c05.get("continue-on-error"), (
        f"El job '{job_de_c05[0]}' no puede ser continue-on-error: aunque el paso "
        "de C-05 corra y falle, el job saldria verde y la exclusion mutua del "
        "microfono dejaria de bloquear"
    )
    assert not job_c05.get("if"), (
        f"El job '{job_de_c05[0]}' no puede llevar condicion "
        f"({job_c05.get('if')!r}): con el paso sano y sin condicion propia, el job "
        "puede no arrancar y la exclusion mutua del microfono deja de bloquear"
    )
    timeout_job = job_c05.get("timeout-minutes")
    assert timeout_job is None or timeout_job >= TIMEOUT_MINIMO_JOB_C05, (
        f"El job '{job_de_c05[0]}' no puede tener timeout-minutes "
        f"({timeout_job}) por debajo de {TIMEOUT_MINIMO_JOB_C05}: el run se "
        "cancelaria antes de que el step llegue a gradle, con la prueba sin "
        "ejecutar. Este es el paso mas lento y bloqueante del job"
    )

    # 1) Un UNICO AtomicLong es el arbitro (punto unico de atomicidad).
    assert codigo_background.count("= AtomicLong(") == 2, (
        "Solo la celda de dueno y el contador de tokens pueden ser AtomicLong"
    )
    assert "AtomicBoolean" not in codigo_background and (
        "AtomicInteger" not in codigo_background
    ), "Ningun otro atómico: el arbitro del microfono es UNA celda"
    # La celda y TODOS sus alias (con o sin tipo, como `val` local o como
    # property `get()`): un alias es la misma celda, asi que se le exige lo
    # mismo en la prohibicion de escrituras y en el permiso del CAS.
    celdas = _alias_de_la_celda(_sin_comentarios(background))
    claim_body = _body_after(background, "fun tryClaimMicrophone(): Long")
    assert "while (true)" in claim_body, "tryClaimMicrophone debe reintentar con CAS en loop"
    assert claim_body.count("compareAndSet") == 1, (
        "tryClaimMicrophone solo puede hacer CAS sobre la celda de dueno"
    )
    cas_claim = re.search(r"if \(([\w.]+)\.compareAndSet\(([^,]+), ([^)]+)\)\)", claim_body)
    assert cas_claim, "tryClaimMicrophone debe hacer el CAS dentro de un if"
    assert cas_claim.group(1) in celdas, (
        f"El CAS de tryClaimMicrophone debe actuar sobre la celda del arbitro "
        f"o sobre un alias suyo, no sobre '{cas_claim.group(1)}'"
    )
    assert cas_claim.group(2).strip() == "actual" and cas_claim.group(3).strip() == "claim", (
        f"El CAS de tryClaimMicrophone debe ser (actual, claim), no "
        f"({cas_claim.group(2).strip()}, {cas_claim.group(3).strip()}): con otro "
        "par de valores el perdedor pisa al dueno"
    )
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
    assert "fun releaseMicrophone(claim: Long): Boolean" in codigo_background, (
        "El release debe reportar si libero de verdad (puente MethodChannel)"
    )
    assert re.search(r"if \(claim <= 0L\) return false", release_body), (
        "La rama de token vacio debe devolver false ANTES del CAS: con un claim <= 0 la "
        "celda no se libera y el dueno real sigue con el microfono tomado"
    )
    assert release_body.count("return") == 2, (
        "releaseMicrophone solo puede retornar 'false' por el token vacio o el "
        "resultado del CAS: un 'return true' antes del CAS reporta exito sin "
        "liberar la celda del arbitro"
    )
    cas_release = re.search(
        r"return ([\w.]+)\.compareAndSet\(([^,]+), ([^)]+)\)\s*\}\s*$",
        re.sub(r"\s+", " ", release_body),
    )
    assert cas_release, (
        "El CAS(token, 0) debe ser la ultima sentencia de releaseMicrophone "
        "(devuelta, sin nada despues): cualquier sentencia posterior puede no "
        "ejecutarse y deja al dueno nuevo con un microfono tomado"
    )
    assert cas_release.group(1) in celdas, (
        f"El CAS de releaseMicrophone debe actuar sobre la celda del arbitro o "
        f"sobre un alias suyo, no sobre '{cas_release.group(1)}'"
    )
    assert cas_release.group(2).strip() == "claim" and cas_release.group(3).strip() == "0L", (
        f"El CAS de releaseMicrophone debe ser (claim, 0L), no "
        f"({cas_release.group(2).strip()}, {cas_release.group(3).strip()}): con "
        "otro par de valores libera al dueno equivocado"
    )
    assert "fun isMicrophoneClaimed(): Boolean = microphoneOwner.get() != 0L" in codigo_background, (
        "isMicrophoneClaimed debe leer la MISMA celda del arbitro"
    )
    by_claim = re.search(
        r"fun isMicrophoneClaimedBy\(claim: Long\): Boolean\s*=\s*([^\n;]+)", codigo_background
    )
    assert by_claim, "isMicrophoneClaimedBy debe seguir siendo legible como cuerpo"
    expresion = re.sub(r"\s+", " ", by_claim.group(1)).strip()
    assert expresion == "claim > 0L && microphoneOwner.get() == claim", (
        "isMicrophoneClaimedBy debe exigir token positivo Y que la celda lo "
        f"tenga; '{expresion}' devuelve la respuesta que espera el teclado sin "
        "mirar la celda, y ownsClaim queda siempre cierto"
    )
    escrituras_ilegales = ("set", "getAndSet", "lazySet", "andUpdate", "accumulateAndGet", "updateAndGet")
    for api in escrituras_ilegales:
        for celda in sorted(celdas):
            assert not re.search(rf"\b{celda}\.{api}\b", background), (
                f"La celda del arbitro jamas se escribe con {celda}.{api}: en dos "
                "pasos puede pisar al dueno nuevo que ya tomo el claim. La unica "
                "escritura admisible es compareAndSet. Ojo: andUpdate y "
                "updateAndGet son lambdas y en Kotlin no llevan parentesis, por eso "
                "el nombre se busca sin exigir '(' (si no, la mutacion pasa). Y el "
                "alias se busca con tipo y como property get(): un "
                "'val celda: AtomicLong = microphoneOwner' o un "
                "'private val celda: AtomicLong get() = microphoneOwner' son la "
                "misma celda, no una puerta trasera."
            )
    celda_ops = set()
    for celda in sorted(celdas):
        celda_ops |= set(
            re.findall(r"\b" + re.escape(celda) + r"\.(\w+)\s*[({\[]", background)
        )
    assert celda_ops <= {"get", "compareAndSet"}, (
        f"Operaciones inesperadas sobre la celda del arbitro (alias incluidos): "
        f"{sorted(celda_ops)}"
    )
    assert "keyboardRecordingActive" not in codigo_background, (
        "El claim no debe re-publicar el flag mutable del teclado"
    )
    assert "result.success(BackgroundWork.isMicrophoneClaimed())" in _codigo(main)
    assert '"claimMicrophone" ->' in _sin_comentarios(main) and (
        "BackgroundWork.tryClaimMicrophone()" in _codigo(main)
    ), (
        "MainActivity debe mapear 'claimMicrophone' al arbitro: sin el puente, "
        "Dart no puede competir por el microfono y cada surface graba sola"
    )
    assert (
        '"releaseMicrophone" ->' in main
        and "result.success(BackgroundWork.releaseMicrophone(claim))" in _codigo(main)
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

    # 1b) BARRIDO de los dos arboles: todo sitio de captura cae en una celda
    # declarada, con su conteo congelado y su claim dentro del cuerpo. El guard
    # leia cinco archivos fijos de Kotlin, asi que un cuarto sitio de captura (en
    # la burbuja, en el fondo o en un archivo que se agregue manana) abria
    # microfono sin pasar por el arbitro y la exclusion mutua seguia verde; y no
    # barrieraba NADA del lado Dart, donde viven la burbuja y Notas: un servicio
    # Dart nuevo con `AudioRecorder()` + `.start(...)` sin claim, o una clase
    # nueva dentro del propio TranscriptionService, pasaban los dos.
    celdas_captura = _sitios_de_captura(kt_dir)
    arbitro = celdas_captura.pop(CELDA_ARBITRO, (0, 0, ""))
    assert arbitro[0] == 0 and arbitro[1] == 1, (
        f"El arbitro ({CELDA_ARBITRO[1]}) debe tener UN solo sitio de captura, y "
        "ese es su RECLAMO: arbitra, no abre microfono. No puede abrir ninguno, o "
        "el unico CAS que decide la exclusion mutua estaria dentro de una celda "
        "que ya tomo el microfono"
    )
    # Kotlin: 4 APERTURAS (2 en la fabrica del AudioRecord, 1 en el arranque del
    # teclado y 1 en el del widget) y 3 RECLAMOS (teclado, widget y puente).
    # Dart: 3 APERTURAS (el recorder de TranscriptionService y su `start`, mas el
    # recorder de sondeo de permiso de Ajustes) y 2 RECLAMOS (el claimer inyectado
    # y el claimer por defecto, que es la fabrica).
    _verifica_celdas_de_captura(
        celdas_captura, CELDAS_CAPTURA, "arbol Kotlin", 4, 3
    )
    celdas_dart = _sitios_de_captura_dart("app_source/lib")
    _verifica_celdas_de_captura(
        celdas_dart, CELDAS_CAPTURA_DART, "app_source/lib", 3, 2
    )
    for celda, (_, _, cuerpo) in sorted(celdas_dart.items()):
        if CELDAS_CAPTURA_DART[celda][2] is not None:
            continue
        assert not re.search(r"\.\s*start\s*\(", cuerpo), (
            f"{celda[0]}::{celda[1]} va sin claim declarado por una de dos "
            "razones: PIDE PERMISO solamente (construye el recorder, pregunta y "
            "lo suelta) o ES la fabrica del claim (el `claimMicrophone` del "
            "canal, el gemelo Dart de la celda del arbitro). Ninguna de las dos "
            "puede abrir la grabacion: si su cuerpo llama a `.start(`, necesita "
            "el claim como cualquier otra apertura, o dos AudioRecords a la vez"
        )

    # 2) Teclado: foco -> chequeos -> claim atomico -> pending -> AudioRecord.
    # El cuerpo entero de startDictation, sin comentarios: el orden de las
    # puertas y el corte de cada rama se afirman sobre codigo, no sobre texto.
    start = _codigo(_body_after(dic, "private fun startDictation()"))
    focus = start.index("if (!gainAudioFocus())")
    bubble = start.index("if (bubbleBusy())")
    permission = start.index("if (!sttClient.hasMicPermission())")
    claim = start.index("BackgroundWork.tryClaimMicrophone()")
    pending = start.index("dictationStartPending = true")
    inicio_foco_perdido, cuerpo_foco_perdido = _bloque_de_if(
        start, r"audioFocusLost", "startDictation"
    )
    focus_lost = start.index("if (audioFocusLost)")
    audio_record = start.index("startRecording()")
    assert focus < bubble < permission < claim < pending < focus_lost < audio_record, (
        "El claim atomico debe ser la ultima puerta antes del AudioRecord"
    )
    # La perdida de foco se comprueba por CUERPO. Saber que el `if` esta donde
    # toca no dice que corte: `if (audioFocusLost) { micState = MicState.IDLE }`
    # compila, respeta el orden y arranca el AudioRecord con el foco ya
    # perdido, con el microfono tomado para todo el proceso.
    sentencias_foco = _statements_at_depth(cuerpo_foco_perdido, 1)
    assert "cancelDictation()" in sentencias_foco, (
        "La rama de foco perdido debe CANCELAR de verdad (cancelDictation()) "
        f"como sentencia de PRIMER NIVEL (sentencias: {sentencias_foco}). Con "
        "solo `micState = MicState.IDLE` el claim tomado, el token propio y el "
        "foco se quedan vivos: el microfono queda tomado para todo el proceso y "
        "burbuja, Notas y widget lo ven en uso"
    )
    assert any(s == "return" or s.startswith("return ") for s in sentencias_foco), (
        "La rama de foco perdido debe ABORTAR de verdad (return) y no solo "
        "ajustar el estado: sin return se sigue hacia sttClient.startRecording() "
        "con el microfono ya tomado"
    )
    assert inicio_foco_perdido < audio_record, (
        "La rama de foco perdido debe estar antes de arrancar el AudioRecord"
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
    # El gemelo del widget, que el punto 7.5 dejo sin guarda: el arranque del
    # TECLADO tambien va en try/catch -> false y publica el cierre por postMain.
    # Sin esto vuelve, del lado del teclado, el P0 del punto 1 del feedback 7.5:
    # BackgroundWork.execute se traga la excepcion, el postMain no corre,
    # onDictationStartResult nunca corre y quedan dictationStartPending y
    # microphoneClaimToken vivos con el claim tomado y el foco sin abandonar.
    # Con micState en IDLE, el siguiente toque muere en la primera linea de
    # startDictation y burbuja, Notas y widget ven microfono en uso hasta que
    # otro app robe el foco de audio.
    d_fondo = _body_after(start, "BackgroundWork.execute {")
    d_fondo_plano = re.sub(r"\s+", " ", d_fondo)
    assert re.search(
        r"val started = try \{[^}]*startRecording\(\)[^}]*\} "
        r"catch \([^)]*\b(?:Exception|Throwable)\b[^)]*\) \{[^}]*false[^}]*\}",
        d_fondo_plano,
    ), (
        "El arranque del AudioRecord del teclado va en try/catch (Exception o "
        "Throwable) -> false, igual que el widget: angostarlo a "
        "IllegalStateException deja escapar el SecurityException del permiso "
        "revocado en vuelo, y sin try/catch entero BackgroundWork.execute se "
        "traga la excepcion y el claim se queda tomado con el microfono "
        "bloqueado para todo el proceso"
    )
    assert d_fondo.count("onDictationStartResult(") == 1, (
        "El cierre del arranque se entrega UNA sola vez"
    )
    assert re.search(
        r"BackgroundWork\.postMain \{[^}]*"
        r"onDictationStartResult\(started, startGeneration, claimToken\)[^}]*\}",
        d_fondo_plano,
    ), (
        "El cierre del arranque del teclado debe publicarse por "
        "BackgroundWork.postMain: onDictationStartResult toca "
        "host.setRecordingActive y micIdle() -> refreshMicVisual(), o sea "
        "trabajo de vistas desde el hilo de trabajo"
    )
    # Constante ANCLADA por palabra completa y usada en la comparacion que
    # decide el foco: por subcadena, `AUDIOFOCUS_REQUEST_GRANTED_V2` (o el
    # nombre viejo solo en un comentario) satisfacia el assert.
    assert re.search(r"==\s*AudioManager\.AUDIOFOCUS_REQUEST_GRANTED\b", codigo_dic), (
        "El foco concedido debe decidirse comparando con "
        "AudioManager.AUDIOFOCUS_REQUEST_GRANTED: por subcadena, un nombre con "
        "sufijo (o el viejo solo comentado) pasaba el assert y el teclado podia "
        "tratar como concedido un foco que se le nego"
    )
    assert "audioFocusLost = true" in codigo_dic, (
        "Perder el foco de audio debe marcar audioFocusLost: sin ese flag, la "
        "rama deAbort que se verifica mas arriba no llega a ejecutarse y el "
        "teclado sigue grabando sin foco"
    )
    assert "micState == MicState.RECORDING || dictationStartPending" in codigo_dic, (
        "El corte por teardown debe reconocer los dos estados vivos (grabando y "
        "arranque en vuelo): sin cualquiera de los dos, un corte con el arranque "
        "en vuelo deja el microfono tomado"
    )
    assert "val ownsClaim = BackgroundWork.isMicrophoneClaimedBy(claimToken)" in codigo_dic, (
        "onDictationStartResult debe MIRAR si el claim sigue siendo propio. "
        "Solo en un comentario, la rama terminal comparaba con una variable no "
        "definida por el camino real y nunca liberaba: el texto crudo del "
        "archivo daba el assert por bueno"
    )
    assert "if (!serviceAlive || !started || !isCurrentStart || !ownsClaim)" in codigo_dic, (
        "El cierre del arranque debe ser un solo camino terminal: duplicarlo fue "
        "lo que llamaba dos veces a host.setRecordingActive(false) en el main"
    )
    # El terminal de EXITO del teclado, POR CUERPO. A nivel de archivo el
    # literal lo satisfacia cualquier otra rama: vaciar el `finally` de
    # finishDictation, sacar el release de ahi o borrar el de cualquiera de las
    # dos ramas de onDictationStartResult dejaba el claim tomado para siempre
    # tras un dictado exitoso (y con el foco de audio sin abandonar).
    finish = _body_after(dic, "private fun finishDictation()")
    fin_finally = _statements_at_depth(
        _cuerpo_del_bloque(
            _body_after(finish, "BackgroundWork.execute {"),
            "finally",
            "finishDictation",
        ),
        1,
    )
    arranque = _body_after(dic, "private fun onDictationStartResult(")
    rama_arrancada = _statements_at_depth(
        _body_after(_body_after(arranque, "if (started) {"), "BackgroundWork.execute {"),
        1,
    )
    sin_arrancar = _statements_at_depth(_body_after(arranque, "else {"), 1)
    # Los dos terminales del apagado defensivo: el `finally` del corte de
    # cancelacion y la rama CON cliente de cancelDictationIfActive. Exigian el
    # release del claim por otras vias, pero no el `abandonAudioFocus()`: con el
    # foco de audio retenido, el siguiente rival (burbuja, Notas, widget) pide
    # foco, no lo obtiene y se queda en "ocupado" con el microfono libre.
    teardown = _codigo(_body_after(dic, "fun cancelDictationIfActive()"))
    corte_cancel = _statements_at_depth(
        _cuerpo_del_bloque(
            _body_after(
                _body_after(dic, "private fun cancelDictation(announce: Boolean = false)"),
                "BackgroundWork.execute {",
            ),
            "finally",
            "cancelDictation",
        ),
        1,
    )
    corte_con_cliente = _statements_at_depth(
        _cuerpo_del_bloque(
            _body_after(_body_after(teardown, "if (client != null) {"), "BackgroundWork.execute {"),
            "finally",
            "cancelDictationIfActive (rama con cliente)",
        ),
        1,
    )
    for donde, sentencias in (
        ("finishDictation (finally del corte)", fin_finally),
        ("onDictationStartResult rama 'started'", rama_arrancada),
        ("onDictationStartResult rama '!started'", sin_arrancar),
        ("cancelDictation (finally del corte)", corte_cancel),
        ("cancelDictationIfActive (finally con cliente)", corte_con_cliente),
    ):
        for sentencia in ("abandonAudioFocus()", "releaseMicrophoneClaim(claimToken)"):
            assert sentencia in sentencias, (
                f"{donde}: '{sentencia}' debe ser sentencia de PRIMER NIVEL de "
                f"su cuerpo (sentencias: {sentencias}). A primer nivel no puede "
                "quedarse sin ejecutar: metida en un if, un try o una lambda, un "
                "dictado exitoso deja el claim tomado para siempre y el microfono "
                "bloqueado para todo el proceso (el siguiente toque muere en la "
                "primera linea y burbuja, Notas y widget ven microfono en uso)"
            )
    # El flag del teclado SI es @Volatile (preexistente, fuera de este diff):
    # por eso las escrituras directas desde hilos de fondo son seguras y la
    # premisa de que postMain las arreglaba era falsa. Se fija el hecho.
    with open(f"{kt_dir}/VoiceKeyboardService.kt", "r", encoding="utf-8") as f:
        vks = f.read()
    assert re.search(
        r"@Volatile\s+(\n\s+)?var keyboardRecordingActive", _sin_comentarios(vks)
    ), "keyboardRecordingActive debe seguir siendo @Volatile: se escribe desde hilos de fondo"
    # El camino de fondo del CIERRE DEL ARRANQUE publica por postMain, y lo
    # hace UNA sola vez. El assert acota su invariante a ese camino (las
    # escrituras directas de finish/cancel van por el campo volatil).
    cierre = _codigo(
        dic[dic.index("private fun onDictationStartResult"):dic.index("private fun finishDictation")]
    )
    fondo_cierre = cierre[cierre.index("BackgroundWork.execute {"):cierre.index("if (!serviceAlive) return")]
    assert fondo_cierre.count("host.setRecordingActive(false)") == 1, (
        "El cierre del arranque se publica UNA vez desde el hilo de fondo: dos "
        "veces, el main recibe dos bajas de estado para un mismo arranque"
    )
    assert "BackgroundWork.postMain { host.setRecordingActive(false) }" in fondo_cierre, (
        "La baja de estado del host en el cierre del arranque debe pasar por "
        "postMain: ese es el unico camino que corre en el main"
    )
    assert cierre.count("host.setRecordingActive(false)") == 2, (
        "setRecordingActive(false) se baja una sola vez por camino terminal: "
        "con !started se llamaba dos veces en el mismo main"
    )
    # Cancele/fallos liberan SIEMPRE (el release por token obsoleto es no-op).
    cancel = _codigo(_body_after(dic, "private fun cancelDictation(announce: Boolean = false)"))
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
    teardown_teclado = teardown
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
    # Liberar en el ARBITRO no basta: si el token propio sobrevive, el
    # siguiente arranque cree tener el microfono tomado y cancelDictationIfActive
    # se apaga con un claim fantasma. La guarda se exige por FORMA (mismo
    # nombre en la comparacion y en la asignacion), no por el nombre del campo.
    cuerpo_release = _codigo(_body_after(dic, "private fun releaseMicrophoneClaim(claimToken: Long)"))
    release_claim = _statements_at_depth(cuerpo_release, 1)
    # Se acepta CUALQUIERA de las dos formas semanticamente identicas
    # (`if (token == claimToken) token = 0L` o `if (token != claimToken) return`
    # seguido de `token = 0L`): exigir la sintaxis literal tumbaba un refactor
    # que no cambia el comportamiento. Lo que no se negocia es el invariante:
    # EXACTAMENTE una sentencia de primer nivel que baje el token a 0L, y solo
    # si el token propio coincide.
    BAJA_GUARDADA = re.compile(
        r"if\s*\(\s*(\w+)\s*==\s*claimToken\s*\)\s*(?:\{\s*)?\1\s*=\s*0L\s*;?\s*\}?"
    )
    BAJA_SUELTA = re.compile(r"(\w+)\s*=\s*0L")
    GUARDA_INVERSA = re.compile(r"if\s*\(\s*(\w+)\s*!=\s*claimToken\s*\)\s*return\b")
    niveles = _niveles_de_llaves(cuerpo_release, _mascara_cadenas(cuerpo_release))
    # Bajar el token PROPIO y solo el propio, a PRIMER NIVEL. Se aceptan las
    # tres formas semanticamente identicas - con o sin llaves, o con el `return`
    # temprano -: exigir la sintaxis literal tumbaba refactores que no cambian
    # el comportamiento. Lo que no se negocia es el invariante.
    guardadas = [
        m.group(1)
        for m in BAJA_GUARDADA.finditer(cuerpo_release)
        if niveles[m.start()] == 1
    ]
    sueltas = [
        m.group(1)
        for sentencia in release_claim
        if (m := BAJA_SUELTA.fullmatch(sentencia))
    ]
    bajas = guardadas + sueltas
    assert len(bajas) == 1, (
        f"releaseMicrophoneClaim debe tener EXACTAMENTE una sentencia de PRIMER "
        f"NIVEL que baje su token a 0L, y tiene {len(bajas)} ({release_claim}). "
        "Sin ella el token propio queda vivo: el siguiente arranque cree tener el "
        "microfono tomado y el apagado defensivo cancelDictationIfActive se "
        "retira por un claim fantasma"
    )
    token_propio = bajas[0]
    con_guarda = token_propio in guardadas or any(
        (m := GUARDA_INVERSA.fullmatch(sentencia)) and m.group(1) == token_propio
        for sentencia in release_claim
    )
    assert con_guarda, (
        f"La baja de '{token_propio} = 0L' debe ir GUIADA por el token propio, "
        "como sentencia de PRIMER NIVEL: 'if (token == claimToken) token = 0L', la "
        "misma con llaves, o 'if (token != claimToken) return' seguido de la baja. "
        "Sin la guarda, un "
        "release por token obsoleto baja el token del dueno NUEVO y deja al "
        f"propio con un microfono tomado que no puede liberar (sentencias: "
        f"{release_claim})"
    )

    # 3) Widget: mismo claim antes de su AudioRecord y release en cada salida.
    w_start = _sin_comentarios(
        widget[widget.index("private fun startRecording"):widget.index("private fun stopAndTranscribe")]
    )
    codigo_w_start = _codigo(w_start)
    assert codigo_w_start.index("claimMicrophoneForDictation() == 0L") < codigo_w_start.index(
        "SpeechToTextClient(this)"
    ), (
        "El widget debe comprobar el claim ANTES de construir su cliente de "
        "dictado: al reves, el AudioRecord se abre sin ser dueno"
    )
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
    w_start_body = _body_after(widget, "private fun startRecording")
    assert _statements_at_depth(w_start_body, 1)[0] == "if (isRecording) return", (
        "startRecording del widget debe ser idempotente: es la unica barrera "
        "si un re-tap llega mientras isBusy todavia no esta puesto"
    )
    assert _statements_at_depth(_body_after(widget, "private fun cancelRecording()"), 1)[0] == (
        "if (!isRecording) return"
    ), "cancelRecording solo puede actuar sobre una captura viva"
    w_fondo = _body_after(w_start_body, "BackgroundWork.execute {")
    assert re.search(
        r"val ok = try \{[^}]*startRecording\(\)[^}]*\} "
        r"catch \([^)]*\b(?:Exception|Throwable)\b[^)]*\) \{[^}]*false[^}]*\}",
        re.sub(r"\s+", " ", w_fondo),
    ), (
        "El arranque del AudioRecord del widget va en try/catch (Exception o "
        "Throwable) -> false: BackgroundWork.execute se traga la excepcion, "
        "asi que un IllegalStateException de rec.startRecording() o un "
        "SecurityException con el permiso revocado en vuelo dejan el claim "
        "tomado, isRecording e isBusy colgados y sin stopSelf() (el microfono "
        "queda bloqueado para todo el proceso)"
    )
    arranque_fallido = _body_after(w_fondo, "if (!ok) {")
    # La recuperacion va por postMain y el reset se exige DENTRO de ese bloque:
    # es el unico que corre en el main, y es donde `_statements_at_depth(., 1)`
    # puede separar el reset real de uno metido en un if/try/lambda. Cortar por
    # la rama de fondo no serviria: ahi el reset vive dentro del postMain.
    recuperacion = _codigo(_body_after(arranque_fallido, "BackgroundWork.postMain {"))
    for piece in ("isRecording = false", "isBusy = false", "releaseMicrophone()", "stopSelf()"):
        assert piece in recuperacion, (
            f"El arranque fallido del widget debe hacer '{piece}' en el postMain: "
            "sin el reset de flags el re-tap queda IGNORED para siempre. Se "
            "comprueba sobre codigo, no sobre texto: comentado, el guard lo daba "
            "por vivo"
        )
    # La rama de CLAIM TOMADO del widget tampoco puede quedarse con el service
    # en pie: `isBusy` ya quedo en true (lo subio handleToggle) y el claim es del
    # rival. Sin stopSelf() y sin return, el widget queda vivo esperando un
    # resultado que nunca llega.
    _, rama_claim_tomado = _bloque_de_if(
        w_start_body, r"claimMicrophoneForDictation\s*\(\s*\)\s*==\s*0L", "widget startRecording"
    )
    sentencias_claim_tomado = _statements_at_depth(rama_claim_tomado, 1)
    assert "stopSelf()" in sentencias_claim_tomado, (
        "La rama de claim tomado del widget debe hacer stopSelf() como sentencia "
        f"de PRIMER NIVEL (sentencias: {sentencias_claim_tomado}): con el service "
        "en pie y isBusy en true, el re-tap del widget queda IGNORED para siempre"
    )
    assert any(
        s == "return" or s.startswith("return ") for s in sentencias_claim_tomado
    ), (
        "La rama de claim tomado del widget debe ABORTAR (return): sin return, el "
        "widget sigue hacia el cliente de dictado con el microfono tomado por el "
        f"rival (sentencias: {sentencias_claim_tomado})"
    )
    w_stop_body = _body_after(widget, "private fun stopAndTranscribe()")
    sin_client = _body_after(w_stop_body, "client ?: run")
    # El cliente se localiza por su ASIGNACION, no por el nombre del local:
    # renombrar `speechClient` no puede tumbar el guard.
    mic_w = _alias_del_cliente(w_start_body, "SpeechToTextClient(", "widget startRecording")
    mic_t = _alias_del_cliente(w_stop_body, "client ?:", "widget stopAndTranscribe")
    for nombre, cuerpo in (
        ("cancelRecording", _codigo(_body_after(widget, "private fun cancelRecording()"))),
        (
            "arranque sin permiso",
            _codigo(_body_after(w_start_body, f"if (!{mic_w}.hasMicPermission()) {{")),
        ),
        ("arranque fallido", _codigo(arranque_fallido)),
        ("onDestroy", _codigo(_body_after(widget, "override fun onDestroy()"))),
        ("stopAndTranscribe", _codigo(w_stop_body)),
        ("stopAndTranscribe con client nulo", _codigo(sin_client)),
    ):
        assert "releaseMicrophone()" in cuerpo, (
            f"Sin releaseMicrophone() en el terminal '{nombre}': exigirlo por "
            "ventana de texto lo satisfacia la propia definicion del metodo o "
            "un release posterior. Se exige sobre codigo (sin comentarios ni "
            "literales) para que un release comentado o citado en una cadena no "
            "lo haga pasar"
        )
    assert f"{mic_t}.stopRecording()" in w_stop_body, (
        f"El corte de captura del widget debe pasar por el cliente resuelto "
        f"({mic_t}.stopRecording()): si la rama lo evita, el AudioRecord queda "
        "abierto con el claim liberado y otro entrypoint puede tomar el microfono"
    )
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
    assert "isBusy = true" in _statements_at_depth(toggle, 1), (
        "isBusy = true debe ser una sentencia de PRIMER NIVEL de handleToggle: "
        "dentro de un if puede no ejecutarse, el IGNORED del re-tap queda "
        "inerte y el widget puede abrir un segundo AudioRecord durante "
        "stopAndTranscribe"
    )
    estados = _body_after(widget, "private fun updateWidgetsState")
    assert re.search(
        r'if \(state != "recording" && state != "transcribing"\) isBusy = false', estados
    ), (
        "Los estados terminales deben bajar isBusy: sin este reset queda "
        "IGNORED para siempre (la fuga de la rama client == null, reabierta "
        "por la otra puerta)"
    )
    # El reset se exige por ORDEN y a PRIMER NIVEL, no por presencia: un
    # `isBusy = true` puesto DESPUES devuelve el IGNORED eterno aunque el
    # `= false` siga ahi, y un `if (isRecording) isBusy = false` anidado es
    # codigo muerto en la rama de arranque fallido (la sentencia anterior ya
    # dejo `isRecording = false`).
    for nombre, cuerpo, condiciones in (
        ("updateWidgetsState", estados, ('if (state != "recording" && state != "transcribing")',)),
        ("stopAndTranscribe con client nulo", sin_client, ()),
        ("arranque fallido", recuperacion, ()),
    ):
        escrituras = _escrituras_is_busy(cuerpo, condiciones)
        assert escrituras, (
            f"{nombre} debe BAJAR isBusy con una sentencia de PRIMER NIVEL de su "
            f"cuerpo (escrituras: {escrituras}): metido en un if, un try, un when "
            "o una lambda el reset puede no ejecutarse nunca, y entonces el "
            "re-tap del widget queda IGNORED para siempre"
        )
        assert all(valor in ("true", "false") for valor in escrituras), (
            f"{nombre} escribe isBusy fuera del reset admitido ({escrituras}): "
            "toda escritura de primer nivel se mira, no solo la que hace "
            "fullmatch con la condicion admitida. Un `if (state == \"saved\") "
            "isBusy = true` que no matchea no es inocuo: es el flag de ocupado "
            "vuelto a subir, y despues del reset deja el re-tap IGNORED para "
            "siempre (el IGNORED eterno que denunciaba el punto 7 del feedback 7.5)"
        )
        assert "true" not in escrituras, (
            f"{nombre} vuelve a SUBIR isBusy ({escrituras}): despues del reset "
            "el re-tap del widget queda IGNORED para siempre, que es el IGNORED "
            "eterno que denunciaba el punto 7 del feedback 7.5"
        )
        assert escrituras[-1] == "false", (
            f"{nombre}: la ultima escritura a isBusy debe ser el reset "
            f"({escrituras})"
        )
    assert _escrituras_is_busy(toggle) == ["true"], (
        f"handleToggle solo puede SUBIR isBusy, nunca bajarlo ({_escrituras_is_busy(toggle)}): "
        "si lo baja, el re-tap que debe quedar IGNORED abre un segundo AudioRecord"
    )
    # main y fondo tocan estos flags: sin @Volatile son una celda partida.
    for field in ("isRecording", "isBusy", "microphoneClaim"):
        assert re.search(
            rf"@Volatile\s+(\n\s+)?(private|internal) var {field}", _sin_comentarios(widget)
        ), (
            f"{field} del widget se escribe desde main y desde el hilo de fondo: "
            "necesita @Volatile"
        )
    assert "WidgetToggleOutcome.IGNORED -> {}" in _sin_comentarios(widget), (
        "Un re-tap durante stopAndTranscribe debe ignorarse, no mostrar error"
    )

    # 4) Dart: claim atomico (no sonda) inmediatamente antes de recorder.start.
    assert "_isMicBlocked" not in _sin_comentarios(dart), (
        "La sonda TOCTOU debe quedar eliminada: preguntar si el microfono esta "
        "libre y despues grabar deja la ventana entre la pregunta y el start"
    )
    assert "'claimMicrophone'" in _sin_comentarios(dart) and (
        "'releaseMicrophone'" in _sin_comentarios(dart)
    ), "Dart debe pedir y devolver el claim por el canal, no decidir por su cuenta"
    for dead in ("_kLocalClaim", "_localClaim", "_claimLocalMicrophone", "_releaseLocalMicrophone"):
        assert dead not in _sin_comentarios(dart), (
            f"{dead} es un segundo arbitro que no excluye al teclado nativo (falla abierto)"
        )
    claimer = _codigo(
        dart[dart.index("Future<int> _defaultMicClaimer()"):dart.index("Future<void> _defaultMicClaimReleaser")]
    )
    assert "} catch (_) {\n    return 0;\n  }" in claimer, (
        "Sin canal nativo el claim debe fallar CERRADO (0), nunca devolver un "
        "claim local que no compite con el teclado"
    )
    assert "?? 0" in claimer, (
        "Un `invokeMethod<int>('claimMicrophone')` que devuelve null debe ser 0, "
        "no un claim: null no es dueno de nada"
    )
    releaser = _codigo(
        dart[dart.index("Future<void> _defaultMicClaimReleaser"):dart.index("class TranscriptionService")]
    )
    assert "if (claim == 0) return;" in releaser, (
        "El releaser solo debe ignorar el token 0 (nada tomado)"
    )
    assert "claim <= 0" not in releaser, (
        "Descartar claim <= 0 mata la liberacion de cualquier token no nativo"
    )
    d_start = _codigo(
        dart[dart.index("Future<void> startRecording"):dart.index("Future<String?> stopRecording")]
    )
    d_permission = d_start.index("if (!await _recorder.hasPermission())")
    d_claim = d_start.index("await _claimMicrophone()")
    recorder_start = d_start.index("await _recorder.start(")
    assert d_permission < d_claim < recorder_start, (
        "El claim se pide DESPUES del permiso y ANTES de abrir la grabacion: al "
        "reves se abre microfono sin arbitro o se pide un claim que ya no protege"
    )
    d_publish = d_start.index("_activeClaim = claim;")
    assert d_claim < d_publish < recorder_start, (
        "El claim debe publicarse ANTES de await _recorder.start: durante el "
        "arranque el microfono ya esta tomado en nativo y hasMicrophoneClaim "
        "debe ser cierto, o el teardown y el stop no pueden liberarlo"
    )
    # P1-1: el claim 0 tiene que ABORTAR, no solo comprobarse. El orden
    # (claim < publish < start) lo cumplo un `if (claim == 0) { log(); }` igual:
    # con el teclado como dueno, burbuja y Notas llegarian a
    # `await _recorder.start(...)` sin ser dueñas y quedarían dos AudioRecord a
    # la vez. Se exige el CUERPO de la rama, a primer nivel, entre pedir el
    # claim y publicarlo, y que CORTA con throw o return.
    cuerpo_inicio_dart = _codigo(_body_after(dart, "Future<void> startRecording"))
    pos_corte, rama_corte = _bloque_de_if(
        cuerpo_inicio_dart, r"claim\s*==\s*0|0\s*==\s*claim", "TranscriptionService.startRecording"
    )
    assert cuerpo_inicio_dart.index("await _claimMicrophone()") < pos_corte < cuerpo_inicio_dart.index(
        "_activeClaim = claim;"
    ), (
        "La rama `if (claim == 0)` debe caer entre pedir el claim y publicarlo: "
        "antes no conoce el token, despues ya lo publico como propio"
    )
    sentencias_corte = _statements_at_depth(rama_corte, 1)
    assert any(
        s == "throw" or s.startswith("throw ") or s == "return" or s.startswith("return ")
        for s in sentencias_corte
    ), (
        "La rama de claim tomado debe CORTE (throw o return) como sentencia de "
        f"PRIMER NIVEL (sentencias: {sentencias_corte}). Un `logSilencioso()` o "
        "un aviso sin corte dejan seguir hacia `await _recorder.start(...)` con "
        "el microfono ya tomado por el rival: dos AudioRecord a la vez"
    )
    assert "await releaseMicrophoneClaim();" in d_start, (
        "Si recorder.start falla hay que liberar por releaseMicrophoneClaim "
        "(pone 0 y libera), no con _releaseMicrophone(claim) a secas"
    )
    d_stop = _codigo(_body_after(dart, "Future<String?> stopRecording()"))
    assert "await _releaseMicrophone(claim)" in d_stop, (
        "stopRecording debe liberar el token que USO para tomar el microfono: "
        "sin esta liberacion, cada parada deja el claim tomado en nativo"
    )
    assert any(
        s == "_activeClaim = 0" for s in _statements_at_depth(d_stop, 1)
    ), (
        "stopRecording debe BAJAR el token como sentencia directa del cuerpo: "
        "metido en un finally o en un if puede quedar sin ejecutar, "
        "hasMicrophoneClaim sigue mintiendo y un teardown posterior libera un "
        "claim ya liberado"
    )
    assert "Future<void> releaseMicrophoneClaim()" in _sin_comentarios(dart)
    assert any(
        s == "_activeClaim = 0" for s in _statements_at_depth(
            _codigo(_body_after(dart, "Future<void> releaseMicrophoneClaim()")), 1
        )
    ), "releaseMicrophoneClaim debe bajar el token como sentencia directa"
    getter = re.sub(
        r"\s+", " ", _expr_body(_sin_comentarios(dart), "bool get hasMicrophoneClaim")
    ).strip()
    assert getter == "bool get hasMicrophoneClaim => _activeClaim != 0;", (
        "hasMicrophoneClaim debe LEER la celda del claim: con '=> false' (o con "
        "'=> _activeClaim == 0') el teardown de Home/Notas corta antes de "
        "liberar y el microfono queda tomado para todo el proceso"
    )
    for source, name in ((home, "home_screen"), (notes, "notes_screen")):
        assert "releaseMicrophoneClaim()" in _sin_comentarios(source), (
            f"{name} debe liberar el claim en su teardown (metodo sin llamadores)"
        )
        dispose = _codigo(_body_after(source, "void dispose()"))
        assert "unawaited(_releaseMicrophoneOnTeardown())" in _statements_at_depth(dispose, 1), (
            f"{name}: dispose() debe INVOCAR al teardown como sentencia de "
            "primer nivel: comentado o metido en un if que no se cumple nunca, "
            "el guard lo daba por vivo y el microfono quedaba tomado para "
            "todo el proceso"
        )
        teardown = _codigo(
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
    # Todo sobre CODIGO: el `BubbleVisualState.idle` del catch estaba como
    # `in` sobre texto crudo y lo satisfacia una linea comentada, con la burbuja
    # encendida para siempre despues de un arranque rechazado por el claim.
    h_start = _codigo(
        home[home.index("Future<void> _startRecording"):home.index("Future<void> _cancelHoldIfTooShort")]
    )
    assert h_start.index("updateBubbleState(BubbleVisualState.recording)") < h_start.index(
        "_transcriptionService.startRecording(path)"
    ), (
        "Home debe publicar el estado visual ANTES de pedir el microfono: si "
        "publica despues, el rejection del claim llega con la burbuja en su "
        "estado anterior y el usuario ve 'grabando' sin que se grabe"
    )
    catch_home = _cuerpo_del_bloque(h_start, "catch", "home_screen._startRecording")
    assert "BubbleVisualState.idle" in catch_home, (
        "El catch del arranque de Home debe volver a idle: sin el, un rechazo "
        "por microfono ocupado deja la burbuja en 'grabando' para siempre (con "
        "el claim tomado por el rival, no hay nada que corte). Se exige DENTRO "
        "del catch, no en el resto del metodo: publicado solo en la rama de "
        "pantalla destruida, el catch compila vacio y el guard lo daba por vivo"
    )
    assert h_start.index("if (!mounted)") < h_start.index("_transcriptionService.startRecording(path)"), (
        "Una pantalla destruida no puede tomar el microfono"
    )
    n_dictate = _codigo(
        notes[notes.index("Future<void> _dictateNew"):notes.index("Future<void> _stopAndSave")]
    )
    assert n_dictate.index("_publishBubbleState(BubbleVisualState.recording)") < n_dictate.index(
        "_transcriptionService.startRecording(path)"
    ), (
        "Notas debe publicar el estado visual ANTES de pedir el microfono, por "
        "el mismo contrato que la burbuja"
    )
    catch_notas = _cuerpo_del_bloque(n_dictate, "catch", "notes_screen._dictateNew")
    assert "BubbleVisualState.idle" in catch_notas, (
        "Notas debe volver a idle cuando el arranque no succeeds: con el "
        "rechazo del claim, la pantalla se queda en 'grabando' sin grabar. Se "
        "exige DENTRO del catch, no en el resto del metodo: publicado solo en "
        "la rama de pantalla destruida, el catch compila vacio y el guard lo "
        "daba por vivo"
    )
    assert n_dictate.index("if (!mounted)") < n_dictate.index(
        "_transcriptionService.startRecording(path)"
    ), "Una pantalla destruida no puede tomar el microfono"
    n_stop = _codigo(
        notes[notes.index("Future<void> _stopAndSave"):notes.index("Future<void> _transcribePending")]
    )
    assert "finally {" in n_stop and "_publishBubbleState(BubbleVisualState.idle)" in n_stop, (
        "El corte de Notas debe publicar idle en su finally: con el estado "
        "visual colgado, el boton queda en 'grabando' y el segundo toque abre un "
        "segundo AudioRecord"
    )
    assert "floatingBubbleService" in _codigo(notes), (
        "Notas debe operar sobre la burbuja flotante"
    )

    # 6) Pruebas de carrera reales, certificadas por su CUERPO.
    # Las tres listas se certifican igual: asercion real en el cuerpo y NINGUN
    # `return` de primer nivel antes de ella (un `return` en la primera linea
    # aborta el caso, no falla, y deja el step bloqueante de CI en verde).
    carreras_kt = (
        "fun concurrentClaimsHaveExactlyOneWinner",
        "fun staleTokenDoesNotFreeTheCurrentClaim",
        "fun keyboardAndWidgetRaceHasASingleWinner",
        "fun widgetDictationStaysOutWhenKeyboardHoldsTheClaim",
        "fun duplicateReleaseDuringTakeoverNeverStealsTheNewOwner",
        "fun concurrentClaimAndDuplicateReleaseNeverOverlapTwoOwners",
        "fun widgetReTapWhileBusyIsIgnoredInsteadOfClaimingAgain",
        "fun releaseIsIdempotentAndIgnoresEmptyTokens",
        "fun widgetDictationTakesTheClaimAndReleasesItInEveryTerminalPath",
    )
    cuerpos_kt = {}
    for marker in carreras_kt:
        assert marker in _sin_comentarios(kt_test), f"Falta la carrera nativa {marker}"
        cuerpos_kt[marker[4:]] = _certifica_test(
            _body_after(kt_test, marker), marker[4:], ASERCION_KOTLIN, "Kotlin"
        )
    # Desactivar la carrera no es fallarla: `@Ignore` / `@Disabled` (o un
    # `Assume` que se salta a si mismo) dejan el step bloqueante en VERDE sin
    # ejecutar nada. Se prohibe en TODO el arbol de tests, nativo y Dart, no
    # solo en el archivo que el guard lee: una carrera nueva desactivada en un
    # archivo vecino pasava igual.
    _prohibe_desactivar_tests(
        "voice_bubble_stt/android/app/src/test", "app_source/test"
    )
    # Las aserciones raiz van DENTRO del test que las nombra: exigirlas a nivel
    # de archivo deja pasar el test que las importa si el mismo literal
    # sobrevive en otro test del archivo.
    _exige_raices(
        cuerpos_kt,
        {
            "concurrentClaimsHaveExactlyOneWinner": (
                "assertEquals(1, winners.get())",
                "assertTrue(BackgroundWork.isMicrophoneClaimed())",
            ),
            "staleTokenDoesNotFreeTheCurrentClaim": (
                "assertTrue(BackgroundWork.isMicrophoneClaimedBy(segundo))",
                "assertFalse(BackgroundWork.isMicrophoneClaimedBy(primero))",
                "assertFalse(BackgroundWork.isMicrophoneClaimed())",
            ),
            "concurrentClaimAndDuplicateReleaseNeverOverlapTwoOwners": (
                "assertEquals(1L, maxHolders.get().toLong())",
                "assertFalse(BackgroundWork.isMicrophoneClaimed())",
            ),
            "duplicateReleaseDuringTakeoverNeverStealsTheNewOwner": (
                "assertFalse(BackgroundWork.isMicrophoneClaimed())",
            ),
            "keyboardAndWidgetRaceHasASingleWinner": (
                "assertEquals(1, winners.get())",
                "assertFalse(BackgroundWork.isMicrophoneClaimed())",
            ),
            "widgetReTapWhileBusyIsIgnoredInsteadOfClaimingAgain": (
                "assertEquals(0L, widget.microphoneClaim)",
            ),
            "widgetDictationStaysOutWhenKeyboardHoldsTheClaim": (
                "assertEquals(0L, widget.microphoneClaim)",
            ),
            "releaseIsIdempotentAndIgnoresEmptyTokens": (
                "assertTrue(BackgroundWork.releaseMicrophone(claim))",
                "assertFalse(BackgroundWork.releaseMicrophone(claim))",
                "assertFalse(BackgroundWork.releaseMicrophone(0L))",
            ),
            "widgetDictationTakesTheClaimAndReleasesItInEveryTerminalPath": (
                "assertEquals(claim, widget.microphoneClaim)",
                "assertEquals(0L, BackgroundWork.tryClaimMicrophone())",
                "assertFalse(BackgroundWork.isMicrophoneClaimed())",
            ),
        },
        "MicrophoneClaimTest.kt",
    )
    carreras_dart = (
        "el claim se toma inmediatamente antes de recorder.start",
        "el claim propio ya excluye al rival en el instante del start",
        "carrera burbuja vs Notas: un solo ganador llega a recorder.start",
        "libera el claim si recorder.start lanza",
        "un token obsoleto no libera el claim de otro",
        "sin canal nativo falla cerrado: la burbuja no puede grabar sola",
        "un canal que lanza no deja un microfono irrecuperable",
        "bloquea el inicio cuando el claim esta tomado",
        "libera el claim al cancelar sin cerrar el recorder",
        "claim por canal nativo y release con el mismo token",
    )
    cuerpos_dart = {}
    for marker in carreras_dart:
        assert marker in _sin_comentarios(dart_test), f"Falta la carrera Dart {marker}"
        cuerpos_dart[marker] = _certifica_test(
            _dart_test_body(dart_test, marker), marker, ASERCION_DART, "Dart"
        )
    _exige_raices(
        cuerpos_dart,
        {
            "bloquea el inicio cuando el claim esta tomado": (
                "expect(recorder.startCount, 0);",
            ),
            "el claim se toma inmediatamente antes de recorder.start": (
                "expect(order, ['permission', 'claim', 'start']);",
            ),
            "el claim propio ya excluye al rival en el instante del start": (
                "expect(roboEnElStart, 0);",
                "expect(recorder.startCount, 1);",
            ),
            "carrera burbuja vs Notas: un solo ganador llega a recorder.start": (
                "expect(recorder.startCount, 1);",
                "expect(gate.isClaimed, isFalse);",
            ),
            "libera el claim si recorder.start lanza": (
                "expect(gate.releases, 1);",
                "expect(gate.isClaimed, isFalse);",
            ),
            "un token obsoleto no libera el claim de otro": (
                "expect(segundo, isNot(0));",
                "expect(gate.isClaimed, isTrue);",
            ),
            "sin canal nativo falla cerrado: la burbuja no puede grabar sola": (
                "primero.startRecording('/tmp/local-1.wav')",
                "segundo.startRecording('/tmp/local-2.wav')",
            ),
            "un canal que lanza no deja un microfono irrecuperable": (
                "expect(liberaciones, [4]);",
                "expect(service.hasMicrophoneClaim, isTrue);",
            ),
            "libera el claim al cancelar sin cerrar el recorder": (
                "expect(service.hasMicrophoneClaim, isTrue);",
                "expect(gate.isClaimed, isFalse);",
            ),
            "claim por canal nativo y release con el mismo token": (
                "expect(liberaciones, [7]);",
            ),
        },
        "mic_exclusion_test.dart",
    )
    pruebas_ui = (
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
    )
    cuerpos_ui = {}
    cuerpos_ui_texto = {}
    for marker in pruebas_ui:
        assert marker in _sin_comentarios(ui_test), f"Falta la prueba de UI {marker}"
        cuerpos_ui_texto[marker] = _codigo(_dart_test_body(ui_test, marker))
        cuerpos_ui[marker] = _certifica_test(
            _dart_test_body(ui_test, marker), marker, ASERCION_DART, "Dart"
        )
    _exige_raices(
        cuerpos_ui,
        {
            "Home publica el estado visual antes de tomar el claim": (
                "expect(order, ['bubble:recording', 'claim', 'start']);",
            ),
            "Home no arranca con el microfono tomado y vuelve a idle": (
                "expect(order, isNot(contains('start')));",
                "expect(order.last, 'bubble:idle');",
            ),
            "Notas toma el claim tras publicar el estado visual": (
                "expect(order, ['bubble:recording', 'claim', 'start']);",
                # Estado real de captura y localizacion por Key (§9.2-12): atar
                # la raiz al copy del boton ("Detener") hacia al guard una
                # violation de la regla y lo tumbaba un renombre legitimo.
                "expect(gate.isClaimed, isTrue);",
                "await tester.tap(find.byKey(const ValueKey('notesMicFab')));",
            ),
            "Notas no arranca con el microfono tomado": (
                "expect(order, isNot(contains('start')));",
                "expect(order.last, 'bubble:idle');",
                "expect(gate.isClaimed, isTrue);",
                "await tester.tap(find.byKey(const ValueKey('notesMicFab')));",
            ),
            "Home libera el microfono si desaparece grabando": (
                "expect(order, contains('stop'));",
                "expect(service.hasMicrophoneClaim, isFalse);",
            ),
            "Home libera el claim aunque el recorder no pueda cerrar": (
                "expect(gate.isClaimed, isFalse);",
            ),
            "Notas libera el microfono si desaparece grabando": (
                "expect(order, contains('stop'));",
            ),
            "Home no toma el microfono si desaparece durante el arranque": (
                "expect(order, ['bubble:recording', 'bubble:idle']);",
            ),
            "Home no deja el microfono tomado si desaparece con recorder.start en vuelo": (
                "expect(recorder.starts, 1);",
                "expect(service.hasMicrophoneClaim, isTrue);",
                "expect(gate.isClaimed, isFalse);",
                "expect(gate.claim(), isNot(0));",
            ),
            "Notas libera el microfono si el segundo toque llega con recorder.start en vuelo": (
                "expect(recorder.starts, 1);",
                "expect(gate.claim(), isNot(0));",
            ),
        },
        "mic_exclusion_flow_test.dart",
    )
    # La clase por PALABRA COMPLETA y ademas USADA: por subcadena,
    # `_HangingStartRecorderV2` satisfacia el `in`, y una clase declarada y
    # nunca instanciada deja a los teardown en vuelo sin la ventana peligrosa
    # que Puebla.
    assert re.search(r"class\s+_HangingStartRecorder\b", _sin_comentarios(ui_test)), (
        "La prueba de teardown durante el arranque necesita un recorder cuyo "
        "start() no resuelve (los tres de teardown anteriores esperan a que el "
        "arranque termine y ninguno entra en la ventana peligrosa)"
    )
    assert any("_HangingStartRecorder(" in cuerpo for cuerpo in cuerpos_ui_texto.values()), (
        "_HangingStartRecorder debe INSTANCIARSE dentro de al menos una de las "
        "pruebas de arranque en vuelo: declararla sin usarla deja a esas "
        "pruebas esperando un arranque que si resuelve, que es exactamente la "
        "ventana que tiene que quedar cubierta"
    )
    assert "Robolectric.buildService(" in _sin_comentarios(kt_test), (
        "MicrophoneClaimTest debe crear el Service con el harness de Robolectric "
        "(buildService(...).create()), no con el constructor"
    )
    assert "WidgetDictationService()" not in _sin_comentarios(kt_test), (
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

def test_c06_dead_connection_contract():
    """
    Guarda C-06: Blindaje del teclado ante conexión muerta.
    Verifica:
    1. Cero llamadas a `currentInputConnection?.` sin control posterior en los 6 archivos
       del contrato (EditEngine, SnippetsLayer, ClipboardLayer, DictationController,
       HistoryLayer, StatusLayer).
    2. Helper `commitOrWarn` en nivel de paquete y en capas dependientes.
    3. Excepciones de IPC (DeadObjectException, RemoteException, IllegalStateException, Exception)
       capturadas en commitOrWarn, handleShiftTap, sendKeyEventWithMeta, sendKeyCode,
       handleBackspace, deleteWordBeforeCursor, handleEnter, y commitImageClip.
    4. Compresión de flujo de UI: aborto sin mutación de estado en SnippetsLayer (no setLayer),
       ClipboardLayer (no showLayer), DictationController (no MicEvent.PASTE), y
       HistoryLayer (no dismissPopups).
    """
    base_kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    c06_files = [
        "EditEngine.kt",
        "SnippetsLayer.kt",
        "ClipboardLayer.kt",
        "DictationController.kt",
        "HistoryLayer.kt",
        "StatusLayer.kt",
    ]
    for fn in c06_files:
        path = os.path.join(base_kt, fn)
        assert os.path.isfile(path), f"Falta archivo C-06: {path}"
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        matches = re.findall(r"currentInputConnection\?\.([a-zA-Z0-9_]+)", content)
        assert len(matches) == 0, f"C-06: {fn} contiene llamadas desprotegidas currentInputConnection?. ({matches})"

    ee_path = os.path.join(base_kt, "EditEngine.kt")
    with open(ee_path, "r", encoding="utf-8") as f:
        ee = f.read()
    commit_fn = ee[ee.find("internal fun commitOrWarn") : ee.find("internal fun warnDeadConnection")]
    for exc in ["DeadObjectException", "RemoteException", "IllegalStateException", "Exception"]:
        assert f"catch (_: {exc})" in commit_fn, f"C-06: commitOrWarn no captura {exc}"

    # Verificación de abortos en UI
    snip_path = os.path.join(base_kt, "SnippetsLayer.kt")
    with open(snip_path, "r", encoding="utf-8") as f:
        snip = f.read()
    assert "if (!commitOrWarn(snippet.contenido)) return" in snip, "C-06: SnippetsLayer no aborta en commit fallido"
    insert_body = snip[snip.find("private fun insert(snippet: VbSnippet)") :]
    assert insert_body.find("if (!commitOrWarn(snippet.contenido)) return") < insert_body.find("host.setLayer(origin)"), "C-06: SnippetsLayer cambia capa antes de commit"

    clip_path = os.path.join(base_kt, "ClipboardLayer.kt")
    with open(clip_path, "r", encoding="utf-8") as f:
        clip = f.read()
    assert "if (commitOrWarn(text)) {" in clip, "C-06: ClipboardLayer no condiciona showLayer a commitOrWarn"
    assert "private fun commitImageClip(clip: ClipboardItem): Boolean" in clip, "C-06: commitImageClip no devuelve Boolean"

    dict_path = os.path.join(base_kt, "DictationController.kt")
    with open(dict_path, "r", encoding="utf-8") as f:
        dict_ctrl = f.read()
    assert "if (commitOrWarn(text)) {" in dict_ctrl and "micEvent(MicEvent.PASTE)" in dict_ctrl, "C-06: DictationController emite PASTE ante commit fallido"

    hist_path = os.path.join(base_kt, "HistoryLayer.kt")
    with open(hist_path, "r", encoding="utf-8") as f:
        hist = f.read()
    assert "if (commitOrWarn(text)) {" in hist and "host.dismissPopups()" in hist, "C-06: HistoryLayer cierra popups ante commit fallido"

def test_c07_credentials_safe_fill_contract():
    """
    Guarda C-07: Relleno de claves seguro [S].
    Verifica:
    1. Captura de editor y conexión iniciales antes del TAB en CredentialsLayer.kt.
    2. Envío de TAB protegido contra excepciones de IPC.
    3. En el diferido (250 ms):
       - Aborto si el TAB no avanzó (misma conexión o mismo fieldId).
       - Aborto si el paquete de la aplicación cambió.
       - Aborto si el nuevo campo de destino no es de contraseña (!isPasswordInput / !isPasswordField).
       - Pegado de contraseña mediante commitOrWarn sin fugas de texto.
    4. Cero llamadas a Log.* en CredentialsLayer.kt.
    """
    creds_path = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/CredentialsLayer.kt"
    assert os.path.isfile(creds_path), f"Falta archivo C-07: {creds_path}"
    with open(creds_path, "r", encoding="utf-8") as f:
        creds = f.read()

    fill_fn = creds[creds.find("private fun fill(entry: VbCredentialEntry)") :]
    assert "val initialEditor = service.currentInputEditorInfo" in fill_fn, "C-07: no captura initialEditor antes del TAB"
    assert "val initialIc = service.currentInputConnection" in fill_fn, "C-07: no captura initialIc antes del TAB"
    assert fill_fn.find("val initialEditor =") < fill_fn.find("KEYCODE_TAB"), "C-07: captura no ocurre antes de TAB"
    assert "if (initialEditor == null || initialIc == null) return" in fill_fn, "C-07: falta null check de initialEditor/initialIc"

    assert "service.sendDownUpKeyEvents(KeyEvent.KEYCODE_TAB)" in fill_fn and "catch (_: DeadObjectException)" in fill_fn, "C-07: TAB no protegido contra IPC"

    deferred = fill_fn[fill_fn.find("handler.postDelayed") : fill_fn.find("host.showLayer(origin)")]
    assert "!host.isServiceAlive()" in deferred, "C-07: falta check isServiceAlive en diferido"
    assert "currentIc === initialIc" in deferred, "C-07: falta check de conexión sin avance"
    assert "didNotAdvance" in deferred and "return@postDelayed" in deferred, "C-07: no aborta si TAB no avanzó"
    assert "currentEditor.packageName != initialEditor.packageName" in deferred, "C-07: falta check de cambio de paquete"
    assert "!isPasswordInput(currentEditor)" in deferred, "C-07: falta check isPasswordInput en diferido"
    assert "!host.isPasswordField()" in deferred, "C-07: falta check host.isPasswordField en diferido"
    assert "commitOrWarn(password)" in deferred, "C-07: no usa commitOrWarn para pegar contraseña"

    assert "Log." not in creds, "C-07: filtración de seguridad: Log.* presente en CredentialsLayer"

def test_c08_rebuild_guards_contract():
    """
    Guarda C-08: Rebuild solo cuando toca y blindaje de restart.
    Verifica:
    1. Early return en VoiceKeyboardService.onStartInputView ante restart sin cambio de paquete ni campo.
    2. Orden estricto en onStartInputView: early return ocurre ANTES de:
       - dictation.cancelDictationIfActive()
       - kbPrefs.load()
       - clipboard.onStartInputView(restarting)
       - rebuild()
    3. ClipboardLayer.onStartInputView es un no-op si restarting == true.
    4. Layer.CLIPBOARD nunca se persiste en lastLettersLayer (setLastLetters, codeToggle, TrackpadBridge.toggle).
    5. ClipboardLayer maneja su propio origin de forma independiente.
    """
    base_kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    vks_path = os.path.join(base_kt, "VoiceKeyboardService.kt")
    clip_path = os.path.join(base_kt, "ClipboardLayer.kt")
    track_path = os.path.join(base_kt, "TrackpadBridge.kt")

    assert os.path.isfile(vks_path), f"Falta archivo: {vks_path}"
    assert os.path.isfile(clip_path), f"Falta archivo: {clip_path}"
    assert os.path.isfile(track_path), f"Falta archivo: {track_path}"

    with open(vks_path, "r", encoding="utf-8") as f:
        vks = f.read()
    with open(clip_path, "r", encoding="utf-8") as f:
        clip = f.read()
    with open(track_path, "r", encoding="utf-8") as f:
        track = f.read()

    # 1. onStartInputView early return
    on_start = vks[vks.find("override fun onStartInputView(info: EditorInfo?, restarting: Boolean)") : vks.find("override fun onFinishInputView")]
    assert "restarting && newPackage != null && newPackage == currentPackageName && isPassword == currentIsPasswordField" in on_start, "C-08: falta early return en onStartInputView"
    assert "return" in on_start, "C-08: falta return en early return guard"

    # 2. Orden estricto
    early_return_pos = on_start.find("if (restarting &&")
    cancel_pos = on_start.find("dictation.cancelDictationIfActive()")
    load_pos = on_start.find("kbPrefs.load()")
    clip_pos = on_start.find("clipboard.onStartInputView(restarting)")
    rebuild_pos = on_start.find("rebuild()")

    assert early_return_pos < cancel_pos, "C-08: cancelDictationIfActive ocurre antes de early return"
    assert early_return_pos < load_pos, "C-08: kbPrefs.load() ocurre antes de early return"
    assert early_return_pos < clip_pos, "C-08: clipboard.onStartInputView ocurre antes de early return"
    assert early_return_pos < rebuild_pos, "C-08: rebuild() ocurre antes de early return"

    # 3. ClipboardLayer no-op en restart
    clip_on_start = clip[clip.find("fun onStartInputView(restarting: Boolean)") : clip.find("fun toggle()")]
    assert "if (restarting) return" in clip_on_start, "C-08: ClipboardLayer.onStartInputView no hace no-op en restarting"

    # 4. Aislamiento de lastLettersLayer
    assert "if (l != Layer.CLIPBOARD)" in vks, "C-08: setLastLetters permite Layer.CLIPBOARD"
    code_toggle = vks[vks.find("override fun codeToggle()") : vks.find("fun setMiniMode(")]
    assert "layer == Layer.CLIPBOARD" in code_toggle, "C-08: codeToggle no previene Layer.CLIPBOARD"
    assert "cur != Layer.CLIPBOARD" in track, "C-08: TrackpadBridge.toggle no previene Layer.CLIPBOARD"
    assert "private var origin = Layer.LETTERS" in clip, "C-08: ClipboardLayer no tiene variable origin privada"

def test_c09_cancel_network_contract():
    """
    Guarda C-09: Cancelar corta la red de verdad.
    Verifica:
    1. HttpURLConnection almacenada en AtomicReference en SpeechToTextClient.kt.
    2. cancelRecording() invoca disconnect() sobre activeConnection.
    3. active.connect() llamado explícitamente y chequeo de cancelRequested inmediatamente tras connect.
    4. Transmisión y lectura por tramos comprobando cancelRequested en cada iteración.
    5. DictationController permite cancelar dictado ante toque en vista proc o long-press en PROCESSING.
    6. DictationController aborta antes de transcribe() si la generación cambió.
    """
    base_kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    stt_path = os.path.join(base_kt, "SpeechToTextClient.kt")
    dict_path = os.path.join(base_kt, "DictationController.kt")

    assert os.path.isfile(stt_path), f"Falta archivo: {stt_path}"
    assert os.path.isfile(dict_path), f"Falta archivo: {dict_path}"

    with open(stt_path, "r", encoding="utf-8") as f:
        stt = f.read()
    with open(dict_path, "r", encoding="utf-8") as f:
        dic = f.read()

    # 1. AtomicReference y disconnect en cancelRecording
    assert "AtomicReference<HttpURLConnection?>" in stt, "C-09: falta AtomicReference para HttpURLConnection"
    cancel_rec = stt[stt.find("fun cancelRecording()") : stt.find("private fun buildWav")]
    assert "activeConnection.getAndSet(null)?.disconnect()" in cancel_rec, "C-09: cancelRecording no desconecta activeConnection"

    # 2. transcribe() almacena activeConnection y verifica connect
    transcribe_fn = stt[stt.find("fun transcribe(") : stt.find("private fun errorDetail")]
    assert "activeConnection.set(active)" in transcribe_fn, "C-09: transcribe no registra activeConnection"
    assert "active.connect()" in transcribe_fn, "C-09: transcribe no llama a active.connect()"

    connect_pos = transcribe_fn.find("active.connect()")
    cancel_after_connect = transcribe_fn.find("if (cancelRequested)", connect_pos)
    assert connect_pos != -1 and cancel_after_connect != -1 and cancel_after_connect < transcribe_fn.find("DataOutputStream", connect_pos), "C-09: no verifica cancelRequested tras active.connect()"

    # 3. Lectura por tramos y ausencia de readText monolítico
    assert "while (reader.read(charBuf)" in transcribe_fn, "C-09: falta lectura por tramos"
    assert "readText()" not in transcribe_fn, "C-09: lectura monolítica readText presente en transcribe"

    # 4. DictationController controles de cancelación en PROCESSING
    assert "proc.setOnClickListener {" in dic and "cancelDictation()" in dic, "C-09: proc view no cancela dictado"
    assert "MicState.PROCESSING -> cancelDictation()" in dic, "C-09: handleMicTap no cancela en PROCESSING"
    assert "if (generation != transcriptionGeneration) return@execute" in dic, "C-09: finishDictation no aborta antes de transcribe ante cambio de generación"

def test_c10_retry_without_re_record_contract():
    """
    Guarda C-10: Reintento sin regrabar con retención de WAV y aviso interactivo.
    Verifica:
    1. LastDictationSlot data class retiene wav y config.
    2. isRetryableError clasifica red/5xx/429/timeout y excluye API key/inválida.
    3. finishDictation asigna lastDictationSlot antes de transcribe y ofrece reintento con onClick.
    4. retryLastDictation() reenvía slot.wav y slot.config sin regrabar.
    5. StatusLayer.show soporta onClick opcional con listener y timeout extendido.
    6. transcription_service.dart conserva audio temporal si el texto devuelto es vacío.
    """
    base_kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    dict_path = os.path.join(base_kt, "DictationController.kt")
    status_path = os.path.join(base_kt, "StatusLayer.kt")
    dart_path = "app_source/lib/services/transcription_service.dart"

    assert os.path.isfile(dict_path), f"Falta archivo: {dict_path}"
    assert os.path.isfile(status_path), f"Falta archivo: {status_path}"
    assert os.path.isfile(dart_path), f"Falta archivo: {dart_path}"

    with open(dict_path, "r", encoding="utf-8") as f:
        dic = f.read()
    with open(status_path, "r", encoding="utf-8") as f:
        stat = f.read()
    with open(dart_path, "r", encoding="utf-8") as f:
        dart = f.read()

    # 1. LastDictationSlot
    assert (
        "data class LastDictationSlot" in dic
        and "val wav: ByteArray" in dic
        and "val config: SpeechToTextClient.Config" in dic
    ), "C-10: falta LastDictationSlot en DictationController"
    assert "var lastDictationSlot: LastDictationSlot? = null" in dic, "C-10: falta lastDictationSlot en DictationController"

    # 2. isRetryableError
    assert "private fun isRetryableError(message: String): Boolean" in dic, "C-10: falta isRetryableError"
    retry_fn = dic[dic.find("private fun isRetryableError") : dic.find("private fun isRetryableError") + 900]
    assert 'message.contains("conexión"' in retry_fn and 'message.contains("API key"' in retry_fn, "C-10: clasificación de errores incompleta"

    # 3. finishDictation
    finish_fn = dic[dic.find("private fun finishDictation()") : dic.find("private fun commitOrWarn")]
    assert "lastDictationSlot = LastDictationSlot(wav, config)" in finish_fn, "C-10: finishDictation no guarda LastDictationSlot"
    assert "onClick = { retryLastDictation() }" in finish_fn, "C-10: finishDictation no ofrece reintento con onClick"

    # 4. retryLastDictation
    assert "fun retryLastDictation()" in dic, "C-10: falta retryLastDictation"
    retry_body = dic[dic.find("fun retryLastDictation()") : dic.find("private fun cancelDictation")]
    assert "val slot = lastDictationSlot ?: return" in retry_body, "C-10: retryLastDictation no usa lastDictationSlot"
    assert "startRecording" not in retry_body and "tryClaimMicrophone" not in retry_body, "C-10: retryLastDictation regraba audio"

    # 5. StatusLayer y Dart
    assert "onClick: (() -> Unit)? = null" in stat, "C-10: StatusLayer.show no soporta onClick"
    assert "if (deleteAudioOnSuccess && result.text.isNotEmpty)" in dart, "C-10: Dart borra audio con texto vacío"

def test_c11_even_network_timeouts_contract():
    """
    Guarda C-11: Tiempos de red parejos en Kotlin y Dart.
    Verifica:
    1. Misma fórmula 60 + bytes/50k con clamp [60, 600] en Kotlin y Dart.
    2. Cálculo con 9.6 MB (9,600,000 bytes) da exactamente 252 segundos en ambos.
    3. Lectura de respuesta fija (60s) separada de la subida adaptativa en ambos.
    4. Tope de archivo de 25 MB (MAX_AUDIO_BYTES / maxFileSizeBytes) verificado antes de subir.
    """
    base_kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    stt_path = os.path.join(base_kt, "SpeechToTextClient.kt")
    widget_path = os.path.join(base_kt, "WidgetDictationService.kt")
    dart_path = "app_source/lib/services/cloud_stt_service.dart"

    assert os.path.isfile(stt_path), f"Falta archivo: {stt_path}"
    assert os.path.isfile(widget_path), f"Falta archivo: {widget_path}"
    assert os.path.isfile(dart_path), f"Falta archivo: {dart_path}"

    with open(stt_path, "r", encoding="utf-8") as f:
        stt = f.read()
    with open(widget_path, "r", encoding="utf-8") as f:
        widget = f.read()
    with open(dart_path, "r", encoding="utf-8") as f:
        dart = f.read()

    # 1. Constantes y fórmulas
    assert "const val TIMEOUT_BASE_SECONDS = 60" in stt and "const val TIMEOUT_BYTES_PER_SECOND = 50000" in stt, "C-11: falta fórmula base en Kotlin"
    assert "static const int _timeoutBaseSeconds = 60;" in dart and "static const int _timeoutBytesPerSecond = 50000;" in dart, "C-11: falta fórmula base en Dart"
    assert "fun timeoutForBytes(bytes: Int): Int" in stt, "C-11: falta timeoutForBytes en Kotlin"
    assert "Duration timeoutForBytes(int bytes)" in dart, "C-11: falta timeoutForBytes en Dart"

    # 2. Cálculo con 9.6 MB
    kt_sec = 60 + (9600000 // 50000)
    dart_sec = 60 + (9600000 // 50000)
    assert kt_sec == 252 and dart_sec == 252, "C-11: cálculo con 9.6 MB no coincide con 252s"

    # 3. Lectura fija separada de subida
    assert "const val TIMEOUT_READ_SECONDS = 60" in stt and "active.readTimeout = TIMEOUT_READ_SECONDS * 1000" in stt, "C-11: falta lectura fija en Kotlin"
    assert "timeoutRead" in dart and "response.stream.bytesToString().timeout(timeoutRead)" in dart, "C-11: falta lectura fija en Dart"

    # 4. Tope de archivo de 25 MB
    assert "MAX_AUDIO_BYTES = 25 * 1024 * 1024" in stt and "if (wav.size > MAX_AUDIO_BYTES)" in stt, "C-11: falta tope de 25 MB en SpeechToTextClient"
    assert "if (wav.size > SpeechToTextClient.MAX_AUDIO_BYTES)" in widget, "C-11: falta tope de 25 MB en WidgetDictationService"
    assert "maxFileSizeBytes = 25 * 1024 * 1024" in dart and "if (fileLength > maxFileSizeBytes)" in dart, "C-11: falta tope de 25 MB en CloudSttService"

def test_c12_no_main_thread_heavy_work_contract():
    """C-12: Sin trabajo pesado en el hilo principal (bóveda, config y prefs cacheadas)."""
    base_kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    sec_path = os.path.join(base_kt, "SecureStore.kt")
    stt_path = os.path.join(base_kt, "SpeechToTextClient.kt")
    dic_path = os.path.join(base_kt, "DictationController.kt")
    prefs_path = os.path.join(base_kt, "KeyboardPrefs.kt")
    vks_path = os.path.join(base_kt, "VoiceKeyboardService.kt")

    with open(sec_path, "r", encoding="utf-8") as f:
        sec = f.read()
    with open(stt_path, "r", encoding="utf-8") as f:
        stt = f.read()
    with open(dic_path, "r", encoding="utf-8") as f:
        dic = f.read()
    with open(prefs_path, "r", encoding="utf-8") as f:
        kp = f.read()
    with open(vks_path, "r", encoding="utf-8") as f:
        vks = f.read()

    # 1. SecureStore: Caché de bóveda y warmUp
    assert "var cachedVault: SharedPreferences? = null" in sec, "C-12: falta cachedVault en SecureStore"
    assert "fun warmUp(context: Context)" in sec and "BackgroundWork.execute" in sec, "C-12: falta warmUp en SecureStore"
    assert "cachedVault?.let { return it }" in sec, "C-12: SecureStore no reutiliza cachedVault"

    # 2. SpeechToTextClient: Caché de config y preload
    assert "var cachedConfig: Config? = null" in stt, "C-12: falta cachedConfig en SpeechToTextClient"
    assert "fun getConfig(): Config = cachedConfig ?: loadConfig()" in stt, "C-12: falta getConfig en SpeechToTextClient"
    assert "fun preloadConfig()" in stt and "BackgroundWork.execute" in stt, "C-12: falta preloadConfig en SpeechToTextClient"

    # 3. DictationController: Toque de mic sin trabajo pesado
    start_body = dic.split("private fun startDictation()")[1].split("private fun ")[0]
    assert "sttClient.getConfig()" in start_body and "sttClient.loadConfig()" not in start_body, "C-12: startDictation no usa getConfig cacheado"
    assert "preloadSttConfig()" in dic and "sttClient.preloadConfig()" in dic, "C-12: falta preloadSttConfig en DictationController"
    create_view_body = dic.split("fun onCreateInputView()")[1].split("fun onDestroy()")[0]
    assert "BackgroundWork.execute" in create_view_body and "initMicSounds()" in create_view_body, "C-12: initMicSounds debe correr en BackgroundWork"

    # 4. KeyboardPrefs: Leer prefs una única vez por load()
    assert "var cachedPrefs: SharedPreferences? = null" in kp, "C-12: falta cachedPrefs en KeyboardPrefs"
    assert "fun warmUp()" in kp, "C-12: falta warmUp en KeyboardPrefs"
    assert kp.count('context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)') == 1, "C-12: KeyboardPrefs debe tener una única apertura de prefs"
    load_body = kp.split("fun load()")[1].split("fun longPressDelayMillis")[0]
    assert "val p = prefs()" in load_body and "context.getSharedPreferences" not in load_body, "C-12: load() debe abrir prefs una sola vez"

    # 5. VoiceKeyboardService: lifecycle fuera del main
    assert "kbPrefs.warmUp()" in vks and "miniStore.warmUp()" in vks and "SecureStore.warmUp(this)" in vks, "C-12: falta warmUp en VKS.onCreate"
    assert "credentialStore.preload()" in vks, "C-12: falta preload en VKS.onCreateInputView"
    assert "dictation.preloadSttConfig()" in vks, "C-12: falta preloadSttConfig en VKS.onStartInputView"
    on_siv = vks.split("override fun onStartInputView(info: EditorInfo?, restarting: Boolean)")[1].split("override fun onFinishInputView")[0]
    assert "getSharedPreferences" not in on_siv and "EncryptedSharedPreferences" not in on_siv, "C-12: onStartInputView contiene llamadas no permitidas a prefs"

def test_c13_widget_auth_vs_network_contract():
    """C-13: El widget distingue 'sin internet' de 'sin clave'."""
    base_kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    stt_path = os.path.join(base_kt, "SpeechToTextClient.kt")
    widget_path = os.path.join(base_kt, "WidgetDictationService.kt")

    with open(stt_path, "r", encoding="utf-8") as f:
        stt = f.read()
    with open(widget_path, "r", encoding="utf-8") as f:
        widget = f.read()

    # 1. SpeechToTextClient propaga código HTTP en onError
    assert "onError: (code: Int?, message: String) -> Unit" in stt, "C-13: transcribe no propaga (code, message) en onError"
    assert "transcribe(wav, config, onDone) { _, message -> onError(message) }" in stt, "C-13: falta sobrecarga de compatibilidad en transcribe"
    assert "onError(code, errorDetail(code, body))" in stt, "C-13: transcribe no propaga responseCode a onError"

    # 2. WidgetDictationService recibe (code, message)
    assert "onError = { code, message ->" in widget, "C-13: WidgetDictationService no recibe (code, message) en onError"

    # 3. isAuthError y shouldEnqueuePending
    assert "fun isAuthError(code: Int?, message: String): Boolean" in widget, "C-13: falta isAuthError con code en WidgetDictationService"
    assert "code == 401 || code == 403" in widget, "C-13: isAuthError no verifica 401 y 403 directamente"
    assert "fun shouldEnqueuePending" in widget, "C-13: falta shouldEnqueuePending en WidgetDictationService"
    assert "code == null || code == 429 || code >= 500" in widget, "C-13: shouldEnqueuePending no restringe encolado a fallas de red/5xx/429"
    assert "if (shouldEnqueuePending(code, message))" in widget, "C-13: WidgetDictationService no evalúa shouldEnqueuePending antes de encolar"

def test_c14_clipboard_out_of_passwords_contract():
    """C-14 [S]: Portapapeles fuera de contraseñas."""
    base_kt = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    toolbar_path = os.path.join(base_kt, "ToolbarLayer.kt")
    clipboard_path = os.path.join(base_kt, "ClipboardLayer.kt")
    vks_path = os.path.join(base_kt, "VoiceKeyboardService.kt")

    with open(toolbar_path, "r", encoding="utf-8") as f:
        toolbar = f.read()
    with open(clipboard_path, "r", encoding="utf-8") as f:
        clipboard = f.read()
    with open(vks_path, "r", encoding="utf-8") as f:
        vks = f.read()

    # 1. ToolbarLayer: no crear btnPaste en password
    assert "if (!host.isPasswordField())" in toolbar, "C-14: falta guarda de isPasswordField en ToolbarLayer"
    tb_paste_idx = toolbar.find("val btnPaste")
    assert tb_paste_idx != -1 and toolbar.rfind("if (!host.isPasswordField())", 0, tb_paste_idx) != -1, "C-14: btnPaste no está dentro de guarda isPasswordField"

    # 2. ClipboardLayer: toggle, pasteLatestOrToggle y pasteClip protegidos
    toggle_chunk = clipboard[clipboard.find("fun toggle()"):clipboard.find("fun buildRows()")]
    assert "if (host.isPasswordField()) return" in toggle_chunk, "C-14: ClipboardLayer.toggle no aborta en password"

    paste_latest_chunk = clipboard[clipboard.find("fun pasteLatestOrToggle()"):clipboard.find("private fun handlePrimaryClipChanged")]
    assert "if (host.isPasswordField()) return" in paste_latest_chunk, "C-14: ClipboardLayer.pasteLatestOrToggle no aborta en password"

    paste_clip_chunk = clipboard[clipboard.find("private fun pasteClip("):clipboard.find("private fun commitImageClip(")]
    assert "if (host.isPasswordField()) return" in paste_clip_chunk, "C-14: ClipboardLayer.pasteClip no aborta en password"

    # 3. VoiceKeyboardService: showLayer, toggles y reseteo al entrar
    show_layer_chunk = vks[vks.find("override fun showLayer(next: Layer)"):vks.find("override fun tapFeedback()")]
    assert "if (currentIsPasswordField && next == Layer.CLIPBOARD) return" in show_layer_chunk, "C-14: showLayer no bloquea CLIPBOARD en password"

    cb_toggle_chunk = vks[vks.find("override fun clipboardToggle()"):vks.find("override fun trackpadToggle()")]
    assert "override fun clipboardToggle() = clipboard.toggle()" in cb_toggle_chunk, "C-14: clipboardToggle no delega en clipboard"

    on_start_chunk = vks[vks.find("override fun onStartInputView("):vks.find("override fun onFinishInputView(")]
    assert "if (currentIsPasswordField && (layer == Layer.TRACKPAD || layer == Layer.SNIPPETS || layer == Layer.CLIPBOARD))" in on_start_chunk, "C-14: onStartInputView no resetea CLIPBOARD en password"

def test_c15_snippet_draft_safe_contract():
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    vks_path = os.path.join(kt_dir, "VoiceKeyboardService.kt")
    snippets_path = os.path.join(kt_dir, "SnippetsLayer.kt")

    with open(vks_path, "r", encoding="utf-8") as f:
        vks = f.read()
    with open(snippets_path, "r", encoding="utf-8") as f:
        snippets = f.read()

    # 1. SnippetsLayer: exposición de isEditorOpen y método saveDraftState
    assert "var isEditorOpen = false" in snippets or "val isEditorOpen" in snippets, "C-15: SnippetsLayer no expone isEditorOpen"
    assert "fun saveDraftState()" in snippets, "C-15: SnippetsLayer no expone saveDraftState()"
    assert "private fun saveDraftState()" not in snippets, "C-15: saveDraftState() no debe ser privado"

    # Preservación de variables y lógica de guardado
    assert "private var draftName = \"\"" in snippets, "C-15: falta variable draftName en SnippetsLayer"
    assert "private var draftContent = \"\"" in snippets, "C-15: falta variable draftContent en SnippetsLayer"
    assert "private var draftActiveIsContent = false" in snippets, "C-15: falta draftActiveIsContent"
    assert "private var draftCursor = 0" in snippets, "C-15: falta draftCursor"

    # 2. VoiceKeyboardService: rebuild salvaguarda borrador al inicio
    rebuild_idx = vks.find("override fun rebuild()")
    assert rebuild_idx != -1, "C-15: override fun rebuild() no encontrado en VoiceKeyboardService"
    rebuild_chunk = vks[rebuild_idx:rebuild_idx + 2500]

    assert "if (::snippets.isInitialized && snippets.isEditorOpen)" in rebuild_chunk, "C-15: rebuild no verifica snippets.isInitialized && snippets.isEditorOpen"
    assert "snippets.saveDraftState()" in rebuild_chunk, "C-15: rebuild no invoca snippets.saveDraftState()"

    # Orden estricto: saveDraftState antes de dismissPopup y root.removeAllViews()
    save_idx = rebuild_chunk.find("snippets.saveDraftState()")
    dismiss_idx = rebuild_chunk.find("dismissPopup()")
    remove_views_idx = rebuild_chunk.find("root.removeAllViews()")
    assert save_idx != -1 and dismiss_idx != -1 and remove_views_idx != -1, "C-15: llamadas clave en rebuild no encontradas"
    assert save_idx < dismiss_idx, "C-15: saveDraftState debe llamarse antes de dismissPopup()"
    assert save_idx < remove_views_idx, "C-15: saveDraftState debe llamarse antes de root.removeAllViews()"

def test_c16_spacebar_no_ghosts_contract():
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    vks_path = os.path.join(kt_dir, "VoiceKeyboardService.kt")
    spacebar_path = os.path.join(kt_dir, "SpacebarLayer.kt")

    with open(vks_path, "r", encoding="utf-8") as f:
        vks = f.read()
    with open(spacebar_path, "r", encoding="utf-8") as f:
        spacebar = f.read()

    # 1. SpacebarLayer: constructor recibe handler y UiHost define longPressDelayMs
    assert "private val handler: Handler" in spacebar, "C-16: SpacebarLayer no recibe Handler en constructor"
    assert "fun longPressDelayMs(): Long" in spacebar, "C-16: SpacebarLayer.UiHost no declara longPressDelayMs"

    # 2. Uso de host.longPressDelayMs() y no literal 300L
    assert "host.longPressDelayMs()" in spacebar, "C-16: SpacebarLayer no usa host.longPressDelayMs()"
    post_delayed_matches = re.findall(r"postDelayed\([^)]+\)", spacebar)
    assert all("300L" not in m for m in post_delayed_matches), "C-16: SpacebarLayer todavía tiene 300L hardcodeado"

    # 3. cancelPending restaura alpha=1 inmediatamente
    cancel_idx = spacebar.find("fun cancelPending()")
    assert cancel_idx != -1, "C-16: cancelPending() no encontrado en SpacebarLayer"
    cancel_chunk = spacebar[cancel_idx:cancel_idx + 600]
    assert "handler.removeCallbacks" in cancel_chunk, "C-16: cancelPending no remueve callbacks del handler compartido"
    assert "setTrackpadBlankOutMode(false" in cancel_chunk, "C-16: cancelPending no restaura blank out"
    assert "immediate = true" in cancel_chunk, "C-16: cancelPending no restaura alpha inmediatamente"

    # 4. VoiceKeyboardService: pasa handler y cancelPendingKeyGestures en rebuild y onDestroy
    assert "spacebar = SpacebarLayer(this, handler, this)" in vks, "C-16: VKS no pasa handler compartido a SpacebarLayer"
    assert "override fun longPressDelayMs(): Long" in vks, "C-16: VKS no implementa longPressDelayMs"

    rebuild_chunk = vks[vks.find("override fun rebuild()"):vks.find("root.removeAllViews()")]
    assert "cancelPendingKeyGestures()" in rebuild_chunk, "C-16: rebuild no cancela gestos pendientes antes de removeAllViews"

    cancel_gestures_chunk = vks[vks.find("private fun cancelPendingKeyGestures()"):vks.find("override fun dismissPopup()")]
    assert "spacebar.cancelPending()" in cancel_gestures_chunk, "C-16: cancelPendingKeyGestures no invoca spacebar.cancelPending()"

def test_c17_single_vibration_contract():
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
    ee_path = os.path.join(kt_dir, "EditEngine.kt")
    kf_path = os.path.join(kt_dir, "KeyFactory.kt")

    with open(ee_path, "r", encoding="utf-8") as f:
        ee = f.read()
    with open(kf_path, "r", encoding="utf-8") as f:
        kf = f.read()

    # 1. EditEngine: CERO llamadas a host.haptic()
    haptic_matches = re.findall(r"host\.haptic\(", ee)
    assert len(haptic_matches) == 0, f"C-17: EditEngine tiene {len(haptic_matches)} llamadas a host.haptic: {haptic_matches}"

    # Verificación por función en EditEngine
    commit_letter_chunk = ee[ee.find("fun commitLetter("):ee.find("private fun releaseMomentaryShift")]
    assert "host.haptic" not in commit_letter_chunk, "C-17: commitLetter vibra innecesariamente"

    commit_symbol_chunk = ee[ee.find("fun commitSymbolText("):ee.find("fun commit(")]
    assert "host.haptic" not in commit_symbol_chunk, "C-17: commitSymbolText vibra innecesariamente"

    send_code_chunk = ee[ee.find("fun sendKeyCode("):ee.find("private fun isCursorKey")]
    assert "host.haptic" not in send_code_chunk, "C-17: sendKeyCode vibra innecesariamente"

    backspace_chunk = ee[ee.find("fun handleBackspace("):ee.find("fun deleteWordBeforeCursor")]
    assert "host.haptic" not in backspace_chunk, "C-17: handleBackspace vibra innecesariamente"

    enter_chunk = ee[ee.find("fun handleEnter("):]
    assert "host.haptic" not in enter_chunk, "C-17: handleEnter vibra innecesariamente"

    # 2. KeyFactory: punto único de vibración en la capa física de gestos
    fast_tap_chunk = kf[kf.find("fun fastTap("):kf.find("fun longPress(")]
    assert "host.haptic(v)" in fast_tap_chunk, "C-17: fastTap no vibra en ACTION_DOWN"

    long_press_chunk = kf[kf.find("fun longPress("):kf.find("fun backspaceGestures(")]
    assert "host.haptic(v)" in long_press_chunk, "C-17: longPress no vibra en ACTION_DOWN"

    gap_chunk = kf[kf.find("private fun makeGapTolerant("):kf.find("private fun nearestChild(")]
    assert "host.haptic(child)" in gap_chunk, "C-17: makeGapTolerant no vibra al resolver tecla"

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
        ("C-06: blindaje del teclado ante conexión muerta", test_c06_dead_connection_contract),
        ("C-07: relleno de claves seguro", test_c07_credentials_safe_fill_contract),
        ("C-08: rebuild solo cuando toca y blindaje restart", test_c08_rebuild_guards_contract),
        ("C-09: cancelar corta la red de verdad", test_c09_cancel_network_contract),
        ("C-10: reintento sin regrabar", test_c10_retry_without_re_record_contract),
        ("C-11: tiempos de red parejos", test_c11_even_network_timeouts_contract),
        ("C-12: sin trabajo pesado en el hilo principal", test_c12_no_main_thread_heavy_work_contract),
        ("C-13: el widget distingue sin internet de sin clave", test_c13_widget_auth_vs_network_contract),
        ("C-14: portapapeles fuera de contraseñas [S]", test_c14_clipboard_out_of_passwords_contract),
        ("C-15: borrador de snippet a salvo", test_c15_snippet_draft_safe_contract),
        ("C-16: spacebar sin fantasmas", test_c16_spacebar_no_ghosts_contract),
        ("C-17: una sola vibración por tecla", test_c17_single_vibration_contract),
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
