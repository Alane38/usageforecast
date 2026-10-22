package com.alane.usageforecast

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdatePolicyTest {
    private val base = "https://github.com/Alane38/usageforecast/releases/download/v1.17.0"

    private fun release(tag: String = "v1.17.0", draft: Boolean = false, extra: String = "") = """
        {"tag_name":"$tag","draft":$draft,"prerelease":false,"html_url":"https://github.com/Alane38/usageforecast/releases/tag/$tag",
         "assets":[
           {"name":"UsageForecast-1.17.0-android.apk","browser_download_url":"$base/UsageForecast-1.17.0-android.apk"},
           {"name":"UsageForecast-1.17.0-android.apk.sha256","browser_download_url":"$base/UsageForecast-1.17.0-android.apk.sha256"}$extra]}
    """.trimIndent()

    @Test fun `les versions se comparent par nombre et non par texte`() {
        assertTrue(UpdatePolicy.isNewer("v1.17.0", "1.16.1"))
        assertTrue(UpdatePolicy.isNewer("1.16.10", "1.16.9"))
        assertTrue(UpdatePolicy.isNewer("2.0.0", "1.99.99"))
        assertFalse(UpdatePolicy.isNewer("1.16.1", "1.16.1"))
        assertFalse(UpdatePolicy.isNewer("1.16.0", "1.16.1"))
    }

    @Test fun `une version illisible n'est jamais plus récente`() {
        assertFalse(UpdatePolicy.isNewer("latest", "1.0.0"))
        assertFalse(UpdatePolicy.isNewer("1.2", "1.0.0"))
        assertFalse(UpdatePolicy.isNewer("1.2.x", "1.0.0"))
        assertFalse(UpdatePolicy.isNewer("1.2.3", "dev"))
    }

    @Test fun `seul github com du depot est de confiance en https`() {
        assertTrue(UpdatePolicy.isTrustedDownload("$base/UsageForecast-1.17.0-android.apk"))
        assertFalse(UpdatePolicy.isTrustedDownload("http://github.com/Alane38/usageforecast/releases/download/v1/a.apk"))
        assertFalse(UpdatePolicy.isTrustedDownload("https://github.com/autre/depot/releases/download/v1/a.apk"))
        assertFalse(UpdatePolicy.isTrustedDownload("https://evil.example/Alane38/usageforecast/releases/download/v1/a.apk"))
        assertFalse(UpdatePolicy.isTrustedDownload("https://github.com.evil.example/Alane38/usageforecast/releases/download/v1/a.apk"))
        assertFalse(UpdatePolicy.isTrustedDownload("pas une url"))
    }

    @Test fun `l'empreinte est lue au format shasum`() {
        val hex = "a".repeat(64)
        assertEquals(hex, UpdatePolicy.parseChecksum("$hex  UsageForecast-1.17.0-android.apk\n"))
        assertEquals(hex, UpdatePolicy.parseChecksum(hex.uppercase()))
        assertNull(UpdatePolicy.parseChecksum("trop court"))
        assertNull(UpdatePolicy.parseChecksum("g".repeat(64)))
        assertNull(UpdatePolicy.parseChecksum(""))
    }

    @Test fun `une release complete est reconnue`() {
        val info = UpdatePolicy.parseRelease(release())
        assertNotNull(info)
        assertEquals("1.17.0", info!!.version)
        assertTrue(info.apkUrl.endsWith("UsageForecast-1.17.0-android.apk"))
        assertTrue(info.checksumUrl.endsWith(".apk.sha256"))
    }

    @Test fun `brouillon, sans apk ou sans empreinte, rien n'est propose`() {
        assertNull(UpdatePolicy.parseRelease(release(draft = true)))
        assertNull(UpdatePolicy.parseRelease("""{"tag_name":"v1.17.0","assets":[]}"""))
        assertNull(UpdatePolicy.parseRelease(release().replace(".apk.sha256", ".apk.autre")))
        assertNull(UpdatePolicy.parseRelease("pas du json"))
        assertNull(UpdatePolicy.parseRelease(release(tag = "dev")))
    }

    @Test fun `un asset hors du depot est ignore`() {
        val hostile = release().replace("github.com/Alane38", "evil.example/Alane38")
        assertNull(UpdatePolicy.parseRelease(hostile))
    }
}
