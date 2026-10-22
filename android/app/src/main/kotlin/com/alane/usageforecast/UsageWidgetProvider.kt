package com.alane.usageforecast

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

class UsageWidgetProvider : AppWidgetProvider() {
    /**
     * Appelé à l'ajout, au redémarrage, après la mise à jour de l'application et toutes les 30 minutes par le système : un second
     * déclencheur, indépendant du JobScheduler (que certaines surcouches de batterie suspendent, et qu'une mise à jour d'APK efface).
     */
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        WidgetRenderer.updateAll(context)
        WidgetScheduler.ensureScheduled(context)
        refreshNow(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) refreshNow(context)
    }

    /** Récupération immédiate, hors du fil principal, avec le délai d'un récepteur de diffusion (goAsync). */
    private fun refreshNow(context: Context) {
        WidgetRenderer.markRefreshing(context)
        val pending = goAsync()
        WidgetRefresher.runAsync(context) { pending.finish() }
    }

    companion object {
        const val ACTION_REFRESH = "com.alane.usageforecast.action.REFRESH_WIDGET"
    }

    /** Redimensionnement : bascule entre la disposition compacte et la grande. */
    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle,
    ) {
        WidgetRenderer.updateAll(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        WidgetScheduler.ensureScheduled(context)
    }

    override fun onDisabled(context: Context) {
        WidgetScheduler.cancelAll(context)
    }
}
