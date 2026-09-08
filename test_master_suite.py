#!/usr/bin/env python3
"""
MASTER VERIFICATION SUITE - VoiceBubble STT
Delega cada suite Python vía subprocess (fallo real si fallan) y conserva
inline SOLO los CI guards propios (contrato de claves, logs limpios y
retención al desinstalar). La versión NO se congela en un literal: se
exige consistencia del MISMO valor entre ambos pubspec (el bump futuro
no debe romper master).
"""

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

def test_clean_logs():
    kt_dir = "voice_bubble_stt/android/app/src/main/kotlin"
    cmd = f"grep -rniE 'Log\\.[a-z]+\\(.*\\b(texto|contenido|api_?key|token)\\b' '{kt_dir}' || true"
    out = subprocess.check_output(cmd, shell=True, text=True).strip()
    assert not out, f"Filtración de contenido detectada en Logs:\n{out}"

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
        ("CI Guard: Ausencia de Filtraciones en Logs", test_clean_logs),
        ("Seguridad: Bóveda cifrada de secretos (SPK-02)", test_secrets_vault),
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
        print("✨ TODOS LOS REQUERIMIENTOS FUERON EJECUTADOS Y VALIDADOS AL 100%.")
        sys.exit(0)
    else:
        print("⚠️ ALGUNOS MÓDULOS PRESENTARON FALLOS.")
        sys.exit(1)

if __name__ == "__main__":
    main()
