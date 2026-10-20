package com.alane.usageforecast

import android.content.Context
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout

/** Panneau affiché quand la page d'accueil du relais ne peut pas être chargée (hors ligne au premier chargement, mauvaise adresse). */
class NetworkErrorPanel(context: Context, onRetry: () -> Unit, onChangeAddress: () -> Unit) : LinearLayout(context) {
    init {
        orientation = VERTICAL
        gravity = Gravity.CENTER
        setBackgroundColor(Ui.color(context, R.color.fond))
        val side = Ui.dp(context, 24)
        setPadding(side, side, side, side)
        addView(Ui.title(context, R.string.reseau_titre))
        addView(Ui.paragraph(context, R.string.reseau_aide))
        addView(Ui.button(context, R.string.reseau_reessayer, primary = true, onClick = onRetry))
        addView(Ui.spacing(context))
        addView(Ui.button(context, R.string.reseau_modifier, primary = false, onClick = onChangeAddress))
        visibility = View.GONE
        // Intercepte les touches pour ne pas agir sur la page cachée dessous.
        isClickable = true
    }

    fun show(visible: Boolean) {
        visibility = if (visible) View.VISIBLE else View.GONE
    }
}
