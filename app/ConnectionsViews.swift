import SwiftUI

/// État des sources de données et reconnexion (import depuis le navigateur ou cookie collé).
struct ConnectionsView: View {
    @ObservedObject var usageManager: UsageManager
    @State private var consoleCookieInput = ""
    @State private var showingConsolePaste = false

    private var consoleState: String {
        if usageManager.consoleCookie.isEmpty { return "non connectée" }
        return usageManager.consoleStatus.isEmpty ? "connectée" : usageManager.consoleStatus
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.caption)
            Spacer()
            Text(value)
                .font(.caption2)
                .foregroundColor(Color.secondaryText)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connexions")
                .font(.caption.weight(.semibold))
            line("Limites", usageManager.usageSource == "claude.ai" ? "claude.ai, en direct" : "statusline Claude Code")
            line("Session claude.ai", !usageManager.keychainIssue.isEmpty ? usageManager.keychainIssue
                 : (usageManager.sessionCookie.isEmpty ? "absente : colle un cookie ou importe-la" : "présente"))
            line("Console (crédits API)", consoleState)

            Button("Importer les sessions depuis Zen / Firefox") {
                if usageManager.importBrowserCookies() { usageManager.fetchUsage() }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            if !usageManager.browserImportReport.isEmpty {
                Text(usageManager.browserImportReport)
                    .font(.caption2)
                    .foregroundColor(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if usageManager.browserAccessDenied { accessHelp }

            Button(showingConsolePaste ? "Annuler" : "Coller le cookie de la Console") {
                showingConsolePaste.toggle()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            if showingConsolePaste { consolePasteSection }
        }
    }

    /// Les trois gestes qui restent à faire pour l'Accès complet au disque, un bouton chacun.
    private var accessHelp: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("1. Ouvrir l'Accès complet au disque") { SystemSettings.openFullDiskAccess() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Text("Active \(Brand.name) dans la liste. S'il n'y est pas, glisse-le depuis le Finder.")
                .font(.caption2)
                .foregroundColor(Color.secondaryText)
            Button("2. Afficher l'app dans le Finder") { SystemSettings.revealAppInFinder() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button("3. Relancer l'app, puis importer à nouveau") { SystemSettings.relaunchApp() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var consolePasteSection: some View {
        Text("platform.claude.com/settings/billing > F12 > Réseau > requête « credits » > En-têtes de requête > Cookie. Colle l'en-tête complet.")
            .font(.caption2)
            .foregroundColor(Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        PasteableTextField(text: $consoleCookieInput, placeholder: "Cookie de la Console…")
            .frame(height: 60)
            .cornerRadius(4)
        HStack(spacing: 8) {
            Button("Enregistrer") {
                guard !consoleCookieInput.isEmpty else { return }
                usageManager.saveConsoleCookie(consoleCookieInput)
                consoleCookieInput = ""
                showingConsolePaste = false
                usageManager.fetchConsoleBalance()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            if !usageManager.consoleCookie.isEmpty {
                Button("Déconnecter") { usageManager.disconnectConsole() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}
