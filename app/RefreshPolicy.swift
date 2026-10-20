import Foundation

/// Cadence de rafraîchissement : une minute en temps normal, cinq minutes quand l'API refuse
/// (429 limite de débit, 401/403 session ou protection, 5xx). Retour à une minute dès un succès.
/// Les endpoints de claude.ai ne sont pas documentés : on évite d'insister contre un blocage.
struct RefreshPolicy: Equatable {
    static let normalInterval: TimeInterval = 60
    static let slowedInterval: TimeInterval = 300

    private(set) var isSlowed = false

    var interval: TimeInterval { isSlowed ? Self.slowedInterval : Self.normalInterval }

    /// `statusCode` nil = pas de réponse (réseau coupé) : la cadence ne change pas, ce n'est pas un refus de l'API.
    mutating func record(statusCode: Int?) {
        guard let statusCode else { return }
        switch statusCode {
        case 200..<300: isSlowed = false
        case 401, 403, 429, 500..<600: isSlowed = true
        default: break
        }
    }
}
