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

/**
 * Historial FIFO-20 en JSON atómico, compartido Flutter↔Kotlin.
 * Identidad por timestamp exacto (SPK-04); I/O fuera del lock (SPK-17).
 */
class TranscriptionHistoryRepository(private val context: Context) {

    companion object {
        const val FILE_NAME = "transcription_history.json"
        const val MAX_ITEMS = 20
        private const val SHARED_HISTORY_KEY = "flutter.transcriptions"
        private val lock = Any()
    }

    private val targetFile: File
        get() = File(context.filesDir, FILE_NAME)

    /**
     * Carga el historial ordenado por timestamp descendente (más reciente primero),
     * con deduplicación segura por timestamp y tope estricto de MAX_ITEMS (20).
     */
    fun loadHistory(): List<JSONObject> {
        // SPK-17: I/O fuera del lock (el archivo se escribe atómico
        // tmp+rename, así que leer sin lock ve un snapshot completo).
        val file = targetFile
        if (!file.exists()) {
            val migrated = migrateFromLegacySources()
            if (migrated.isNotEmpty()) {
                synchronized(lock) { saveAtomic(migrated) }
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

    // SPK-22: purgas dormidas eliminadas (historial persistente FIFO-20
    // con retención; cero llamadores). Si la retención importa, un test
    // afirma que `load` no purga.

    /** Agrega un dictado con su timestamp (SPK-04); ver docs/contrato-stt.md. */
    fun addTranscription(text: String, timestampIso: String? = null) {
        if (text.isBlank()) return
        // SPK-17: construir fuera del lock; el lock solo cubre el write
        // atómico (exclusión mutua burbuja↔teclado: sin escritores concurrentes).
        val instant = try {
            if (!timestampIso.isNullOrBlank()) Instant.parse(timestampIso) else Instant.now()
        } catch (_: Exception) {
            Instant.now()
        }
        val newEntry = JSONObject()
            .put("text", text)
            .put("timestamp", instant.toString())
        val current = loadHistory().toMutableList()
        current.add(0, newEntry)
        val out = dedupAndSort(current)
        synchronized(lock) { saveAtomic(out) }
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

    /** Migración solo-lectura del legado prefs→archivo (SPK-04). */
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
