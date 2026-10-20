import CryptoKit
import Foundation

/// Synchro mobile : à chaque relevé (une fois par minute), si elle est activée, le Mac chiffre un snapshot et l'envoie au relais.
/// Le relais ne voit jamais que du texte chiffré ; la clé ne quitte le Mac que par le code d'association que tu scannes toi-même.
extension UsageManager {
    /// Identifiant du coffre et clé de chiffrement du téléphone.
    struct MobilePairing {
        let id: String
        let cipherKey: SymmetricKey
    }

    // MARK: - Identifiants

    /// Créés au premier besoin et gardés dans le même magasin que les cookies (trousseau en release).
    func mobilePairing(create: Bool = true) -> MobilePairing? {
        if let mobilePairingOverride { return mobilePairingOverride }
        let store = AppSecrets.store
        if let id = store.read(account: AppSecrets.mobileIDAccount), id.count == 32,
           let text = store.read(account: AppSecrets.mobileKeyAccount), let data = MobileCrypto.data(fromBase64url: text), data.count == 32 {
            return MobilePairing(id: id, cipherKey: SymmetricKey(data: data))
        }
        guard create else { return nil }
        let id = MobileCrypto.newDeviceID()
        let fresh = MobileCrypto.newKey()
        guard store.write(id, account: AppSecrets.mobileIDAccount),
              store.write(MobileCrypto.base64url(MobileCrypto.keyData(fresh)), account: AppSecrets.mobileKeyAccount) else { return nil }
        return MobilePairing(id: id, cipherKey: fresh)
    }

    /// Nouvelle clé et nouveau coffre : l'ancien téléphone n'a plus accès à rien, il faut rescanner le code.
    func rotateMobilePairing() {
        AppSecrets.store.delete(account: AppSecrets.mobileIDAccount)
        AppSecrets.store.delete(account: AppSecrets.mobileKeyAccount)
        mobileStatus = ""
        mobileLastSuccess = nil
        lastMobileUpload = nil
        _ = mobilePairing()
        sendMobileSnapshotIfEnabled(now: Date(), force: true)
    }

    var mobileRelay: URL? { MobileUploader.normalizedRelay(mobileRelayText) }

    /// Lien (et donc code QR) d'association : adresse du relais, identifiant et clé dans le fragment.
    var mobilePairingURL: URL? {
        guard let relay = mobileRelay, let pairing = mobilePairing() else { return nil }
        return PairingLink(relay: relay, id: pairing.id, key: MobileCrypto.keyData(pairing.cipherKey)).url
    }

    // MARK: - Snapshot

    func buildMobileSnapshot(now: Date = Date()) -> MobileSnapshot {
        let services = delegate?.statusManager
        return MobileSnapshot(
            version: MobileSnapshot.currentVersion, updatedAt: now,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            source: usageSource == "claude.ai" ? "claude.ai" : "statusline", dataAt: lastUpdated,
            forecast: currentForecast(now: now), dayBudget: MobileSnapshot.budgetInfo(dayBudget),
            credits: MobileSnapshot.creditsInfo(creditsSummary),
            servicesOK: (services?.hasFetched ?? false) ? services?.indicator == "none" : nil,
            history: MobileSnapshot.decimate(historySamples), daily: Array(dailySummaries.suffix(MobileSnapshot.dailyDays)))
    }

    /// Le snapshot chiffré et la requête d'envoi, prêts à partir ; nil si la synchro n'est pas configurée.
    func mobileUploadRequest(now: Date = Date(), pairing override: MobilePairing? = nil) -> (request: URLRequest, bytes: Int)? {
        guard let relay = mobileRelay, let pairing = override ?? mobilePairing(),
              let plain = buildMobileSnapshot(now: now).encoded(), let blob = MobileCrypto.seal(plain, key: pairing.cipherKey),
              let request = MobileUploader.request(relay: relay, id: pairing.id, blob: blob, token: MobileCrypto.writeToken(key: pairing.cipherKey))
        else { return nil }
        return (request, blob.utf8.count)
    }

    // MARK: - Envoi

    func sendMobileSnapshotIfEnabled(now: Date, force: Bool = false) {
        guard mobileSyncEnabled, !isProbeRun, !mobileUploadInFlight else { return }
        if !force, let last = lastMobileUpload, now.timeIntervalSince(last) < 55 { return }
        guard mobileRelay != nil else {
            DispatchQueue.main.async { self.mobileStatus = "Renseigne l'adresse du relais." }
            return
        }
        guard let upload = mobileUploadRequest(now: now) else {
            DispatchQueue.main.async { self.mobileStatus = "Impossible de préparer l'envoi (clé introuvable)." }
            return
        }
        lastMobileUpload = now
        mobileUploadInFlight = true
        MobileUploader.upload(upload.request, bytes: upload.bytes) { [weak self] outcome in
            DispatchQueue.main.async {
                guard let self else { return }
                self.mobileUploadInFlight = false
                self.mobileStatus = outcome.message
                if outcome.ok { self.mobileLastSuccess = Date() }
            }
        }
    }

    /// Active ou désactive la synchro. À la désactivation, rien n'est supprimé sur le relais (les données y expirent au bout de 30 jours).
    func setMobileSync(_ enabled: Bool) {
        mobileSyncEnabled = enabled
        saveDisplaySettings()
        if enabled {
            _ = mobilePairing()
            sendMobileSnapshotIfEnabled(now: Date(), force: true)
        } else {
            mobileStatus = ""
        }
    }
}
