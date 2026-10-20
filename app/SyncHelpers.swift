import Foundation

enum SyncHelpers {
    /// Identifiant d'organisation porté par le cookie `lastActiveOrg` d'un en-tête Cookie.
    static func organizationId(fromCookie cookie: String) -> String? {
        for part in cookie.components(separatedBy: ";") {
            let pair = part.trimmingCharacters(in: .whitespaces)
            guard pair.hasPrefix("lastActiveOrg=") else { continue }
            let value = String(pair.dropFirst("lastActiveOrg=".count))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// « à l'instant », « il y a 12 min », « il y a 3 h », « il y a 2 j ».
    static func age(since date: Date, now: Date = AppClock.now) -> String {
        let minutes = max(Int(now.timeIntervalSince(date) / 60), 0)
        if minutes < 1 { return "à l'instant" }
        if minutes < 60 { return "il y a \(minutes) min" }
        if minutes < 1440 { return "il y a \(minutes / 60) h" }
        return "il y a \(minutes / 1440) j"
    }

    /// Une donnée de plus de 10 minutes est signalée comme périmée (statusline sans session Claude Code active).
    static func isStale(_ date: Date, now: Date = AppClock.now) -> Bool {
        now.timeIntervalSince(date) > 600
    }
}
