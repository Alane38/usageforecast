import Foundation

/// Cadence des envois vers le relais. L'offre gratuite de Cloudflare KV autorise 1 000 écritures par jour :
/// une écriture par minute (1 440 par jour) la dépassait. Ici : au plus une toutes les 5 minutes (288 par jour) et un plafond
/// quotidien de sécurité. Pas d'envoi « seulement si ça a changé » : le téléphone juge une donnée périmée au-delà de 10 minutes,
/// il faut donc toujours un envoi plus fréquent que ça.
enum MobileSyncPolicy {
    static let minInterval: TimeInterval = 300
    static let dailyCap = 800

    static func shouldSend(now: Date, lastSent: Date?, sentToday: Int, force: Bool) -> Bool {
        guard sentToday < dailyCap else { return false }
        if force { return true }
        guard let lastSent else { return true }
        return now.timeIntervalSince(lastSent) >= minInterval
    }

    /// Jour UTC : c'est à 00:00 UTC que Cloudflare remet le compteur à zéro.
    static func utcDayStamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
