package com.royleguiza.voicebubblestt

import org.json.JSONArray
import org.json.JSONObject

import android.content.Context
import android.util.Log

/**
 * Snippet del teclado (K4): item de la lista compartida con la app Flutter.
 */
data class VbSnippet(
    val id: String,
    val nombre: String,
    val contenido: String,
    val orden: Int,
)

/**
 * Store de snippets del teclado (K4): lee/escribe la lista compartida con la
 * app Flutter via SharedPreferences (puente "flutter." sobre el archivo
 * FlutterSharedPreferences, mismo patron de SpeechToTextClient).
 *
 * PRIVACIDAD: jamas se registra en Log el contenido, nombre ni id de los
 * snippets; solo estados numericos (cantidades y tamanos).
 * Parseo tolerante: JSON ausente/corrupto/tipo incorrecto devuelve una lista
 * vacia con log diagnostico; nunca lanza excepciones hacia afuera.
 * Los limites (50 snippets / 2000 chars) son solo informativos: la validacion
 * real vive en la app Flutter.
 */
class SnippetStore(private val context: Context) {

    companion object {
        private const val TAG = "VbSnippetStore"

        /** Mismo archivo/modo que usan los demas componentes del proyecto. */
        const val PREFS_NAME = "FlutterSharedPreferences"

        /** Clave de datos escrita por la app Flutter (array JSON como string). */
        const val KEY_DATA = "flutter.voice_snippets_v1"

        /** Flag de primera apertura para sembrar los seeds. */
        const val KEY_SEEDED = "flutter.kb_snippets_seeded"

        /** Limites informativos del contrato K4. */
        const val MAX_SNIPPETS = 50
        const val MAX_CONTENIDO = 2000
    }

    private val cacheLock = Any()

    @Volatile
    private var cache: List<VbSnippet>? = null

    /**
     * Lectura fresca desde prefs con parseo tolerante, ordenada por "orden"
     * ascendente (el desempate preserva el orden de aparicion: sort estable).
     */
    fun load(): List<VbSnippet> {
        val raw = try {
            prefs().getString(KEY_DATA, null)
        } catch (_: Exception) {
            Log.w(TAG, "tipo incorrecto en prefs")
            null
        }
        val parsed = parse(raw)
        synchronized(cacheLock) { cache = parsed }
        return parsed
    }

    /** Fuerza relectura desde prefs y refresca el cache. */
    fun reload() {
        load()
    }

    /** Devuelve el cache; carga perezosa si nunca se cargo. */
    fun get(): List<VbSnippet> {
        synchronized(cacheLock) { cache?.let { return it } }
        return load()
    }

    /**
     * Siembra los 5 seeds solo en la primera apertura (flag ausente/false):
     * si no hay snippets guardados escribe los seeds; si ya existen, los
     * respeta y no toca datos. Siempre marca el flag al final.
     * Idempotente y seguro ante carreras basicas: relee prefs justo antes de
     * decidir (no confia en el cache), asi dos llamadas concurrentes producen
     * el mismo resultado o respetan lo ya escrito por la otra.
     */
    fun seedIfFirstOpen() {
        try {
            val prefs = prefs()
            val alreadySeeded = try {
                prefs.getBoolean(KEY_SEEDED, false)
            } catch (_: Exception) {
                false
            }
            if (alreadySeeded) return
            // Relectura fresca dentro del metodo (contrato: releer antes de escribir).
            val existing = parse(try {
                prefs.getString(KEY_DATA, null)
            } catch (_: Exception) {
                null
            })
            if (existing.isEmpty()) {
                val seeds = buildSeeds()
                writeAll(seeds)
                synchronized(cacheLock) { cache = seeds }
                Log.i(TAG, "seeds escritos: ${seeds.size}")
            } else {
                synchronized(cacheLock) { cache = existing }
                Log.i(TAG, "seeds omitidos: existentes=${existing.size}")
            }
            prefs.edit().putBoolean(KEY_SEEDED, true).apply()
        } catch (_: Exception) {
            // Jamas propagar: el teclado debe arrancar aunque falle el seed.
        }
    }

    private fun prefs() =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Escritura atomica del array JSON completo bajo la misma clave. */
    private fun writeAll(snippets: List<VbSnippet>) {
        val arr = JSONArray()
        for (s in snippets) {
            arr.put(
                JSONObject()
                    .put("id", s.id)
                    .put("nombre", s.nombre)
                    .put("contenido", s.contenido)
                    .put("orden", s.orden),
            )
        }
        prefs().edit().putString(KEY_DATA, arr.toString()).apply()
    }

    /**
     * Parseo tolerante: entradas que no son objetos se descartan, campos
     * faltantes toman defaults neutros; un array corrupto completo deja la
     * lista vacia con log diagnostico numerico (sin contenido jamas).
     */
    private fun parse(raw: String?): List<VbSnippet> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            val out = ArrayList<VbSnippet>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i)
                if (obj == null) {
                    Log.w(TAG, "entrada ignorada en indice $i")
                    continue
                }
                out.add(
                    VbSnippet(
                        id = obj.optString("id"),
                        nombre = obj.optString("nombre"),
                        contenido = obj.optString("contenido"),
                        // Sin campo explicito, el indice conserva orden estable.
                        orden = obj.optInt("orden", i),
                    ),
                )
            }
            // Reportes informativos de tamano (no se rechaza nada).
            if (out.size > MAX_SNIPPETS) {
                Log.i(TAG, "sobre el maximo: ${out.size} de $MAX_SNIPPETS")
            }
            val oversized = out.count { it.contenido.length > MAX_CONTENIDO }
            if (oversized > 0) {
                Log.i(TAG, "contenidos largos: $oversized")
            }
            Log.d(TAG, "snippets parseados: ${out.size}")
            out.sortedBy { it.orden }
        } catch (_: Exception) {
            Log.w(TAG, "json invalido")
            emptyList()
        }
    }

    /** Seeds exactos del contrato K4: ids estables identicos al lado Dart. */
    private fun buildSeeds(): List<VbSnippet> = listOf(
        VbSnippet(id = "seed-codex", nombre = "Codex", contenido = "codex \"", orden = 0),
        VbSnippet(id = "seed-gemini", nombre = "Gemini", contenido = "gemini -p \"", orden = 1),
        VbSnippet(id = "seed-git-commit", nombre = "Git commit", contenido = "git add . && git commit -m \"", orden = 2),
        VbSnippet(id = "seed-git-push", nombre = "Git push", contenido = "git push origin main", orden = 3),
        VbSnippet(id = "seed-supabase-push", nombre = "Supabase push", contenido = "supabase db push", orden = 4),
    )
}
