import Foundation
import Security

/// Stockage d'un secret dans le Keychain (mot de passe générique, limité à cet appareil).
/// Remplace UserDefaults, qui écrit le cookie de session en clair dans un .plist lisible.
struct KeychainStore {
    let service: String

    private func baseQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func read(account: String) -> String? { readResult(account: account).value }

    /// Valeur et code OSStatus : distingue « absent » (errSecItemNotFound) d'un accès refusé par le trousseau.
    func readResult(account: String) -> (value: String?, status: OSStatus) {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return (nil, status) }
        return (String(data: data, encoding: .utf8), status)
    }

    /// Idempotent : remplace la valeur existante.
    @discardableResult
    func write(_ value: String, account: String) -> Bool {
        delete(account: account)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func delete(account: String) -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
