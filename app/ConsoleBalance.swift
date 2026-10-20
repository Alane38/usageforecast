import Foundation

/// Solde des crédits API (Console), lu sur `platform.claude.com/api/organizations/{org}/prepaid/credits`
/// et `current_spend`. Endpoints non documentés : le parsing reste tolérant et renvoie nil si `amount` manque.
/// Format réel observé : `amount` (centimes) = achetés + promotionnels ; les lots promo sont dans `promo_tranches`.
struct ConsoleBalance: Equatable {
    let balance: Double
    let currency: String
    let spentThisPeriod: Double?
    let periodResetsAt: Date?
    /// Plus proche expiration parmi les lots de crédits (promotionnels inclus), si l'API la donne.
    let nextExpiry: Date?
    /// Total accordé par les lots promotionnels (ex. 100 $ du plan Max 5x), pour mesurer la part consommée.
    let promoGranted: Double?
    let promoName: String?

    /// Part des crédits promotionnels déjà consommée, de 0 à 1.
    var promoUsedFraction: Double? {
        guard let granted = promoGranted, granted > 0 else { return nil }
        return min(max((granted - balance) / granted, 0), 1)
    }

    static func parse(credits: Data, spend: Data?, now: Date = AppClock.now) -> ConsoleBalance? {
        guard let root = try? JSONSerialization.jsonObject(with: credits) as? [String: Any],
              let amountMinor = number(root["amount"]) else { return nil }

        let spendRoot = spend.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let promoLots = (root["promo_tranches"] as? [[String: Any]]) ?? []
        let granted = promoLots.compactMap { number($0["granted_amount_minor_units"]) }.reduce(0, +)
        return ConsoleBalance(
            balance: amountMinor / 100,
            currency: (root["currency"] as? String) ?? "USD",
            spentThisPeriod: number(spendRoot?["amount"]).map { $0 / 100 },
            periodResetsAt: date(spendRoot?["resets_at"]),
            nextExpiry: date(root["next_expires_at"]).flatMap { $0 > now ? $0 : nil } ?? earliestExpiry(in: root, after: now),
            promoGranted: granted > 0 ? granted / 100 : nil,
            promoName: promoLots.compactMap { $0["name"] as? String }.first)
    }

    /// Jours avant la prochaine échéance connue : expiration des crédits, à défaut fin de période de dépense.
    func daysLeft(now: Date = AppClock.now) -> Int? {
        guard let deadline = nextExpiry ?? periodResetsAt else { return nil }
        return max(Int(ceil(deadline.timeIntervalSince(now) / 86400)), 0)
    }

    func dailyBudget(now: Date = AppClock.now) -> Double? {
        guard let days = daysLeft(now: now), days > 0 else { return nil }
        return balance / Double(days)
    }

    // MARK: - Lecture tolérante

    private static func number(_ value: Any?) -> Double? {
        if let int = value as? Int { return Double(int) }
        return value as? Double
    }

    private static func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    /// Cherche, dans chaque lot de `tranches` / `promo_tranches`, une clé d'échéance (`expires_at`, `expiry`…).
    private static func earliestExpiry(in root: [String: Any], after now: Date) -> Date? {
        let lots = ["tranches", "promo_tranches"].flatMap { (root[$0] as? [[String: Any]]) ?? [] }
        let deadlines = lots.flatMap { lot in
            lot.filter { $0.key.lowercased().contains("expir") }.compactMap { date($0.value) }
        }
        return deadlines.filter { $0 > now }.min()
    }
}
