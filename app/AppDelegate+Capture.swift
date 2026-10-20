import AppKit
import SwiftUI

/// Lecture des options de développement de la ligne de commande (`--layout cards`, `--wait 3`, …).
enum DevFlags {
    static func isSet(_ name: String) -> Bool {
        CommandLine.arguments.contains(name)
    }

    static func number(_ name: String) -> Double? {
        Snapshot.option(name).flatMap(Double.init)
    }

    static func integer(_ name: String) -> Int? {
        Snapshot.option(name).flatMap(Int.init)
    }

    /// Délai laissé au statusline et au réseau pour remplir les données avant d'agir.
    static var wait: TimeInterval { number("--wait") ?? 2 }
}

/// Modes de vérification visuelle (`scripts/visual-check.sh`) : jamais enregistrés dans les réglages de l'utilisateur.
extension AppDelegate {
    func applyDevelopmentOptions() {
        applyDisplayOverrides()
        if DevFlags.isSet("--settings-window") { runAfterWait { self.openSettings() } }
        if DevFlags.isSet("--show") { runAfterWait { self.showPopover() } }
        guard let imagePath = Snapshot.outputPath else { return }
        runAfterWait { self.captureAndQuit(to: imagePath) }
    }

    private func runAfterWait(_ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + DevFlags.wait, execute: work)
    }

    private func applyDisplayOverrides() {
        if let layout = Snapshot.option("--layout").flatMap(PopoverLayout.init(rawValue:)) {
            usageManager.popoverLayout = layout
        }
        if let style = Snapshot.option("--menubar").flatMap(MenuBarStyle.init(rawValue:)) {
            usageManager.menuBarStyle = style
        }
        if DevFlags.isSet("--reset-in-menubar") { usageManager.menuBarShowReset = true }
    }

    private func captureAndQuit(to imagePath: String) {
        applyDisplayOverrides()
        if DevFlags.isSet("--denied") { simulateDeniedBrowserAccess() }
        if DevFlags.isSet("--real-history") { loadRealHistory() }
        if DevFlags.isSet("--demo") { installDemoData() }
        if let relay = Snapshot.option("--mobile-upload") { uploadDemoSnapshot(to: relay) }
        if DevFlags.isSet("--demo-update") { simulateAvailableUpdate() }
        render(to: imagePath)
        NSApp.terminate(nil)
    }

    private func simulateDeniedBrowserAccess() {
        usageManager.browserAccessDenied = true
        usageManager.browserImportReport = "macOS bloque la lecture de ton navigateur : "
            + "\(Brand.name) a besoin de l'Accès complet au disque."
    }

    /// Aperçu avec le vrai historique de l'utilisateur, en lecture seule.
    private func loadRealHistory() {
        let dayAgo = Date().addingTimeInterval(-24 * 3600)
        usageManager.historySamples = usageManager.history.load(since: dayAgo)
        usageManager.hasFetchedData = true
    }

    /// Essai de bout en bout : le vrai chemin (instantané, chiffrement, requête) vers un relais local, avec les données de démonstration.
    private func uploadDemoSnapshot(to relay: String) {
        usageManager.mobileRelayText = relay
        let outcome = usageManager.mobileUploadRequest().map { MobileUploader.uploadAndWait($0.request, bytes: $0.bytes) }
        print("envoi mobile :", outcome?.message ?? "requête impossible")
    }

    private func simulateAvailableUpdate() {
        let releases = "https://github.com/Alane38/usageforecast/releases"
        let archive = "\(releases)/download/v9.9.9/UsageForecast-9.9.9-arm64.zip"
        usageManager.availableUpdate = ReleaseInfo(version: "9.9.9", pageURL: URL(string: releases)!,
                                                   zipURL: URL(string: archive), checksumURL: URL(string: archive + ".sha256"))
        switch Snapshot.option("--demo-update") {
        case "working": usageManager.updateInstallState = .working("Téléchargement…")
        case "failed":
            usageManager.updateInstallState = .failed("La somme SHA-256 ne correspond pas : archive corrompue ou modifiée, mise à jour refusée.")
        default: break
        }
    }

    private func render(to imagePath: String) {
        if DevFlags.isSet("--menubar-styles") {
            Snapshot.write(view: menuBarStyleSheet, to: imagePath, size: NSSize(width: 320, height: 170))
        } else if DevFlags.isSet("--welcome") {
            let welcome = WelcomeView(usageManager: usageManager, openConnections: {}, finish: {})
            Snapshot.write(view: welcome, to: imagePath, size: NSSize(width: 520, height: 620))
        } else if DevFlags.isSet("--settings") {
            let height = DevFlags.number("--height").map { CGFloat($0) } ?? 560
            let settings = SettingsView(usageManager: usageManager, statusManager: statusManager)
            Snapshot.write(view: settings, to: imagePath, size: NSSize(width: 560, height: height))
        } else {
            let popoverContent = PopoverView(usageManager: usageManager, statusManager: statusManager)
            Snapshot.write(view: popoverContent, to: imagePath, size: NSSize(width: 360, height: 640))
        }
    }

    private var menuBarStyleSheet: some View {
        let manager: UsageManager = usageManager
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(MenuBarStyle.allCases, id: \.self) { style in
                HStack(spacing: 12) {
                    Text(style.label).font(.caption).frame(width: 90, alignment: .leading)
                    MenuBarPreview(usageManager: manager, style: style)
                }
            }
        }
        .padding(16)
    }
}
