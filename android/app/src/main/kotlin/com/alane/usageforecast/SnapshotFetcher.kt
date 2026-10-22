package com.alane.usageforecast

import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

sealed interface FetchResult {
    /** Nouveau blob chiffré, avec l'horodatage `x-updated-at` du relais. */
    data class Fresh(val blob: String, val stamp: String) : FetchResult
    data object Unchanged : FetchResult
    /** Coffre encore vide : le Mac n'a rien envoyé. */
    data object Empty : FetchResult
    data object Failure : FetchResult
}

/** Un seul GET par rafraîchissement : le téléphone ne fait jamais d'écriture sur le relais. */
object SnapshotFetcher {
    const val MAX_BYTES = 256 * 1024
    private const val TIMEOUT_MS = 8_000

    fun fetch(origin: String, id: String, previousStamp: String?): FetchResult {
        if (!origin.startsWith("https://")) return FetchResult.Failure
        val connection = try {
            URL("$origin/v1/$id").openConnection() as HttpURLConnection
        } catch (_: IOException) {
            return FetchResult.Failure
        }
        return try {
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS
            // Une redirection pourrait sortir du https ou de l'origine du relais.
            connection.instanceFollowRedirects = false
            connection.useCaches = false
            when (connection.responseCode) {
                404 -> FetchResult.Empty
                200 -> readBody(connection, previousStamp)
                else -> FetchResult.Failure
            }
        } catch (_: IOException) {
            FetchResult.Failure
        } finally {
            connection.disconnect()
        }
    }

    private fun readBody(connection: HttpURLConnection, previousStamp: String?): FetchResult {
        val stamp = connection.getHeaderField("x-updated-at").orEmpty()
        // Pas de lecture du corps si rien n'a changé depuis le dernier traitement.
        if (stamp.isNotEmpty() && stamp == previousStamp) return FetchResult.Unchanged
        val bytes = readLimited(connection.inputStream, MAX_BYTES) ?: return FetchResult.Failure
        return FetchResult.Fresh(bytes.toString(Charsets.US_ASCII), stamp)
    }

    /** Lit au plus [max] octets ; null si le flux est plus long (réponse anormale du relais). */
    fun readLimited(stream: InputStream, max: Int): ByteArray? {
        val buffer = java.io.ByteArrayOutputStream()
        val chunk = ByteArray(8192)
        while (true) {
            val count = stream.read(chunk)
            if (count < 0) break
            if (buffer.size() + count > max) return null
            buffer.write(chunk, 0, count)
        }
        return buffer.toByteArray()
    }
}
