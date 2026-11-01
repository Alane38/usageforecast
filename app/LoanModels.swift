import Foundation

/// Un prêt de quota (ADR 003) : une part de la limite hebdomadaire accordée à une autre personne pendant une période.
/// La clé de chiffrement du coffre de l'invité n'est pas ici : elle vit dans le magasin des secrets (`AppSecrets.loanKeyAccount`).
struct Loan: Codable, Equatable {
    let id: String
    var guestName: String
    /// Part de la semaine prêtée, de 0,1 à 0,9 (70 % prêtés : 0,7).
    var share: Double
    let startsAt: Date
    var endsAt: Date
    /// Adresse du relais et identifiant du coffre où le collecteur de l'invité dépose son activité.
    var relay: String
    var vaultID: String
    /// Coffre de lecture de l'invité (prêt créé depuis le téléphone avec un code) : le Mac y publie sa vue. nil sinon.
    var viewVaultID: String? = nil

    static let shareRange: ClosedRange<Double> = 0.1...0.9

    var sharePoints: Double { share * 100 }
    var reservePoints: Double { 100 - sharePoints }

    func isActive(at date: Date) -> Bool { date >= startsAt && date < endsAt }

    /// Prénom saisi, ou « l'invité » s'il est vide (les textes d'alerte restent lisibles).
    var displayName: String {
        let trimmed = guestName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "l'invité" : trimmed
    }
}

/// Activité d'une tranche de 5 minutes : nombre de réponses et tokens (entrée, sortie, écriture et lecture du cache), par modèle.
struct ActivityBucket: Codable, Equatable {
    let t: TimeInterval
    let n: Int
    let input: Int
    let output: Int
    let cacheWrite: Int
    let cacheRead: Int
    let models: [String: Int]

    static let duration: TimeInterval = 300

    enum CodingKeys: String, CodingKey {
        case t, n, input = "in", output = "out", cacheWrite = "cw", cacheRead = "cr", models
    }

    init(t: TimeInterval, n: Int, input: Int, output: Int, cacheWrite: Int, cacheRead: Int, models: [String: Int] = [:]) {
        (self.t, self.n, self.input, self.output, self.cacheWrite, self.cacheRead, self.models) = (t, n, input, output, cacheWrite, cacheRead, models)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        t = try values.decode(TimeInterval.self, forKey: .t)
        n = try values.decodeIfPresent(Int.self, forKey: .n) ?? 0
        input = try values.decodeIfPresent(Int.self, forKey: .input) ?? 0
        output = try values.decodeIfPresent(Int.self, forKey: .output) ?? 0
        cacheWrite = try values.decodeIfPresent(Int.self, forKey: .cacheWrite) ?? 0
        cacheRead = try values.decodeIfPresent(Int.self, forKey: .cacheRead) ?? 0
        models = try values.decodeIfPresent([String: Int].self, forKey: .models) ?? [:]
    }

    /// Poids pour répartir une hausse quand les deux personnes travaillent en même temps. Hypothèse : la lecture du cache, très peu
    /// coûteuse, est exclue ; aucune pondération par modèle (Anthropic ne publie pas la formule des limites).
    var weight: Int { input + output + cacheWrite }

    /// La tranche `[t, t + 5 min)` touche-t-elle l'intervalle `[start, end]` ?
    func overlaps(_ start: TimeInterval, _ end: TimeInterval) -> Bool {
        t < end && t + Self.duration > start
    }
}

/// Le document que le collecteur de l'invité dépose, chiffré, sur le relais (`mobile/collector/lib/report.js`).
struct GuestReport: Equatable {
    let updatedAt: Date
    let reason: String
    let collectorVersion: String
    let platform: String
    let lastActivityAt: Date?
    let buckets: [ActivityBucket]

    static let supportedVersion = 1

    private struct Wire: Decodable {
        struct Collector: Decodable { let version: String?; let platform: String? }
        let kind: String
        let version: Int
        let updatedAt: String
        let reason: String?
        let collector: Collector?
        let lastActivityAt: String?
        let buckets: [ActivityBucket]?
    }

    /// Dates du collecteur : ISO 8601 avec millisecondes (`toISOString()` de JavaScript), ou sans.
    static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return precise.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    /// nil si ce n'est pas un rapport de collecteur, d'une version connue, avec une date lisible.
    static func decode(_ data: Data) -> GuestReport? {
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data), wire.kind == "guest-activity",
              wire.version == supportedVersion, let updatedAt = date(wire.updatedAt) else { return nil }
        return GuestReport(updatedAt: updatedAt, reason: wire.reason ?? "", collectorVersion: wire.collector?.version ?? "",
                           platform: wire.collector?.platform ?? "", lastActivityAt: date(wire.lastActivityAt),
                           buckets: (wire.buckets ?? []).sorted { $0.t < $1.t })
    }

    /// « Windows », « Linux » ou « macOS » pour l'interface.
    var platformLabel: String {
        switch platform {
        case "win32": return "Windows"
        case "darwin": return "macOS"
        case "linux": return "Linux"
        default: return platform.isEmpty ? "machine inconnue" : platform
        }
    }
}
