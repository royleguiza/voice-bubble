package com.royleguiza.voicebubblestt

import org.json.JSONArray
import org.json.JSONObject

/**
 * T1 · Formato de la copia de seguridad (`.zip`) y reglas de fusión.
 *
 * Lógica pura (sin Context) para poder probarla en la JVM. El archivo lleva:
 * `manifest.json` (formato y versión), `notes.json` + `audio/…` (WAV de las
 * notas), `history.json`, `snippets.json`, `clips.json` + `clips/…`
 * (imágenes del portapapeles) y `settings.json` (ajustes planos).
 *
 * Privacidad: jamás entran claves de API, credenciales ni la bóveda. Los
 * ajustes pasan por [isExportablePrefKey] (lista negra explícita + patrón
 * de nombres sensibles) tanto al exportar como al importar.
 */
object BackupFormat {
    const val FORMAT = "orison-backup"
    const val VERSION = 1

    const val MANIFEST = "manifest.json"
    const val NOTES = "notes.json"
    const val HISTORY = "history.json"
    const val SNIPPETS = "snippets.json"
    const val CLIPS = "clips.json"
    const val SETTINGS = "settings.json"
    const val AUDIO_DIR = "audio/"
    const val CLIP_MEDIA_DIR = "clips/"

    /** Topes al importar: un zip roto o malicioso no llena el teléfono. */
    const val MAX_JSON_BYTES = 32L * 1024 * 1024
    const val MAX_MEDIA_BYTES = 256L * 1024 * 1024
    const val MAX_TOTAL_BYTES = 2L * 1024 * 1024 * 1024
    const val MAX_ENTRIES = 1000

    private val JSON_ENTRIES = setOf(MANIFEST, NOTES, HISTORY, SNIPPETS, CLIPS, SETTINGS)
    private val SAFE_FILE = Regex("^[A-Za-z0-9_][A-Za-z0-9._-]{0,159}$")

    enum class EntryKind { JSON, AUDIO, CLIP_MEDIA }

    fun isSafeFileName(name: String): Boolean =
        SAFE_FILE.matches(name) && !name.contains("..")

    /** Clasifica una entrada del zip; null = desconocida o peligrosa (se ignora). */
    fun classifyEntry(name: String): EntryKind? = when {
        name in JSON_ENTRIES -> EntryKind.JSON
        name.startsWith(AUDIO_DIR) && isSafeFileName(name.removePrefix(AUDIO_DIR)) -> EntryKind.AUDIO
        name.startsWith(CLIP_MEDIA_DIR) && isSafeFileName(name.removePrefix(CLIP_MEDIA_DIR)) ->
            EntryKind.CLIP_MEDIA
        else -> null
    }

    // ---------------------------------------------------------------- ajustes

    /** Datos que viajan por su propio archivo o secretos que nunca viajan. */
    private val EXCLUDED_PREF_KEYS = setOf(
        "flutter.kb_stt_api_key",
        "flutter.kb_stt_key_configured",
        "flutter.vb_cred_pass_v1",
        "flutter.vb_credentials_v1",
        "flutter.voice_notes_v1",
        "flutter.voice_notes_pending_v1",
        "flutter.voice_snippets_v1",
        "flutter.transcriptions",
    )
    private val SENSITIVE_NAME = Regex(
        "(api_?key|token|secret|password|passwd|_pass|credential|vault|auth)",
        RegexOption.IGNORE_CASE,
    )

    fun isExportablePrefKey(key: String): Boolean =
        key.startsWith("flutter.") &&
            key !in EXCLUDED_PREF_KEYS &&
            !SENSITIVE_NAME.containsMatchIn(key)

    /** Serializa los ajustes planos con su tipo para restaurarlos tal cual. */
    fun encodePrefs(all: Map<String, *>): JSONObject {
        val out = JSONObject()
        for (key in all.keys.sorted()) {
            if (!isExportablePrefKey(key)) continue
            val entry = when (val value = all[key]) {
                is Boolean -> JSONObject().put("t", "b").put("v", value)
                is Int -> JSONObject().put("t", "i").put("v", value)
                is Long -> JSONObject().put("t", "l").put("v", value)
                is Float -> JSONObject().put("t", "f").put("v", value.toDouble())
                is String -> JSONObject().put("t", "s").put("v", value)
                is Set<*> -> JSONObject().put("t", "ss")
                    .put("v", JSONArray(value.filterIsInstance<String>().sorted()))
                else -> null
            } ?: continue
            out.put(key, entry)
        }
        return out
    }

    /** Inversa de [encodePrefs]; descarta claves no exportables o tipos rotos. */
    fun decodePrefs(json: JSONObject): Map<String, Any> {
        val out = LinkedHashMap<String, Any>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            if (!isExportablePrefKey(key)) continue
            val entry = json.optJSONObject(key) ?: continue
            if (!entry.has("v")) continue
            val value: Any = when (entry.optString("t")) {
                "b" -> (entry.opt("v") as? Boolean) ?: continue
                "i" -> (entry.opt("v") as? Number)?.toInt() ?: continue
                "l" -> (entry.opt("v") as? Number)?.toLong() ?: continue
                "f" -> (entry.opt("v") as? Number)?.toFloat() ?: continue
                "s" -> (entry.opt("v") as? String) ?: continue
                "ss" -> {
                    val arr = entry.optJSONArray("v") ?: continue
                    (0 until arr.length()).mapNotNull { arr.opt(it) as? String }.toSet()
                }
                else -> continue
            }
            out[key] = value
        }
        return out
    }

    // ------------------------------------------------------------------ notas

    fun noteToJson(note: VbNote, audioEntry: String?): JSONObject {
        val obj = JSONObject()
            .put("id", note.id)
            .put("titulo", note.titulo)
            .put("cuerpo", note.cuerpo)
            .put("createdAt", note.createdAt)
            .put("updatedAt", note.updatedAt)
        if (audioEntry != null) obj.put("audio", audioEntry)
        return obj
    }

    /**
     * Nota del archivo; [VbNote.audioPath] trae el nombre de la entrada
     * `audio/…` (o vacío), que quien importa reemplaza por la ruta local.
     */
    fun noteFromJson(obj: JSONObject): VbNote? {
        val id = (obj.opt("id") as? String)?.takeIf { it.isNotBlank() } ?: return null
        val titulo = obj.opt("titulo") as? String ?: return null
        val cuerpo = obj.opt("cuerpo") as? String ?: return null
        val createdAt = (obj.opt("createdAt") as? String)?.takeIf { it.contains('T') } ?: return null
        val updatedAt = (obj.opt("updatedAt") as? String)?.takeIf { it.contains('T') } ?: return null
        val audio = (obj.opt("audio") as? String)
            ?.takeIf { classifyEntry(it) == EntryKind.AUDIO }
            ?: ""
        return VbNote(id, titulo, cuerpo, createdAt, updatedAt, audio)
    }

    data class NoteMerge(
        val notes: List<VbNote>,
        val added: Int,
        val updated: Int,
        val skipped: Int,
    )

    /**
     * Fusión por id: las locales nunca se pierden. Mismo id → gana la de
     * updatedAt más nuevo (si la importada no trae audio, conserva el local).
     * Nuevas → entran las más recientes mientras haya lugar bajo [max].
     */
    fun mergeNotes(
        local: List<VbNote>,
        incoming: List<VbNote>,
        max: Int,
        epoch: (String) -> Long,
    ): NoteMerge {
        val byId = LinkedHashMap<String, VbNote>()
        for (note in local) byId[note.id] = note
        val fresh = LinkedHashMap<String, VbNote>()
        var updated = 0
        for (note in incoming) {
            val current = byId[note.id]
            if (current != null) {
                if (epoch(note.updatedAt) > epoch(current.updatedAt)) {
                    val merged = if (note.audioPath.isBlank()) {
                        note.copy(audioPath = current.audioPath)
                    } else {
                        note
                    }
                    byId[note.id] = merged
                    updated++
                }
                continue
            }
            val previous = fresh[note.id]
            if (previous == null || epoch(note.updatedAt) > epoch(previous.updatedAt)) {
                fresh[note.id] = note
            }
        }
        val room = (max - byId.size).coerceAtLeast(0)
        val newest = fresh.values.sortedByDescending { epoch(it.updatedAt) }
        val taken = newest.take(room)
        for (note in taken) byId[note.id] = note
        val out = byId.values.sortedByDescending { epoch(it.updatedAt) }
        return NoteMerge(
            notes = out,
            added = taken.size,
            updated = updated,
            skipped = newest.size - taken.size,
        )
    }

    // --------------------------------------------------------------- snippets

    fun snippetToJson(snippet: VbSnippet): JSONObject {
        val obj = JSONObject()
            .put("id", snippet.id)
            .put("nombre", snippet.nombre)
            .put("contenido", snippet.contenido)
            .put("orden", snippet.orden)
        if (snippet.color != null) obj.put("color", snippet.color)
        return obj
    }

    fun snippetFromJson(obj: JSONObject, maxContenido: Int): VbSnippet? {
        val id = (obj.opt("id") as? String)?.takeIf { it.isNotBlank() } ?: return null
        val nombre = obj.opt("nombre") as? String ?: return null
        val contenido = (obj.opt("contenido") as? String)?.takeIf { it.isNotEmpty() } ?: return null
        if (contenido.length > maxContenido) return null
        val orden = (obj.opt("orden") as? Number)?.toInt() ?: 0
        val color = (obj.opt("color") as? String)?.takeIf { SnippetPalette.isValid(it) }
        return VbSnippet(id, nombre, contenido, orden, color)
    }

    data class SnippetMerge(val snippets: List<VbSnippet>, val added: Int, val skipped: Int)

    /**
     * Fusión de snippets: se agregan al final los que no existen ni por id ni
     * por el mismo nombre y contenido (así los ejemplos precargados de las dos
     * instalaciones no se duplican). Lo local no se toca.
     */
    fun mergeSnippets(local: List<VbSnippet>, incoming: List<VbSnippet>, max: Int): SnippetMerge {
        val out = local.toMutableList()
        val ids = local.map { it.id }.toHashSet()
        val bodies = local.map { it.nombre to it.contenido }.toHashSet()
        var orden = (local.maxOfOrNull { it.orden } ?: -1) + 1
        var added = 0
        var skipped = 0
        for (snippet in incoming.sortedBy { it.orden }) {
            if (snippet.id in ids || (snippet.nombre to snippet.contenido) in bodies) continue
            if (out.size >= max) {
                skipped++
                continue
            }
            out.add(snippet.copy(orden = orden++))
            ids.add(snippet.id)
            bodies.add(snippet.nombre to snippet.contenido)
            added++
        }
        return SnippetMerge(out, added, skipped)
    }

    // ---------------------------------------------------------- portapapeles

    data class ClipMerge(val items: List<ClipboardItem>, val added: Int)

    /**
     * Fusión del portapapeles: por id y por el mismo texto (o la misma imagen).
     * Los fijados entran todos; los no fijados respetan el tope de siempre,
     * quedando los más recientes.
     */
    fun mergeClips(
        local: List<ClipboardItem>,
        incoming: List<ClipboardItem>,
        maxUnpinned: Int,
    ): ClipMerge {
        val out = local.toMutableList()
        val localIds = local.map { it.id }.toHashSet()
        val ids = HashSet(localIds)
        val texts = local.mapNotNull { it.text }.toHashSet()
        for (item in incoming) {
            if (item.id in ids) continue
            if (item.type != ClipType.IMAGE && item.text != null && item.text in texts) continue
            if (item.type == ClipType.IMAGE && item.mediaFileName == null) continue
            if (item.type != ClipType.IMAGE && item.text.isNullOrEmpty()) continue
            out.add(item)
            ids.add(item.id)
            item.text?.let { texts.add(it) }
        }
        val pinned = out.filter { it.isPinned }
        val unpinned = out.filter { !it.isPinned }.sortedByDescending { it.timestamp }
        val kept = pinned + unpinned.take(maxUnpinned)
        return ClipMerge(kept, kept.count { it.id !in localIds })
    }
}
