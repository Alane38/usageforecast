import Foundation
import Security

/// Stockage des secrets (cookies de session). Deux implémentations : le trousseau (release) et un fichier
/// réservé à l'utilisateur (développement), voir AppSecrets.
protocol SecretStoring {
    func readResult(account: String) -> (value: String?, status: OSStatus)
    @discardableResult func write(_ value: String, account: String) -> Bool
    @discardableResult func delete(account: String) -> Bool
}

extension SecretStoring {
    func read(account: String) -> String? { readResult(account: account).value }
}

extension KeychainStore: SecretStoring {}

/// Un fichier par secret, droits 0600 dans un dossier 0700. Aucune fenêtre macOS, quelle que soit la signature
/// du binaire : c'est le choix du mode développement, où l'on recompile et réinstalle sans cesse.
struct FileSecretStore: SecretStoring {
    let directory: URL

    private func url(_ account: String) -> URL { directory.appendingPathComponent(account) }

    func readResult(account: String) -> (value: String?, status: OSStatus) {
        guard let data = try? Data(contentsOf: url(account)), let text = String(data: data, encoding: .utf8) else {
            return (nil, errSecItemNotFound)
        }
        return (text, errSecSuccess)
    }

    @discardableResult
    func write(_ value: String, account: String) -> Bool {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
            try? manager.removeItem(at: url(account))
            // Créé directement en 0600 : le secret n'existe jamais avec des droits plus larges.
            return manager.createFile(atPath: url(account).path, contents: Data(value.utf8),
                                      attributes: [.posixPermissions: 0o600])
        } catch {
            return false
        }
    }

    @discardableResult
    func delete(account: String) -> Bool {
        try? FileManager.default.removeItem(at: url(account))
        return !FileManager.default.fileExists(atPath: url(account).path)
    }
}
