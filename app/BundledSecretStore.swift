import Foundation
import Security

/// Les secrets d'un même magasin sérialisés en un seul texte JSON : un objet de chaînes.
enum SecretBundle {
    static func decode(_ text: String) -> [String: String]? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: String] else { return nil }
        return object
    }

    static func encode(_ values: [String: String]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

/// Tous les secrets dans UN seul élément du trousseau.
///
/// Pourquoi : macOS lie l'autorisation du trousseau à l'empreinte du binaire, donc chaque nouvelle version redemande le mot de passe
/// **par élément**. Un seul élément = une seule demande par mise à jour (avant : une par cookie, soit deux).
/// Le contenu est lu une fois puis gardé en mémoire pour la durée du processus.
///
/// Migration : si l'élément unique n'existe pas encore, les anciens éléments séparés (un par compte) sont lus, regroupés,
/// puis supprimés une fois le regroupement écrit.
final class BundledSecretStore: SecretStoring {
    static let bundleAccount = "secret_bundle"

    private let backend: SecretStoring
    private let legacy: SecretStoring?
    private let legacyAccounts: [String]
    private let lock = NSLock()
    private var cache: [String: String]?
    private var loadStatus: OSStatus = errSecItemNotFound

    init(backend: SecretStoring, legacy: SecretStoring? = nil, legacyAccounts: [String] = []) {
        self.backend = backend
        self.legacy = legacy
        self.legacyAccounts = legacyAccounts
    }

    /// Contenu du magasin. Un accès refusé n'est pas mis en cache : on réessaiera, et surtout on n'écrasera rien.
    private func load() -> [String: String] {
        if let cache { return cache }
        let result = backend.readResult(account: Self.bundleAccount)
        if let text = result.value, let values = SecretBundle.decode(text) {
            cache = values
            loadStatus = errSecSuccess
            return values
        }
        loadStatus = result.status
        guard result.status == errSecItemNotFound else { return [:] }

        var merged: [String: String] = [:]
        if let legacy {
            for account in legacyAccounts { if let value = legacy.read(account: account) { merged[account] = value } }
            if !merged.isEmpty, backend.write(SecretBundle.encode(merged), account: Self.bundleAccount) {
                for account in merged.keys { legacy.delete(account: account) }
            }
        }
        cache = merged
        loadStatus = errSecItemNotFound
        return merged
    }

    func readResult(account: String) -> (value: String?, status: OSStatus) {
        lock.lock(); defer { lock.unlock() }
        let values = load()
        if let value = values[account] { return (value, errSecSuccess) }
        return (nil, loadStatus == errSecSuccess ? errSecItemNotFound : loadStatus)
    }

    @discardableResult
    func write(_ value: String, account: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        var values = load()
        guard loadStatus == errSecSuccess || loadStatus == errSecItemNotFound else { return false }
        values[account] = value
        return persist(values)
    }

    @discardableResult
    func delete(account: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        var values = load()
        guard loadStatus == errSecSuccess || loadStatus == errSecItemNotFound else { return false }
        guard values.removeValue(forKey: account) != nil else { return true }
        return persist(values)
    }

    private func persist(_ values: [String: String]) -> Bool {
        let saved = values.isEmpty ? backend.delete(account: Self.bundleAccount)
                                   : backend.write(SecretBundle.encode(values), account: Self.bundleAccount)
        if saved { cache = values; loadStatus = values.isEmpty ? errSecItemNotFound : errSecSuccess }
        return saved
    }
}
