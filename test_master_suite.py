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
