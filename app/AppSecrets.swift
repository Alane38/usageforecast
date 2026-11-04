import Foundation

/// Où vivent les cookies de session, selon la compilation :
/// - développement (`scripts/build.sh`) : fichier réservé à l'utilisateur, aucune fenêtre du trousseau ;
/// - release (`scripts/build.sh --release`) : trousseau (un seul élément pour tous les secrets), chiffré et réservé à l'app.
/// Voir docs/adr/001-stockage-des-secrets.md.
enum AppSecrets {
    static let keychainService = "com.alane.usageforecast"
    static let claudeAccount = "claude_session_cookie"
    static let consoleAccount = "console_session_cookie"
    /// Synchro mobile : identifiant du coffre sur le relais et clé de chiffrement du téléphone.
    static let mobileIDAccount = "mobile_id"
    static let mobileKeyAccount = "mobile_cipher"

    #if RELEASE
    static let isRelease = true
    static let storageLabel = "trousseau macOS (release)"
    /// Un seul élément du trousseau pour les deux cookies : une seule demande de mot de passe par mise à jour.
    static let store: SecretStoring = BundledSecretStore(
        backend: KeychainStore(service: keychainService),
        legacy: KeychainStore(service: keychainService),
        legacyAccounts: [claudeAccount, consoleAccount])
    #else
    static let isRelease = false
    static let storageLabel = "fichier protégé (développement)"
    static let store: SecretStoring = FileSecretStore(directory: secretsDirectory)
    #endif

    static var secretsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(AppSupport.folderName)/secrets")
    }

    /// À la première release, les secrets saisis en développement passent dans le trousseau puis le fichier est supprimé.
    static func migrateDevFilesToKeychain() {
        #if RELEASE
        let files = FileSecretStore(directory: secretsDirectory)
        for account in [claudeAccount, consoleAccount] {
            guard let value = files.read(account: account) else { continue }
            if store.write(value, account: account) { files.delete(account: account) }
        }
        #endif
    }
}
