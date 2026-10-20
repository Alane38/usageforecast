import AppKit
import SwiftUI

/// Collage du cookie claude.ai (stocké dans le Keychain).
struct ClaudeSessionSection: View {
    @ObservedObject var usageManager: UsageManager
    @State private var cookieInput = ""

    private var state: String {
        if !usageManager.keychainIssue.isEmpty { return usageManager.keychainIssue }
        return usageManager.sessionCookie.isEmpty ? "absente" : "présente"
    }

    var body: some View {
        LabeledContent("Stockage des secrets", value: AppSecrets.storageLabel)
        LabeledContent("Session claude.ai", value: state)
        if usageManager.organizations.count > 1 {
            Picker("Organisation suivie", selection: Binding(
                get: { usageManager.selectedOrganizationId ?? "" },
                set: { usageManager.selectOrganization($0.isEmpty ? nil : $0) })) {
                Text("Automatique (dernière utilisée sur claude.ai)").tag("")
                ForEach(usageManager.organizations) { Text($0.name).tag($0.id) }
            }
        }
        Text("claude.ai > Réglages > Usage, puis F12 > Réseau > requête « usage » > En-têtes de requête > Cookie. Colle l'en-tête complet.")
            .font(.caption)
            .foregroundColor(.secondary)
        PasteableTextField(text: $cookieInput, placeholder: "Cookie de claude.ai…")
            .frame(height: 60)
            .cornerRadius(4)
        #if !RELEASE
        Button("Importer l'ancien trousseau (macOS demandera ton mot de passe une fois)") { usageManager.importLegacyKeychain() }
        if !usageManager.legacyImportReport.isEmpty {
            Text(usageManager.legacyImportReport).font(.caption).foregroundColor(.secondary)
        }
        #endif
        HStack {
            Button("Enregistrer") {
                guard !cookieInput.isEmpty else { return }
                usageManager.saveSessionCookie(cookieInput)
                cookieInput = ""
                usageManager.fetchUsage()
            }
            if !usageManager.sessionCookie.isEmpty {
                Button("Supprimer la session") { usageManager.clearSessionCookie() }
            }
        }
    }
}

struct ConnectionsTab: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View {
        Form {
            Section("Import depuis le navigateur et Console") { ConnectionsView(usageManager: usageManager) }
            Section("claude.ai") { ClaudeSessionSection(usageManager: usageManager) }
        }
        .formStyle(.grouped)
    }
}

struct CreditsTab: View {
    @ObservedObject var usageManager: UsageManager

    private func amountField(_ title: String, _ keyPath: ReferenceWritableKeyPath<UsageManager, Double>) -> some View {
        LabeledContent(title) {
            TextField("0", value: Binding(get: { usageManager[keyPath: keyPath] },
                                          set: { usageManager[keyPath: keyPath] = $0; usageManager.saveDisplaySettings() }),
                      format: .number)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
        }
    }

    var body: some View {
        Form {
            Section("Crédits API (Max / Team)") {
                if !usageManager.consoleCookie.isEmpty {
                    Text(usageManager.consoleBalance == nil
                         ? "Console connectée : le solde s'affichera au prochain rafraîchissement."
                         : "Le solde est lu en direct sur la Console, rien à saisir.")
                        .foregroundColor(.secondary)
                } else {
                    Toggle("Saisie manuelle (sans connexion à la Console)", isOn: Binding(
                        get: { usageManager.apiCreditCycleEnd != nil },
                        set: { usageManager.apiCreditCycleEnd = $0 ? Date().addingTimeInterval(30 * 86400) : nil
                               usageManager.saveDisplaySettings() }))
                    if usageManager.apiCreditCycleEnd != nil {
                        amountField("Montant mensuel ($)", \.apiCreditMonthly)
                        amountField("Dépensé ($)", \.apiCreditSpent)
                        DatePicker("Fin du cycle", selection: Binding(
                            get: { usageManager.apiCreditCycleEnd ?? Date() },
                            set: { usageManager.apiCreditCycleEnd = $0; usageManager.saveDisplaySettings() }),
                                   displayedComponents: .date)
                        Text("Relève « Solde restant » sur platform.claude.com/settings/billing, ou connecte la Console pour le lire en direct.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AlertsTab: View {
    @ObservedObject var usageManager: UsageManager
    @ObservedObject var statusManager: StatusManager

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Seuils d'utilisation (25, 50, 75 et 90 % de la session)", isOn: Binding(
                    get: { usageManager.usageNotificationsEnabled },
                    set: { usageManager.usageNotificationsEnabled = $0; usageManager.saveSettings() }))
                Toggle("Pannes des services Claude suivis", isOn: Binding(
                    get: { usageManager.statusNotificationsEnabled },
                    set: { usageManager.statusNotificationsEnabled = $0; usageManager.saveSettings() }))
                Button("Envoyer une notification de test") { usageManager.sendTestNotification() }
            }
            Section("Alertes anticipées") {
                Button("Voir des exemples d'alertes") { usageManager.sendDemoAlerts() }
                ForEach(AlertKind.allCases, id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(kind.label, isOn: Binding(get: { usageManager.alertSettings.isOn(kind) },
                                                         set: { usageManager.setAlert(kind, enabled: $0) }))
                        Text(kind.detail).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Section("Services suivis") {
                Text("Seuls les services cochés déclenchent des alertes et apparaissent dans le popover.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(statusManager.allComponents) { component in
                    Toggle(component.name, isOn: Binding(get: { statusManager.isTracked(component.id) },
                                                         set: { _ in statusManager.toggleComponent(component.id) }))
                }
            }
        }
        .formStyle(.grouped)
    }
}
