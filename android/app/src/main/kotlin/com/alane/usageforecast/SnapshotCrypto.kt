package com.alane.usageforecast

import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Déchiffrement des snapshots du relais, compatible avec la PWA (`mobile/pwa/lib/crypto.js`) :
 * blob = base64url( nonce 12 octets | texte chiffré | étiquette GCM 16 octets ), AES-256-GCM.
 * Logique pure : retourne null au moindre problème, sans distinguer les causes (comme la PWA).
 */
object SnapshotCrypto {
    private const val NONCE_BYTES = 12
    private const val TAG_BITS = 128
    private const val KEY_BYTES = 32
    private val base64urlPattern = Regex("^[A-Za-z0-9_-]*$")

    /** Décode du base64url sans remplissage, ou null si le texte contient autre chose. */
    fun decodeBase64Url(text: String): ByteArray? {
        if (!base64urlPattern.matches(text)) return null
        return try {
            Base64.getUrlDecoder().decode(text)
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    fun decrypt(blob: String, key: ByteArray): ByteArray? {
        if (key.size != KEY_BYTES) return null
        val combined = decodeBase64Url(blob.trim()) ?: return null
        if (combined.size < NONCE_BYTES + TAG_BITS / 8) return null
        return try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                SecretKeySpec(key, "AES"),
                GCMParameterSpec(TAG_BITS, combined, 0, NONCE_BYTES),
            )
            cipher.doFinal(combined, NONCE_BYTES, combined.size - NONCE_BYTES)
        } catch (_: java.security.GeneralSecurityException) {
            null
        }
    }

    fun decryptText(blob: String, key: ByteArray): String? =
        decrypt(blob, key)?.toString(Charsets.UTF_8)
}
