package com.alane.usageforecast

import android.content.Context
import android.graphics.Color
import android.util.TypedValue
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Petits éléments d'interface construits en code : pas de layout XML pour deux écrans. */
object Ui {
    fun dp(context: Context, value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()

    fun color(context: Context, id: Int): Int = context.getColor(id)

    fun title(context: Context, text: Int): TextView = TextView(context).apply {
        setText(text)
        setTextColor(color(context, R.color.texte))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
    }

    fun paragraph(context: Context, text: Int): TextView = TextView(context).apply {
        setText(text)
        setTextColor(color(context, R.color.texte_discret))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        setPadding(0, dp(context, 12), 0, dp(context, 16))
    }

    fun button(context: Context, text: Int, primary: Boolean, onClick: () -> Unit): Button =
        Button(context).apply {
            setText(text)
            isAllCaps = false
            minHeight = dp(context, 48)
            setTextColor(if (primary) Color.BLACK else color(context, R.color.texte))
            backgroundTintList = android.content.res.ColorStateList.valueOf(
                if (primary) color(context, R.color.accent) else 0x33FFFFFF,
            )
            setOnClickListener { onClick() }
        }

    fun column(context: Context): LinearLayout = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        val side = dp(context, 24)
        setPadding(side, dp(context, 32), side, side)
    }

    fun spacing(context: Context, height: Int = 12): View = View(context).apply {
        layoutParams = LinearLayout.LayoutParams(1, dp(context, height))
    }
}
