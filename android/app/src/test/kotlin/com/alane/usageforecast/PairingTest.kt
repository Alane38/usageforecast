package com.alane.usageforecast

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class PairingTest {
    private val id = "0123456789abcdef0123456789abcdef"
    private val keyText = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8" // octets 0..31, clé de test publique (gitleaks:allow)

    @Test
    fun `un lien complet, un fragment ou le texte seul sont acceptés`() {
        for (input in listOf("https://x.workers.dev/#v1.$id.$keyText", "#v1.$id.$keyText", "v1.$id.$keyText")) {
            val pairing = Pairing.parse(input)
            assertNotNull(input, pairing)
            assertEquals(id, pairing!!.id)
            assertArrayEquals(ByteArray(32) { it.toByte() }, pairing.keyBytes())
        }
    }

    @Test
    fun `les liens invalides sont refusés`() {
        assertNull(Pairing.parse("https://x.workers.dev/"))
        assertNull(Pairing.parse("v2.$id.$keyText"))
        assertNull(Pairing.parse("v1.${id.uppercase()}.$keyText"))
        assertNull(Pairing.parse("v1.$id.AAEC"))
        assertNull(Pairing.parse("v1.$id.$keyText.extra"))
    }

    @Test
    fun `la clé n'apparaît jamais dans toString`() {
        val pairing = Pairing.parse("v1.$id.$keyText")!!
        assertFalse(pairing.toString().contains(keyText))
        assertFalse(pairing.toString().contains(id))
    }

    @Test
    fun `l'adresse relaie le lien sans exposer la clé`() {
        val address = (RelayAddress.parse("https://x.workers.dev/#v1.$id.$keyText") as ParseResult.Valid).address
        assertEquals(id, address.pairing()?.id)
        assertFalse(address.toString().contains(keyText))
        val bare = (RelayAddress.parse("https://x.workers.dev") as ParseResult.Valid).address
        assertNull(bare.pairing())
    }
}
