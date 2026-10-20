import Foundation

/// Part de la limite hebdomadaire utilisable chaque jour jusqu'au reset, au prorata des heures de chaque jour.
struct PlanSegment: Equatable {
    let label: String
    let percent: Double
    let isToday: Bool
    /// Ce qui est déjà consommé aujourd'hui, en % de la limite hebdomadaire (jauge du bloc « auj. »). nil pour les autres jours.
    var consumed: Double? = nil
}

/// Planning calculé depuis minuit : le bloc du jour garde sa taille quand on consomme, et se remplit.
struct DayPlan: Equatable {
    let usedBeforeToday: Double
    let segments: [PlanSegment]
}

enum WeekPlan {
    static func make(used: Double, now: Date, resetsAt: Date, calendar: Calendar = .current) -> [PlanSegment] {
        let remaining = 100 - min(max(used, 0), 100)
        return segments(from: now, remaining: remaining, now: now, resetsAt: resetsAt, calendar: calendar, consumedToday: nil)
    }

    /// Planning depuis minuit : `used` est l'usage hebdomadaire actuel, `usedToday` ce qui en a été consommé depuis minuit.
    /// Le premier bloc est le budget complet du jour (même valeur que `DayBudget`), rempli à hauteur de `usedToday`.
    static func makeFromMidnight(used: Double, usedToday: Double, now: Date, resetsAt: Date,
                                 calendar: Calendar = .current) -> DayPlan? {
        guard resetsAt > now, used < 100 else { return nil }
        let usedBefore = min(max(used - usedToday, 0), 100)
        let plan = segments(from: calendar.startOfDay(for: now), remaining: 100 - usedBefore, now: now, resetsAt: resetsAt,
                            calendar: calendar, consumedToday: max(usedToday, 0))
        return plan.isEmpty ? nil : DayPlan(usedBeforeToday: usedBefore, segments: plan)
    }

    private static func segments(from origin: Date, remaining: Double, now: Date, resetsAt: Date, calendar: Calendar,
                                 consumedToday: Double?) -> [PlanSegment] {
        let totalSeconds = resetsAt.timeIntervalSince(origin)
        guard totalSeconds > 0, remaining > 0 else { return [] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE"

        var result: [PlanSegment] = []
        var start = origin
        var dayIndex = 0
        while start < resetsAt, dayIndex < 10 {
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)) ?? resetsAt
            let end = min(nextMidnight, resetsAt)
            let share = remaining * end.timeIntervalSince(start) / totalSeconds
            let label = dayIndex == 0 ? "auj." : (dayIndex == 1 ? "dem." : formatter.string(from: start).replacingOccurrences(of: ".", with: ""))
            result.append(PlanSegment(label: label, percent: share, isToday: dayIndex == 0, consumed: dayIndex == 0 ? consumedToday : nil))
            start = end
            dayIndex += 1
        }
        return result
    }
}
