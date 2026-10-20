import SwiftUI

extension Text {
    /// Texte d'aide discret sous un réglage (partagé par les onglets de réglages).
    func helpStyle() -> some View {
        font(.caption).foregroundColor(.secondary)
    }
}

// MARK: - Connexions

/// Cookie claude.ai (conservé dans le Keychain) et organisation suivie.
struct ClaudeSessionSection: View {
    @ObservedObject var usageManager: UsageManager
    @State private var cookieInput = ""

    private var sessionState: String {
        if !usageManager.keychainIssue.isEmpty { return usageManager.keychainIssue }
        return usageManager.sessionCookie.isEmpty ? "absente" : "présente"
    }

    var body: some View {
        LabeledContent("Stockage des secrets", value: AppSecrets.storageLabel)
        LabeledContent("Session claude.ai", value: sessionState)
        organizationPicker
        Text("claude.ai > Réglages > Usage, puis F12 > Réseau > requête « usage » > En-têtes de requête > Cookie. Colle l'en-tête complet.")
            .helpStyle()
        PasteableTextField(text: $cookieInput, placeholder: "Cookie de claude.ai…")
            .frame(minHeight: 60, maxHeight: 60)
            .cornerRadius(4)
        legacyKeychainImport
        HStack {
            Button("Enregistrer", action: saveCookie)
            if !usageManager.sessionCookie.isEmpty {
                Button("Supprimer la session", action: usageManager.clearSessionCookie)
            }
        }
    }

    @ViewBuilder
    private var organizationPicker: some View {
        if usageManager.organizations.count > 1 {
            Picker("Organisation suivie", selection: organizationSelection) {
                Text("Automatique (dernière utilisée sur claude.ai)").tag("")
                ForEach(usageManager.organizations) { organization in
                    Text(organization.name).tag(organization.id)
                }
            }
        }
    }

    private var organizationSelection: Binding<String> {
        Binding(
            get: { usageManager.selectedOrganizationId ?? "" },
            set: { usageManager.selectOrganization($0.isEmpty ? nil : $0) }
        )
    }

    @ViewBuilder
    private var legacyKeychainImport: some View {
        #if !RELEASE
        Button("Importer l'ancien trousseau (macOS demandera ton mot de passe une fois)",
               action: usageManager.importLegacyKeychain)
        if !usageManager.legacyImportReport.isEmpty {
            Text(usageManager.legacyImportReport).helpStyle()
        }
        #endif
    }

    private func refreshNow() { usageManager.fetchUsage() }

    private func saveCookie() {
        guard !cookieInput.isEmpty else { return }
        usageManager.saveSessionCookie(cookieInput)
        cookieInput = ""
        refreshNow()
    }
}

struct ConnectionsTab: View {
    let usageManager: UsageManager

    var body: some View {
        Form {
            Section("Import depuis le navigateur et Console") { ConnectionsView(usageManager: usageManager) }
            Section("claude.ai") { ClaudeSessionSection(usageManager: usageManager) }
        }
        .formStyle(.grouped)
    }
}
