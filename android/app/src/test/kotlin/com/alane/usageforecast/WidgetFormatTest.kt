package com.alane.usageforecast

import java.io.ByteArrayInputStream
import java.time.Duration
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetFormatTest {
    private val now = Instant.parse("2026-10-19T10:00:00Z")

    @Test
    fun `la couleur suit les règles de la PWA`() {
        assertEquals(Tone.OK, WidgetFormat.tone(25.0, Pace.UNDER, stale = false))
        assertEquals(Tone.WARNING, WidgetFormat.tone(25.0, Pace.OVER, stale = false))
        assertEquals(Tone.WARNING, WidgetFormat.tone(70.0, Pace.UNDER, stale = false))
        assertEquals(Tone.DANGER, WidgetFormat.tone(90.0, null, stale = false))
        assertEquals(Tone.STALE, WidgetFormat.tone(25.0, Pace.UNDER, stale = true))
        assertEquals(Tone.DANGER, WidgetFormat.tone(95.0, Pace.UNDER, stale = true))
    }

    @Test
    fun `les durées`() {
        assertEquals("25 min", WidgetFormat.duration(Duration.ofMinutes(25)))
        assertEquals("1 h 40", WidgetFormat.duration(Duration.ofMinutes(100)))
        assertEquals("2 h", WidgetFormat.duration(Duration.ofMinutes(120)))
        assertEquals("38 h", WidgetFormat.duration(Duration.ofHours(38)))
        assertEquals("3 j 4 h", WidgetFormat.duration(Duration.ofHours(76)))
        assertEquals("2 j", WidgetFormat.duration(Duration.ofHours(48)))
    }

    @Test
    fun `le reset passé ou inconnu n'a pas de délai`() {
        assertEquals("2 h 30", WidgetFormat.untilReset(Instant.parse("2026-10-19T12:30:00Z"), now))
        assertNull(WidgetFormat.untilReset(Instant.parse("2026-10-19T09:00:00Z"), now))
        assertNull(WidgetFormat.untilReset(null, now))
    }

    @Test
    fun `la donnée est ancienne au-delà de 10 minutes ou si l'âge est inconnu`() {
        assertFalse(WidgetFormat.isStale(WidgetFormat.age(now.minusSeconds(600), now)))
        assertTrue(WidgetFormat.isStale(WidgetFormat.age(now.minusSeconds(601), now)))
        assertTrue(WidgetFormat.isStale(WidgetFormat.age(null, now)))
        assertEquals(Duration.ZERO, WidgetFormat.age(now.plusSeconds(60), now))
    }

    @Test
    fun `la lecture est bornée`() {
        assertEquals(10, SnapshotFetcher.readLimited(ByteArrayInputStream(ByteArray(10)), 10)!!.size)
        assertNull(SnapshotFetcher.readLimited(ByteArrayInputStream(ByteArray(11)), 10))
    }
}
