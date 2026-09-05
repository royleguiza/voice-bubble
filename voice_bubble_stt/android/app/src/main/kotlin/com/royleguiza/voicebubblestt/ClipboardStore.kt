package com.royleguiza.voicebubblestt

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.util.LruCache
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import android.os.Handler
import android.os.Looper

enum class ClipType { TEXT, CODE, IMAGE, MATH, URL }

/**
 * Representa un elemento individual capturado en el historial del portapapeles.
 */
data class ClipboardItem(
    val id: String = UUID.randomUUID().toString(),
    val type: ClipType,
    val text: String? = null,
    val preview: String? = null,
    val mediaFileName: String? = null,
    val mimeType: String = "text/plain",
    val timestamp: Long = System.currentTimeMillis(),
    val isPinned: Boolean = false,
    val charCount: Int = text?.length ?: 0,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("type", type.name)
        put("text", text ?: "")
        put("preview", preview ?: "")
        put("mediaFileName", mediaFileName ?: "")
        put("mimeType", mimeType)
        put("timestamp", timestamp)
        put("isPinned", isPinned)
        put("charCount", charCount)
    }

    companion object {
        fun fromJson(json: JSONObject): ClipboardItem {
            val typeStr = json.optString("type", "TEXT")
            val type = try {
                ClipType.valueOf(typeStr)
            } catch (_: Exception) {
                ClipType.TEXT
            }
            return ClipboardItem(
                id = json.optString("id", UUID.randomUUID().toString()),
                type = type,
                text = json.optString("text").takeIf { it.isNotEmpty() },
                preview = json.optString("preview").takeIf { it.isNotEmpty() },
                mediaFileName = json.optString("mediaFileName").takeIf { it.isNotEmpty() },
                mimeType = json.optString("mimeType", "text/plain"),
                timestamp = json.optLong("timestamp", System.currentTimeMillis()),
                isPinned = json.optBoolean("isPinned", false),
                charCount = json.optInt("charCount", 0),
            )
        }
    }
}

/**
 * Gestor y almacén persistente del portapapeles del sistema para VoiceBubble IME.
 *
 * Características de producción:
 * 1. Persistencia atómica en JSON (renombrado atómico de archivo .tmp).
 * 2. Copiado local seguro de imágenes a sandbox privado (inmunidad ante URIs content:// expirados).
 * 3. Límite FIFO estricto de 25 clips no fijados con limpieza automática de archivos huérfanos.
 * 4. Los clips fijados (isPinned = true) se conservan permanentemente.
 * 5. LruCache en memoria (4MB) con downsampling eficiente (RGB_565) para 0 jank y 0 OOM.
 * 6. Deduplicación inteligente: copias repetidas se actualizan en el tope sin duplicar entradas.
 */
class ClipboardStore(
    private val context: Context,
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
) {

    companion object {
        private const val TAG = "VbClipboardStore"
        private const val FILE_HISTORY = "clipboard_history.json"
        private const val DIR_MEDIA = "clipboard_media"
        const val MAX_UNPINNED_ITEMS = 25
        const val MAX_TEXT_PREVIEW_CHARS = 120
    }

    private val lock = Any()
    private val mediaDir: File by lazy {
        File(context.filesDir, DIR_MEDIA).apply { if (!exists()) mkdirs() }
    }

    // Cache LRU de 4MB para miniaturas de imagen en RAM
    private val thumbnailCache = object : LruCache<String, Bitmap>(4 * 1024 * 1024) {
        override fun sizeOf(key: String, bitmap: Bitmap): Int = bitmap.byteCount
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var itemsCache: MutableList<ClipboardItem>? = null

    /**
     * Carga y devuelve la lista actual de clips ordenada (fijados primero y más recientes primero).
     *
     * El I/O de disco corre FUERA del lock (antes `file.readText()` estaba
     * dentro del `synchronized`: ANR en eMMC lentas). El lock solo protege
     * la caché en memoria; la doble comprobación evita adoptar un snapshot
     * obsoleto si otro hilo pobló la caché mientras leíamos el disco.
     */
    fun loadItems(): List<ClipboardItem> {
        itemsCache?.let { return ArrayList(it) }
        val fromDisk = readFromDisk()
        synchronized(lock) {
            itemsCache?.let { return ArrayList(it) }
            val list = fromDisk
            sortAndNormalize(list)
            itemsCache = list
            return ArrayList(list)
        }
    }

    /** Lee y parsea el JSON del historial sin tomar el lock (solo disco). */
    private fun readFromDisk(): MutableList<ClipboardItem> {
        val list = mutableListOf<ClipboardItem>()
        val file = File(context.filesDir, FILE_HISTORY)
        if (file.exists()) {
            try {
                val raw = file.readText()
                val array = JSONArray(raw)
                for (i in 0 until array.length()) {
                    list.add(ClipboardItem.fromJson(array.getJSONObject(i)))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error leyendo clipboard_history.json", e)
            }
        }
        return list
    }

    /**
     * Obtiene el clip más reciente del historial.
     */
    fun getLatestClip(): ClipboardItem? {
        val list = loadItems()
        return list.firstOrNull()
    }

    /**
     * Agrega un clip de texto/código/URL/matemática de forma asíncrona sin bloquear el hilo principal.
     */
    fun addTextClip(text: String, onComplete: ((List<ClipboardItem>) -> Unit)? = null) {
        if (text.isEmpty()) return
        executor.execute {
            val detectedType = classifyTextContent(text)
            val preview = generateTextPreview(text)

            val item = ClipboardItem(
                type = detectedType,
                text = text,
                preview = preview,
                mimeType = "text/plain",
                charCount = text.length,
            )
            insertAndPersist(item)
            val updated = loadItems()
            onComplete?.invoke(updated)
        }
    }

    /**
     * Copia de forma segura los bytes de una imagen URI al sandbox privado local y agrega el clip.
     */
    fun addImageClip(uri: Uri, mimeType: String, onComplete: ((List<ClipboardItem>) -> Unit)? = null) {
        executor.execute {
            try {
                val fileName = "clip_${UUID.randomUUID()}.png"
                val destFile = File(mediaDir, fileName)

                context.contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(destFile).use { output ->
                        input.copyTo(output)
                    }
                } ?: return@execute

                val item = ClipboardItem(
                    type = ClipType.IMAGE,
                    mediaFileName = fileName,
                    mimeType = mimeType,
                    preview = "Imagen (${mimeType.substringAfter('/')})",
                )
                insertAndPersist(item)
                val updated = loadItems()
                onComplete?.invoke(updated)
            } catch (e: Exception) {
                Log.e(TAG, "Error guardando imagen en cache local", e)
            }
        }
    }

    private fun insertAndPersist(newItem: ClipboardItem) {
        // Snapshot de disco fuera del lock (el lock solo protege la
        // memoria); dentro se prefiere la caché vigente por si otro hilo
        // la pobló mientras tanto. Sin llamadas anidadas bajo lock: antes
        // se invocaba loadItems() (synchronized) desde este mismo lock.
        val diskSnapshot = if (itemsCache == null) readFromDisk() else null
        val updated: List<ClipboardItem>
        var evictedMedia: List<String> = emptyList()
        synchronized(lock) {
            val current = (itemsCache ?: diskSnapshot ?: mutableListOf()).toMutableList()

            // Deduplicación: actualizar si ya existía el mismo texto exacto o archivo
            val existingIdx = current.indexOfFirst { existing ->
                if (newItem.type == ClipType.IMAGE) {
                    existing.mediaFileName != null && existing.mediaFileName == newItem.mediaFileName
                } else {
                    existing.text != null && existing.text == newItem.text
                }
            }

            if (existingIdx != -1) {
                val old = current.removeAt(existingIdx)
                // Conservar estado fijado si ya estaba fijado
                current.add(0, newItem.copy(isPinned = old.isPinned, timestamp = System.currentTimeMillis()))
            } else {
                current.add(0, newItem)
            }

            // Aplicar límite FIFO solo a los no fijados
            val pinned = current.filter { it.isPinned }
            val unpinned = current.filter { !it.isPinned }

            if (unpinned.size > MAX_UNPINNED_ITEMS) {
                val toEvict = unpinned.drop(MAX_UNPINNED_ITEMS)
                val toKeep = unpinned.take(MAX_UNPINNED_ITEMS)

                evictedMedia = toEvict.mapNotNull { evicted -> evicted.mediaFileName }
                toEvict.forEach { evicted -> thumbnailCache.remove(evicted.id) }

                current.clear()
                current.addAll(pinned + toKeep)
            }

            sortAndNormalize(current)
            itemsCache = current
            updated = ArrayList(current)
        }
        // I/O fuera del lock: borrado de imágenes desalojadas + escritura
        // atómica del JSON. El lock solo cubrió la mutación en memoria.
        deleteEvictedMedia(evictedMedia)
        saveToDisk(updated)
    }

    private fun deleteEvictedMedia(names: List<String>) {
        names.forEach { fname ->
            try {
                val f = File(mediaDir, fname)
                if (f.exists()) f.delete()
            } catch (_: Exception) {}
        }
    }

    /**
     * Alterna el estado de fijado (pin / unpin) de un clip.
     * Sin llamadas anidadas bajo lock: el snapshot se lee fuera y dentro
     * solo se muta la caché (la escritura a disco ya corría en executor).
     */
    fun togglePin(itemId: String): List<ClipboardItem> {
        val snapshot = loadItems()
        val toPersist: List<ClipboardItem>?
        val updated: List<ClipboardItem>
        synchronized(lock) {
            val current = (itemsCache ?: snapshot.toMutableList()).toMutableList()
            val idx = current.indexOfFirst { it.id == itemId }
            if (idx != -1) {
                val old = current[idx]
                current[idx] = old.copy(isPinned = !old.isPinned)
                sortAndNormalize(current)
                itemsCache = current
                toPersist = ArrayList(current)
            } else {
                toPersist = null
            }
            updated = ArrayList(current)
        }
        toPersist?.let { executor.execute { saveToDisk(it) } }
        return updated
    }

    /**
     * Limpia todos los clips que NO estén fijados.
     * Sin llamadas anidadas bajo lock (ver [togglePin]).
     */
    fun clearAllUnpinned(): List<ClipboardItem> {
        val snapshot = loadItems()
        val unpinned: List<ClipboardItem>
        val updated: List<ClipboardItem>
        synchronized(lock) {
            val current = (itemsCache ?: snapshot.toMutableList()).toMutableList()
            unpinned = current.filter { !it.isPinned }
            current.removeAll(unpinned)
            itemsCache = current
            updated = ArrayList(current)
        }
        executor.execute {
            unpinned.forEach { item ->
                item.mediaFileName?.let { fname ->
                    val f = File(mediaDir, fname)
                    if (f.exists()) f.delete()
                }
            }
            saveToDisk(updated)
        }
        return updated
    }

    /**
     * Carga asincrona de miniaturas en hilo secundario para no bloquear el hilo principal (UI).
     */
    fun loadThumbnailAsync(item: ClipboardItem, targetW: Int, targetH: Int, onLoaded: (Bitmap?) -> Unit) {
        if (item.type != ClipType.IMAGE || item.mediaFileName == null) {
            onLoaded(null)
            return
        }
        val cached = thumbnailCache.get(item.id)
        if (cached != null) {
            onLoaded(cached)
            return
        }

        executor.execute {
            val file = File(mediaDir, item.mediaFileName)
            val bmp = if (file.exists()) {
                decodeSampledBitmap(file.absolutePath, targetW, targetH)?.also {
                    thumbnailCache.put(item.id, it)
                }
            } else {
                null
            }
            mainHandler.post { onLoaded(bmp) }
        }
    }

    /**
     * Cierra el executor para liberar hilos y recursos en onDestroy.
     */
    fun shutdown() {
        try {
            executor.shutdown()
        } catch (_: Exception) {}
    }

    /**
     * Devuelve el archivo físico de la imagen en almacenamiento privado.
     */
    fun getMediaFile(item: ClipboardItem): File? {
        if (item.mediaFileName == null) return null
        val f = File(mediaDir, item.mediaFileName)
        return if (f.exists()) f else null
    }

    private fun sortAndNormalize(list: MutableList<ClipboardItem>) {
        list.sortWith(compareByDescending<ClipboardItem> { it.isPinned }.thenByDescending { it.timestamp })
    }

    private fun saveToDisk(list: List<ClipboardItem>) {
        try {
            val array = JSONArray()
            list.forEach { array.put(it.toJson()) }
            val tmpFile = File(context.filesDir, "$FILE_HISTORY.tmp")
            val targetFile = File(context.filesDir, FILE_HISTORY)
            tmpFile.writeText(array.toString())
            if (!tmpFile.renameTo(targetFile)) {
                tmpFile.copyTo(targetFile, overwrite = true)
                try { tmpFile.delete() } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error guardando clipboard a disco", e)
        }
    }

    /**
     * Clasifica heurísticamente el contenido textual preservando la integridad del string original.
     */
    fun classifyTextContent(raw: String): ClipType {
        val trimmed = raw.trim()
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://") || trimmed.startsWith("ftp://")) {
            return ClipType.URL
        }
        if (trimmed.contains("\\int") || trimmed.contains("\\frac") || trimmed.contains("\\sqrt") ||
            trimmed.contains("\\sum") || (trimmed.startsWith("$$") && trimmed.endsWith("$$"))) {
            return ClipType.MATH
        }
        if (detectCodeHeuristic(raw)) {
            return ClipType.CODE
        }
        return ClipType.TEXT
    }

    private fun detectCodeHeuristic(text: String): Boolean {
        if (text.lines().size >= 2 && (text.startsWith("    ") || text.startsWith("\t"))) return true
        val codeMarkers = listOf(
            "const ", "let ", "var ", "function", "def ", "import ", "class ", "return ",
            "SELECT ", "FROM ", "WHERE ", "CREATE ", "INSERT ", "UPDATE ", "{", "}", "=>", "#!/bin/", "public static", "void ",
            "fun ", "val ", "println", "git "
        )
        val matches = codeMarkers.count { text.contains(it, ignoreCase = true) }
        return matches >= 2 || text.contains("SELECT ", ignoreCase = true) || (text.contains("{\n") && text.contains("}")) || text.contains(";\n")
    }

    private fun generateTextPreview(text: String): String {
        val singleLine = text.replace(Regex("\\s+"), " ").trim()
        return if (singleLine.length > MAX_TEXT_PREVIEW_CHARS) {
            singleLine.substring(0, MAX_TEXT_PREVIEW_CHARS) + "…"
        } else {
            singleLine
        }
    }

    private fun decodeSampledBitmap(path: String, reqWidth: Int, reqHeight: Int): Bitmap? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, options)

        var inSampleSize = 1
        val (height: Int, width: Int) = options.outHeight to options.outWidth
        if (height > reqHeight || width > reqWidth) {
            val halfHeight: Int = height / 2
            val halfWidth: Int = width / 2
            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }

        return BitmapFactory.Options().run {
            this.inSampleSize = inSampleSize
            inJustDecodeBounds = false
            inPreferredConfig = Bitmap.Config.RGB_565
            BitmapFactory.decodeFile(path, this)
        }
    }
}
