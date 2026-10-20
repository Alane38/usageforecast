package com.alane.usageforecast

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient

/** Garde la PWA sur l'origine du relais ; tout le reste part dans le navigateur. */
class ShellWebViewClient(
    private val relayOrigin: String,
    private val onMainFrameError: () -> Unit,
    private val onPageOk: () -> Unit,
    private val onRendererGone: () -> Unit,
) : WebViewClient() {

    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
        val target = request.url
        if (RelayAddress.isSameOrigin(target.toString(), relayOrigin)) return false
        openInBrowser(view, target)
        return true
    }

    private fun openInBrowser(view: WebView, target: Uri) {
        // Seuls http(s) sortent : un schéma intent:, file: ou javascript: ne doit pas déclencher d'autre application.
        if (target.scheme != "https" && target.scheme != "http") return
        try {
            view.context.startActivity(Intent(Intent.ACTION_VIEW, target).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: ActivityNotFoundException) {
            // Aucun navigateur : on reste sur la page plutôt que de planter.
        }
    }

    override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
        if (request.isForMainFrame) onMainFrameError()
    }

    override fun onPageFinished(view: WebView, url: String) {
        onPageOk()
    }

    override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
        onRendererGone()
        return true
    }
}
