import Foundation

/// Remises à zéro de limite encore utilisables : lecture de l'objet `cedar_ember` de /usage.
extension UsageManager {

    /// Compte les remises utilisables (non suspendues, dans leur fenêtre de validité)
    /// et renvoie la plus proche date de fin parmi elles.
    static func parseLimitResets(_ raw: Any?, now: Date = Date()) -> (Int, Date?) {
        guard let object = raw as? [String: Any],
              object["eligible"] as? Bool == true,
              let grants = object["grants"] as? [[String: Any]] else { return (0, nil) }

        let parseDate = makeLenientISODateParser()
        let usable = grants.compactMap { usableReset(in: $0, now: now, parseDate: parseDate) }
        return (usable.reduce(0) { $0 + $1.count }, usable.map(\.endsAt).min())
    }

    private static func usableReset(in grant: [String: Any], now: Date,
                                    parseDate: (Any?) -> Date?) -> (count: Int, endsAt: Date)? {
        let count = grant["resets_left"] as? Int ?? 0
        guard count > 0, grant["paused"] as? Bool != true,
              let endsAt = parseDate(grant["ends_at"]), endsAt > now else { return nil }
        if let startsAt = parseDate(grant["starts_at"]), startsAt > now { return nil }
        return (count, endsAt)
    }

    /// Accepte les dates ISO avec ou sans fractions de seconde.
    private static func makeLenientISODateParser() -> (Any?) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        return { value in
            guard let text = value as? String else { return nil }
            return withFraction.date(from: text) ?? plain.date(from: text)
        }
    }
}
