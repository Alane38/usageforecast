import Foundation

/// Prévision exportée dans `~/Library/Application Support/UsageForecast/forecast.json`, pour qu'un statusline
/// ou un script la lise sans rien recalculer. `line` est un résumé prêt à afficher.
struct ForecastExport: Codable, Equatable {
    struct Window: Codable, Equatable {
        let percent: Double
        let resetsAt: Date?
        let projectedPercent: Double?
        let ratePerHour: Double?
        let exhaustsAt: Date?
        let perDayPercent: Double?
        let pace: String?
        /// Où l'on en serait à rythme parfaitement régulier (repère de la jauge).
        var expectedPercent: Double? = nil
    }

    struct Credits: Codable, Equatable {
        let balance: Double
        let currency: String
        let daysLeft: Int?
        let perDay: Double?
    }

    let version: Int
    let updatedAt: Date
    let session: Window?
    let weekly: Window?
    let usedTodayPercent: Double?
    let credits: Credits?
    let line: String

    static func make(now: Date, sessionPercent: Double?, sessionResetsAt: Date?, sessionForecast: WindowForecast?,
                     sessionRecent: RecentForecast?, weeklyPercent: Double?, weeklyResetsAt: Date?,
                     weeklyForecast: WindowForecast?, weeklyRecent: RecentForecast?, usedToday: Double?,
                     credits: ConsoleBalance?) -> ForecastExport {
        func window(_ percent: Double?, _ resets: Date?, _ forecast: WindowForecast?, _ recent: RecentForecast?, daily: Bool) -> Window? {
            guard let percent else { return nil }
            return Window(percent: percent, resetsAt: resets, projectedPercent: forecast?.projectedPercent,
                          ratePerHour: recent?.ratePerHour, exhaustsAt: recent?.exhaustsAt ?? forecast?.exhaustsAt,
                          perDayPercent: daily ? forecast?.remainingPerDay : nil, pace: forecast.map { paceName($0.pace) },
                          expectedPercent: forecast?.expectedPercent)
        }
        let session = window(sessionPercent, sessionResetsAt, sessionForecast, sessionRecent, daily: false)
        let weekly = window(weeklyPercent, weeklyResetsAt, weeklyForecast, weeklyRecent, daily: true)
        let creditsExport = credits.map {
            Credits(balance: $0.balance, currency: $0.currency, daysLeft: $0.daysLeft(now: now), perDay: $0.dailyBudget(now: now))
        }
        return ForecastExport(version: 1, updatedAt: now, session: session, weekly: weekly, usedTodayPercent: usedToday,
                              credits: creditsExport, line: summaryLine(session: session, weekly: weekly))
    }

    /// « Prévision · session ≈ 74 % (100 % vers 18 h 40) · semaine ≈ 59 % (24 %/j) ».
    private static func summaryLine(session: Window?, weekly: Window?) -> String {
        var parts: [String] = []
        if let projected = session?.projectedPercent {
            var text = "session ≈ \(Int(projected.rounded())) %"
            if let eta = session?.exhaustsAt { text += " (100 % vers \(AlertRules.moment(eta)))" }
            parts.append(text)
        }
        if let projected = weekly?.projectedPercent {
            var text = "semaine ≈ \(Int(projected.rounded())) %"
            if let perDay = weekly?.perDayPercent, (weekly?.percent ?? 0) < 100 { text += " (\(Int(perDay.rounded())) %/j)" }
            parts.append(text)
        }
        return parts.isEmpty ? "" : "Prévision · " + parts.joined(separator: " · ")
    }

    private static func paceName(_ pace: Pace) -> String {
        switch pace {
        case .under:   return "under"
        case .onTrack: return "onTrack"
        case .over:    return "over"
        }
    }

    func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(self)
    }

    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(AppSupport.folderName)/forecast.json")
    }
}
