package com.alane.usageforecast

import java.time.Duration
import java.time.Instant
import kotlin.math.roundToInt

enum class Tone { OK, WARNING, DANGER, STALE }

/** Mises en forme pures du widget (règles de la PWA : `mobile/pwa/lib/format.js`). */
object WidgetFormat {
    val staleAfter: Duration = Duration.ofMinutes(10)

    /** Un danger ou un avertissement garde sa couleur même sur une donnée ancienne ; seul « tout va bien » est grisé. */
    fun tone(percent: Double, pace: Pace?, stale: Boolean): Tone = when {
        percent >= 90 -> Tone.DANGER
        percent >= 70 || pace == Pace.OVER -> Tone.WARNING
        stale -> Tone.STALE
        else -> Tone.OK
    }

    /** « 25 min », « 1 h 40 », « 38 h », « 3 j 4 h » : en jours seulement à partir de 48 h. */
    fun duration(span: Duration): String {
        val totalMinutes = maxOf(span.toMinutes(), 0)
        val days = totalMinutes / 1440
        val hours = totalMinutes % 1440 / 60
        val minutes = totalMinutes % 60
        return when {
            totalMinutes >= 48 * 60 -> if (hours > 0) "$days j $hours h" else "$days j"
            totalMinutes >= 600 -> "${totalMinutes / 60} h"
            hours > 0 -> if (minutes > 0) "$hours h ${minutes.toString().padStart(2, '0')}" else "$hours h"
            else -> "$minutes min"
        }
    }

    /** Délai avant le reset, ou null s'il est déjà passé (la donnée n'a pas encore été rafraîchie). */
    fun untilReset(resetsAt: Instant?, now: Instant): String? {
        if (resetsAt == null || !resetsAt.isAfter(now)) return null
        return duration(Duration.between(now, resetsAt))
    }

    /** Âge de la donnée ; null (inconnu) est traité comme ancien par l'appelant. */
    fun age(dataAt: Instant?, now: Instant): Duration? =
        dataAt?.let { Duration.between(it, now).let { span -> if (span.isNegative) Duration.ZERO else span } }

    fun isStale(age: Duration?): Boolean = age == null || age > staleAfter

    fun percentText(percent: Double): String = "${percent.roundToInt()} %"

    fun progress(percent: Double): Int = percent.roundToInt().coerceIn(0, 100)
}
