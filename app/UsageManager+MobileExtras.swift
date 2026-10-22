import Foundation

/// Les informations avancées du popover que le téléphone affiche aussi : modèles, utilisation payante, courbe de la semaine.
extension UsageManager {
    func mobileWeekHistory(now: Date) -> [MobileSnapshot.HistoryPoint] {
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let samples = history.load(since: weekAgo)
        return MobileSnapshot.decimate(samples, bucket: 3_600).map { MobileSnapshot.HistoryPoint(t: $0.t, s: nil, w: $0.w) }
    }

    func mobileModels() -> [MobileSnapshot.ModelShare] {
        var shares: [MobileSnapshot.ModelShare] = []
        if hasWeeklySonnet { shares.append(.init(name: "Sonnet", percent: Double(weeklySonnetUsage))) }
        if hasWeeklyFable && weeklyFableUsage >= 1 { shares.append(.init(name: "Fable", percent: Double(weeklyFableUsage))) }
        return shares
    }

    func mobileExtraLines() -> [MobileSnapshot.ExtraLine] {
        func money(_ minor: Int) -> String { CreditsSummary.money(Double(minor) / 100, creditCurrency) }
        var lines: [MobileSnapshot.ExtraLine] = []
        if hasCreditUsage {
            let spent = extraSpentMinor, limit = extraLimitMinor
            lines.append(.init(label: "Utilisation supplémentaire",
                               text: limit > 0 ? "\(money(spent)) sur \(money(limit))" : "\(money(spent)) dépensés",
                               fraction: limit > 0 ? min(Double(spent) / Double(limit), 1) : nil))
        }
        if freeCreditsMinor > 0 {
            lines.append(.init(label: "Crédits gratuits", text: "\(money(freeCreditsMinor)) restants", fraction: nil))
        }
        if limitResetsLeft > 0 {
            let plural = limitResetsLeft > 1 ? "s" : ""
            lines.append(.init(label: "Réinitialisations de limite", text: "\(limitResetsLeft) disponible\(plural)", fraction: nil))
        }
        return lines
    }
}
