package com.alane.usageforecast

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RelayAddressTest {
    private fun valid(input: String): RelayAddress =
        (RelayAddress.parse(input) as ParseResult.Valid).address

    private fun reason(input: String): Reason =
        (RelayAddress.parse(input) as ParseResult.Invalid).reason

    @Test
    fun `une adresse nue reçoit https et perd chemin et requête`() {
        assertEquals("https://xxx.workers.dev", valid("  XXX.workers.dev/abc?q=1 ").origin)
        assertEquals("https://xxx.workers.dev/", valid("https://xxx.workers.dev").launchUrl())
    }

    @Test
    fun `le port 443 disparait et un autre port est conservé`() {
        assertEquals("https://relais.example.org", valid("https://relais.example.org:443/").origin)
        assertEquals("https://relais.example.org:8443", valid("https://relais.example.org:8443").origin)
    }

    @Test
    fun `le lien d'association garde son fragment pour le premier chargement seulement`() {
        val address = valid("https://xxx.workers.dev/#v1.abc.def_GH-1")
        assertTrue(address.hasPairing)
        assertEquals("https://xxx.workers.dev/#v1.abc.def_GH-1", address.pairingUrl())
        assertEquals("https://xxx.workers.dev/", address.launchUrl())
    }

    @Test
    fun `sans fragment le premier chargement est la page d'accueil`() {
        assertFalse(valid("xxx.workers.dev").hasPairing)
        assertEquals("https://xxx.workers.dev/", valid("xxx.workers.dev#").pairingUrl())
    }

    @Test
    fun `le texte d'affichage ne divulgue jamais le fragment`() {
        val address = valid("https://xxx.workers.dev/#v1.identifiant.cleSecrete")
        assertFalse(address.toString().contains("cleSecrete"))
        assertFalse(address.toString().contains("identifiant"))
    }

    @Test
    fun `les refus ont une raison précise`() {
        assertEquals(Reason.EMPTY, reason("   "))
        assertEquals(Reason.NOT_HTTPS, reason("http://xxx.workers.dev"))
        assertEquals(Reason.NOT_HTTPS, reason("ftp://xxx.workers.dev"))
        assertEquals(Reason.BAD_ADDRESS, reason("https://localhost"))
        assertEquals(Reason.BAD_ADDRESS, reason("https://user@xxx.workers.dev"))
        assertEquals(Reason.BAD_ADDRESS, reason("https://exemple .dev"))
        assertEquals(Reason.BAD_FRAGMENT, reason("https://xxx.workers.dev/#a b"))
    }

    @Test
    fun `seule l'origine exacte du relais est interne`() {
        val relay = "https://xxx.workers.dev"
        assertTrue(RelayAddress.isSameOrigin("https://xxx.workers.dev/stats?x=1#y", relay))
        assertTrue(RelayAddress.isSameOrigin("HTTPS://XXX.workers.dev:443/", relay))
        assertFalse(RelayAddress.isSameOrigin("https://autre.workers.dev/", relay))
        assertFalse(RelayAddress.isSameOrigin("https://xxx.workers.dev.evil.com/", relay))
        assertFalse(RelayAddress.isSameOrigin("https://evil.com/@xxx.workers.dev", relay))
        assertFalse(RelayAddress.isSameOrigin("https://xxx.workers.dev:8443/", relay))
        assertFalse(RelayAddress.isSameOrigin("http://xxx.workers.dev/", relay))
        assertFalse(RelayAddress.isSameOrigin("intent://xxx.workers.dev/", relay))
        assertFalse(RelayAddress.isSameOrigin("javascript:alert(1)", relay))
    }

    @Test
    fun `une URL non https n'a pas d'origine`() {
        assertNull(RelayAddress.originOf("mailto:a@b.c"))
        assertNull(RelayAddress.originOf("http://xxx.workers.dev"))
    }
}
