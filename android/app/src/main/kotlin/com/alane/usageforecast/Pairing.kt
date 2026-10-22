package com.alane.usageforecast

/**
 * Identifiant du coffre et clé AES-256 d'un lien d'association (`v1.<id>.<clé>`).
 * Ni toString ni equals n'exposent la clé : un journal ou un message d'erreur ne peut pas la divulguer.
 */
class Pairing(val id: String, internal val key: ByteArray) {
    fun keyBytes(): ByteArray = key.copyOf()

    override fun toString(): String = "Pairing(***)"

    companion object {
        private val idPattern = Regex("^[0-9a-f]{32}$")

        /** Accepte l'URL complète, le fragment avec ou sans « # ». Null si invalide (même règle que la PWA). */
        fun parse(input: String): Pairing? {
            val fragment = if (input.contains('#')) input.substringAfter('#') else input.trim()
            val parts = fragment.trim().split('.')
            if (parts.size != 3 || parts[0] != "v1" || !idPattern.matches(parts[1])) return null
            val key = SnapshotCrypto.decodeBase64Url(parts[2]) ?: return null
            return if (key.size == 32) Pairing(parts[1], key) else null
        }
    }
}
