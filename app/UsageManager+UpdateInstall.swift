import AppKit

enum UpdateInstallState: Equatable {
    case idle
    case working(String)
    case failed(String)
}

/// Mise à jour en un clic : voir `UpdateInstaller` pour les vérifications. L'application se ferme quand tout est prêt ;
/// un script la remplace et la relance. En cas d'échec, rien n'est touché et le bandeau garde le lien vers la page.
extension UsageManager {
    func installUpdate() {
        guard let release = availableUpdate, let zip = release.zipURL, let checksum = release.checksumURL else { return }
        if case .working = updateInstallState { return }
        updateInstallState = .working("Téléchargement…")
        let bundleID = Bundle.main.bundleIdentifier ?? "com.alane.usageforecast"
        let target = Bundle.main.bundleURL
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("UsageForecast-update-\(release.version)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let newApp = try UpdateInstaller.prepare(zip: zip, checksum: checksum, version: release.version,
                                                         bundleID: bundleID, workDirectory: work)
                DispatchQueue.main.async { self?.updateInstallState = .working("Installation…") }
                let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
                try UpdateInstaller.launchReplacement(newApp: newApp, target: target, trash: trash,
                                                      pid: ProcessInfo.processInfo.processIdentifier, relaunch: true, workDirectory: work)
                DispatchQueue.main.async { NSApp.terminate(nil) }
            } catch {
                let message = (error as? UpdateInstaller.Failure)?.message ?? error.localizedDescription
                DispatchQueue.main.async { self?.updateInstallState = .failed(message) }
            }
        }
    }
}
