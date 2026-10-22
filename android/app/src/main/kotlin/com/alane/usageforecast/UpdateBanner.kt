package com.alane.usageforecast

import android.app.Activity
import android.content.Intent
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.TextView
import java.util.concurrent.Executors

/** Bandeau discret en bas de l'écran quand une nouvelle version existe. Une recherche à chaque ouverture (au plus toutes les 15 minutes), hors du fil principal. */
class UpdateBanner(private val activity: Activity, private val parent: FrameLayout) {
    private val preferences = activity.getSharedPreferences("maj", Activity.MODE_PRIVATE)
    private val banner = TextView(activity).apply {
        visibility = android.view.View.GONE
        setTextColor(Ui.color(context, R.color.texte))
        setBackgroundColor(0xFF2A2A2E.toInt())
        textSize = 14f
        gravity = Gravity.CENTER
        val pad = Ui.dp(context, 14)
        setPadding(pad, pad, pad, pad)
        setOnClickListener { activity.startActivity(Intent(activity, UpdateActivity::class.java)) }
    }

    init {
        parent.addView(banner, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM))
    }

    fun checkIfDue(now: Long = System.currentTimeMillis()) {
        if (now - preferences.getLong(LAST_CHECK, 0) < MIN_GAP_MS) return
        val installed = runCatching { activity.packageManager.getPackageInfo(activity.packageName, 0).versionName }.getOrNull() ?: return
        Executors.newSingleThreadExecutor().execute {
            val outcome = UpdateChecker.check(installed)
            if (outcome !is UpdateChecker.Outcome.Failed) preferences.edit().putLong(LAST_CHECK, now).apply()
            if (outcome is UpdateChecker.Outcome.Available) activity.runOnUiThread {
                banner.text = activity.getString(R.string.maj_bandeau, outcome.release.version)
                banner.visibility = android.view.View.VISIBLE
            }
        }
    }

    fun hide() { banner.visibility = android.view.View.GONE }

    private companion object {
        const val LAST_CHECK = "derniere_recherche"
        const val MIN_GAP_MS = 15L * 60 * 1000
    }
}
