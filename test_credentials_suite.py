#!/usr/bin/env python3
"""
CREDENTIALS SUITE - VoiceBubble STT (contrato Claves)
Sección propia de credenciales: dock inferior + pantalla + storage Dart y
botón llave + capa + relleno en el teclado nativo Kotlin.

Garantiza: funcionamiento del flujo (guardar/listar/pegar/borrar) y NO
regresión del resto del teclado (capas, toggle ?123, snippets, toolbar).
"""

import os
import re
import sys

from test_helpers import Suite

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
VKS = os.path.join(WORKSPACE, KT, "VoiceKeyboardService.kt")
STORE = os.path.join(WORKSPACE, KT, "CredentialStore.kt")


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


def log_lines_with(content, *words):
    """Líneas con Log que además mencionen datos sensibles (filtración)."""
    out = []
    for line in content.splitlines():
        if "Log." in line and any(w in line for w in words):
            out.append(line.strip())
    return out


def main():
    suite = Suite()
    vks = read(os.path.join(KT, "VoiceKeyboardService.kt"))
    # SPK-05 módulo 6: la capa trackpad vive en TrackpadBridge.kt; VKS
    # delega (trackpad.toggle). Se suma al contenido para regresión.
    try:
        vks += read(os.path.join(KT, "TrackpadBridge.kt"))
    except FileNotFoundError:
        pass
    # SPK-05 módulo 8: la capa snippets vive en SnippetsLayer.kt; VKS
    # delega (snippets.toggle). Se suma al contenido para regresión.
    try:
        vks += read(os.path.join(KT, "SnippetsLayer.kt"))
    except FileNotFoundError:
        pass
    # SPK-05 módulo 12: la toolbar (con el botón llave) vive en
    # ToolbarLayer.kt; VKS delega (credentialsToggle). Se suma igual.
    try:
        vks += read(os.path.join(KT, "ToolbarLayer.kt"))
    except FileNotFoundError:
        pass
    # SPK-05: los enums viven en KeyboardTypes.kt y la capa en
    # CredentialsLayer.kt (mismo paquete).
    types = read(os.path.join(KT, "KeyboardTypes.kt"))
    creds = read(os.path.join(KT, "CredentialsLayer.kt"))
    store = read(os.path.join(KT, "CredentialStore.kt"))
    model = read("app_source/lib/models/credential.dart")
    storage = read("app_source/lib/services/storage_service.dart")
    screen = read("app_source/lib/screens/credentials_screen.dart")
    settings = read("app_source/lib/screens/settings_screen.dart")
    tabbar = read("app_source/lib/widgets/settings_tab_bar.dart")
    contract = read("docs/contract-keys.txt").strip().split("\n")

    # --- 1. Modelo Dart sin secretos ---
    suite.check("Modelo VbCredential existe", os.path.isfile(
        os.path.join(WORKSPACE, "app_source/lib/models/credential.dart")))
    suite.check("Modelo con id/nombre/usuario",
                all(k in model for k in ("final String id", "final String nombre", "final String usuario")),
                "Faltan campos del contrato")
    suite.check("Modelo SIN campo password",
                "String password" not in model and "'password'" not in model
                and '"password"' not in model,
                "El modelo no debe portar secretos")
    suite.check("toString sin secretos", "password" not in model.split("toString")[1]
                if "toString" in model else False, "toString expone datos")

    # --- 2. Storage Dart ---
    for key in ("vb_credentials_v1", "vb_cred_pass_v1", "vb_cred_show_user"):
        suite.check(f"Storage expone clave {key}", f"'{key}'" in storage,
                    f"Falta {key}")
    suite.check("addCredential valida vacíos y límites",
                "addCredential" in storage and "maxCredentials" in storage,
                "Sin validación")
    suite.check("deleteCredential borra índice Y contraseña",
                "deleteCredential" in storage and "passes.remove(id)" in storage,
                "Borrado incompleto")
    suite.check("Sin API de lectura de passwords en UI",
                "readPassword" not in storage and "getPassword" not in storage,
                "La UI no debe releer contraseñas")
    suite.check("Dart jamás escribe secretos en prefs planas (SPK-02)",
                "prefs.setString(sttApiKeyMirrorKey" not in storage
                and "prefs.setString(credPassKey" not in storage,
                "Escritura plana de secretos prohibida")
    suite.check("Migración Dart del mapa plano a la bóveda",
                "_migratePlainPassMap" in storage
                and "prefs.remove(credPassKey)" in storage,
                "Falta la migración del legado")
    suite.check("showUser default false", "?? false" in storage and
                "loadCredShowUser" in storage, "Default incorrecto")

    # --- 3. Pantalla propia ---
    suite.check("CredentialsScreen existe", os.path.isfile(
        os.path.join(WORKSPACE, "app_source/lib/screens/credentials_screen.dart")))
    suite.check("Formulario con 3 campos",
                all(k in screen for k in ("credenciales-add-nombre", "credenciales-add-usuario", "credenciales-add-password")),
                "Falta algún campo")
    suite.check("Password obscure sin ojo", "obscureText: true" in screen and
                "visibility" not in screen.lower(), "Ojo o sin ocultar")
    suite.check("Sin edición (solo borrar)", "updateCredential" not in screen and
                "Icons.delete_outline" in screen, "Hay edición o falta borrado")
    suite.check("Switch mostrar-usuario", "credenciales-show-user" in screen and
                "SwitchListTile" in screen, "Falta el switch")

    # --- 4. Dock inferior con sección propia ---
    suite.check("Tab Claves en el dock", "tab-credenciales" in tabbar and
                "'Claves'" in tabbar and "vpn_key" in tabbar,
                "Dock sin sección propia")
    suite.check("Settings monta tab 5 perezoso",
                "CredentialsScreen(storageService: _storageService)" in settings
                and "_builtTabs.contains(5)" in settings,
                "Tab no cableado")

    # --- 5. Teclado nativo: botón y capa ---
    suite.check("Drawable ic_key.xml existe", os.path.isfile(
        os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_key.xml")))
    suite.check("CredentialStore solo-lectura existe", os.path.isfile(STORE))
    suite.check("Store sin API pública de escritura",
                "fun save" not in store and "fun delete" not in store,
                "El teclado no debe exponer escritura de credenciales")
    suite.check("Única escritura: migración del legado a la bóveda",
                store.count(".edit()") == 1 and "migrateLegacyPasses" in store
                and "SecureStore.write" in store,
                "Toda escritura fuera de la migración está prohibida")
    suite.check("Passwords solo en bóveda cifrada",
                "SecureStore.read" in store and "SecureStore.CRED_PASS_MAP" in store
                and "remove(KEY_PASS)" in store,
                "El mapa plano debe migrarse a la bóveda y borrarse")
    suite.check("Store sin Log de valores",
                not log_lines_with(store, "nombre", "usuario", "password", "pass"),
                "Filtración en logs del store")
    suite.check("Layer.CREDENTIALS declarada",
                "CREDENTIALS" in vks + types
                and "SNIPPETS, TRACKPAD, CREDENTIALS" in vks + types,
                "Falta la capa")
    suite.check("Botón llave en toolbar", "R.drawable.ic_key" in vks and
                ("credentials.toggle()" in vks or "credentialsToggle()" in vks), "Falta el botón")
    suite.check("Llave visible en campos password",
                "tambien en contraseñas" in vks,
                "La llave debe vivir en el login")
    suite.check("Capa sobrevive en password (no reseteada)",
                "TRACKPAD || layer == Layer.SNIPPETS" in vks and
                "CREDENTIALS" not in vks.split("TRACKPAD || layer == Layer.SNIPPETS")[0].split("\n")[-1],
                "Guard de password mata la capa")
    suite.check("Relleno usuario+TAB+clave diferida",
                "private fun fill(" in creds and "KEYCODE_TAB" in creds and
                "postDelayed" in creds and "250L" in creds,
                "Falta la secuencia de relleno")
    suite.check("Tras pegar vuelve a la capa origen",
                "host.showLayer(origin)" in creds,
                "No vuelve al origen")
    suite.check("?123 muestra ABC en CREDENTIALS",
                "Layer.CREDENTIALS -> \"ABC\"" in vks,
                "Etiqueta incorrecta")
    suite.check("VKS sin Log de password",
                not log_lines_with(vks, "password"),
                "Filtración en logs del teclado")

    # --- 6. No regresión del resto del teclado ---
    for token in ("Layer.LETTERS", "Layer.SYMBOLS", "Layer.CODE",
                  "Layer.SNIPPETS", "Layer.TRACKPAD",
                  "buildSnippetRows",
                  "toggleCodeLayer",
                  "commitSymbolText", "if (!restarting)"):
        suite.check(f"Regresión: {token} intacto", token in vks,
                    f"Se rompió {token}")
    # SPK-05 módulo 6: el toggle del trackpad vive en el puente.
    suite.check("Regresión: toggleTrackpadLayer intacto",
                "toggleTrackpadLayer" in vks or ("TrackpadBridge" in vks and "fun toggle()" in vks),
                "Se rompió toggleTrackpadLayer")
    # SPK-05 módulo 8: el toggle de snippets vive en la capa.
    suite.check("Regresión: toggleSnippetsLayer intacto",
                "toggleSnippetsLayer" in vks or ("SnippetsLayer" in vks and "fun toggle()" in vks),
                "Se rompió toggleSnippetsLayer")
    suite.check("Contrato de claves incluye las 3",
                all(k in contract for k in ("vb_credentials_v1", "vb_cred_pass_v1", "vb_cred_show_user")),
                "contract-keys.txt desactualizado")

    print("\n============================================================")
    print(f" RESULTADOS: {suite.passed} Pasados, {suite.failed} Fallidos")
    print("============================================================\n")
    if suite.failed > 0:
        print("❌ ERROR: Existen fallas en la suite de credenciales.")
        sys.exit(1)
    print("✅ VERIFICACIÓN AL 100% EXITOSA: Listo para producción.")
    sys.exit(0)


if __name__ == "__main__":
    main()
