#!/usr/bin/env python3
"""
test_c34_signing_lockfile_and_https_suite.py
============================================
Auditoría C-34: Firma, lockfile y https [S]

Verifica:
1. Verificación de firma y fingerprint documentados (INSTALL.md, build.gradle.kts):
   - apksigner verify --print-certs documentado en INSTALL.md.
   - Fingerprint SHA-256 (8C:1C:C5:5D:74:87:4F:35:98:99:DB:93:0E:53:47:9D:A0:4C:68:AF:88:14:43:F6:E8:F2:B5:DA:33:C0:3E:C3).
   - Fingerprint SHA-1 (F8:EA:32:A5:FB:8E:95:B8:DB:3A:A4:F0:B0:49:44:39:83:94:A3:C3).
   - Bloque release en build.gradle.kts condicionado a variables de entorno sin exponer secretos.
2. Permisos y notas de seguridad (INSTALL.md §4):
   - Fila VIBRATE en tabla de permisos.
   - Nota sobre FileProvider (clipboardfileprovider) y BIND_INPUT_METHOD.
3. Blindaje HTTPS estricto y cleartextTrafficPermitted="false" (SpeechToTextClient.kt, network_security_config.xml, AndroidManifest.xml):
   - SpeechToTextClient.kt valida resolveUrl exigiendo https:// y fallback a DEFAULT_URL ante http:// o inválidos.
   - network_security_config.xml declara cleartextTrafficPermitted="false".
   - AndroidManifest.xml vincula android:networkSecurityConfig="@xml/network_security_config".
4. Lockfiles versionados y cumplimiento estricto (--enforce-lockfile, .gitignore, pubspec.lock):
   - .gitignore permite pubspec.lock.
   - app_source/pubspec.lock y voice_bubble_stt/pubspec.lock existen.
   - android.yml sincroniza pubspec.lock y ejecuta flutter pub get --enforce-lockfile.
5. Inmutabilidad de CI: Pinning de GitHub Actions por SHA de 40 caracteres (android.yml):
   - Todas las actions de checkout, setup-java, gradle, flutter y upload-artifact usan SHA completo.
6. Batería de mutaciones negativas para garantizar detección contra regresiones.
"""

import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INSTALL_MD = os.path.join(BASE_DIR, "INSTALL.md")
BUILD_GRADLE = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "build.gradle.kts")
SPEECH_CLIENT = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "SpeechToTextClient.kt")
NET_SEC_CONFIG = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "res", "xml", "network_security_config.xml")
MANIFEST = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "AndroidManifest.xml")
GITIGNORE = os.path.join(BASE_DIR, ".gitignore")
WORKFLOW = os.path.join(BASE_DIR, ".github", "workflows", "android.yml")
APP_LOCK = os.path.join(BASE_DIR, "app_source", "pubspec.lock")
VB_LOCK = os.path.join(BASE_DIR, "voice_bubble_stt", "pubspec.lock")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def test_apk_fingerprint_and_signing():
    """1. Verificación apksigner, fingerprints y configuración de firma segura."""
    doc = read_file(INSTALL_MD)
    gradle = read_file(BUILD_GRADLE)

    assert "apksigner verify --print-certs" in doc, (
        "INSTALL.md debe documentar el comando apksigner verify --print-certs"
    )
    assert "8C:1C:C5:5D:74:87:4F:35:98:99:DB:93:0E:53:47:9D:A0:4C:68:AF:88:14:43:F6:E8:F2:B5:DA:33:C0:3E:C3" in doc, (
        "INSTALL.md debe publicar el SHA-256 fingerprint de la firma debug"
    )
    assert "F8:EA:32:A5:FB:8E:95:B8:DB:3A:A4:F0:B0:49:44:39:83:94:A3:C3" in doc, (
        "INSTALL.md debe publicar el SHA-1 fingerprint de la firma debug"
    )
    assert "KEYSTORE_FILE" in gradle and "KEYSTORE_PASSWORD" in gradle, (
        "build.gradle.kts debe condicionar la firma release a variables de entorno"
    )


def test_permissions_and_components_in_install():
    """2. Permisos y componentes del sistema documentados en INSTALL.md §4."""
    doc = read_file(INSTALL_MD)

    assert "`VIBRATE`" in doc or "| VIBRATE |" in doc, (
        "INSTALL.md §4 debe incluir la fila para el permiso VIBRATE"
    )
    assert "FileProvider" in doc and "clipboardfileprovider" in doc, (
        "INSTALL.md §4 debe documentar el FileProvider para compartir clips sin exponer el almacenamiento"
    )
    assert "BIND_INPUT_METHOD" in doc, (
        "INSTALL.md §4 debe documentar la restricción del permiso BIND_INPUT_METHOD"
    )


def test_https_enforced_and_http_impossible():
    """3. Validación estricta HTTPS en cliente y bloqueo cleartext en sistema."""
    client = read_file(SPEECH_CLIENT)
    manifest = read_file(MANIFEST)

    assert os.path.isfile(NET_SEC_CONFIG), (
        "network_security_config.xml debe existir en res/xml/"
    )
    net_xml = read_file(NET_SEC_CONFIG)

    assert 'cleartextTrafficPermitted="false"' in net_xml, (
        "network_security_config.xml debe declarar cleartextTrafficPermitted='false'"
    )
    assert 'android:networkSecurityConfig="@xml/network_security_config"' in manifest, (
        "AndroidManifest.xml debe enlazar @xml/network_security_config"
    )

    assert "DEFAULT_URL" in client and "https://api.groq.com" in client, (
        "SpeechToTextClient.kt debe definir DEFAULT_URL HTTPS por defecto"
    )
    assert "resolveUrl(" in client, (
        "SpeechToTextClient.kt debe implementar función resolveUrl"
    )
    assert 'startsWith("https://", ignoreCase = true)' in client or 'startsWith("https://"' in client, (
        "SpeechToTextClient.resolveUrl debe exigir que la URL comience con https://"
    )


def test_lockfiles_versioned_and_enforced():
    """4. Lockfiles versionados y obligatoriedad en CI."""
    gi = read_file(GITIGNORE)
    wf = read_file(WORKFLOW)

    # .gitignore no debe tener pubspec.lock como regla activa
    for line in gi.splitlines():
        line = line.strip()
        if line == "pubspec.lock":
            assert False, ".gitignore no debe ignorar pubspec.lock"

    assert os.path.isfile(APP_LOCK), "app_source/pubspec.lock debe existir y estar versionado"
    assert os.path.isfile(VB_LOCK), "voice_bubble_stt/pubspec.lock debe existir y estar versionado"

    assert "app_source/pubspec.lock" in wf, (
        "android.yml debe sincronizar app_source/pubspec.lock hacia voice_bubble_stt"
    )
    assert "--enforce-lockfile" in wf, (
        "android.yml debe ejecutar flutter pub get con --enforce-lockfile"
    )


def test_github_actions_pinned_by_sha():
    """5. Todas las actions en android.yml deben estar fijadas por SHA de 40 hex."""
    wf = read_file(WORKFLOW)
    uses_lines = [line.strip() for line in wf.splitlines() if line.strip().startswith("uses:")]

    assert len(uses_lines) >= 5, "android.yml debe contener al menos 5 pasos uses"
    for line in uses_lines:
        action_spec = line.split("uses:")[1].strip().split("#")[0].strip()
        # Debe contener '@' seguido de exactamente 40 caracteres hexadecimales
        match = re.search(r"@([0-9a-fA-F]{40})$", action_spec)
        assert match, (
            f"La action '{action_spec}' en android.yml no está fijada a un commit SHA de 40 hex: {line}"
        )


def test_negative_mutations():
    """6. Batería de mutaciones negativas reales contra los invariantes de C-34."""
    mutations = [
        (
            "resolveUrl permite http://",
            SPEECH_CLIENT,
            lambda s: s.replace('startsWith("https://"', 'startsWith("http://"'),
            test_https_enforced_and_http_impossible,
        ),
        (
            "cleartextTrafficPermitted=true en network_security_config.xml",
            NET_SEC_CONFIG,
            lambda s: s.replace('cleartextTrafficPermitted="false"', 'cleartextTrafficPermitted="true"'),
            test_https_enforced_and_http_impossible,
        ),
        (
            "Remover networkSecurityConfig de AndroidManifest.xml",
            MANIFEST,
            lambda s: re.sub(r'android:networkSecurityConfig="[^"]+"', '', s),
            test_https_enforced_and_http_impossible,
        ),
        (
            "Reintroducir pubspec.lock en .gitignore",
            GITIGNORE,
            lambda s: s + "\npubspec.lock\n",
            test_lockfiles_versioned_and_enforced,
        ),
        (
            "Remover --enforce-lockfile de android.yml",
            WORKFLOW,
            lambda s: s.replace("--enforce-lockfile", ""),
            test_lockfiles_versioned_and_enforced,
        ),
        (
            "Fingerprint SHA-256 removido de INSTALL.md",
            INSTALL_MD,
            lambda s: s.replace("8C:1C:C5:5D:74:87:4F:35:98:99:DB:93:0E:53:47:9D:A0:4C:68:AF:88:14:43:F6:E8:F2:B5:DA:33:C0:3E:C3", "00:00:00"),
            test_apk_fingerprint_and_signing,
        ),
        (
            "Action sin pin por SHA en android.yml",
            WORKFLOW,
            lambda s: re.sub(r"actions/checkout@[0-9a-fA-F]{40}", "actions/checkout@v4", s),
            test_github_actions_pinned_by_sha,
        ),
    ]

    for desc, filepath, mutator, test_func in mutations:
        orig = read_file(filepath)
        mutated = mutator(orig)
        assert mutated != orig, f"La mutación '{desc}' no modificó el archivo"
        try:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(mutated)
            failed = False
            try:
                test_func()
            except AssertionError:
                failed = True
            assert failed, f"La mutación negativa falló en ser detectada: {desc}"
        finally:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(orig)


def run_all_tests():
    tests = [
        ("C-34.1: Fingerprint APK y firma release por secrets", test_apk_fingerprint_and_signing),
        ("C-34.2: Permisos VIBRATE, FileProvider y BIND documentados", test_permissions_and_components_in_install),
        ("C-34.3: Blindaje HTTPS estricto y cleartext prohibido", test_https_enforced_and_http_impossible),
        ("C-34.4: Lockfiles versionados y --enforce-lockfile en CI", test_lockfiles_versioned_and_enforced),
        ("C-34.5: Pinning de GitHub Actions por commit SHA", test_github_actions_pinned_by_sha),
        ("C-34.6: Detección de 7 mutaciones negativas", test_negative_mutations),
    ]

    passed = 0
    print("=" * 65)
    print(" 🚀 INICIANDO AUDITORÍA C-34: Firma, lockfile y https [S]")
    print("=" * 65)

    for name, test_func in tests:
        try:
            test_func()
            print(f"  ▶ {name}... ✅ PASS")
            passed += 1
        except AssertionError as e:
            print(f"  ▶ {name}... ❌ FAIL: {e}")
        except Exception as e:
            print(f"  ▶ {name}... 💥 ERROR: {type(e).__name__}: {e}")

    print("=" * 65)
    print(f" RESULTADO C-34: {passed}/{len(tests)} pruebas pasadas.")
    print("=" * 65)

    if passed == len(tests):
        print("✨ Todos los invariantes de C-34 verificados correctamente.")
        return 0
    else:
        print("⚠️ Fallos detectados en contrato C-34.")
        return 1


if __name__ == "__main__":
    sys.exit(run_all_tests())
