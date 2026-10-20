import SwiftUI
import AppKit

/// Modes de développement : options de ligne de commande qui préparent l'app (données fictives, fenêtres ouvertes)
/// et rendent un écran dans un PNG. `scripts/visual-check.sh` s'appuie dessus ; rien n'est jamais enregistré dans les réglages.
extension AppDelegate {
    private func hasFlag(_ flag: String) -> Bool { CommandLine.arguments.contains(flag) }

    /// Délai avant d'agir, pour laisser le statusline et le réseau remplir les données (`--wait`, 2 s par défaut).
    private var captureDelay: TimeInterval { Snapshot.option("--wait").flatMap(Double.init) ?? 2 }

    func runDevelopmentModes() {
        applyDisplayOptions()
        if hasFlag("--settings-window") {
            DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay) { self.openSettings() }
        }
        if hasFlag("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay) { self.openPopover() }
        }
        guard let outputPath = Snapshot.outputPath else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay) {
            self.renderCapture(to: outputPath)
            NSApp.terminate(nil)
        }
    }

    private func applyDisplayOptions() {
        if let layout = Snapshot.option("--layout").flatMap(PopoverLayout.init(rawValue:)) { usageManager.popoverLayout = layout }
        if let style = Snapshot.option("--menubar").flatMap(MenuBarStyle.init(rawValue:)) { usageManager.menuBarStyle = style }
        if hasFlag("--reset-in-menubar") { usageManager.menuBarShowReset = true }
    }

    private func renderCapture(to path: String) {
        applyDisplayOptions()
        if hasFlag("--denied") { simulateBrowserAccessDenied() }
        if hasFlag("--real-history") { loadRealHistory() }
        if hasFlag("--demo") { loadDemoData() }
        if let relay = Snapshot.option("--mobile-upload") { runMobileUpload(relay: relay) }
        if hasFlag("--demo-update") { simulateAvailableUpdate(mode: Snapshot.option("--demo-update") ?? "") }
        writeScreen(to: path)
    }

    private func writeScreen(to path: String) {
        if hasFlag("--menubar-styles") {
            let styles = VStack(alignment: .leading, spacing: 10) {
                ForEach(MenuBarStyle.allCases, id: \.self) { style in
                    HStack(spacing: 12) {
                        Text(style.label).font(.caption).frame(width: 90, alignment: .leading)
                        MenuBarPreview(usageManager: self.usageManager, style: style)
                    }
                }
            }
            Snapshot.write(view: styles.padding(16), to: path, size: NSSize(width: 320, height: 170))
        } else if hasFlag("--welcome") {
            let welcome = WelcomeView(usageManager: usageManager, openConnections: {}, finish: {})
            Snapshot.write(view: welcome, to: path, size: NSSize(width: 520, height: 620))
        } else if hasFlag("--settings") {
            let height = Snapshot.option("--height").flatMap(Double.init).map { CGFloat($0) } ?? 560
            Snapshot.write(view: SettingsView(usageManager: usageManager, statusManager: statusManager),
                           to: path, size: NSSize(width: 560, height: height))
        } else {
            Snapshot.write(view: PopoverView(usageManager: usageManager, statusManager: statusManager),
                           to: path, size: NSSize(width: 360, height: 640))
        }
    }

    private func simulateBrowserAccessDenied() {
        usageManager.browserAccessDenied = true
        usageManager.browserImportReport = "macOS bloque la lecture de ton navigateur : \(Brand.name) a besoin de l'Accès complet au disque."
    }

    /// Aperçu avec le vrai historique de l'utilisateur, en lecture seule.
    private func loadRealHistory() {
        usageManager.historySamples = usageManager.history.load(since: Date().addingTimeInterval(-24 * 3600))
        usageManager.hasFetchedData = true
    }

    private func runMobileUpload(relay: String) {
        // Essai de bout en bout : le vrai chemin (snapshot, chiffrement, requête) vers un relais local, avec les données de démonstration.
        usageManager.mobileRelayText = relay
        let outcome = usageManager.mobileUploadRequest().map { MobileUploader.uploadAndWait($0.request, bytes: $0.bytes) }
        print("envoi mobile :", outcome?.message ?? "requête impossible")
    }

    private func simulateAvailableUpdate(mode: String) {
        let releases = "https://github.com/Alane38/usageforecast/releases"
        let archive = releases + "/download/v9.9.9/UsageForecast-9.9.9-arm64.zip"
        usageManager.availableUpdate = ReleaseInfo(version: "9.9.9", pageURL: URL(string: releases)!,
                                                   zipURL: URL(string: archive), checksumURL: URL(string: archive + ".sha256"))
        switch mode {
        case "working": usageManager.updateInstallState = .working("Téléchargement…")
        case "failed": usageManager.updateInstallState = .failed("La somme SHA-256 ne correspond pas : archive corrompue ou modifiée, mise à jour refusée.")
        default: break
        }
    }
}
