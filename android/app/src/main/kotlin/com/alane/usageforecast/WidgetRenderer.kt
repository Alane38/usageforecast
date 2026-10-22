package com.alane.usageforecast

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.time.Instant

/** Construit les RemoteViews du widget à partir de l'état local (aucun accès réseau ici). */
object WidgetRenderer {
    /** Sous cette hauteur (une ligne de lanceur), on utilise la disposition compacte. */
    private const val COMPACT_BELOW_DP = 100

    private sealed interface State {
        data class Message(val text: Int) : State
        data class Data(val snapshot: WidgetSnapshot, val offline: Boolean) : State
    }

    private class GaugeViews(val label: Int, val percent: Int, val reset: Int, val bars: Map<Tone, Int>)

    private val sessionViews = GaugeViews(
        R.id.session_label, R.id.session_percent, R.id.session_reset,
        mapOf(Tone.OK to R.id.session_bar_ok, Tone.WARNING to R.id.session_bar_warning,
            Tone.DANGER to R.id.session_bar_danger, Tone.STALE to R.id.session_bar_stale),
    )
    private val weeklyViews = GaugeViews(
        R.id.weekly_label, R.id.weekly_percent, R.id.weekly_reset,
        mapOf(Tone.OK to R.id.weekly_bar_ok, Tone.WARNING to R.id.weekly_bar_warning,
            Tone.DANGER to R.id.weekly_bar_danger, Tone.STALE to R.id.weekly_bar_stale),
    )

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, UsageWidgetProvider::class.java))
        if (ids.isEmpty()) return
        val state = stateOf(context)
        for (id in ids) {
            val minHeight = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val layout = if (minHeight in 1 until COMPACT_BELOW_DP) R.layout.widget_compact else R.layout.widget_large
            manager.updateAppWidget(id, build(context, layout, state))
        }
    }

    private fun stateOf(context: Context): State {
        RelayStore(context).load() ?: return State.Message(R.string.widget_pas_de_relais)
        val pairing = PairingVault(context).load() ?: return State.Message(R.string.widget_pas_de_cle)
        val store = WidgetStore(context)
        val blob = store.blob ?: return State.Message(
            when {
                store.relayEmpty -> R.string.widget_rien_envoye
                store.offline -> R.string.widget_hors_ligne_vide
                else -> R.string.widget_en_attente
            },
        )
        val json = SnapshotCrypto.decryptText(blob, pairing.keyBytes())
        val snapshot = json?.let { WidgetSnapshot.decode(it) } ?: return State.Message(R.string.widget_illisible)
        return State.Data(snapshot, store.offline)
    }

    private fun build(context: Context, layout: Int, state: State): RemoteViews {
        val views = RemoteViews(context.packageName, layout)
        views.setOnClickPendingIntent(R.id.widget_root, openApp(context, state))
        // Le pied (« il y a 3 min · … ») actualise sans ouvrir l'application.
        views.setOnClickPendingIntent(R.id.widget_footer, refreshIntent(context))
        when (state) {
            is State.Message -> {
                views.setViewVisibility(R.id.widget_gauges, View.GONE)
                views.setViewVisibility(R.id.widget_footer, View.GONE)
                views.setViewVisibility(R.id.widget_message, View.VISIBLE)
                views.setTextViewText(R.id.widget_message, context.getString(state.text))
            }
            is State.Data -> {
                views.setViewVisibility(R.id.widget_message, View.GONE)
                views.setViewVisibility(R.id.widget_gauges, View.VISIBLE)
                views.setViewVisibility(R.id.widget_footer, View.VISIBLE)
                fill(context, views, state, Instant.now())
            }
        }
        return views
    }

    private fun fill(context: Context, views: RemoteViews, state: State.Data, now: Instant) {
        val age = WidgetFormat.age(state.snapshot.dataAt, now)
        val stale = WidgetFormat.isStale(age)
        gauge(context, views, sessionViews, R.string.widget_session, state.snapshot.session, stale, now)
        gauge(context, views, weeklyViews, R.string.widget_semaine, state.snapshot.weekly, stale, now)
        views.setTextViewText(R.id.widget_footer, footer(context, state, age, stale))
        views.setTextColor(R.id.widget_footer, context.getColor(if (stale) R.color.widget_warning else R.color.texte_discret))
    }

    private fun gauge(
        context: Context, views: RemoteViews, ids: GaugeViews, label: Int,
        data: GaugeData?, stale: Boolean, now: Instant,
    ) {
        views.setTextViewText(ids.label, context.getString(label))
        val tone = if (data == null) Tone.STALE else WidgetFormat.tone(data.percent, data.pace, stale)
        views.setTextViewText(ids.percent, data?.let { WidgetFormat.percentText(it.percent) } ?: "—")
        views.setTextColor(ids.percent, toneColor(context, tone))
        val untilReset = data?.let { WidgetFormat.untilReset(it.resetsAt, now) }
        views.setTextViewText(
            ids.reset,
            when {
                untilReset != null -> context.getString(R.string.widget_reset_dans, untilReset)
                data?.resetsAt != null -> context.getString(R.string.widget_reset_en_cours)
                else -> ""
            },
        )
        for ((barTone, barId) in ids.bars) {
            views.setViewVisibility(barId, if (barTone == tone) View.VISIBLE else View.GONE)
            views.setProgressBar(barId, 100, data?.let { WidgetFormat.progress(it.percent) } ?: 0, false)
        }
    }

    private fun footer(context: Context, state: State.Data, age: java.time.Duration?, stale: Boolean): String {
        val parts = mutableListOf<String>()
        parts += when {
            age == null -> context.getString(R.string.widget_age_inconnu)
            age.toMinutes() < 1 -> context.getString(R.string.widget_age_maintenant)
            else -> context.getString(R.string.widget_age, WidgetFormat.duration(age))
        }
        if (stale) parts += context.getString(R.string.widget_anciennes)
        if (state.offline) parts += context.getString(R.string.widget_hors_ligne)
        state.snapshot.dayBudget?.let {
            parts += context.getString(R.string.widget_budget, Math.round(it.used), Math.round(it.allowed))
        }
        parts += context.getString(R.string.widget_actualiser)
        return parts.joinToString(" · ")
    }

    private fun toneColor(context: Context, tone: Tone): Int = context.getColor(
        when (tone) {
            Tone.OK -> R.color.widget_ok
            Tone.WARNING -> R.color.widget_warning
            Tone.DANGER -> R.color.widget_danger
            Tone.STALE -> R.color.texte_discret
        },
    )

    private fun refreshIntent(context: Context): PendingIntent {
        val intent = Intent(context, UsageWidgetProvider::class.java).setAction(UsageWidgetProvider.ACTION_REFRESH)
        return PendingIntent.getBroadcast(context, 1, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    /** Sans clé, le toucher mène directement à l'écran où coller le lien ; sinon, à l'application. */
    private fun openApp(context: Context, state: State): PendingIntent {
        val target = if (state is State.Message && state.text == R.string.widget_pas_de_cle) {
            SetupActivity::class.java
        } else {
            MainActivity::class.java
        }
        val intent = Intent(context, target).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }
}
