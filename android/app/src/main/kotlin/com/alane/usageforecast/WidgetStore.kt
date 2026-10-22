package com.alane.usageforecast

import android.content.Context

/**
 * Dernier état connu du widget. On garde le blob **chiffré** tel que le relais l'a servi (jamais le
 * clair) : il est déchiffré à chaque affichage avec la clé du coffre, donc effacer le coffre rend
 * les données illisibles même si cette étape d'effacement échouait.
 */
class WidgetStore(context: Context) {
    private val preferences = context.getSharedPreferences("widget", Context.MODE_PRIVATE)

    val blob: String? get() = preferences.getString(KEY_BLOB, null)

    val stamp: String? get() = preferences.getString(KEY_STAMP, null)

    /** Vrai si le dernier essai de récupération a échoué : le widget l'affiche comme « hors ligne ». */
    val offline: Boolean get() = preferences.getBoolean(KEY_OFFLINE, false)

    /** Vrai si le relais répond mais que le Mac n'a encore rien envoyé. */
    val relayEmpty: Boolean get() = preferences.getBoolean(KEY_EMPTY, false)

    fun saveFresh(blob: String, stamp: String) {
        preferences.edit().putString(KEY_BLOB, blob).putString(KEY_STAMP, stamp)
            .putBoolean(KEY_OFFLINE, false).putBoolean(KEY_EMPTY, false).apply()
    }

    fun markReachable(empty: Boolean) {
        preferences.edit().putBoolean(KEY_OFFLINE, false).putBoolean(KEY_EMPTY, empty).apply()
    }

    fun markOffline() {
        preferences.edit().putBoolean(KEY_OFFLINE, true).apply()
    }

    fun clear() {
        preferences.edit().clear().apply()
    }

    private companion object {
        const val KEY_BLOB = "blob"
        const val KEY_STAMP = "horodatage"
        const val KEY_OFFLINE = "hors_ligne"
        const val KEY_EMPTY = "vide"
    }
}
