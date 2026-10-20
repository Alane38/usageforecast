package com.alane.usageforecast

import android.content.Context
import android.webkit.CookieManager
import android.webkit.WebStorage

/** Mémorise l'origine du relais (jamais le fragment ni la clé) dans des préférences privées. */
class RelayStore(context: Context) {
    private val preferences = context.getSharedPreferences("relais", Context.MODE_PRIVATE)

    /** Origine enregistrée, relue puis revalidée : une valeur altérée est traitée comme absente. */
    fun load(): String? {
        val saved = preferences.getString(KEY_ORIGIN, null) ?: return null
        return RelayAddress.originOf(saved)
    }

    fun save(origin: String) {
        preferences.edit().putString(KEY_ORIGIN, origin).apply()
    }

    fun forget() {
        preferences.edit().remove(KEY_ORIGIN).apply()
    }

    private companion object {
        const val KEY_ORIGIN = "origine"
    }
}

/**
 * Lien d'association en attente d'un premier chargement. Gardé en mémoire plutôt que dans un Intent :
 * il contient la clé, et un Intent peut être copié dans les instantanés de tâches ou les journaux système.
 */
object PendingPairing {
    private var url: String? = null

    fun set(value: String?) {
        url = value
    }

    /** Lecture unique : la clé ne reste pas en mémoire une fois le chargement lancé. */
    fun take(): String? = url.also { url = null }
}

/** Efface ce que la PWA a gardé sur l'appareil (clé de déchiffrement, dernières données). */
object WebData {
    fun wipe() {
        WebStorage.getInstance().deleteAllData()
        CookieManager.getInstance().removeAllCookies(null)
        CookieManager.getInstance().flush()
    }
}
