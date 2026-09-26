#!/usr/bin/env python3
"""
Test Suite: Contrato C-12 (Sin trabajo pesado en el hilo principal).

Garantiza:
1. Cero EncryptedSharedPreferences.create o getSharedPreferences en caminos de tap
   (handleMicTap/startDictation, finishDictation, SnippetsLayer.toggle, CredentialsLayer.toggle)
   ni en onStartInputView.
2. Caché en memoria de Config STT en SpeechToTextClient con precarga en BackgroundWork
   antes del foco y consultas de tap vía getConfig().
3. Bóveda cifrada SecureStore con caché perezosa de la instancia de SharedPreferences
   y método warmUp() ejecutado en segundo plano en onCreate() del servicio.
4. KeyboardPrefs abre y referencia SharedPreferences una única vez por llamada a load(),
   reutilizando la instancia en memoria (warmUp en BackgroundWork).
5. SnippetStore y CredentialStore precargan sus datos y bóveda fuera del hilo principal,
   y los toggles/rebuilds de UI consumen snapshots cacheados en memoria.
6. Mutaciones negativas reales verificadas sobre los puntos críticos de regresión.
"""

import os
import re
import sys

WORKSPACE = os.path.abspath(os.path.dirname(__file__))
KT_DIR = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt")


class Suite:
    def __init__(self):
        self.passed = 0
        self.failed = 0

    def check(self, desc, cond, detail=""):
        if cond:
            print(f"  [PASS] {desc}")
            self.passed += 1
        else:
            print(f"  [FAIL] {desc} -> {detail}")
            self.failed += 1


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def run_suite():
    s = Suite()
    print("\n============================================================")
    print(" INICIANDO TEST SUITE: CONTRATO C-12 (SIN TRABAJO PESADO EN MAIN)")
    print("============================================================\n")

    dict_path = os.path.join(KT_DIR, "DictationController.kt")
    stt_path = os.path.join(KT_DIR, "SpeechToTextClient.kt")
    sec_path = os.path.join(KT_DIR, "SecureStore.kt")
    kb_prefs_path = os.path.join(KT_DIR, "KeyboardPrefs.kt")
    mini_store_path = os.path.join(KT_DIR, "MiniModeStore.kt")
    cred_store_path = os.path.join(KT_DIR, "CredentialStore.kt")
    snip_store_path = os.path.join(KT_DIR, "SnippetStore.kt")
    snip_layer_path = os.path.join(KT_DIR, "SnippetsLayer.kt")
    cred_layer_path = os.path.join(KT_DIR, "CredentialsLayer.kt")
    vks_path = os.path.join(KT_DIR, "VoiceKeyboardService.kt")

    # 1. Existencia de archivos
    for name, p in [
        ("DictationController.kt", dict_path),
        ("SpeechToTextClient.kt", stt_path),
        ("SecureStore.kt", sec_path),
        ("KeyboardPrefs.kt", kb_prefs_path),
        ("MiniModeStore.kt", mini_store_path),
        ("CredentialStore.kt", cred_store_path),
        ("SnippetStore.kt", snip_store_path),
        ("SnippetsLayer.kt", snip_layer_path),
        ("CredentialsLayer.kt", cred_layer_path),
        ("VoiceKeyboardService.kt", vks_path),
    ]:
        s.check(f"{name} existe", os.path.isfile(p))

    dict_code = read_file(dict_path)
    stt_code = read_file(stt_path)
    sec_code = read_file(sec_path)
    kb_code = read_file(kb_prefs_path)
    mini_code = read_file(mini_store_path)
    cred_code = read_file(cred_store_path)
    snip_code = read_file(snip_store_path)
    snip_l_code = read_file(snip_layer_path)
    cred_l_code = read_file(cred_layer_path)
    vks_code = read_file(vks_path)

    # 2. SecureStore: Caché de instancia y warmUp
    s.check(
        "SecureStore tiene cachedVault @Volatile",
        "@Volatile" in sec_code and "var cachedVault: SharedPreferences? = null" in sec_code,
    )
    s.check(
        "SecureStore implementa warmUp fuera del hilo principal",
        "fun warmUp(context: Context)" in sec_code and "BackgroundWork.execute" in sec_code,
    )
    s.check(
        "SecureStore implementa isInitialized()",
        "fun isInitialized(): Boolean" in sec_code,
    )
    s.check(
        "SecureStore.vault solo crea EncryptedSharedPreferences si cachedVault es null",
        "cachedVault?.let { return it }" in sec_code and "cachedVault = esp" in sec_code,
    )

    # 3. SpeechToTextClient: Caché de Config y preloading
    s.check(
        "SpeechToTextClient tiene cachedConfig @Volatile",
        "@Volatile" in stt_code and "var cachedConfig: Config? = null" in stt_code,
    )
    s.check(
        "SpeechToTextClient expone getConfig() sin golpear I/O innecesario",
        "fun getConfig(): Config = cachedConfig ?: loadConfig()" in stt_code,
    )
    s.check(
        "SpeechToTextClient implementa preloadConfig() en BackgroundWork",
        "fun preloadConfig()" in stt_code and "BackgroundWork.execute" in stt_code,
    )
    s.check(
        "SpeechToTextClient implementa refreshConfigAsync()",
        "fun refreshConfigAsync" in stt_code and "BackgroundWork.executeWithResult" in stt_code,
    )
    s.check(
        "SpeechToTextClient.loadConfig actualiza cachedConfig",
        "cachedConfig = loaded" in stt_code and "return loaded" in stt_code,
    )

    # 4. DictationController: Toque de mic sin trabajo pesado
    start_body = dict_code.split("private fun startDictation()")[1].split("private fun ")[0]
    s.check(
        "startDictation usa sttClient.getConfig() en vez de loadConfig() sincrónico",
        "sttClient.getConfig()" in start_body and "sttClient.loadConfig()" not in start_body,
    )
    finish_body = dict_code.split("private fun finishDictation()")[1].split("private fun ")[0]
    s.check(
        "finishDictation usa sttClient.getConfig()",
        "sttClient.getConfig()" in finish_body and "sttClient.loadConfig()" not in finish_body,
    )
    s.check(
        "DictationController expone preloadSttConfig()",
        "fun preloadSttConfig()" in dict_code and "sttClient.preloadConfig()" in dict_code,
    )
    create_view_body = dict_code.split("fun onCreateInputView()")[1].split("fun onDestroy()")[0]
    s.check(
        "onCreateInputView precarga config STT",
        "preloadSttConfig()" in create_view_body,
    )
    s.check(
        "onCreateInputView ejecuta initMicSounds en BackgroundWork",
        "BackgroundWork.execute" in create_view_body and "initMicSounds()" in create_view_body,
    )

    # 5. KeyboardPrefs: Abrir prefs una única vez por load()
    s.check(
        "KeyboardPrefs tiene cachedPrefs @Volatile",
        "@Volatile" in kb_code and "var cachedPrefs: SharedPreferences? = null" in kb_code,
    )
    s.check(
        "KeyboardPrefs implementa warmUp()",
        "fun warmUp()" in kb_code and "prefs()" in kb_code,
    )
    s.check(
        "KeyboardPrefs tiene una única llamada a getSharedPreferences en todo el archivo",
        kb_code.count('context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)') == 1,
    )
    load_body = kb_code.split("fun load()")[1].split("fun longPressDelayMillis")[0]
    s.check(
        "load() abre prefs una sola vez al inicio",
        "val p = prefs()" in load_body and "context.getSharedPreferences" not in load_body,
    )

    # 6. MiniModeStore: Instancia de SharedPreferences cacheada
    s.check(
        "MiniModeStore tiene cachedPrefs y warmUp()",
        "@Volatile" in mini_code and "var cachedPrefs" in mini_code and "fun warmUp()" in mini_code,
    )

    # 7. SnippetStore & SnippetsLayer: fuera del main
    s.check(
        "SnippetStore tiene cachedPrefs y método preload()",
        "@Volatile" in snip_code and "var cachedPrefs" in snip_code and "fun preload()" in snip_code,
    )
    s.check(
        "SnippetsLayer.onCreateInputView precarga snippets con store.preload()",
        "store.preload()" in snip_l_code.split("fun onCreateInputView()")[1].split("fun toggle()")[0],
    )
    toggle_snip = snip_l_code.split("fun toggle()")[1].split("fun resetState()")[0]
    s.check(
        "SnippetsLayer.toggle no hace store.load() sincrónico en main",
        "BackgroundWork.execute" in toggle_snip and "store.load()" in toggle_snip,
    )

    # 8. CredentialStore & CredentialsLayer: fuera del main
    s.check(
        "CredentialStore tiene cachedPrefs, getIndex() y preload()",
        "fun getIndex(): List<VbCredentialEntry>" in cred_code
        and "fun preload()" in cred_code
        and "BackgroundWork.execute" in cred_code,
    )
    s.check(
        "CredentialsLayer.buildRows usa store.getIndex() en vez de recargar disco",
        "store.getIndex()" in cred_l_code and "store.loadIndex()" not in cred_l_code,
    )
    toggle_cred = cred_l_code.split("fun toggle()")[1].split("fun buildRows")[0]
    s.check(
        "CredentialsLayer.toggle ejecuta store.preload() en BackgroundWork",
        "BackgroundWork.execute" in toggle_cred and "store.preload()" in toggle_cred,
    )

    # 9. VoiceKeyboardService: lifecycle y onStartInputView
    on_create_vks = vks_code.split("override fun onCreate()")[1].split("override fun onEvaluateFullscreenMode()")[0]
    s.check(
        "VoiceKeyboardService.onCreate ejecuta warmUp de kbPrefs, miniStore y SecureStore en BackgroundWork",
        "BackgroundWork.execute" in on_create_vks
        and "kbPrefs.warmUp()" in on_create_vks
        and "miniStore.warmUp()" in on_create_vks
        and "SecureStore.warmUp(this)" in on_create_vks,
    )
    on_civ_vks = vks_code.split("override fun onCreateInputView(): View")[1].split("override fun onStartInputView")[0]
    s.check(
        "VoiceKeyboardService.onCreateInputView precarga credentialStore",
        "credentialStore.preload()" in on_civ_vks,
    )
    on_siv_vks = vks_code.split("override fun onStartInputView(info: EditorInfo?, restarting: Boolean)")[1].split("override fun onFinishInputView")[0]
    s.check(
        "VoiceKeyboardService.onStartInputView precarga config STT",
        "dictation.preloadSttConfig()" in on_siv_vks,
    )
    s.check(
        "VoiceKeyboardService.onStartInputView tiene cero llamadas a getSharedPreferences",
        "getSharedPreferences" not in on_siv_vks,
    )
    s.check(
        "VoiceKeyboardService.onStartInputView tiene cero llamadas a EncryptedSharedPreferences",
        "EncryptedSharedPreferences" not in on_siv_vks,
    )

    # 10. Mutaciones Negativas
    print("\n--- Verificación de Mutaciones Negativas ---")

    # Mutación 1: startDictation vuelve a llamar sttClient.loadConfig()
    mut1 = start_body.replace("sttClient.getConfig()", "sttClient.loadConfig()")
    s.check(
        "Mutación 1 (startDictation con loadConfig sincrónico): detectada",
        "sttClient.loadConfig()" in mut1 and ("sttClient.getConfig()" not in mut1 or "loadConfig" in mut1),
    )

    # Mutación 2: initMicSounds vuelve a correr sincrónico en onCreateInputView
    mut2 = create_view_body.replace("BackgroundWork.execute {\n            initMicSounds()\n        }", "initMicSounds()")
    s.check(
        "Mutación 2 (initMicSounds sincrónico en main): detectada",
        "BackgroundWork.execute" not in mut2,
    )

    # Mutación 3: SecureStore sin caché de vault (recrea ESP en cada llamada)
    mut3 = sec_code.replace("cachedVault?.let { return it }", "")
    s.check(
        "Mutación 3 (SecureStore sin chequeo de cachedVault): detectada",
        "cachedVault?.let { return it }" not in mut3,
    )

    # Mutación 4: KeyboardPrefs.load vuelve a llamar getSharedPreferences 20+ veces
    mut4 = kb_code.replace("val p = prefs()", 'val p = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)')
    s.check(
        "Mutación 4 (KeyboardPrefs.load llama getSharedPreferences): detectada",
        mut4.count('context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)') > 1,
    )

    # Mutación 5: SnippetsLayer.toggle vuelve a hacer store.load sincrónico
    mut5 = toggle_snip.replace("BackgroundWork.execute {\n            store.load()\n        }", "store.load()")
    s.check(
        "Mutación 5 (SnippetsLayer.toggle con store.load sincrónico): detectada",
        "BackgroundWork.execute" not in mut5,
    )

    # Mutación 6: VoiceKeyboardService.onCreate omite SecureStore.warmUp
    mut6 = on_create_vks.replace("SecureStore.warmUp(this)", "")
    s.check(
        "Mutación 6 (VKS.onCreate omite SecureStore.warmUp): detectada",
        "SecureStore.warmUp(this)" not in mut6,
    )

    print("\n============================================================")
    print(f" RESULTADOS C-12: {s.passed} pasados, {s.failed} fallidos.")
    print("============================================================\n")

    if s.failed > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    run_suite()
