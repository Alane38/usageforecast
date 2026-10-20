import SwiftUI

private extension View {
    /// Légende discrète : petite, grisée, qui passe à la ligne au lieu d'être tronquée.
    func discreetCaption() -> some View {
        font(.caption2)
            .foregroundStyle(Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    func smallButton(prominent: Bool) -> some View {
        modifier(SmallButtonStyle(prominent: prominent))
    }

    func linkLikeButton() -> some View {
        buttonStyle(.borderless).font(.caption)
    }
}

private struct SmallButtonStyle: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.borderedProminent).controlSize(.small)
        } else {
            content.buttonStyle(.bordered).controlSize(.small)
        }
    }
}

/// État des sources de données et reconnexion (import depuis le navigateur ou cookie collé).
struct ConnectionsView: View {
    @ObservedObject var usageManager: UsageManager
    @State private var consoleCookieInput = ""
    @State private var showingConsolePaste = false

    var body: some View {
        leadingColumn(spacing: 8) {
            Text("Connexions").font(.caption.weight(.semibold))
            statusRows
            browserImportSection
            consolePasteToggle
            if showingConsolePaste { consolePasteSection }
        }
    }

    private func leadingColumn<Content: View>(spacing: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: spacing, content: content)
    }

    // MARK: Lignes d'état

    private var limitsSourceText: String {
        usageManager.usageSource == "claude.ai" ? "claude.ai, en direct" : "statusline Claude Code"
    }

    private var sessionText: String {
        if !usageManager.keychainIssue.isEmpty { return usageManager.keychainIssue }
        return usageManager.sessionCookie.isEmpty ? "absente : colle un cookie ou importe-la" : "présente"
    }

    private var consoleText: String {
        guard !usageManager.consoleCookie.isEmpty else { return "non connectée" }
        return usageManager.consoleStatus.isEmpty ? "connectée" : usageManager.consoleStatus
    }

    @ViewBuilder
    private var statusRows: some View {
        row("Limites", limitsSourceText)
        row("Session claude.ai", sessionText)
        row("Console (crédits API)", consoleText)
    }

    private func row(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(.caption)
            Spacer()
            Text(detail)
                .multilineTextAlignment(.trailing)
                .discreetCaption()
        }
    }

    private func note(_ message: String) -> some View {
        Text(message).discreetCaption()
    }

    // MARK: Import depuis le navigateur

    @ViewBuilder
    private var browserImportSection: some View {
        Button("Importer les sessions depuis Zen / Firefox", action: importFromBrowsers)
            .linkLikeButton()
        if !usageManager.browserImportReport.isEmpty { note(usageManager.browserImportReport) }
        if usageManager.browserAccessDenied { fullDiskAccessSteps }
    }

    private func importFromBrowsers() {
        let imported = usageManager.importBrowserCookies()
        if imported { usageManager.fetchUsage() }
    }

    /// Les trois gestes qui restent pour l'Accès complet au disque, un bouton chacun.
    private var fullDiskAccessSteps: some View {
        leadingColumn(spacing: 6) {
            Button("1. Ouvrir l'Accès complet au disque", action: SystemSettings.openFullDiskAccess)
                .smallButton(prominent: true)
            note("Active \(Brand.name) dans la liste. S'il n'y est pas, glisse-le depuis le Finder.")
            secondaryStep("2. Afficher l'app dans le Finder", action: SystemSettings.revealAppInFinder)
            secondaryStep("3. Relancer l'app, puis importer à nouveau", action: SystemSettings.relaunchApp)
        }
        .padding(.vertical, 4)
    }

    private func secondaryStep(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).smallButton(prominent: false)
    }

    // MARK: Cookie de la Console

    private var consolePasteToggle: some View {
        Button(showingConsolePaste ? "Annuler" : "Coller le cookie de la Console") {
            showingConsolePaste.toggle()
        }
        .linkLikeButton()
    }

    @ViewBuilder
    private var consolePasteSection: some View {
        note("platform.claude.com/settings/billing > F12 > Réseau > requête « credits » > En-têtes de requête > Cookie. Colle l'en-tête complet.")
        PasteableTextField(text: $consoleCookieInput, placeholder: "Cookie de la Console…")
            .frame(minHeight: 60, maxHeight: 60)
            .cornerRadius(4)
        HStack(alignment: .center, spacing: 8) {
            Button("Enregistrer", action: saveConsoleCookie).smallButton(prominent: true)
            if !usageManager.consoleCookie.isEmpty {
                secondaryStep("Déconnecter", action: usageManager.disconnectConsole)
            }
        }
    }

    private func saveConsoleCookie() {
        guard !consoleCookieInput.isEmpty else { return }
        usageManager.saveConsoleCookie(consoleCookieInput)
        consoleCookieInput = ""
        showingConsolePaste = false
        usageManager.fetchConsoleBalance()
    }
}
