package com.alane.usageforecast

import java.net.HttpURLConnection
import java.net.URL

/** Interroge GitHub pour la dernière release. À appeler hors du fil principal. */
object UpdateChecker {
    sealed interface Outcome {
        data class Available(val release: ReleaseInfo) : Outcome
        data object UpToDate : Outcome
        data class Failed(val message: String) : Outcome
    }

    fun check(currentVersion: String): Outcome {
        val body = try {
            fetchText(UpdatePolicy.RELEASES_API, maxBytes = 1024 * 1024)
        } catch (error: java.io.IOException) {
            return Outcome.Failed("GitHub est injoignable. Vérifie ta connexion.")
        }
        val release = UpdatePolicy.parseReleases(body) ?: return Outcome.UpToDate
        return if (UpdatePolicy.isNewer(release.version, currentVersion)) Outcome.Available(release) else Outcome.UpToDate
    }

    /** Petit texte en https, taille bornée. */
    fun fetchText(address: String, maxBytes: Int): String {
        val connection = URL(address).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 10_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("Accept", "application/vnd.github+json")
            connection.setRequestProperty("User-Agent", "UsageForecast-Android")
            if (connection.responseCode !in 200..299) throw java.io.IOException("HTTP ${connection.responseCode}")
            val bytes = connection.inputStream.use { it.readNBytes(maxBytes + 1) }
            if (bytes.size > maxBytes) throw java.io.IOException("réponse trop grande")
            return String(bytes, Charsets.UTF_8)
        } finally {
            connection.disconnect()
        }
    }
}
