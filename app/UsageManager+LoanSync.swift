import CryptoKit
import Foundation

/// Prêt de quota, échanges avec le téléphone et l'invité (ADR 003, étape 3) :
/// - le téléphone dépose ses commandes (créer, terminer) dans un coffre de contrôle dérivé de l'appairage mobile ; le Mac le lit ;
/// - le Mac publie la vue de l'invité dans le coffre de lecture que le téléphone a créé avec le code d'invitation.
extension UsageManager {
    private static let lastCommandStorageName = "loan_last_command"
    /// La vue de l'invité au plus toutes les 15 minutes : le relais gratuit accepte 1 000 écritures par jour pour tout le compte.
    private static let guestViewInterval: TimeInterval = 900
    /// Le coffre de contrôle est lu au plus toutes les 5 minutes (une lecture ne coûte rien sur le quota d'écriture).
    private static let commandPollInterval: TimeInterval = 270

    var loanLastCommandID: String? { UserDefaults.standard.string(forKey: Self.lastCommandStorageName) }

    /// Coffre de contrôle : identifiant = 16 premiers octets de HMAC(clé, "usageforecast/control"), clé = HMAC(clé, "usageforecast/control-key").
    /// Mêmes calculs que `controlPairing` de mobile/pwa/lib/crypto.js.
    static func controlVault(for key: SymmetricKey) -> (id: String, key: SymmetricKey) {
        let id = HMAC<SHA256>.authenticationCode(for: Data("usageforecast/control".utf8), using: key)
        let derived = HMAC<SHA256>.authenticationCode(for: Data("usageforecast/control-key".utf8), using: key)
        return (Data(id).prefix(16).map { String(format: "%02x", $0) }.joined(), SymmetricKey(data: Data(derived)))
    }

    func pollLoanCommands(now: Date = Date()) {
        guard mobileSyncEnabled, !isProbeRun, let relay = mobileRelay, let pairing = mobilePairing(create: false) else { return }
        if let last = lastLoanCommandPoll, now.timeIntervalSince(last) < Self.commandPollInterval { return }
        lastLoanCommandPoll = now
        let control = Self.controlVault(for: pairing.cipherKey)
        guard let url = MobileUploader.endpoint(relay: relay, id: control.id) else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard (response as? HTTPURLResponse)?.statusCode == 200, let data, let blob = String(data: data, encoding: .utf8),
                  let plain = MobileCrypto.open(blob, key: control.key), let command = LoanCommand.decode(plain) else { return }
            DispatchQueue.main.async { [weak self] in self?.apply(command, relay: relay, now: Date()) }
        }.resume()
    }

    /// Une commande n'est appliquée qu'une fois ; la plus récente seulement (le coffre n'en garde qu'une).
    func apply(_ command: LoanCommand, relay: URL, now: Date) {
        guard command.id != loanLastCommandID else { return }
        UserDefaults.standard.set(command.id, forKey: Self.lastCommandStorageName)
        switch command.action {
        case .end:
            if loan != nil { endLoan(now: now) }
        case let .create(guestName, share, endsAt, guestVault, viewVault):
            guard let guestKey = MobileCrypto.data(fromBase64url: guestVault.key), guestKey.count == 32,
                  let viewKey = MobileCrypto.data(fromBase64url: viewVault.key), viewKey.count == 32 else {
                loanStatus = "Prêt reçu du téléphone mais illisible : recrée-le."
                return
            }
            if loan != nil { endLoan(now: now) }
            loanStatus = beginLoan(guestName: guestName, share: share, endsAt: endsAt, relay: relay, guestVault: (guestVault.id, guestKey),
                                   viewVault: (viewVault.id, viewKey), now: now) ?? ""
        }
        sendMobileSnapshotIfEnabled(now: now, force: true)   // le téléphone voit tout de suite que le prêt est pris en compte
    }

    func publishGuestViewIfDue(loan: Loan, state: LoanState, days: [(day: String, points: Double)], now: Date, force: Bool = false, active: Bool? = nil) {
        guard let viewID = loan.viewVaultID, let relay = URL(string: loan.relay),
              let text = AppSecrets.store.read(account: AppSecrets.loanViewKeyAccount), let keyData = MobileCrypto.data(fromBase64url: text) else { return }
        if !force, let last = lastGuestViewPublish, now.timeIntervalSince(last) < Self.guestViewInterval { return }
        let key = SymmetricKey(data: keyData)
        let document = LoanPublishing.guestView(loan: loan, state: state, days: days, showsReserve: true, now: now, active: active)
        guard let plain = LoanPublishing.encode(document), let blob = MobileCrypto.seal(plain, key: key),
              let request = MobileUploader.request(relay: relay, id: viewID, blob: blob, token: MobileCrypto.writeToken(key: key)) else { return }
        lastGuestViewPublish = now
        MobileUploader.upload(request, bytes: blob.utf8.count) { outcome in
            if !outcome.ok { NSLog("⚠️ Vue de l'invité non publiée : \(outcome.message)") }
        }
    }

    /// Dernière publication à la fin du prêt : l'invité voit « Prêt terminé » et ses chiffres définitifs.
    func publishFinalGuestView(now: Date) {
        guard let loan, let state = loanState else { return }
        publishGuestViewIfDue(loan: loan, state: state, days: [], now: now, force: true, active: false)
    }
}
