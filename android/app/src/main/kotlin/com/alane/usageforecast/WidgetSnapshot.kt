package com.alane.usageforecast

import java.time.Instant
import java.time.format.DateTimeParseException
import org.json.JSONException
import org.json.JSONObject

enum class Pace { UNDER, ON_TRACK, OVER }

data class GaugeData(val percent: Double, val resetsAt: Instant?, val pace: Pace?)

data class DayBudget(val allowed: Double, val used: Double)

/** Le strict nécessaire du snapshot de la PWA pour le widget. */
data class WidgetSnapshot(
    val session: GaugeData?,
    val weekly: GaugeData?,
    val dataAt: Instant?,
    val dayBudget: DayBudget?,
) {
    companion object {
        private const val SUPPORTED_VERSION = 1

        /** Null si le JSON est invalide, d'une autre version, ou sans aucune jauge exploitable. */
        fun decode(json: String): WidgetSnapshot? {
            val root = try {
                JSONObject(json)
            } catch (_: JSONException) {
                return null
            }
            if (root.optInt("version", -1) != SUPPORTED_VERSION) return null
            val forecast = root.optJSONObject("forecast") ?: return null
            val session = gaugeOf(forecast.optJSONObject("session"))
            val weekly = gaugeOf(forecast.optJSONObject("weekly"))
            if (session == null && weekly == null) return null
            // Comme la PWA : sans dataAt, l'heure d'envoi sert de repli.
            val dataAt = instantOf(root.optString("dataAt")) ?: instantOf(root.optString("updatedAt"))
            return WidgetSnapshot(session, weekly, dataAt, budgetOf(root.optJSONObject("dayBudget")))
        }

        private fun gaugeOf(raw: JSONObject?): GaugeData? {
            val percent = raw?.optDouble("percent", Double.NaN) ?: return null
            if (!percent.isFinite()) return null
            val pace = when (raw.optString("pace")) {
                "under" -> Pace.UNDER
                "onTrack" -> Pace.ON_TRACK
                "over" -> Pace.OVER
                else -> null
            }
            return GaugeData(percent, instantOf(raw.optString("resetsAt")), pace)
        }

        private fun budgetOf(raw: JSONObject?): DayBudget? {
            val allowed = raw?.optDouble("allowed", Double.NaN) ?: return null
            val used = raw.optDouble("used", Double.NaN)
            return if (allowed.isFinite() && used.isFinite()) DayBudget(allowed, used) else null
        }

        private fun instantOf(text: String): Instant? = try {
            if (text.isEmpty()) null else Instant.parse(text)
        } catch (_: DateTimeParseException) {
            null
        }
    }
}
