package com.royleguiza.voicebubblestt

import java.time.DateTimeException
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.format.ResolverStyle
import java.time.temporal.ChronoField
import java.time.temporal.ChronoUnit
import java.util.Locale

enum class TranscriptionHistorySource(val precedence: Int) {
    MEMORY(0),
    FILE(1),
    PREFERENCES(2),
}

data class TranscriptionHistoryRecord<T>(
    val value: T,
    val text: String,
    val instant: Instant,
    val source: TranscriptionHistorySource = TranscriptionHistorySource.MEMORY,
    val sourceIndex: Int = 0,
)

object TranscriptionHistoryLogic {
    const val MAX_ITEMS = 20
    const val JSON_LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"

    private val timestampPattern = Regex(
        "([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})" +
            "(?:\\.([0-9]+))?" +
            "(Z|[+-][0-9]{2}:[0-9]{2})",
    )
    private val legacyTimestampPattern = Regex(
        "([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})" +
            "(?:\\.([0-9]+))?",
    )
    private val timestampFormatter: DateTimeFormatter = DateTimeFormatterBuilder()
        .appendPattern("uuuu-MM-dd'T'HH:mm:ss")
        .appendFraction(ChronoField.NANO_OF_SECOND, 0, 6, true)
        .appendOffset("+HH:MM", "Z")
        .toFormatter(Locale.ROOT)
        .withResolverStyle(ResolverStyle.STRICT)
    private val legacyFormatter: DateTimeFormatter = DateTimeFormatterBuilder()
        .appendPattern("uuuu-MM-dd'T'HH:mm:ss")
        .appendFraction(ChronoField.NANO_OF_SECOND, 0, 9, true)
        .toFormatter(Locale.ROOT)
        .withResolverStyle(ResolverStyle.STRICT)
    private val canonicalFormatter: DateTimeFormatter = DateTimeFormatterBuilder()
        .appendInstant(6)
        .toFormatter(Locale.ROOT)

    fun parseTimestamp(raw: String?): Instant? {
        if (raw == null) return null
        val match = timestampPattern.matchEntire(raw) ?: return null
        val fraction = match.groupValues[2]
        val normalized = buildString {
            append(match.groupValues[1])
            if (fraction.isNotEmpty()) {
                append('.')
                append(fraction.padEnd(6, '0').take(6))
            }
            append(match.groupValues[3])
        }
        if (!validOffset(match.groupValues[3])) return null
        val instant = try {
            OffsetDateTime.parse(normalized, timestampFormatter).toInstant()
        } catch (_: DateTimeException) {
            null
        } ?: return null
        val utcYear = instant.atZone(ZoneOffset.UTC).year
        return if (utcYear in 0..9999) instant else null
    }

    fun parseHistoryTimestamp(raw: String?, legacyZone: ZoneId): Instant? =
        parseTimestamp(raw) ?: parseLegacyLocalTimestamp(raw, legacyZone)

    private fun parseLegacyLocalTimestamp(raw: String?, legacyZone: ZoneId): Instant? {
        if (raw == null) return null
        val match = legacyTimestampPattern.matchEntire(raw) ?: return null
        val fraction = match.groupValues[2]
        val normalized = buildString {
            append(match.groupValues[1])
            if (fraction.isNotEmpty()) {
                append('.')
                append(fraction.padEnd(9, '0').take(9))
            }
        }
        return try {
            val local = LocalDateTime.parse(normalized, legacyFormatter)
            val validOffsets = legacyZone.rules.getValidOffsets(local)
            if (validOffsets.isEmpty()) return null
            val instant = local.atOffset(validOffsets[0]).toInstant()
            val utcYear = instant.atZone(ZoneOffset.UTC).year
            if (utcYear in 0..9999) instant else null
        } catch (_: DateTimeException) {
            null
        }
    }

    fun decodeFlutterStringList(raw: String?): String? {
        if (raw == null || !raw.startsWith(JSON_LIST_PREFIX)) return null
        return raw.removePrefix(JSON_LIST_PREFIX)
    }

    fun <T> merge(
        fileEntries: List<TranscriptionHistoryRecord<T>>,
        preferencesEntries: List<TranscriptionHistoryRecord<T>>,
    ): List<T> = mergeRecords(fileEntries, preferencesEntries).map { it.value }

    fun <T> mergeRecords(
        fileEntries: List<TranscriptionHistoryRecord<T>>,
        preferencesEntries: List<TranscriptionHistoryRecord<T>>,
    ): List<TranscriptionHistoryRecord<T>> = normalizeRecords(
        fileEntries.mapIndexed { index, record ->
            record.copy(
                source = TranscriptionHistorySource.FILE,
                sourceIndex = index,
            )
        } + preferencesEntries.mapIndexed { index, record ->
            record.copy(
                source = TranscriptionHistorySource.PREFERENCES,
                sourceIndex = index,
            )
        },
    )

    fun <T> normalize(records: List<TranscriptionHistoryRecord<T>>): List<T> =
        normalizeRecords(records).map { it.value }

    private fun <T> normalizeRecords(
        records: List<TranscriptionHistoryRecord<T>>,
    ): List<TranscriptionHistoryRecord<T>> {
        val indexed = records.mapIndexed { index, record -> IndexedRecord(index, record) }
        val sorted = indexed.sortedWith(
            compareByDescending<IndexedRecord<T>> {
                it.record.instant.truncatedTo(ChronoUnit.MICROS)
            }
                .thenBy { it.record.source.precedence }
                .thenBy { it.record.sourceIndex }
                .thenBy { it.index },
        )
        val seen = HashSet<String>()
        val out = ArrayList<TranscriptionHistoryRecord<T>>(MAX_ITEMS)
        for (indexedRecord in sorted) {
            val record = indexedRecord.record
            if (isBlankText(record.text)) continue
            val instant = record.instant.truncatedTo(ChronoUnit.MICROS)
            val identity = "${canonicalTimestamp(instant)}|${record.text}"
            if (!seen.add(identity)) continue
            out.add(record)
            if (out.size >= MAX_ITEMS) break
        }
        return out
    }

    fun isBlankText(value: String): Boolean {
        var index = 0
        while (index < value.length) {
            val codePoint = value.codePointAt(index)
            if (!isBlankCodePoint(codePoint)) return false
            index += Character.charCount(codePoint)
        }
        return true
    }

    private fun isBlankCodePoint(codePoint: Int): Boolean = when {
        codePoint in 0x0009..0x000D -> true
        codePoint in 0x001C..0x001F -> true
        codePoint == 0x0020 -> true
        codePoint == 0x0085 -> true
        codePoint == 0x00A0 -> true
        codePoint == 0x1680 -> true
        codePoint in 0x2000..0x200A -> true
        codePoint == 0x2028 -> true
        codePoint == 0x2029 -> true
        codePoint == 0x202F -> true
        codePoint == 0x205F -> true
        codePoint == 0x3000 -> true
        codePoint == 0xFEFF -> true
        else -> false
    }

    private fun validOffset(raw: String): Boolean {
        if (raw == "Z") return true
        val hours = raw.substring(1, 3).toInt()
        val minutes = raw.substring(4, 6).toInt()
        return hours <= 14 && minutes <= 59 && (hours < 14 || minutes == 0)
    }

    fun canonicalTimestamp(instant: Instant): String =
        canonicalFormatter.format(instant.truncatedTo(ChronoUnit.MICROS))

    private data class IndexedRecord<T>(
        val index: Int,
        val record: TranscriptionHistoryRecord<T>,
    )
}
