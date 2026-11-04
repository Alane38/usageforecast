import Foundation

/// Ce que le popover affiche des crédits API, que la source soit la Console (en direct) ou une saisie manuelle.
struct CreditsSummary: Equatable {
    let title: String
    let valueText: String
    /// Part consommée, de 0 à 1.
    let usedFraction: Double
    let detail: String
    /// Un lot par ligne quand la Console en donne plusieurs (sinon vide : la carte garde sa ligne unique).
    var lots: [LotRow] = []

    struct LotRow: Equatable {
        /// « 50,09 $ sur 100 $ » (ou le seul reste quand le montant accordé est inconnu).
        let amountText: String
        /// « expire le 05/11/2026 » : date en UTC, comme sur la Console.
        let whenText: String
        /// Part restante du lot, de 0 à 1 : l'anneau. nil si le montant accordé est inconnu.
        let remainingFraction: Double?
        /// Le lot qui expire en premier : mis en avant.
        let isNext: Bool
    }

    static func make(console: ConsoleBalance?, manual: ApiCredits?, now: Date = AppClock.now) -> CreditsSummary? {
        if let console { return fromConsole(console, now: now) }
        if let manual { return fromManual(manual, now: now) }
        return nil
    }

    private static func fromConsole(_ balance: ConsoleBalance, now: Date) -> CreditsSummary {
        return CreditsSummary(title: balance.promoName.map { "Crédits API · \(shortName($0))" } ?? "Crédits API",
                              valueText: money(balance.balance, balance.currency),
                              usedFraction: balance.promoUsedFraction ?? 0,
                              detail: expiryText(balance, now: now),
                              lots: lotRows(balance, now: now))
    }

    /// Une ligne par lot, du plus proche au plus lointain, comme le tableau de la Console ; vide s'il n'y a qu'une échéance.
    static func lotRows(_ balance: ConsoleBalance, now: Date) -> [LotRow] {
        guard !balance.laterLots(now: now).isEmpty, let next = balance.nextExpiry else { return [] }
        let sorted = balance.lots.filter { $0.remaining > 0 }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
        return sorted.map { lot in
            let left = money(lot.remaining, balance.currency)
            let amount = lot.granted.map { "\(left) sur \(money($0, balance.currency))" } ?? left
            let when = utcDate(lot.expiresAt).map { "expire le \($0)" } ?? "sans échéance"
            let fraction = lot.granted.flatMap { $0 > 0 ? min(lot.remaining / $0, 1) : nil }
            return LotRow(amountText: amount, whenText: when, remainingFraction: fraction, isNext: lot.expiresAt == next)
        }
    }

    private static func utcDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }

    /// « Expirent dans 6 j · ≈ 16,67 $ par jour » pour un seul échéancier ; avec plusieurs lots, seul le plus proche est annoncé :
    /// « 50,09 $ expirent dans 11 h · puis 100 $ le 5 déc. ». Annoncer tout le solde à la première échéance était faux.
    static func expiryText(_ balance: ConsoleBalance, now: Date, calendar: Calendar = .current) -> String {
        guard let days = balance.daysLeft(now: now), let next = balance.nextExpiry ?? balance.periodResetsAt else { return "" }
        let later = balance.laterLots(now: now)
        guard !later.isEmpty else {
            var parts = ["Expirent dans \(days) j"]
            if let perDay = balance.dailyBudget(now: now) { parts.append("≈ \(money(perDay, balance.currency)) par jour") }
            return parts.joined(separator: " · ")
        }
        let hours = Int(ceil(next.timeIntervalSince(now) / 3600))
        let when = hours <= 24 ? "dans \(max(hours, 1)) h" : "dans \(days) j"
        var first = "\(money(balance.expiringAmount(now: now), balance.currency)) expirent \(when)"
        if days >= 2, let perDay = balance.dailyBudget(now: now) { first += " (≈ \(money(perDay, balance.currency)) par jour)" }
        let laterTotal = later.map(\.remaining).reduce(0, +)
        let laterDate = shortDate(later[0].expiresAt, calendar: calendar).map { " le \($0)" } ?? ""
        return "\(first) · puis \(money(laterTotal, balance.currency))\(laterDate)"
    }

    private static func shortDate(_ date: Date?, calendar: Calendar) -> String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.timeZone = calendar.timeZone
        f.dateFormat = "d MMM"
        return f.string(from: date)
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
        let amounts = NumberFormatter()
        amounts.locale = Locale(identifier: "fr_FR")
        amounts.minimumFractionDigits = 0
        amounts.maximumFractionDigits = 2
        let number = amounts.string(from: NSNumber(value: value)) ?? String(value)
        return "\(number) \(currency == "USD" ? "$" : currency)"
    }
}
