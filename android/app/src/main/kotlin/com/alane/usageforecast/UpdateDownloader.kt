package com.alane.usageforecast

import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/** Télécharge l'APK et vérifie son empreinte SHA-256 avant toute installation. Hors du fil principal. */
object UpdateDownloader {
    class Rejected(message: String) : IOException(message)

    /** Retourne le fichier vérifié ; lève [Rejected] si l'empreinte ne correspond pas ou si la taille est anormale. */
    fun download(release: ReleaseInfo, directory: File, onProgress: (Int) -> Unit): File {
        val expected = UpdatePolicy.parseChecksum(UpdateChecker.fetchText(release.checksumUrl, maxBytes = 1024))
            ?: throw Rejected("Le fichier d'empreinte est illisible : mise à jour refusée.")
        directory.mkdirs()
        directory.listFiles()?.forEach { it.delete() }
        val target = File(directory, "UsageForecast-${release.version}-android.apk")

        val connection = URL(release.apkUrl).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.setRequestProperty("User-Agent", "UsageForecast-Android")
            if (connection.responseCode !in 200..299) throw IOException("Téléchargement refusé (HTTP ${connection.responseCode}).")
            val digest = MessageDigest.getInstance("SHA-256")
            val total = connection.contentLengthLong
            var received = 0L
            connection.inputStream.use { input ->
                target.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        received += count
                        if (received > UpdatePolicy.MAX_APK_BYTES) throw Rejected("Taille de téléchargement inattendue.")
                        digest.update(buffer, 0, count)
                        output.write(buffer, 0, count)
                        if (total > 0) onProgress((received * 100 / total).toInt())
                    }
                }
            }
            val actual = digest.digest().joinToString("") { "%02x".format(it) }
            if (actual != expected) {
                target.delete()
                throw Rejected("L'empreinte SHA-256 ne correspond pas : fichier corrompu ou modifié, mise à jour refusée.")
            }
            return target
        } finally {
            connection.disconnect()
        }
    }
}
