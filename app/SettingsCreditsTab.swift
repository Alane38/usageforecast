import SwiftUI

struct CreditsTab: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View {
        Form {
            Section("Crédits API (Max / Team)") {
                if usageManager.consoleCookie.isEmpty { manualEntry } else { consoleNotice }
            }
        }
        .formStyle(.grouped)
    }

    private var consoleNotice: some View {
        let hasBalance = usageManager.consoleBalance != nil
        return Text(hasBalance
                    ? "Le solde est lu en direct sur la Console, rien à saisir."
                    : "Console connectée : le solde s'affichera au prochain rafraîchissement.")
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var manualEntry: some View {
        Toggle("Saisie manuelle (sans connexion à la Console)", isOn: manualEntryEnabled)
        if usageManager.apiCreditCycleEnd != nil {
            amountField("Montant mensuel ($)", \.apiCreditMonthly)
            amountField("Dépensé ($)", \.apiCreditSpent)
            DatePicker("Fin du cycle", selection: cycleEnd, displayedComponents: .date)
            Text("Relève « Solde restant » sur platform.claude.com/settings/billing, ou connecte la Console pour le lire en direct.")
                .helpStyle()
        }
    }

    /// Activer la saisie manuelle fixe une fin de cycle à 30 jours ; la désactiver l'efface.
    private var manualEntryEnabled: Binding<Bool> {
        let thirtyDays: TimeInterval = 30 * 86400
        return savedBinding(
            get: { usageManager.apiCreditCycleEnd != nil },
            set: { usageManager.apiCreditCycleEnd = $0 ? Date().addingTimeInterval(thirtyDays) : nil }
        )
    }

    private var cycleEnd: Binding<Date> {
        savedBinding(
            get: { usageManager.apiCreditCycleEnd ?? Date() },
            set: { usageManager.apiCreditCycleEnd = $0 }
        )
    }

    /// Binding dont chaque écriture est aussitôt enregistrée dans les réglages d'affichage.
    private func savedBinding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: { newValue in
            set(newValue)
            usageManager.saveDisplaySettings()
        })
    }

    private func amountField(_ title: String, _ keyPath: ReferenceWritableKeyPath<UsageManager, Double>) -> some View {
        let amount = savedBinding(
            get: { usageManager[keyPath: keyPath] },
            set: { usageManager[keyPath: keyPath] = $0 }
        )
        return LabeledContent(title) {
            TextField("0", value: amount, format: .number)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
        }
    }
}
