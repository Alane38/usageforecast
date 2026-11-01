import CryptoKit
import Foundation

/// Après un prêt : vérification de la révocation pendant 48 h et effacement du coffre de l'invité (ADR 003, étape 4).
/// La logique est dans LoanRevocation (testée) ; ici, le stockage, la lecture des journaux et l'alerte.
extension UsageManager {
    private static let revocationStorageName = "loan_revocation"
    private static let revocationInterval: TimeInterval = 270

    func loadRevocationWatch(now: Date = Date()) {
        guard let data = UserDefaults.standard.data(forKey: Self.revocationStorageName),
              let watch = try? JSONDecoder().decode(RevocationWatch.self, from: data) else { return }
        if now > watch.watchEndsAt.addingTimeInterval(LoanRevocation.keepFor) { dismissRevocationWatch() } else { revocationWatch = watch }
    }

    func startRevocationWatch(guestName: String, now: Date) {
        let watch = RevocationWatch(endedAt: now, guestName: guestName)
        revocationWatch = watch
        revocationStatus = nil
        lastRevocationCheck = nil
        if let data = try? JSONEncoder().encode(watch) { UserDefaults.standard.set(data, forKey: Self.revocationStorageName) }
    }

    func dismissRevocationWatch() {
        (revocationWatch, revocationStatus) = (nil, nil)
        UserDefaults.standard.removeObject(forKey: Self.revocationStorageName)
    }

    func refreshRevocation(now: Date = Date(), force: Bool = false) {
        guard let watch = revocationWatch, !isProbeRun else { return }
        if now > watch.watchEndsAt.addingTimeInterval(LoanRevocation.keepFor) { return dismissRevocationWatch() }
        // Après les 48 h, un dernier calcul suffit : le résultat ne change plus.
        if revocationStatus != nil, now > watch.watchEndsAt.addingTimeInterval(600) { return }
        if !force, let last = lastRevocationCheck, now.timeIntervalSince(last) < Self.revocationInterval { return }
        lastRevocationCheck = now
        let directories = ClaudeTranscripts.projectDirectories(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser)
        let (scanner, store) = (transcriptScanner, self.history)
        let apply: ([ActivityBucket], [UsageSample]) -> Void = { [weak self] owner, samples in
            guard let self, self.revocationWatch == watch else { return }
            let status = LoanRevocation.status(watch: watch, samples: samples, owner: owner, now: now)
            self.revocationStatus = status
            if let alert = LoanRevocation.alert(watch: watch, status: status, now: now) { self.notifyLoan([alert]) }   // jamais désactivée
        }
        Self.loanQueue.async {
            let owner = scanner.scan(directories: directories, since: watch.endedAt.addingTimeInterval(-600))
            let samples = store.load(since: watch.endedAt.addingTimeInterval(-3600))
            DispatchQueue.main.async { apply(owner, samples) }
        }
    }

    /// Efface sur le relais le coffre où le collecteur de l'invité déposait son activité (le Mac en a la clé, donc le jeton).
    func deleteGuestVault(_ loan: Loan) {
        guard let relay = URL(string: loan.relay), let text = AppSecrets.store.read(account: AppSecrets.loanKeyAccount),
              let keyData = MobileCrypto.data(fromBase64url: text),
              let request = MobileUploader.deleteRequest(relay: relay, id: loan.vaultID, token: MobileCrypto.writeToken(key: SymmetricKey(data: keyData)))
        else { return }
        MobileUploader.upload(request, bytes: 0) { outcome in
            if !outcome.ok { NSLog("⚠️ Coffre de l'invité non effacé : \(outcome.message) (il expirera seul au bout de 30 jours)") }
        }
    }
}
