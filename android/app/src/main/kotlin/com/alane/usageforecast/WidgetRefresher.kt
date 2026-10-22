package com.alane.usageforecast

import android.content.Context

/** Une passe de rafraîchissement : lit le coffre, interroge le relais, mémorise, puis redessine. */
object WidgetRefresher {
    fun run(context: Context) {
        val origin = RelayStore(context).load()
        val pairing = PairingVault(context).load()
        val store = WidgetStore(context)
        if (origin != null && pairing != null) {
            when (val result = SnapshotFetcher.fetch(origin, pairing.id, store.stamp)) {
                is FetchResult.Fresh -> store.saveFresh(result.blob, result.stamp)
                FetchResult.Unchanged -> store.markReachable(empty = false)
                FetchResult.Empty -> store.markReachable(empty = true)
                FetchResult.Failure -> store.markOffline()
            }
        }
        WidgetRenderer.updateAll(context)
    }

    /**
     * Même passe, sur un fil à part (le réseau est interdit sur le fil principal), puis [done]. Sert aux déclencheurs qui n'ont pas
     * de JobScheduler : ouverture de l'application, appui sur le pied du widget, mise à jour périodique du système.
     */
    fun runAsync(context: Context, done: () -> Unit = {}) {
        val app = context.applicationContext
        Thread {
            try {
                run(app)
            } finally {
                done()
            }
        }.start()
    }
}
