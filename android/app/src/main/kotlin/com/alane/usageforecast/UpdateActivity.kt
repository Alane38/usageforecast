package com.alane.usageforecast

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.ScrollView
import android.widget.TextView
import java.io.File
import java.util.concurrent.Executors

/** Écran « Mises à jour » : cherche une release, la télécharge, vérifie son empreinte, puis lance l'installation. */
class UpdateActivity : Activity() {
    private val worker = Executors.newSingleThreadExecutor()
    private lateinit var status: TextView
    private lateinit var checkButton: Button
    private lateinit var installButton: Button
    private var found: ReleaseInfo? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val column = Ui.column(this)
        column.addView(Ui.title(this, R.string.maj_titre))
        status = TextView(this).apply {
            setTextColor(Ui.color(context, R.color.texte_discret))
            textSize = 15f
            setPadding(0, Ui.dp(context, 12), 0, Ui.dp(context, 16))
            text = getString(R.string.maj_version, currentVersion())
        }
        column.addView(status)
        checkButton = Ui.button(this, R.string.maj_chercher, primary = true) { search() }
        installButton = Ui.button(this, R.string.maj_installer, primary = true) { start() }.apply { visibility = android.view.View.GONE }
        column.addView(checkButton)
        column.addView(installButton)
        column.addView(Ui.spacing(this, 16))
        column.addView(Ui.button(this, R.string.setup_annuler, primary = false) { finish() })
        setContentView(ScrollView(this).apply {
            fitsSystemWindows = true
            isFillViewport = true
            setBackgroundColor(Ui.color(context, R.color.fond))
            addView(column)
        })
        search()
    }

    override fun onResume() {
        super.onResume()
        InstallStatus.listener = { message -> runOnUiThread { say(message) } }
    }

    override fun onPause() {
        InstallStatus.listener = null
        super.onPause()
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun currentVersion(): String = packageManager.getPackageInfo(packageName, 0).versionName ?: "0.0.0"

    private fun say(message: String) { status.text = message }

    private fun search() {
        checkButton.isEnabled = false
        say(getString(R.string.maj_recherche))
        worker.execute {
            val outcome = UpdateChecker.check(currentVersion())
            runOnUiThread {
                checkButton.isEnabled = true
                when (outcome) {
                    is UpdateChecker.Outcome.Available -> {
                        found = outcome.release
                        say(getString(R.string.maj_disponible, outcome.release.version, currentVersion()))
                        installButton.visibility = android.view.View.VISIBLE
                    }
                    UpdateChecker.Outcome.UpToDate -> say(getString(R.string.maj_a_jour, currentVersion()))
                    is UpdateChecker.Outcome.Failed -> say(outcome.message)
                }
            }
        }
    }

    private fun start() {
        val release = found ?: return
        if (!packageManager.canRequestPackageInstalls()) {
            say(getString(R.string.maj_autoriser))
            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
            return
        }
        installButton.isEnabled = false
        worker.execute {
            try {
                val file: File = UpdateDownloader.download(release, File(cacheDir, "update")) { percent ->
                    runOnUiThread { say(getString(R.string.maj_telechargement, percent)) }
                }
                UpdateInstaller.check(this, file)?.let { throw UpdateDownloader.Rejected(it) }
                runOnUiThread { say(getString(R.string.maj_verifie)) }
                UpdateInstaller.install(this, file)
            } catch (error: java.io.IOException) {
                runOnUiThread { say(error.message ?: getString(R.string.maj_echec)); installButton.isEnabled = true }
            } catch (error: SecurityException) {
                runOnUiThread { say(getString(R.string.maj_echec)); installButton.isEnabled = true }
            }
        }
    }
}
