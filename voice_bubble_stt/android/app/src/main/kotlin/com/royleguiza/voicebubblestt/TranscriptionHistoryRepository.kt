package com.royleguiza.voicebubblestt

import android.content.Context
import android.util.Xml
import org.json.JSONArray
import org.json.JSONObject
import org.xmlpull.v1.XmlPullParser
import java.io.File
import java.io.FileInputStream
import java.io.InputStreamReader
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.math.abs

/**
 * Repositorio unificado, profesional y thread-safe para el historial de transcripciones (FIFO-20).
 *
 * Utiliza un archivo JSON atómico ('transcription_history.json') en el almacenamiento privado
 * ('context.filesDir'), compartido directamente entre el teclado nativo Kotlin y Flutter.
 *
 * Beneficios arquitectónicos:
 * 1. Escritura atómica (archivo .tmp + rename) que previene condiciones de carrera o lecturas parciales.
 * 2. Cero dependencia del formato interno / prefijos Base64 de FlutterSharedPreferences.
 * 3. Cero excepciones de incompatibilidad de tipos (String vs Set<String>).
 * 4. Migración transparente desde SharedPreferences legados si el archivo aún no existe.
 */
class TranscriptionHistoryRepository(private val context: Context) {

    companion object {
        const val FILE_NAME = "transcription_history.json"
        const val MAX_ITEMS = 20
        private const val SHARED_HISTORY_KEY = "flutter.transcriptions"
        /**
         * Ventana anti-doble-escritura: el MISMO texto reingresado dentro de
         * este margen se considera eco del mismo dictado, no uno nuevo.
         */
        private const val DEDUP_TEXT_WINDOW_MS = 30_000L
        private val lock = Any()
    }

    private val targetFile: File
        get() = File(context.filesDir, FILE_NAME)

    /**
     * Carga el historial ordenado por timestamp descendente (más reciente primero),
     * con deduplicación segura por timestamp y tope estricto de MAX_ITEMS (20).
     */
    fun loadHistory(): List<JSONObject> {
        synchronized(lock) {
            val file = targetFile
            if (!file.exists()) {
                val migrated = migrateFromLegacySources()
                if (migrated.isNotEmpty()) {
                    saveAtomic(migrated)
                }
                return migrated
            }

            return try {
                val text = file.readText(Charsets.UTF_8).trim()
                if (text.isEmpty()) return emptyList()
                val array = JSONArray(text)
                val list = ArrayList<JSONObject>(array.length())
                for (i in 0 until array.length()) {
                    val obj = array.optJSONObject(i)
                    if (obj != null && obj.has("text")) {
                        list.add(obj)
                    }
                }
                dedupAndSort(list)
            } catch (_: Exception) {
                migrateFromLegacySources()
            }
        }
    }

    /**
     * Purga historiales previos al arrancar una nueva sesión para garantizar
     * un historial efímero acotado únicamente a la sesión activa (Session-Scoped Ephemeral History).
     * Garantiza que solo las transcripciones generadas en la sesión activa sean retenidas.
     */
    fun purgePreviousSessionHistory() {
        synchronized(lock) {
            try {
                val tmp = File(context.filesDir, "$FILE_NAME.tmp")
                if (tmp.exists()) {
                    tmp.delete()
                }
                val file = targetFile
                file.writeText("[]", Charsets.UTF_8)
                // apply(), no commit(): esta purga sigue muerta (sin purga
                // automática), pero un commit() sincrónico en el main sería
                // una trampa de ANR si alguien la invoca en el futuro.
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .edit()
                    .remove(SHARED_HISTORY_KEY)
                    .apply()
            } catch (_: Exception) {}
        }
    }

    /**
     * Alias de conveniencia semántica para el arranque de sesión.
     */
    fun clearPreviousHistoryOnStartup() = purgePreviousSessionHistory()

    /**
     * Agrega una nueva transcripción al tope del historial de forma atómica y thread-safe.
     *
     * Guarda anti-eco: la app escribe cada dictado DOS veces al MISMO
     * archivo (Dart `StorageService.add` + write-through nativo
     * `pushHistoryEntry`), con distinto timestamp cada vez, así que el
     * dedup por timestamp de [dedupAndSort] no los caza y la modal muestra
     * duplicados. Si el mismo texto ya existe con timestamp dentro de
     * [DEDUP_TEXT_WINDOW_MS], se ignora el add (es el eco, no un dictado
     * nuevo). Dictados idénticos genuinamente separados en el tiempo
     * siguen guardándose como entradas propias.
     */
    fun addTranscription(text: String) {
        if (text.isBlank()) return
        synchronized(lock) {
            val current = loadHistory().toMutableList()
            val nowMs = Instant.now().toEpochMilli()
            val isEcho = current.any { obj ->
                try {
                    obj.optString("text", "") == text &&
                        abs(parseInstant(obj).toEpochMilli() - nowMs) <= DEDUP_TEXT_WINDOW_MS
                } catch (_: Exception) {
                    false
                }
            }
            if (isEcho) return
            val newEntry = JSONObject()
                .put("text", text)
                .put("timestamp", Instant.now().toString())
            current.add(0, newEntry)

            val deduped = dedupAndSort(current)
            saveAtomic(deduped)

            // Reflejo secundario defensivo a SharedPreferences para compatibilidad externa
            mirrorToSharedPreferences(deduped)
        }
    }

    private fun dedupAndSort(items: List<JSONObject>): List<JSONObject> {
        val sorted = items.sortedByDescending { parseInstant(it) }
        val seen = HashSet<Instant>()
        val out = ArrayList<JSONObject>(MAX_ITEMS)
        for (obj in sorted) {
            val ts = parseInstant(obj)
            if (ts != Instant.EPOCH && !seen.add(ts)) {
                continue
            }
            out.add(obj)
            if (out.size >= MAX_ITEMS) break
        }
        return out
    }

    private fun saveAtomic(items: List<JSONObject>) {
        try {
            val array = JSONArray()
            for (item in items) {
                array.put(item)
            }
            val tmp = File(context.filesDir, "$FILE_NAME.tmp")
            tmp.writeText(array.toString(), Charsets.UTF_8)
            if (!tmp.renameTo(targetFile)) {
                tmp.copyTo(targetFile, overwrite = true)
                try { tmp.delete() } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    private fun mirrorToSharedPreferences(items: List<JSONObject>) {
        try {
            val set = LinkedHashSet<String>()
            for (obj in items) {
                set.add(obj.toString())
            }
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putStringSet(SHARED_HISTORY_KEY, set)
                .apply()
        } catch (_: Exception) {}
    }

    /**
     * Migración defensiva desde FlutterSharedPreferences.xml tolerante tanto a <set> como
     * a <string> con prefijos Base64 de Flutter.
     */
    private fun migrateFromLegacySources(): List<JSONObject> {
        val results = ArrayList<JSONObject>()

        // 1. Intentar getStringSet en SharedPreferences de Android
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getStringSet(SHARED_HISTORY_KEY, null)?.let { set ->
                for (raw in set) {
                    try {
                        results.add(JSONObject(raw))
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}

        // 2. Si no hubo resultados, leer directamente del XML en disco desmontando cualquier prefijo de Flutter
        if (results.isEmpty()) {
            try {
                val xmlFile = File(context.applicationInfo.dataDir, "shared_prefs/FlutterSharedPreferences.xml")
                if (xmlFile.exists()) {
                    val rawCandidates = readRawCandidatesFromXml(xmlFile)
                    for (raw in rawCandidates) {
                        try {
                            results.add(JSONObject(raw))
                        } catch (_: Exception) {}
                    }
                }
            } catch (_: Exception) {}
        }

        return dedupAndSort(results)
    }

    private fun readRawCandidatesFromXml(file: File): List<String> {
        val out = ArrayList<String>()
        val parser = Xml.newPullParser()
        InputStreamReader(FileInputStream(file), Charsets.UTF_8).use { reader ->
            parser.setInput(reader)
            val chunk = StringBuilder()
            var capture = false
            var event = parser.eventType
            while (event != XmlPullParser.END_DOCUMENT) {
                when (event) {
                    XmlPullParser.START_TAG -> {
                        if (chunk.isNotEmpty()) {
                            processChunk(chunk.toString(), out)
                            chunk.setLength(0)
                        }
                        if (parser.getAttributeValue(null, "name") == SHARED_HISTORY_KEY) {
                            capture = true
                        }
                    }
                    XmlPullParser.TEXT -> if (capture) {
                        chunk.append(parser.text)
                    }
                    XmlPullParser.END_TAG -> {
                        if (capture) {
                            processChunk(chunk.toString(), out)
                            chunk.setLength(0)
                            if (parser.name == "set" || parser.name == "string") {
                                capture = false
                            }
                        }
                    }
                }
                event = parser.next()
            }
            if (chunk.isNotEmpty()) {
                processChunk(chunk.toString(), out)
            }
        }
        return out
    }

    private fun processChunk(raw: String, out: MutableList<String>) {
        val trimmed = raw.trim()
        if (trimmed.isBlank()) return

        // Desempaquetar prefijos de Flutter (ej. VGhpcy...["{...}"])
        val jsonArrayStart = trimmed.indexOf('[')
        val jsonArrayEnd = trimmed.lastIndexOf(']')
        if (jsonArrayStart in 0 until jsonArrayEnd) {
            val jsonArrayStr = trimmed.substring(jsonArrayStart, jsonArrayEnd + 1)
            try {
                val arr = JSONArray(jsonArrayStr)
                for (i in 0 until arr.length()) {
                    val item = arr.optString(i)
                    if (!item.isNullOrBlank()) out.add(item)
                }
                return
            } catch (_: Exception) {}
        }

        // String individual
        out.add(trimmed)
    }

    private fun parseInstant(obj: JSONObject): Instant {
        val ts = obj.optString("timestamp", "")
        if (ts.isBlank()) return Instant.EPOCH
        return try {
            Instant.parse(ts)
        } catch (_: Exception) {
            try {
                LocalDateTime.parse(ts).atZone(ZoneId.systemDefault()).toInstant()
            } catch (_: Exception) {
                Instant.EPOCH
            }
        }
    }
}
