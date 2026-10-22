package com.alane.usageforecast

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import android.webkit.CookieManager
import android.webkit.WebSettings
import android.webkit.WebView
import android.widget.FrameLayout

/** Coque plein écran qui charge la PWA servie par le relais de l'utilisateur. */
class MainActivity : Activity() {
    private var webView: WebView? = null
    private lateinit var errorPanel: NetworkErrorPanel
    private var relayOrigin: String = ""
    private var updateBanner: UpdateBanner? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val origin = RelayStore(this).load()
        if (origin == null) {
            openSettings()
            finish()
            return
        }
        relayOrigin = origin
        WidgetScheduler.ensureScheduled(this)

        val root = FrameLayout(this).apply {
            fitsSystemWindows = true
            setBackgroundColor(Ui.color(context, R.color.fond))
        }
        val view = createWebView()
        errorPanel = NetworkErrorPanel(this, onRetry = { loadStart() }, onChangeAddress = { openSettings() })
        root.addView(view)
        root.addView(errorPanel)
        setContentView(root)
        webView = view
        updateBanner = UpdateBanner(this, root).also { it.checkDaily() }

        // Le lien d'association (avec la clé) n'est chargé qu'une fois ; ensuite, la PWA a sa clé en stockage.
        view.loadUrl(PendingPairing.take() ?: "$relayOrigin/")
    }

    private fun createWebView(): WebView = WebView(this).apply {
        setBackgroundColor(Ui.color(context, R.color.fond))
        with(settings) {
            javaScriptEnabled = true
            domStorageEnabled = true // localStorage et IndexedDB, indispensables à la PWA et à son service worker
            allowFileAccess = false
            allowContentAccess = false
            @Suppress("DEPRECATION")
            saveFormData = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            cacheMode = WebSettings.LOAD_DEFAULT
        }
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, false)
        webViewClient = ShellWebViewClient(
            relayOrigin = relayOrigin,
            onMainFrameError = { errorPanel.show(true) },
            onPageOk = { errorPanel.show(false) },
            onRendererGone = { recreate() },
        )
    }

    private fun loadStart() {
        errorPanel.show(false)
        webView?.loadUrl("$relayOrigin/")
    }

    private fun openSettings() {
        startActivity(Intent(this, SetupActivity::class.java))
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            event.startTracking()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    /** Appui long sur Retour : réglage de l'adresse (l'icône d'application en offre aussi un raccourci). */
    override fun onKeyLongPress(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            openSettings()
            return true
        }
        return super.onKeyLongPress(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK && !event.isCanceled) {
            val view = webView
            if (view != null && view.canGoBack()) view.goBack() else finish()
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    override fun onResume() {
        super.onResume()
        updateBanner?.hide()
        webView?.onResume()
    }

    override fun onPause() {
        webView?.onPause()
        CookieManager.getInstance().flush()
        super.onPause()
    }

    override fun onDestroy() {
        webView?.destroy()
        webView = null
        super.onDestroy()
    }
}
