import AppKit

extension AppDelegate {
    /// L'assistant s'ouvre une fois, quelques secondes après le lancement, si aucune donnée n'est arrivée.
    /// Il peut aussi être rouvert depuis Réglages > Général.
    func setUpWelcome() {
        NotificationCenter.default.addObserver(forName: .showWelcome, object: nil, queue: .main) { [weak self] _ in self?.showWelcome() }
        guard Snapshot.outputPath == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, FirstRun.isNeeded(seen: UserDefaults.standard.bool(forKey: FirstRun.seenKey),
                                              hasData: self.usageManager.hasFetchedData) else { return }
            self.showWelcome()
        }
    }

    func showWelcome() {
        welcomeController.show(usageManager: usageManager) { [weak self] in self?.openSettings() }
    }
}
