package com.alane.usageforecast

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SnapshotCryptoTest {
    // Vecteur partagé avec mobile/pwa/test/crypto.test.js : clé 0..31, nonce a0..ab.
    private val key = ByteArray(32) { it.toByte() }
    private val blob = "oKGio6SlpqeoqaqrnToUSCmnbZ1YR-q8ZROsu1LR6TTezi9REKnTcKBV7_CgZQ"

    @Test
    fun `le vecteur de la PWA se déchiffre`() {
        assertEquals("""{"hello":"mobile"}""", SnapshotCrypto.decryptText(blob, key))
    }

    @Test
    fun `un blob avec des espaces autour reste lisible`() {
        assertEquals("""{"hello":"mobile"}""", SnapshotCrypto.decryptText("$blob\n", key))
    }

    @Test
    fun `un blob altéré échoue proprement`() {
        val tampered = blob.dropLast(1) + (if (blob.last() == 'A') 'B' else 'A')
        assertNull(SnapshotCrypto.decrypt(tampered, key))
        val flippedMiddle = blob.substring(0, 30) + (if (blob[30] == 'A') 'B' else 'A') + blob.substring(31)
        assertNull(SnapshotCrypto.decrypt(flippedMiddle, key))
    }

    @Test
    fun `une mauvaise clé échoue proprement`() {
        assertNull(SnapshotCrypto.decrypt(blob, ByteArray(32) { 1 }))
    }

    @Test
    fun `les entrées invalides ne lèvent jamais d'exception`() {
        assertNull(SnapshotCrypto.decrypt("", key))
        assertNull(SnapshotCrypto.decrypt("court", key))
        assertNull(SnapshotCrypto.decrypt("pas du base64 !!", key))
        assertNull(SnapshotCrypto.decrypt(blob, ByteArray(16)))
        assertNull(SnapshotCrypto.decrypt(blob, ByteArray(0)))
    }

    @Test
    fun `base64url sans remplissage`() {
        assertArrayEquals(byteArrayOf(-5, -1), SnapshotCrypto.decodeBase64Url("-_8"))
        assertNull(SnapshotCrypto.decodeBase64Url("a+b/"))
    }
}
