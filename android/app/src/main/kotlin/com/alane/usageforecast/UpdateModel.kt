package com.alane.usageforecast

import org.json.JSONObject

/** Une release GitHub exploitable : l'APK, son fichier d'empreinte et la page de la version. */
data class ReleaseInfo(val version: String, val apkUrl: String, val checksumUrl: String, val pageUrl: String)

/**
 * Règles de la mise à jour intégrée. Logique pure, sans Android : testable seule.
 * Un téléchargement n'est accepté que depuis les releases de ce dépôt, en https ; Android refuse ensuite toute
 * mise à jour dont la signature diffère de l'application installée, ce qui est la garantie finale.
 */
object UpdatePolicy {
    const val RELEASES_API = "https://api.github.com/repos/Alane38/usageforecast/releases/latest"
    private const val TRUSTED_HOST = "github.com"
    private const val TRUSTED_PATH = "/Alane38/usageforecast/releases/download/"
    const val MAX_APK_BYTES = 60L * 1024 * 1024

    /** « v1.16.1 » ou « 1.16.1 » -> [1, 16, 1] ; null si le texte n'est pas une version. */
    fun parseVersion(text: String): List<Int>? {
        val parts = text.trim().removePrefix("v").split(".")
        if (parts.size != 3) return null
        val numbers = parts.map { it.toIntOrNull() ?: return null }
        return if (numbers.any { it < 0 }) null else numbers
    }

    fun isNewer(candidate: String, current: String): Boolean {
        val next = parseVersion(candidate) ?: return false
        val installed = parseVersion(current) ?: return false
        for (index in next.indices) {
            if (next[index] != installed[index]) return next[index] > installed[index]
        }
        return false
    }

    fun isTrustedDownload(url: String): Boolean {
        val uri = runCatching { java.net.URI(url) }.getOrNull() ?: return false
        return uri.scheme == "https" && uri.host == TRUSTED_HOST && uri.rawPath?.startsWith(TRUSTED_PATH) == true
    }

    /** Somme SHA-256 au format de `shasum -a 256` (« <64 hex>  fichier ») ; null si la ligne n'en contient pas. */
    fun parseChecksum(text: String): String? {
        val token = text.trim().split(Regex("\\s+")).firstOrNull()?.lowercase() ?: return null
        return if (token.length == 64 && token.all { it in '0'..'9' || it in 'a'..'f' }) token else null
    }

    /** Lit la réponse de `releases/latest` ; null pour un brouillon, une préversion ou une release sans APK vérifiable. */
    fun parseRelease(json: String): ReleaseInfo? {
        val root = runCatching { JSONObject(json) }.getOrNull() ?: return null
        if (root.optBoolean("draft") || root.optBoolean("prerelease")) return null
        val tag = root.optString("tag_name")
        val version = parseVersion(tag)?.joinToString(".") ?: return null
        val assets = root.optJSONArray("assets") ?: return null
        val urls = (0 until assets.length()).mapNotNull { index ->
            val asset = assets.optJSONObject(index) ?: return@mapNotNull null
            asset.optString("name") to asset.optString("browser_download_url")
        }.filter { isTrustedDownload(it.second) }.toMap()
        val apkName = "UsageForecast-$version-android.apk"
        val apk = urls[apkName] ?: return null
        val checksum = urls["$apkName.sha256"] ?: return null
        val page = root.optString("html_url").takeIf { it.startsWith("https://github.com/") } ?: ""
        return ReleaseInfo(version, apk, checksum, page)
    }
}
