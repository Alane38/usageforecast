import Foundation

/// Vérification des nouvelles versions : un appel GET public à l'API GitHub, au plus toutes les 6 h, jamais de donnée envoyée.
extension UsageManager {
    var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func checkForUpdateIfDue(force: Bool = false) {
        guard checksForUpdates || force else { return }
        guard force || UpdateChecker.shouldCheck(lastCheck: lastUpdateCheck) else { return }
        lastUpdateCheck = Date()
        UserDefaults.standard.set(lastUpdateCheck, forKey: "last_update_check")
        var request = URLRequest(url: UpdateChecker.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(Brand.name)/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            let release = data.flatMap(UpdateChecker.parse)
            DispatchQueue.main.async { self?.applyRelease(release, announce: !force) }
        }.resume()
    }

    func applyRelease(_ release: ReleaseInfo?, announce: Bool) {
        updateCheckReport = release.map { UpdateChecker.isNewer($0.version, than: currentVersion)
            ? "Version \($0.version) disponible" : "Tu as la dernière version (\(currentVersion))" } ?? "Aucune version publiée trouvée"
        guard let release, UpdateChecker.isNewer(release.version, than: currentVersion) else { availableUpdate = nil; return }
        availableUpdate = release
        let defaults = UserDefaults.standard
        guard announce, defaults.string(forKey: "notified_update_version") != release.version else { return }
        defaults.set(release.version, forKey: "notified_update_version")
        Notifier.send(title: "\(Brand.name) \(release.version) disponible",
                      body: "Tu as la \(currentVersion). Ouvre le popover pour voir les nouveautés.", id: "update-\(release.version)")
    }
}
