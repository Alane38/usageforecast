package com.alane.usageforecast

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

class UsageWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        // Aussi appelé après un redémarrage : c'est ce qui reprogramme la tâche sans RECEIVE_BOOT_COMPLETED.
        WidgetRenderer.updateAll(context)
        WidgetScheduler.ensureScheduled(context)
        WidgetScheduler.refreshSoon(context)
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
