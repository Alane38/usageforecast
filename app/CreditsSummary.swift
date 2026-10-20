import Foundation

/// Ce que le popover affiche des crédits API, que la source soit la Console (en direct) ou une saisie manuelle.
struct CreditsSummary: Equatable {
    let title: String
    let valueText: String
    /// Part consommée, de 0 à 1.
    let usedFraction: Double
    let detail: String

    static func make(console: ConsoleBalance?, manual: ApiCredits?, now: Date = AppClock.now) -> CreditsSummary? {
        if let console { return fromConsole(console, now: now) }
        if let manual { return fromManual(manual, now: now) }
        return nil
    }

    private static func fromConsole(_ balance: ConsoleBalance, now: Date) -> CreditsSummary {
        var parts: [String] = []
        if let days = balance.daysLeft(now: now) { parts.append("Expirent dans \(days) j") }
        if let perDay = balance.dailyBudget(now: now) { parts.append("≈ \(money(perDay, balance.currency)) par jour") }
        return CreditsSummary(title: balance.promoName.map { "Crédits API · \(shortName($0))" } ?? "Crédits API",
                              valueText: money(balance.balance, balance.currency),
                              usedFraction: balance.promoUsedFraction ?? 0,
                              detail: parts.joined(separator: " · "))
    }

    private static func fromManual(_ credits: ApiCredits, now: Date) -> CreditsSummary {
        var parts = ["Expirent dans \(credits.daysLeft(now: now)) j"]
        if let perDay = credits.dailyBudget(now: now) { parts.append("≈ \(money(perDay, "USD")) par jour") }
        return CreditsSummary(title: "Crédits API (saisie manuelle)",
                              valueText: money(credits.remaining, "USD"),
                              usedFraction: credits.usedFraction,
                              detail: parts.joined(separator: " · "))
    }

    /// « API credit (Max 5x) » -> « Max 5x » : la parenthèse est ce qui distingue le plan.
    private static func shortName(_ name: String) -> String {
        guard let open = name.firstIndex(of: "("), let close = name.firstIndex(of: ")"), open < close else { return name }
        return String(name[name.index(after: open)..<close])
    }

    static func money(_ value: Double, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return "\(number) \(currency == "USD" ? "$" : currency)"
    }
}
