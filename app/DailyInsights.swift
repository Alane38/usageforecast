import Foundation

/// Une case du graphique des derniers jours : un jour du calendrier, avec ou sans données.
struct DayPoint: Equatable {
    let day: String
    let date: Date
    let summary: DailySummary?
    let isToday: Bool

    var isReliable: Bool { summary.map(DailyInsights.isReliable) ?? false }
}

struct WeekdayStat: Equatable {
    /// 0 = lundi … 6 = dimanche.
    let weekday: Int
    /// Moyenne des points de semaine consommés ces jours-là ; nil sans aucun jour fiable observé.
    let average: Double?
    /// Nombre de jours fiables observés.
    let count: Int

    /// Une moyenne n'est « solide » qu'à partir de trois occurrences du même jour.
    var isSolid: Bool { count >= DailyInsights.solidWeekdayCount }
}

struct HourStat: Equatable {
    let hour: Int
    let activeDays: Int
    let totalDays: Int

    var fraction: Double { totalDays > 0 ? Double(activeDays) / Double(totalDays) : 0 }
}

/// Semaine en cours comparée à la précédente **à jours égaux** : seuls les jours complets déjà passés comptent des deux côtés
/// (du lundi à hier), sans quoi une semaine entamée paraîtrait toujours en retard sur la précédente.
struct WeekComparison: Equatable {
    /// Nombre de jours complets de la semaine en cours (0 le lundi).
    let completedDays: Int
    let current: Double
    /// Les mêmes jours de la semaine précédente ; nil si elle n'a pas tous ces jours avec assez de relevés.
    let previous: Double?

    /// Écart en points ; nil sans semaine précédente exploitable.
    var delta: Double? { previous.map { current - $0 } }
}

enum DataConfidence: Equatable {
    case veryLow, building, good, solid

    init(reliableDays: Int) {
        switch reliableDays {
        case ..<3: self = .veryLow
        case ..<14: self = .building
        case ..<28: self = .good
        default: self = .solid
        }
    }

    var label: String {
        switch self {
        case .veryLow: return "Très peu de données"
        case .building: return "En construction"
        case .good: return "Correct"
        case .solid: return "Fiable"
        }
    }

    var detail: String {
        switch self {
        case .veryLow: return "Les moyennes par jour de la semaine apparaissent à partir de 3 jours identiques observés."
        case .building: return "Les tendances se précisent à chaque semaine qui passe."
        case .good: return "Assez de recul pour comparer tes semaines."
        case .solid: return "Plusieurs semaines complètes : ton rythme habituel est bien établi."
        }
    }
}

/// Statistiques pures calculées à partir du journal quotidien.
enum DailyInsights {
    /// Une journée est exploitable à partir de 5 h de relevés (300 minutes) : en dessous, l'app était trop souvent fermée.
    static let minReliableSamples = 300
    static let solidWeekdayCount = 3

    static func isReliable(_ summary: DailySummary) -> Bool { summary.samples >= minReliableSamples }

    static func date(fromStamp stamp: String, calendar: Calendar = .current) -> Date? {
        let parts = stamp.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// 0 = lundi … 6 = dimanche.
    static func weekdayIndex(of date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// Les `count` derniers jours, aujourd'hui compris, du plus ancien au plus récent. Un jour sans donnée reste présent (case vide).
    static func recentDays(_ summaries: [DailySummary], count: Int, now: Date = AppClock.now,
                           calendar: Calendar = .current) -> [DayPoint] {
        let byDay = Dictionary(summaries.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let day = DailyStats.stamp(for: date, calendar: calendar)
            return DayPoint(day: day, date: date, summary: byDay[day], isToday: offset == 0)
        }
    }

    /// Jours passés fiables (aujourd'hui exclu, car incomplet), sur les `window` derniers jours.
    static func reliablePastDays(_ summaries: [DailySummary], window: Int, now: Date = AppClock.now,
                                 calendar: Calendar = .current) -> [DailySummary] {
        recentDays(summaries, count: window, now: now, calendar: calendar)
            .filter { !$0.isToday }.compactMap(\.summary).filter(isReliable)
    }

    /// Consommation moyenne par jour (points de semaine) sur les jours passés fiables des 14 derniers jours.
    static func averagePerDay(_ summaries: [DailySummary], window: Int = 14, now: Date = AppClock.now,
                              calendar: Calendar = .current) -> (value: Double, days: Int)? {
        let days = reliablePastDays(summaries, window: window, now: now, calendar: calendar)
        guard !days.isEmpty else { return nil }
        return (days.map(\.weeklyUsed).reduce(0, +) / Double(days.count), days.count)
    }

    /// Le jour fiable le plus chargé (aujourd'hui compris s'il est déjà fiable).
    static func busiestDay(_ summaries: [DailySummary]) -> DailySummary? {
        summaries.filter(isReliable).max { $0.weeklyUsed < $1.weeklyUsed }
    }

    /// Moyenne par jour de la semaine, lundi en premier, sur les jours passés fiables des 12 dernières semaines.
    static func weekdayStats(_ summaries: [DailySummary], now: Date = AppClock.now, calendar: Calendar = .current) -> [WeekdayStat] {
        var buckets = [[Double]](repeating: [], count: 7)
        for summary in reliablePastDays(summaries, window: 84, now: now, calendar: calendar) {
            guard let date = date(fromStamp: summary.day, calendar: calendar) else { continue }
            buckets[weekdayIndex(of: date, calendar: calendar)].append(summary.weeklyUsed)
        }
        return buckets.enumerated().map { index, values in
            WeekdayStat(weekday: index, average: values.isEmpty ? nil : values.reduce(0, +) / Double(values.count), count: values.count)
        }
    }

    /// Pour chaque heure : sur combien de jours fiables (28 derniers jours, aujourd'hui exclu) l'usage a augmenté.
    static func hourStats(_ summaries: [DailySummary], window: Int = 28, now: Date = AppClock.now,
                          calendar: Calendar = .current) -> [HourStat] {
        let days = reliablePastDays(summaries, window: window, now: now, calendar: calendar)
        return (0..<24).map { hour in HourStat(hour: hour, activeDays: days.filter { $0.activeHours.contains(hour) }.count, totalDays: days.count) }
    }

    static func peakHour(_ stats: [HourStat]) -> HourStat? {
        stats.filter { $0.activeDays > 0 }.max { $0.activeDays < $1.activeDays }
    }

    /// Voir `WeekComparison` : les jours complets du lundi à hier, comparés aux mêmes jours de la semaine précédente.
    static func weekComparison(_ summaries: [DailySummary], now: Date = AppClock.now, calendar: Calendar = .current) -> WeekComparison {
        let today = calendar.startOfDay(for: now)
        let completed = weekdayIndex(of: today, calendar: calendar)
        let currentStart = calendar.date(byAdding: .day, value: -completed, to: today) ?? today
        let byDay = Dictionary(summaries.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
        func total(from start: Date) -> (sum: Double, usable: Int) {
            let days = (0..<completed).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
                .compactMap { byDay[DailyStats.stamp(for: $0, calendar: calendar)] }
            return (days.map(\.weeklyUsed).reduce(0, +), days.filter(isReliable).count)
        }
        let current = total(from: currentStart)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: currentStart) ?? currentStart
        let previous = total(from: previousStart)
        return WeekComparison(completedDays: completed, current: current.sum,
                              previous: completed > 0 && previous.usable == completed ? previous.sum : nil)
    }

    static func confidence(_ summaries: [DailySummary]) -> DataConfidence {
        DataConfidence(reliableDays: summaries.filter(isReliable).count)
    }
}
