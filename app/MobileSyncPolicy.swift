import Foundation

/// Cadence des envois vers le relais. L'offre gratuite de Cloudflare KV autorise 1 000 écritures par jour :
/// une écriture par minute (1 440 par jour) la dépassait. Ici : au plus une toutes les 5 minutes (288 par jour),
/// rien si les valeurs n'ont pas bougé (sauf un envoi de présence toutes les 20 minutes), et un plafond quotidien de sécurité.
enum MobileSyncPolicy {
    static let minInterval: TimeInterval = 300
    static let heartbeat: TimeInterval = 1200
    static let dailyCap = 800

    static func shouldSend(now: Date, lastSent: Date?, changed: Bool, sentToday: Int, force: Bool) -> Bool {
        guard sentToday < dailyCap else { return false }
        if force { return true }
        guard let lastSent else { return true }
        let elapsed = now.timeIntervalSince(lastSent)
        guard elapsed >= minInterval else { return false }
        return changed || elapsed >= heartbeat
    }

    /// Jour UTC : c'est à 00:00 UTC que Cloudflare remet le compteur à zéro.
    static func utcDayStamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
