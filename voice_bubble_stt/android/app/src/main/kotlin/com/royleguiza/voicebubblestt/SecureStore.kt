package com.royleguiza.voicebubblestt

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Bóveda cifrada del IME (SPK-02): secretos que el teclado/burbuja nativos
 * necesitan sin FlutterEngine (API key STT, contraseñas de Claves).
 *
 * Interopera con flutter_secure_storage v9 (pin `^9.0.0` en
 * `app_source/pubspec.yaml`) SIN duplicar su cripto: se abre el MISMO
 * archivo ("FlutterSecureStorage") con la MISMA master key por defecto y
 * los MISMOS esquemas públicos de AndroidX (AES256_SIV en claves,
 * AES256_GCM en valores), leyendo las claves con el prefijo estable de FSS.
 * Verificado contra el fuente de FSS 9.2.4
 * (`FlutterSecureStorage.java`: `initializeEncryptedSharedPreferencesManager`
 * + `addPrefixToKey`); Dart usa `AndroidOptions(encryptedSharedPreferences:
 * true)`, que además auto-migra el formato viejo al abrirlo.
 *
 * JAMÁS lanza: cualquier fallo (keystore bloqueado, archivo corrupto,
 * cambio futuro de FSS) devuelve null/false para que los llamadores
 * degraden al fail-fast honesto ya existente ("Falta la API key" →
 * Ajustes). Nada se registra en Log salvo estados sin contenido.
 *
 * Jubilación: cuando se retire la migración del legado plano, borrar en el
 * MISMO commit los literales "flutter.kb_stt_api_key"/"flutter.vb_cred_pass_v1"
 * y sus líneas de docs/contract-keys.txt (el guard de paridad lo exige).
 */
object SecureStore {

    private const val TAG = "VbSecureStore"

    /** Archivo de FSS v9 con ESP activado (ver KDoc). */
    const val FILE = "FlutterSecureStorage"

    /** `ELEMENT_PREFERENCES_KEY_PREFIX` de FSS v9 (estable desde v3). */
    const val KEY_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg"

    /** Clave de la API key STT (= `StorageService.secureSttApiKey` en Dart). */
    const val STT_API_KEY = "groq_api_key"

    /** Mapa {id: password} de Claves (= `StorageService.credPassKey`). */
    const val CRED_PASS_MAP = "vb_cred_pass_v1"

    fun prefixed(key: String) = "${KEY_PREFIX}_$key"

    private fun vault(context: Context): SharedPreferences? = try {
        val masterKey = MasterKey.Builder(context, MasterKey.DEFAULT_MASTER_KEY_ALIAS)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context.applicationContext,
            FILE,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (_: Exception) {
        Log.w(TAG, "boveda no disponible")
        null
    }

    fun read(context: Context, key: String): String? = try {
        vault(context)?.getString(prefixed(key), null)
    } catch (_: Exception) {
        null
    }

    fun write(context: Context, key: String, value: String): Boolean = try {
        val v = vault(context) ?: return false
        v.edit().putString(prefixed(key), value).apply()
        true
    } catch (_: Exception) {
        false
    }

    fun remove(context: Context, key: String): Boolean = try {
        val v = vault(context) ?: return false
        v.edit().remove(prefixed(key)).apply()
        true
    } catch (_: Exception) {
        false
    }
}
