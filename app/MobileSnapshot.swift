import Foundation

/// Tout ce que le téléphone affiche, en un seul document JSON chiffré avant l'envoi. Jamais de cookie ni de secret : des pourcentages,
/// des prévisions, le solde des crédits, l'état des services et le journal quotidien.
struct MobileSnapshot: Codable, Equatable {
    struct DayBudgetInfo: Codable, Equatable {
        let allowed: Double
        let used: Double
        /// « ok », « close » ou « over ».
        let level: String
    }

    /// Les crédits API tels que le popover les affiche (titre, valeur, détail, part consommée).
    struct CreditsInfo: Codable, Equatable {
        let title: String
        let value: String
        let detail: String
        /// De 0 à 1.
        let usedFraction: Double
    }

    /// Un point de la courbe de 24 h (5 minutes de résolution) : instant en secondes, session et semaine en %.
    struct HistoryPoint: Codable, Equatable {
        let t: Double
        let s: Double?
        let w: Double?
    }

    static let currentVersion = 1
    /// Jours de journal quotidien envoyés : de quoi alimenter les statistiques du téléphone (le fichier du Mac en garde 400).
    static let dailyDays = 120

    let version: Int
    let updatedAt: Date
    let appVersion: String
    /// « claude.ai » ou « statusline » : d'où viennent les pourcentages.
    let source: String
    /// Instant de la dernière donnée reçue de l'usage (le téléphone affiche son âge).
    let dataAt: Date
    let forecast: ForecastExport
    let dayBudget: DayBudgetInfo?
    let credits: CreditsInfo?
    /// nil quand l'état des services n'est pas encore connu.
    let servicesOK: Bool?
    let history: [HistoryPoint]
    let daily: [DailySummary]

    /// Dernier relevé de chaque tranche de `bucket` secondes : une courbe de 24 h tient en 288 points au lieu de 1 440.
    static func decimate(_ samples: [UsageSample], bucket: TimeInterval = 300) -> [HistoryPoint] {
        var lastInBucket: [Int: UsageSample] = [:]
        for sample in samples.sorted(by: { $0.time < $1.time }) { lastInBucket[Int(sample.time / bucket)] = sample }
        return lastInBucket.keys.sorted().compactMap { key in
            lastInBucket[key].map { HistoryPoint(t: $0.time.rounded(), s: $0.session, w: $0.weekly) }
        }
    }

    static func budgetInfo(_ budget: DayBudget?) -> DayBudgetInfo? {
        budget.map { DayBudgetInfo(allowed: $0.allowed, used: $0.used, level: $0.level == .over ? "over" : ($0.level == .close ? "close" : "ok")) }
    }

    static func creditsInfo(_ summary: CreditsSummary?) -> CreditsInfo? {
        summary.map { CreditsInfo(title: $0.title, value: $0.valueText, detail: $0.detail, usedFraction: $0.usedFraction) }
    }

    func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(self)
    }

    static func decode(_ data: Data) -> MobileSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MobileSnapshot.self, from: data)
    }
}
