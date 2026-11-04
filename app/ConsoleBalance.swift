import Foundation

/// Un lot de crédits (acheté ou promotionnel) : sa part restante et sa propre date d'expiration.
struct CreditLot: Equatable {
    let remaining: Double
    let expiresAt: Date?
    /// Montant accordé au départ (« 50,09 $ sur 100 $ »), quand l'API le donne.
    var granted: Double? = nil
}

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
    /// Les lots restants avec leur échéance : l'expiration ne concerne que le lot le plus proche, pas tout le solde.
    var lots: [CreditLot] = []

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
            promoName: promoLots.compactMap { $0["name"] as? String }.first,
            lots: lots(in: root))
    }

    /// Jours avant la prochaine échéance connue : expiration des crédits, à défaut fin de période de dépense.
    func daysLeft(now: Date = AppClock.now) -> Int? {
        guard let deadline = nextExpiry ?? periodResetsAt else { return nil }
        return max(Int(ceil(deadline.timeIntervalSince(now) / 86400)), 0)
    }

    /// Montant qui expire à la prochaine échéance (les lots qui la partagent). Sans détail par lot, tout le solde.
    func expiringAmount(now: Date = AppClock.now) -> Double {
        guard let next = nextExpiry, next > now, !lots.isEmpty else { return balance }
        let sum = lots.filter { $0.expiresAt == next }.map(\.remaining).reduce(0, +)
        return sum > 0 ? sum : balance
    }

    /// Ce qui reste après la prochaine échéance : lots qui expirent plus tard, du plus proche au plus lointain.
    func laterLots(now: Date = AppClock.now) -> [CreditLot] {
        guard let next = nextExpiry else { return [] }
        return lots.filter { $0.remaining > 0 && ($0.expiresAt ?? .distantFuture) > next }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }

    /// À dépenser par jour pour ne rien perdre à la prochaine échéance (le lot qui expire, pas tout le solde).
    func dailyBudget(now: Date = AppClock.now) -> Double? {
        guard let days = daysLeft(now: now), days > 0 else { return nil }
        return expiringAmount(now: now) / Double(days)
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

    private static func lots(in root: [String: Any]) -> [CreditLot] {
        ["tranches", "promo_tranches"].flatMap { (root[$0] as? [[String: Any]]) ?? [] }.compactMap { lot in
            guard let remaining = number(lot["remaining_amount_minor_units"]) else { return nil }
            return CreditLot(remaining: remaining / 100, expiresAt: date(lot["expires_at"]),
                             granted: number(lot["granted_amount_minor_units"]).map { $0 / 100 })
        }
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
