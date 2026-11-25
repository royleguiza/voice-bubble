package com.royleguiza.voicebubblestt

import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

/** T9 (K6) · Hora del historial: «HH:mm» hoy, «ayer», o «dd/MM». */
class HistoryTimeTest {
    private val zone = ZoneId.of("America/Argentina/Buenos_Aires")
    private val now = ZonedDateTime.of(2026, 11, 25, 22, 30, 0, 0, zone)

    private fun at(y: Int, m: Int, d: Int, h: Int, min: Int): Instant =
        ZonedDateTime.of(y, m, d, h, min, 0, 0, zone).toInstant()

    @Test
    fun today() = assertEquals("22:13", HistoryTime.label(at(2026, 11, 25, 22, 13), now, "ayer"))

    @Test
    fun earlyToday() = assertEquals("00:05", HistoryTime.label(at(2026, 11, 25, 0, 5), now, "ayer"))

    @Test
    fun yesterday() = assertEquals("ayer", HistoryTime.label(at(2026, 11, 24, 23, 59), now, "ayer"))

    @Test
    fun older() = assertEquals("03/11", HistoryTime.label(at(2026, 11, 3, 10, 0), now, "ayer"))
}
