package com.alane.usageforecast

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdatePolicyTest {
    private fun base(tag: String) = "https://github.com/Alane38/usageforecast/releases/download/$tag"

    private fun release(tag: String, version: String = tag.removePrefix("android-v").removePrefix("v"), draft: Boolean = false, withApk: Boolean = true) = """
        {"tag_name":"$tag","draft":$draft,"prerelease":false,"html_url":"https://github.com/Alane38/usageforecast/releases/tag/$tag",
         "assets":[${if (withApk) """
           {"name":"UsageForecast-$version-android.apk","browser_download_url":"${base(tag)}/UsageForecast-$version-android.apk"},
           {"name":"UsageForecast-$version-android.apk.sha256","browser_download_url":"${base(tag)}/UsageForecast-$version-android.apk.sha256"}""" else ""}]}
    """.trimIndent()

    private fun list(vararg releases: String) = releases.joinToString(",", "[", "]")

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
        assertTrue(UpdatePolicy.isTrustedDownload("${base("android-v1.19.0")}/UsageForecast-1.19.0-android.apk"))
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

    @Test fun `la plus recente des releases android est retenue`() {
        val info = UpdatePolicy.parseReleases(list(release("android-v1.19.1"), release("android-v1.19.10"), release("android-v1.19.2")))
        assertNotNull(info)
        assertEquals("1.19.10", info!!.version)
        assertTrue(info.apkUrl.endsWith("UsageForecast-1.19.10-android.apk"))
        assertTrue(info.checksumUrl.endsWith(".apk.sha256"))
    }

    @Test fun `les releases de l'application Mac sont ignorees`() {
        // Une release du Mac plus récente ne masque pas l'APK, et un tag du Mac n'est jamais pris pour une version Android.
        val info = UpdatePolicy.parseReleases(list(release("v9.0.0", "9.0.0"), release("android-v1.19.1")))
        assertEquals("1.19.1", info!!.version)
        assertNull(UpdatePolicy.parseReleases(list(release("v1.19.0", "1.19.0"))))
    }

    @Test fun `brouillon, sans apk ou sans empreinte, rien n'est propose`() {
        assertNull(UpdatePolicy.parseReleases(list(release("android-v1.19.1", draft = true))))
        assertNull(UpdatePolicy.parseReleases(list(release("android-v1.19.1", withApk = false))))
        assertNull(UpdatePolicy.parseReleases(list(release("android-v1.19.1").replace(".apk.sha256", ".apk.autre"))))
        assertNull(UpdatePolicy.parseReleases(list(release("android-vdev", "dev"))))
        assertNull(UpdatePolicy.parseReleases("pas du json"))
        assertNull(UpdatePolicy.parseReleases("[]"))
    }

    @Test fun `un asset hors du depot est ignore`() {
        val hostile = release("android-v1.19.1").replace("github.com/Alane38", "evil.example/Alane38")
        assertNull(UpdatePolicy.parseReleases(list(hostile)))
    }
}
