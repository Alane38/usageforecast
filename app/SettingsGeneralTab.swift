import AppKit
import SwiftUI

struct GeneralTab: View {
    @ObservedObject var usageManager: UsageManager

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (build \(build))"
    }

    private var dailyJournalLabel: String {
        let days = usageManager.dailySummaries
        guard let first = days.first else { return "aucun pour l'instant" }
        let parts = first.day.split(separator: "-")
        let since = parts.count == 3 ? "\(parts[2])/\(parts[1])/\(parts[0])" : first.day
        return "\(days.count) · depuis le \(since)"
    }

    private func binding(_ read: @escaping () -> Bool, write: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: read, set: write)
    }

    private var manager: UsageManager { usageManager }

    /// Applique le changement puis l'écrit dans les réglages : un seul chemin pour tous les interrupteurs.
    private func commit(_ change: () -> Void) {
        change()
        manager.saveSettings()
    }

    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        let workspace = NSWorkspace.shared
        workspace.open(url)
    }

    var body: some View { settingsForm }

    private var settingsForm: some View {
        Form {
            Section("À propos") {
                LabeledContent("Version", value: versionLabel)
                LabeledContent("Stockage des secrets", value: AppSecrets.storageLabel)
                Button("Revoir l'assistant de démarrage") {
                    NotificationCenter.default.post(name: .showWelcome, object: nil)
                }
                .buttonStyle(.link)
                Button("Voir le code et le journal des changements") {
                    open("https://github.com/Alane38/usageforecast")
                }
                .buttonStyle(.link)
                Toggle("Prévenir des nouvelles versions", isOn: Binding(
                    get: { usageManager.checksForUpdates },
                    set: { usageManager.checksForUpdates = $0; usageManager.saveDisplaySettings() }))
                HStack {
                    Button("Rechercher maintenant") { usageManager.checkForUpdateIfDue(force: true) }
                    if !usageManager.updateCheckReport.isEmpty {
                        Text(usageManager.updateCheckReport).font(.caption).foregroundColor(.secondary)
                    }
                }
                Text("Une requête publique à GitHub toutes les 6 h, sans aucune donnée envoyée.").font(.caption).foregroundColor(.secondary)
            }
            Section("Démarrage") {
                Toggle("Ouvrir à la connexion", isOn: binding({ usageManager.openAtLogin }, write: { enabled in
                    commit {
                        usageManager.openAtLogin = enabled
                        usageManager.applyLoginItem(enabled)
                    }
                }))
            }
            Section("Journal quotidien") {
                LabeledContent("Jours enregistrés", value: dailyJournalLabel)
                Text("Une ligne par jour (consommation, pic, heures d'activité) dans daily.jsonl, gardée 400 jours : la base pour apprendre ton rythme habituel. Rien ne quitte ta machine.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section("Statusline de Claude Code") {
                Toggle("Exporter la prévision", isOn: Binding(
                    get: { usageManager.exportsForecast },
                    set: { usageManager.exportsForecast = $0; usageManager.saveDisplaySettings() }))
                Text("Écrit ~/Library/Application Support/UsageForecast/forecast.json chaque minute. Ton statusline peut en afficher la ligne de prévision.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section("Raccourci clavier") {
                Toggle("Afficher le popover avec ⌘U", isOn: binding({ usageManager.shortcutEnabled }, write: { enabled in
                    commit { usageManager.shortcutEnabled = enabled }
                    (NSApp.delegate as? AppDelegate)?.setShortcutEnabled(enabled)
                }))
                Text("À désactiver s'il entre en conflit avec une autre application.").font(.caption).foregroundColor(.secondary)
                if usageManager.shortcutEnabled, !usageManager.isAccessibilityEnabled {
                    Button("Autoriser l'Accessibilité") {
                        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
