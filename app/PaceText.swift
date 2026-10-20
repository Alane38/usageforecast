import Foundation

/// Textes du rythme : le libellé suit la même logique que la couleur, pour ne jamais dire « en rythme » en jaune.
enum PaceText {
    static func chip(for forecast: WindowForecast?, percent: Int) -> String? {
        if percent >= 100 { return "Limite atteinte" }
        if percent >= 90 { return "Limite proche" }
        guard let forecast else { return percent >= 70 ? "Usage élevé" : nil }
        if forecast.pace == .over { return "Trop rapide" }
        if percent >= 70 { return "Usage élevé" }
        return forecast.pace == .under ? "En dessous du rythme" : "En rythme"
    }

    /// Version courte pour les cartes étroites : « En dessous du rythme » passerait sur deux lignes.
    static func compactChip(for forecast: WindowForecast?, percent: Int) -> String? {
        chip(for: forecast, percent: percent).map { $0 == "En dessous du rythme" ? "Sous le rythme" : $0 }
    }

    /// Session à 0 % sans heure de reset : aucune fenêtre de 5 h n'est ouverte (elle démarre au prochain message).
    static func idleSession(percent: Int, resetsAt: Date?) -> String? {
        percent == 0 && resetsAt == nil ? "Aucune session en cours" : nil
    }

    static func summary(for forecast: WindowForecast?, showsDailyBudget: Bool) -> String {
        var parts: [String] = []
        if let projected = forecast?.projectedPercent {
            parts.append("≈ \(Int(projected.rounded())) % au reset")
        }
        if showsDailyBudget, let perDay = forecast?.remainingPerDay, (forecast?.usedPercent ?? 0) < 100 {
            parts.append("\(Int(perDay.rounded())) % par jour")
        }
        return parts.joined(separator: " · ")
    }

    /// « Rythme récent : 12 %/h · 100 % vers 18 h 40 » ; nil quand le rythme est négligeable et sans échéance.
    static func recentLine(_ recent: RecentForecast?) -> String? {
        guard let recent, recent.ratePerHour >= 1 || recent.exhaustsAt != nil else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.maximumFractionDigits = recent.ratePerHour < 10 ? 1 : 0
        let rate = formatter.string(from: NSNumber(value: recent.ratePerHour)) ?? "?"
        var line = "Rythme récent : \(rate) %/h"
        if let eta = recent.exhaustsAt { line += " · 100 % vers \(AlertRules.clock(eta))" }
        return line
    }

    /// « Aujourd'hui : +9 % de la semaine » ; nil si l'historique du jour est trop court.
    static func todayLine(_ usedToday: Double?) -> String? {
        guard let usedToday else { return nil }
        return "Aujourd'hui : +\(Int(usedToday.rounded())) % de la semaine"
    }
}

