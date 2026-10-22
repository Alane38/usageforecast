package com.alane.usageforecast

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Coffre de l'identifiant et de la clé d'association. Les deux sont chiffrés par une clé AES-GCM du
 * Android Keystore (non exportable : le matériel de la clé ne quitte pas le Keystore) avant d'être
 * écrits dans des préférences privées. Jamais journalisé, jamais placé dans un Intent.
 */
class PairingVault(context: Context) {
    private val preferences = context.getSharedPreferences("association", Context.MODE_PRIVATE)

    fun save(pairing: Pairing): Boolean {
        val plain = pairing.id.toByteArray(Charsets.US_ASCII) + pairing.keyBytes()
        return try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, keystoreKey(createIfMissing = true))
            val sealed = cipher.iv + cipher.doFinal(plain)
            preferences.edit().putString(KEY_SEALED, Base64.encodeToString(sealed, Base64.NO_WRAP)).apply()
            true
        } catch (_: GeneralSecurityException) {
            false
        } finally {
            plain.fill(0)
        }
    }

    /** Null si rien n'est enregistré, ou si le coffre est illisible (clé du Keystore perdue : on ne devine pas). */
    fun load(): Pairing? {
        val text = preferences.getString(KEY_SEALED, null) ?: return null
        return try {
            val sealed = Base64.decode(text, Base64.NO_WRAP)
            if (sealed.size <= IV_BYTES) return null
            val key = keystoreKey(createIfMissing = false) ?: return null
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, sealed, 0, IV_BYTES))
            val plain = cipher.doFinal(sealed, IV_BYTES, sealed.size - IV_BYTES)
            try {
                if (plain.size != ID_BYTES + KEY_BYTES) return null
                Pairing(String(plain, 0, ID_BYTES, Charsets.US_ASCII), plain.copyOfRange(ID_BYTES, plain.size))
            } finally {
                plain.fill(0)
            }
        } catch (_: GeneralSecurityException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    /** Efface le texte chiffré et la clé du Keystore : « oublier » ou changement de relais. */
    fun clear() {
        preferences.edit().remove(KEY_SEALED).apply()
        try {
            KeyStore.getInstance(PROVIDER).apply { load(null) }.deleteEntry(ALIAS)
        } catch (_: GeneralSecurityException) {
            // Rien de plus à faire : le texte chiffré est déjà supprimé.
        }
    }

    private fun keystoreKey(createIfMissing: Boolean): SecretKey? {
        val store = KeyStore.getInstance(PROVIDER).apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        if (!createIfMissing) return null
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, PROVIDER)
        generator.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val PROVIDER = "AndroidKeyStore"
        const val ALIAS = "uf_association"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_SEALED = "scelle"
        const val IV_BYTES = 12
        const val TAG_BITS = 128
        const val ID_BYTES = 32
        const val KEY_BYTES = 32
    }
}
