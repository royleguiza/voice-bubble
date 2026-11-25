package com.royleguiza.voicebubblestt

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import java.io.File
import java.util.UUID

/**
 * T16 · Stickers propios: cada imagen importada se guarda como webp de
 * 512 × 512 (lo que piden WhatsApp y Telegram), centrada sobre fondo
 * transparente y sin deformar, en `filesDir/stickers/`. El teclado los
 * manda con commitContent por el FileProvider. Sin Log de contenido.
 */
class StickerStore(private val context: Context) {

    companion object {
        const val SIZE = 512
        const val MAX_STICKERS = 300
        const val DIR = "stickers"
        const val MIME = "image/webp"
        private const val MAX_SOURCE_BYTES = 20L * 1024 * 1024

        /** Rectángulo donde entra una imagen w × h dentro de un cuadrado de [box], sin deformar. */
        fun fitInside(w: Int, h: Int, box: Int = SIZE): Rect {
            if (w <= 0 || h <= 0) return Rect(0, 0, box, box)
            val scale = minOf(box.toFloat() / w, box.toFloat() / h)
            val dw = (w * scale).toInt().coerceIn(1, box)
            val dh = (h * scale).toInt().coerceIn(1, box)
            val left = (box - dw) / 2
            val top = (box - dh) / 2
            return Rect(left, top, left + dw, top + dh)
        }

        /** Potencia de 2 para decodificar sin cargar fotos enormes en memoria. */
        fun sampleSize(w: Int, h: Int, target: Int = SIZE * 2): Int {
            var sample = 1
            while (w / (sample * 2) >= target && h / (sample * 2) >= target) sample *= 2
            return sample
        }
    }

    val directory: File get() = File(context.filesDir, DIR).apply { if (!exists()) mkdirs() }

    /** Los más nuevos primero. */
    fun list(): List<File> = try {
        directory.listFiles { f -> f.isFile && f.name.endsWith(".webp") }
            ?.sortedByDescending { it.lastModified() }
            ?: emptyList()
    } catch (_: Exception) {
        emptyList()
    }

    fun delete(file: File): Boolean = try {
        file.parentFile?.canonicalFile == directory.canonicalFile && file.delete()
    } catch (_: Exception) {
        false
    }

    /** Importa una imagen (galería, archivos o «Compartir»). null si no se pudo. */
    fun import(uri: Uri): File? {
        if (list().size >= MAX_STICKERS) return null
        return try {
            val resolver = context.contentResolver
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            val opts = BitmapFactory.Options().apply {
                inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight)
            }
            val source = resolver.openInputStream(uri)?.use { input ->
                BitmapFactory.decodeStream(LimitedInputStream(input, MAX_SOURCE_BYTES), null, opts)
            } ?: return null
            val out = Bitmap.createBitmap(SIZE, SIZE, Bitmap.Config.ARGB_8888)
            Canvas(out).drawBitmap(
                source,
                null,
                fitInside(source.width, source.height),
                Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG),
            )
            source.recycle()
            val file = File(directory, "sticker_${UUID.randomUUID()}.webp")
            file.outputStream().use { stream ->
                @Suppress("DEPRECATION")
                val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    Bitmap.CompressFormat.WEBP_LOSSY
                } else {
                    Bitmap.CompressFormat.WEBP
                }
                out.compress(format, 90, stream)
            }
            out.recycle()
            if (file.length() > 0) file else null.also { file.delete() }
        } catch (_: Throwable) {
            null
        }
    }

    /** Corta la lectura de una imagen absurda (no llena la memoria). */
    private class LimitedInputStream(
        private val inner: java.io.InputStream,
        private var left: Long,
    ) : java.io.FilterInputStream(inner) {
        override fun read(): Int {
            if (left <= 0) return -1
            val b = super.read()
            if (b >= 0) left--
            return b
        }

        override fun read(b: ByteArray, off: Int, len: Int): Int {
            if (left <= 0) return -1
            val n = super.read(b, off, minOf(len.toLong(), left).toInt())
            if (n > 0) left -= n
            return n
        }
    }
}
