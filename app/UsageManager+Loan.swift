import CryptoKit
import Foundation

/// Prêt de quota (ADR 003) : enregistrement du prêt, lecture du coffre du collecteur de l'invité, attribution et alertes.
/// La logique de calcul est dans LoanAttribution et LoanRules (testées) ; ici, seulement le stockage, le réseau et l'enchaînement.
extension UsageManager {
    private static let loanStorageName = "loan"
    private static let loanAlertsStorageName = "loan_alerts_enabled"
    static let loanQueue = DispatchQueue(label: "usageforecast.loan", qos: .utility)
    /// Un rapport toutes les 5 minutes au plus : le collecteur n'envoie pas plus souvent que toutes les 10 minutes.
    private static let loanRefreshInterval: TimeInterval = 270

    func loadLoan() {
        let defaults = UserDefaults.standard
        loanAlertsEnabled = defaults.object(forKey: Self.loanAlertsStorageName) as? Bool ?? true
        guard !isProbeRun else { return }
        loadRevocationWatch()
        guard let data = defaults.data(forKey: Self.loanStorageName) else { return }
        loan = try? JSONDecoder().decode(Loan.self, from: data)
    }

    private func saveLoan() {
        let defaults = UserDefaults.standard
        if let loan, let data = try? JSONEncoder().encode(loan) { defaults.set(data, forKey: Self.loanStorageName) }
        else { defaults.removeObject(forKey: Self.loanStorageName) }
    }

    func setLoanAlerts(_ enabled: Bool) {
        loanAlertsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.loanAlertsStorageName)
    }

    /// Début de la fenêtre comptée : le prêt, ou le début de la semaine en cours s'il a commencé avant (la part est hebdomadaire).
    func loanWindowStart(_ loan: Loan) -> Date {
        guard let resetsAt = weeklyResetsAt else { return loan.startsAt }
        return max(loan.startsAt, resetsAt.addingTimeInterval(-7 * 86400))
    }

    /// Démarre un prêt avec le lien affiché par le collecteur de l'invité. Retourne un message d'erreur lisible, ou nil si tout va bien.
    func startLoan(guestName: String, share: Double, endsAt: Date, link: String, now: Date = Date()) -> String? {
        guard let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)), let pairing = PairingLink.parse(url) else {
            return "Lien illisible : colle le lien complet affiché par « collecteur associer » (https://…/#v1.…)."
        }
        guard MobileUploader.endpoint(relay: pairing.relay, id: pairing.id) != nil else { return "Le relais doit être en https://." }
        return beginLoan(guestName: guestName, share: share, endsAt: endsAt, relay: pairing.relay, guestVault: (pairing.id, pairing.key), now: now)
    }

    /// Enregistre un prêt (depuis les Réglages ou une commande du téléphone) : clés dans le magasin des secrets, le reste dans les préférences.
    func beginLoan(guestName: String, share: Double, endsAt: Date, relay: URL, guestVault: (id: String, key: Data),
                   viewVault: (id: String, key: Data)? = nil, now: Date = Date()) -> String? {
        guard endsAt > now else { return "La fin du prêt doit être dans le futur." }
        guard AppSecrets.store.write(MobileCrypto.base64url(guestVault.key), account: AppSecrets.loanKeyAccount),
              viewVault.map({ AppSecrets.store.write(MobileCrypto.base64url($0.key), account: AppSecrets.loanViewKeyAccount) }) ?? true else {
            return "Impossible d'enregistrer la clé du coffre (\(AppSecrets.storageLabel))."
        }
        loan = Loan(id: UUID().uuidString.lowercased(), guestName: guestName, share: min(max(share, Loan.shareRange.lowerBound), Loan.shareRange.upperBound),
                    startsAt: now, endsAt: endsAt, relay: relay.absoluteString, vaultID: guestVault.id, viewVaultID: viewVault?.id)
        saveLoan()
        lastGuestViewPublish = nil
        (guestReport, loanState, loanStatus) = (nil, nil, "")
        refreshLoan(now: now, force: true)
        return nil
    }

    /// Termine le prêt ici. La révocation de l'accès se fait sur claude.ai (Settings › Claude Code) : l'app ne peut pas la faire.
    func endLoan(now: Date = Date()) {
        guard let ended = loan else { return }
        publishFinalGuestView(now: now)   // l'invité voit « Prêt terminé » au lieu d'une vue figée
        deleteGuestVault(ended)           // son activité ne reste pas sur le relais
        loan = nil
        (guestReport, loanState, loanStatus) = (nil, nil, "")
        AppSecrets.store.delete(account: AppSecrets.loanKeyAccount)
        AppSecrets.store.delete(account: AppSecrets.loanViewKeyAccount)
        saveLoan()
        startRevocationWatch(guestName: ended.displayName, now: now)
    }

    func refreshLoan(now: Date = Date(), force: Bool = false) {
        guard let loan, !isProbeRun else { return }
        if !force, let last = lastLoanRefresh, now.timeIntervalSince(last) < Self.loanRefreshInterval { return }
        lastLoanRefresh = now
        fetchGuestReport(loan) { [weak self] report, problem in
            DispatchQueue.main.async {
                guard let self, self.loan?.id == loan.id else { return }
                if let report { self.guestReport = report }
                self.loanStatus = problem ?? ""
                self.recomputeLoan(now: now)
            }
        }
    }

    private func fetchGuestReport(_ loan: Loan, completion: @escaping (GuestReport?, String?) -> Void) {
        guard let relay = URL(string: loan.relay), let url = MobileUploader.endpoint(relay: relay, id: loan.vaultID),
              let text = AppSecrets.store.read(account: AppSecrets.loanKeyAccount), let keyData = MobileCrypto.data(fromBase64url: text), keyData.count == 32
        else { return completion(nil, "Clé du coffre introuvable : termine le prêt et recommence.") }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode
            guard let status else { return completion(nil, "Relais injoignable : attribution par estimation en attendant.") }
            if status == 404 { return completion(nil, "Le collecteur de \(loan.displayName) n'a encore rien envoyé.") }
            guard status == 200, let data, let blob = String(data: data, encoding: .utf8) else { return completion(nil, "Le relais a répondu une erreur (\(status)).") }
            guard let plain = MobileCrypto.open(blob, key: SymmetricKey(data: keyData)), let report = GuestReport.decode(plain) else {
                return completion(nil, "Données du collecteur illisibles (clé différente ou version inconnue).")
            }
            completion(report, nil)
        }.resume()
    }

    /// Attribution et alertes : lecture des journaux de ce Mac et de l'historique hors du fil principal, calcul et notifications sur celui-ci.
    private func recomputeLoan(now: Date) {
        guard let loan else { return }
        let since = loanWindowStart(loan), end = min(now, loan.endsAt)
        let directories = ClaudeTranscripts.projectDirectories(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser)
        let (scanner, store, guestBuckets, reportAt) = (transcriptScanner, self.history, guestReport?.buckets ?? [], guestReport?.updatedAt)
        // Le résultat revient par une fermeture créée ici, sur le fil principal : la file de calcul ne touche jamais `self`.
        let apply: ([ActivityBucket], [UsageSample]) -> Void = { [weak self] owner, samples in
            guard let self, self.loan?.id == loan.id else { return }
            let tally = LoanAttribution.tally(samples: samples, guest: guestBuckets, owner: owner, from: since, to: end)
            let state = LoanRules.state(loan: loan, tally: tally, since: since, now: now, reportAt: reportAt)
            self.loanState = state
            if self.loanAlertsEnabled { self.notifyLoan(LoanRules.alerts(loan: loan, state: state, now: now)) }
            if loan.viewVaultID != nil {
                let days = LoanAttribution.daily(samples: samples, guest: guestBuckets, owner: owner, from: since, to: end)
                self.publishGuestViewIfDue(loan: loan, state: state, days: days, now: now)
            }
        }
        Self.loanQueue.async {
            let owner = scanner.scan(directories: directories, since: since.addingTimeInterval(-600))
            let samples = store.load(since: since.addingTimeInterval(-3600))
            DispatchQueue.main.async { apply(owner, samples) }
        }
    }

    func notifyLoan(_ alerts: [LoanAlert]) {
        let fresh = alerts.filter { !alertLedger.has($0.key) }
        for alert in fresh {
            Notifier.send(title: alert.title, body: alert.body, id: alert.key)
            alertLedger.mark(alert.key)
        }
        if !fresh.isEmpty { UserDefaults.standard.set(alertLedger.sent, forKey: "alert_ledger") }
    }
}
