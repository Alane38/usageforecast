package com.alane.usageforecast

import android.app.Activity
import android.content.Intent
import android.webkit.JavascriptInterface

/**
 * Passerelle minimale entre la PWA et la coque : sans bouton Retour (navigation par gestes), l'appui long sur Retour
 * est inaccessible, la PWA propose donc elle-même l'accès aux écrans natifs. N'expose que l'ouverture de ces deux
 * écrans et le numéro de version : aucune donnée, aucune clé. La WebView ne charge que l'origine du relais.
 */
class NativeBridge(private val activity: Activity) {
    @JavascriptInterface
    fun openSettings() = open(SetupActivity::class.java)

    @JavascriptInterface
    fun openUpdates() = open(UpdateActivity::class.java)

    @JavascriptInterface
    fun version(): String =
        runCatching { activity.packageManager.getPackageInfo(activity.packageName, 0).versionName }.getOrNull() ?: ""

    private fun open(target: Class<out Activity>) {
        activity.runOnUiThread { activity.startActivity(Intent(activity, target)) }
    }
}
