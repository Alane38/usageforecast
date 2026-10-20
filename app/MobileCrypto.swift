import CryptoKit
import Foundation

/// Chiffrement de bout en bout de la synchro mobile : AES-256-GCM. Le relais ne voit que du texte chiffré ; la clé n'existe que sur le Mac
/// et sur le téléphone (elle voyage dans le fragment du lien d'appairage, que le navigateur n'envoie jamais à un serveur).
enum MobileCrypto {
    // MARK: - Base64 URL

    static func base64url(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func data(fromBase64url text: String) -> Data? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        return Data(base64Encoded: base64)
    }

    // MARK: - Clés et identifiants

    static func newKey() -> SymmetricKey { SymmetricKey(size: .bits256) }

    static func keyData(_ key: SymmetricKey) -> Data { key.withUnsafeBytes { Data($0) } }

    /// Identifiant du coffre sur le relais : 128 bits aléatoires, impossibles à deviner.
    static func newDeviceID() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Jeton qui prouve qu'on est l'écrivain du coffre : HMAC de la clé, que le téléphone peut aussi recalculer mais qui ne dévoile pas la clé.
    static func writeToken(key: SymmetricKey) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: Data("claude-usage-bar/write".utf8), using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    /// Identifiant et clé fixes pour les démonstrations et les essais locaux (jamais utilisés avec un vrai relais) : les mêmes que
    /// `mobile/scripts/seed-demo.mjs` avec DEMO_FIXED=1, pour qu'un Mac de démonstration et un téléphone de démonstration s'entendent.
    static func demoPairing() -> (id: String, secret: Data) {
        func digest(_ label: String) -> [UInt8] { Array(SHA256.hash(data: Data(label.utf8))) }
        let id = digest("claude-usage-bar demo id").map { String(format: "%02x", $0) }.joined().prefix(32)
        return (String(id), Data(digest("claude-usage-bar demo key")))
    }

    // MARK: - Chiffrement

    /// `nonce (12 octets) | texte chiffré | étiquette (16 octets)`, en base64url. Le nonce aléatoire est tiré à chaque envoi.
    static func seal(_ plaintext: Data, key: SymmetricKey, nonce: AES.GCM.Nonce? = nil) -> String? {
        let box = try? nonce.map { try AES.GCM.seal(plaintext, using: key, nonce: $0) } ?? AES.GCM.seal(plaintext, using: key)
        return box?.combined.map(base64url)
    }

    static func open(_ blob: String, key: SymmetricKey) -> Data? {
        guard let combined = data(fromBase64url: blob), let box = try? AES.GCM.SealedBox(combined: combined) else { return nil }
        return try? AES.GCM.open(box, using: key)
    }
}

/// Lien d'appairage : `https://relais/#v1.<identifiant>.<clé en base64url>`.
struct PairingLink: Equatable {
    let relay: URL
    let id: String
    let key: Data

    var url: URL? {
        var components = URLComponents(url: relay, resolvingAgainstBaseURL: false)
        components?.fragment = "v1.\(id).\(MobileCrypto.base64url(key))"
        return components?.url
    }

    static func parse(_ url: URL) -> PairingLink? {
        guard let fragment = url.fragment else { return nil }
        let parts = fragment.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, parts[0] == "v1", parts[1].count == 32, parts[1].allSatisfy(\.isHexDigit),
              let key = MobileCrypto.data(fromBase64url: parts[2]), key.count == 32 else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        guard let relay = components?.url else { return nil }
        return PairingLink(relay: relay, id: parts[1], key: key)
    }
}
