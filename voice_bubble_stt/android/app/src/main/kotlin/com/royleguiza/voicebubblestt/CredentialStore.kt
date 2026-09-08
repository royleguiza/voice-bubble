package com.royleguiza.voicebubblestt

import org.json.JSONArray
import org.json.JSONObject

import android.content.Context
import android.util.Log

/**
 * Credencial del teclado (contrato Claves): solo identificadores.
 * La contraseña JAMAS se muestra ni se registra en Log; solo se lee para
 * inyectarla directo en el campo destino ante el toque explícito.
 */
data class VbCredentialEntry(
    val id: String,
    val nombre: String,
    val usuario: String,
)

/**
 * Store de credenciales del teclado: el ÍNDICE (identificadores) se lee
 * de SharedPreferences (puente "flutter." sobre el archivo
 * FlutterSharedPreferences, mismo patrón de SnippetStore); las CONTRASEÑAS
 * viven SOLO en la bóveda cifrada [SecureStore] (SPK-02, mismo archivo que
 * flutter_secure_storage con ESP). El teclado jamás escribe credenciales
 * salvo la migración única del mapa plano pre-SPK-02 (leer plano →
 * escribir bóveda → borrar plano, idempotente). Altas/bajas solo en
 * Ajustes → Claves.
 *
 * Claves (contrato compartido, ver StorageService Dart):
 * - flutter.vb_credentials_v1: JSON array [{id, nombre, usuario}]
 * - bóveda vb_cred_pass_v1: JSON objeto {id: password} (cifrado)
 * - flutter.vb_cred_show_user: boolean (default false: solo nombre)
 *
 * PRIVACIDAD: ningun valor (nombre, usuario, password) se registra en Log;
 * solo estados numericos. Parseo tolerante: nunca lanza hacia afuera.
 */
class CredentialStore(private val context: Context) {

    companion object {
        private const val TAG = "VbCredentialStore"

        const val PREFS_NAME = "FlutterSharedPreferences"

        const val KEY_INDEX = "flutter.vb_credentials_v1"
        const val KEY_PASS = "flutter.vb_cred_pass_v1"
        const val KEY_SHOW_USER = "flutter.vb_cred_show_user"
    }

    private val cacheLock = Any()

    @Volatile
    private var indexCache: List<VbCredentialEntry>? = null

    @Volatile
    private var passCache: Map<String, String>? = null

    /** Indice fresco de identificadores (sin passwords), en orden de alta. */
    fun loadIndex(): List<VbCredentialEntry> {
        val raw = try {
            prefs().getString(KEY_INDEX, null)
        } catch (_: Exception) {
            Log.w(TAG, "tipo incorrecto en prefs")
            null
        }
        val parsed = parseIndex(raw)
        synchronized(cacheLock) { indexCache = parsed }
        return parsed
    }

    /** Password de una credencial, o null si no existe. Uso unico: relleno.
     *  Ante un miss en cache recarga (alta en Ajustes con teclado abierto). */
    fun getPassword(id: String): String? {
        synchronized(cacheLock) { passCache?.let { it[id]?.let { v -> return v } } }
        return loadPasses()[id]
    }

    /** true = mostrar usuario junto al nombre; default false. */
    fun getShowUser(): Boolean {
        return try {
            prefs().getBoolean(KEY_SHOW_USER, false)
        } catch (_: Exception) {
            false
        }
    }

    private fun loadPasses(): Map<String, String> {
        val raw = SecureStore.read(context, SecureStore.CRED_PASS_MAP)
            ?: migrateLegacyPasses()
        val parsed = parsePasses(raw)
        synchronized(cacheLock) { passCache = parsed }
        return parsed
    }

    /** Traslada el mapa plano pre-SPK-02 a la bóveda y lo borra. Solo legado. */
    private fun migrateLegacyPasses(): String? {
        val raw = try {
            prefs().getString(KEY_PASS, null)?.takeIf { it.isNotBlank() }
        } catch (_: Exception) {
            null
        } ?: return null
        if (SecureStore.write(context, SecureStore.CRED_PASS_MAP, raw)) {
            try {
                prefs().edit().remove(KEY_PASS).apply()
            } catch (_: Exception) {
            }
        }
        return raw
    }

    private fun prefs() =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun parseIndex(raw: String?): List<VbCredentialEntry> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            val out = ArrayList<VbCredentialEntry>(arr.length())
            val seen = HashSet<String>()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i)
                if (obj == null) {
                    Log.w(TAG, "entrada ignorada en indice $i")
                    continue
                }
                val id = obj.optString("id")
                if (id.isBlank() || !seen.add(id)) continue
                out.add(
                    VbCredentialEntry(
                        id = id,
                        nombre = obj.optString("nombre"),
                        usuario = obj.optString("usuario"),
                    ),
                )
            }
            out
        } catch (_: Exception) {
            Log.w(TAG, "json invalido")
            emptyList()
        }
    }

    private fun parsePasses(raw: String?): Map<String, String> {
        if (raw.isNullOrBlank()) return emptyMap()
        return try {
            val obj = JSONObject(raw)
            val out = HashMap<String, String>()
            val keys = obj.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                val v = obj.optString(k, "")
                if (v.isNotEmpty()) out[k] = v
            }
            out
        } catch (_: Exception) {
            Log.w(TAG, "json invalido")
            emptyMap()
        }
    }
}
