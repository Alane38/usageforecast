package com.alane.usageforecast

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.ScrollView
import android.widget.TextView

/** Premier lancement et réglage : saisie de l'adresse du relais (ou du lien d'association complet). */
class SetupActivity : Activity() {
    private lateinit var store: RelayStore
    private lateinit var input: EditText
    private lateinit var errorView: TextView
    private var currentOrigin: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = RelayStore(this)
        currentOrigin = store.load()
        setContentView(buildContent())
    }

    private fun buildContent(): ScrollView {
        val column = Ui.column(this)
        column.addView(Ui.title(this, R.string.setup_titre))
        column.addView(Ui.paragraph(this, R.string.setup_aide))

        input = EditText(this).apply {
            setHint(R.string.setup_indice)
            setHintTextColor(Ui.color(context, R.color.texte_discret))
            setTextColor(Ui.color(context, R.color.texte))
            // Pas de suggestions ni de mémorisation par le clavier : la saisie peut contenir la clé.
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI or
                InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            imeOptions = EditorInfo.IME_ACTION_GO or EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING
            setSingleLine()
            setText(currentOrigin.orEmpty())
            setOnEditorActionListener { _, _, _ -> submit(); true }
        }
        column.addView(input)

        errorView = TextView(this).apply {
            setTextColor(Ui.color(context, R.color.erreur))
            visibility = android.view.View.GONE
        }
        column.addView(errorView)
        column.addView(Ui.spacing(this, 16))
        column.addView(Ui.button(this, R.string.setup_valider, primary = true) { submit() })

        if (currentOrigin != null) {
            column.addView(Ui.spacing(this))
            column.addView(Ui.button(this, R.string.setup_annuler, primary = false) { finish() })
            column.addView(Ui.spacing(this, 24))
            column.addView(Ui.button(this, R.string.setup_oublier, primary = false) { forgetRelay() })
        }

        return ScrollView(this).apply {
            fitsSystemWindows = true
            isFillViewport = true
            setBackgroundColor(Ui.color(context, R.color.fond))
            addView(column)
        }
    }

    private fun submit() {
        when (val result = RelayAddress.parse(input.text.toString())) {
            is ParseResult.Invalid -> showError(result.reason)
            is ParseResult.Valid -> accept(result.address)
        }
    }

    private fun accept(address: RelayAddress) {
        // Changer de relais : l'ancienne clé ne doit pas rester sur l'appareil.
        if (currentOrigin != null && currentOrigin != address.origin) WebData.wipe()
        store.save(address.origin)
        PendingPairing.set(if (address.hasPairing) address.pairingUrl() else null)
        restartMain()
    }

    private fun forgetRelay() {
        WebData.wipe()
        store.forget()
        PendingPairing.set(null)
        restartMain()
    }

    private fun restartMain() {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(intent)
        finish()
    }

    private fun showError(reason: Reason) {
        errorView.setText(
            when (reason) {
                Reason.EMPTY -> R.string.erreur_vide
                Reason.NOT_HTTPS -> R.string.erreur_http
                Reason.BAD_ADDRESS -> R.string.erreur_adresse
                Reason.BAD_FRAGMENT -> R.string.erreur_fragment
            },
        )
        errorView.visibility = android.view.View.VISIBLE
    }
}
