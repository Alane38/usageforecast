package com.alane.usageforecast

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class WidgetSnapshotTest {
    // Même forme que rawSnapshot() de mobile/pwa/test/helpers.js (champs inutiles au widget compris).
    private val sample = """{
      "version": 1, "updatedAt": "2026-10-19T10:00:00Z", "dataAt": "2026-10-19T09:58:00Z",
      "appVersion": "1.13.0", "source": "claude.ai",
      "forecast": {
        "version": 1, "updatedAt": "2026-10-19T10:00:00Z",
        "session": {"percent": 25, "resetsAt": "2026-10-19T12:30:00Z", "projectedPercent": 77, "pace": "under", "ratePerHour": 8.2},
        "weekly": {"percent": 54.4, "resetsAt": "2026-10-21T10:00:00Z", "pace": "onTrack", "perDayPercent": 25},
        "usedTodayPercent": 17, "line": "Prévision"
      },
      "dayBudget": {"allowed": 24, "used": 17, "level": "ok"},
      "models": [{"name": "Sonnet", "percent": 12}]
    }"""

    @Test
    fun `un snapshot d'exemple se décode`() {
        val snapshot = WidgetSnapshot.decode(sample)!!
        assertEquals(25.0, snapshot.session!!.percent, 0.0)
        assertEquals(Pace.UNDER, snapshot.session!!.pace)
        assertEquals(Instant.parse("2026-10-19T12:30:00Z"), snapshot.session!!.resetsAt)
        assertEquals(54.4, snapshot.weekly!!.percent, 0.0)
        assertEquals(Pace.ON_TRACK, snapshot.weekly!!.pace)
        assertEquals(Instant.parse("2026-10-19T09:58:00Z"), snapshot.dataAt)
        assertEquals(DayBudget(24.0, 17.0), snapshot.dayBudget)
    }

    @Test
    fun `dataAt absent retombe sur updatedAt`() {
        val snapshot = WidgetSnapshot.decode(sample.replace("\"dataAt\": \"2026-10-19T09:58:00Z\",", ""))!!
        assertEquals(Instant.parse("2026-10-19T10:00:00Z"), snapshot.dataAt)
    }

    @Test
    fun `une jauge manquante ou invalide est ignorée sans tout refuser`() {
        val snapshot = WidgetSnapshot.decode(sample.replace("\"percent\": 25", "\"percent\": \"x\""))!!
        assertNull(snapshot.session)
        assertNotNull(snapshot.weekly)
    }

    @Test
    fun `un rythme inconnu devient null`() {
        val snapshot = WidgetSnapshot.decode(sample.replace("\"under\"", "\"bizarre\""))!!
        assertNull(snapshot.session!!.pace)
    }

    @Test
    fun `les JSON invalides ou d'une autre version sont refusés`() {
        assertNull(WidgetSnapshot.decode("pas du json"))
        assertNull(WidgetSnapshot.decode("{}"))
        assertNull(WidgetSnapshot.decode(sample.replace("\"version\": 1, \"updatedAt\"", "\"version\": 2, \"updatedAt\"")))
        assertNull(WidgetSnapshot.decode("""{"version":1,"forecast":{}}"""))
    }
}
