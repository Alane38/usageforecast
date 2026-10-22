package com.alane.usageforecast

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context

/**
 * Planification par JobScheduler (aucune dépendance tierce). Les tâches ne sont pas persistantes :
 * cela évite RECEIVE_BOOT_COMPLETED ; après un redémarrage, le lanceur rappelle onUpdate du widget,
 * ce qui reprogramme la tâche.
 */
object WidgetScheduler {
    private const val PERIODIC_JOB_ID = 4201
    private const val NOW_JOB_ID = 4202
    private const val PERIOD_MS = 15 * 60 * 1000L

    private fun component(context: Context) = ComponentName(context, RefreshJobService::class.java)

    private fun scheduler(context: Context) = context.getSystemService(JobScheduler::class.java)

    fun widgetCount(context: Context): Int =
        AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, UsageWidgetProvider::class.java)).size

    /** Idempotent : une tâche déjà programmée est laissée telle quelle pour ne pas repousser son échéance. */
    fun ensureScheduled(context: Context) {
        val jobs = scheduler(context) ?: return
        if (widgetCount(context) == 0) {
            jobs.cancel(PERIODIC_JOB_ID)
            return
        }
        if (jobs.getPendingJob(PERIODIC_JOB_ID) != null) return
        jobs.schedule(
            JobInfo.Builder(PERIODIC_JOB_ID, component(context))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPeriodic(PERIOD_MS)
                .build(),
        )
    }

    /** Un rafraîchissement unique dès que le réseau est là (ajout du widget, nouveau lien d'association). */
    fun refreshSoon(context: Context) {
        if (widgetCount(context) == 0) return
        scheduler(context)?.schedule(
            JobInfo.Builder(NOW_JOB_ID, component(context))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .build(),
        )
    }

    fun cancelAll(context: Context) {
        scheduler(context)?.apply {
            cancel(PERIODIC_JOB_ID)
            cancel(NOW_JOB_ID)
        }
    }
}

/** Récupère, déchiffre et affiche : tout le travail réseau se fait hors du fil principal. */
class RefreshJobService : JobService() {
    @Volatile private var worker: Thread? = null

    override fun onStartJob(params: JobParameters): Boolean {
        worker = Thread {
            WidgetRefresher.run(applicationContext)
            jobFinished(params, false)
        }.also { it.start() }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        worker?.interrupt()
        return true
    }
}
