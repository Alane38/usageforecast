import Foundation

/// Résumé d'une journée (heure locale) : de quoi apprendre le rythme habituel sur des mois, pour quelques centaines d'octets par jour.
struct DailySummary: Codable, Equatable {
    /// Jour local au format AAAA-MM-JJ.
    let day: String
    /// Points de la limite hebdomadaire consommés ce jour-là (somme des hausses ; les remises à zéro sont ignorées).
    let weeklyUsed: Double
    /// Points de session consommés (somme des hausses de toutes les sessions de la journée).
    let sessionUsed: Double
    /// Plus haut pourcentage de session atteint.
    let peakSession: Double
    /// Heures (0 à 23) pendant lesquelles l'usage a augmenté.
    let activeHours: [Int]
    /// Nombre de relevés ce jour-là (environ un par minute : mesure la couverture, l'app ne note rien quand elle est fermée).
    let samples: Int
}

/// Calculs purs sur les résumés quotidiens.
enum DailyStats {
    /// Un an de recul : de quoi comparer des semaines et des mois, pour moins de 150 Ko.
    static let retentionDays = 400

    static func stamp(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Un résumé par jour présent dans les relevés, dans l'ordre des jours.
    static func summarize(_ samples: [UsageSample], calendar: Calendar = .current) -> [DailySummary] {
        let byDay = Dictionary(grouping: samples.sorted { $0.time < $1.time }) { stamp(for: $0.date, calendar: calendar) }
        return byDay.keys.sorted().map { day in
            let daySamples = byDay[day] ?? []
            var weekly = 0.0, session = 0.0
            var hours = Set<Int>()
            var previousWeekly: Double?, previousSession: Double?
            for sample in daySamples {
                var rose = false
                if let value = sample.weekly {
                    if let previous = previousWeekly, value > previous { weekly += value - previous; rose = true }
                    previousWeekly = value
                }
                if let value = sample.session {
                    if let previous = previousSession, value > previous { session += value - previous; rose = true }
                    previousSession = value
                }
                if rose { hours.insert(calendar.component(.hour, from: sample.date)) }
            }
            return DailySummary(day: day, weeklyUsed: weekly, sessionUsed: session,
                                peakSession: daySamples.compactMap(\.session).max() ?? 0,
                                activeHours: hours.sorted(), samples: daySamples.count)
        }
    }

    /// Fusionne des résumés récents dans ceux déjà enregistrés. Pour un même jour, le résumé qui s'appuie sur le plus de relevés gagne :
    /// un jour dont le début a été purgé de l'historique de 8 jours n'écrase donc jamais son résumé complet.
    /// Les jours de plus de `retentionDays` sont retirés.
    static func merge(existing: [DailySummary], fresh: [DailySummary], now: Date = AppClock.now,
                      calendar: Calendar = .current) -> [DailySummary] {
        var byDay = Dictionary(existing.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
        for summary in fresh where summary.samples >= (byDay[summary.day]?.samples ?? 0) { byDay[summary.day] = summary }
        let oldest = stamp(for: calendar.date(byAdding: .day, value: -retentionDays, to: now) ?? now, calendar: calendar)
        return byDay.values.filter { $0.day >= oldest }.sorted { $0.day < $1.day }
    }
}

/// Fichier `daily.jsonl` : une ligne JSON par jour, droits 0600, réécrit en entier (quelques centaines de lignes au plus).
struct DailyHistory {
    let url: URL

    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(AppSupport.folderName)/daily.jsonl")
    }

    func load() -> [DailySummary] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return content.split(separator: "\n").compactMap { try? decoder.decode(DailySummary.self, from: Data($0.utf8)) }
    }

    func save(_ summaries: [DailySummary]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = summaries.compactMap { try? encoder.encode($0) }.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data((body.isEmpty ? "" : body + "\n").utf8).write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
