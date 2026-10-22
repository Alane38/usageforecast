package com.alane.usageforecast

import java.net.URI
import java.net.URISyntaxException

/** Résultat de l'analyse d'une saisie : une adresse exploitable, ou la raison du refus. */
sealed interface ParseResult {
    data class Valid(val address: RelayAddress) : ParseResult
    data class Invalid(val reason: Reason) : ParseResult
}

enum class Reason { EMPTY, NOT_HTTPS, BAD_ADDRESS, BAD_FRAGMENT }

/**
 * Adresse du relais, ramenée à son origine https. Logique pure, sans Android : testable seule.
 *
 * Le fragment d'un lien d'association (`#v1.<id>.<clé>`) contient la clé de déchiffrement. Il n'est
 * conservé que pour le premier chargement ; [toString] ne l'affiche jamais, pour qu'un journal
 * ou un message d'erreur ne puisse pas le divulguer.
 */
class RelayAddress private constructor(
    val origin: String,
    private val pairingFragment: String?,
) {
    val hasPairing: Boolean get() = pairingFragment != null

    /** Identifiant et clé du lien d'association, ou null (adresse seule, ou fragment qui n'en est pas un). */
    fun pairing(): Pairing? = pairingFragment?.let { Pairing.parse(it) }

    /** Page de démarrage ordinaire : la PWA relit sa clé dans son propre stockage. */
    fun launchUrl(): String = "$origin/"

    /** Premier chargement après saisie : porte le fragment, qu'un navigateur n'envoie jamais au serveur. */
    fun pairingUrl(): String = if (pairingFragment == null) launchUrl() else "$origin/#$pairingFragment"

    override fun toString(): String = "RelayAddress($origin)"

    companion object {
        private val fragmentPattern = Regex("^[\\x21-\\x7E]+$")

        fun parse(input: String): ParseResult {
            val text = input.trim()
            if (text.isEmpty()) return ParseResult.Invalid(Reason.EMPTY)

            val withScheme = if (text.contains("://")) text else "https://$text"
            if (!withScheme.startsWith("https://", ignoreCase = true)) {
                return ParseResult.Invalid(Reason.NOT_HTTPS)
            }

            val hashIndex = withScheme.indexOf('#')
            val base = if (hashIndex < 0) withScheme else withScheme.substring(0, hashIndex)
            val fragment = if (hashIndex < 0) "" else withScheme.substring(hashIndex + 1)
            if (fragment.isNotEmpty() && !fragmentPattern.matches(fragment)) {
                return ParseResult.Invalid(Reason.BAD_FRAGMENT)
            }

            val origin = originOf(base) ?: return ParseResult.Invalid(Reason.BAD_ADDRESS)
            return ParseResult.Valid(RelayAddress(origin, fragment.ifEmpty { null }))
        }

        /** Origine (`https://hôte[:port]`) d'une URL, ou null si elle n'est pas une URL https sans identifiants. */
        fun originOf(url: String): String? {
            val uri = try {
                URI(url.substringBefore('#'))
            } catch (_: URISyntaxException) {
                return null
            }
            val host = uri.host?.lowercase() ?: return null
            if (!uri.scheme.equals("https", ignoreCase = true)) return null
            if (uri.userInfo != null || !host.contains('.')) return null
            val port = if (uri.port == -1 || uri.port == 443) "" else ":${uri.port}"
            return "https://$host$port"
        }

        /** Vrai si [url] appartient exactement à l'origine du relais : le reste s'ouvre dans le navigateur. */
        fun isSameOrigin(url: String, relayOrigin: String): Boolean = originOf(url) == relayOrigin
    }
}
