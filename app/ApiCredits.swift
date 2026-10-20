import Foundation

/// Crédits API mensuels inclus dans Max/Team (Claude Platform). Aucun endpoint public ne donne le solde :
/// la dépense est saisie à la main (Console > Billing > Promotional credits), le reste est calculé.
struct ApiCredits: Equatable {
    let monthlyAmount: Double
    let spent: Double
    /// Fin du cycle de facturation : les crédits non dépensés expirent sans report.
    let cycleEndsAt: Date

    var remaining: Double { max(monthlyAmount - spent, 0) }
    var usedFraction: Double { monthlyAmount > 0 ? min(spent / monthlyAmount, 1) : 0 }

    func daysLeft(now: Date = AppClock.now) -> Int {
        max(Int(ceil(cycleEndsAt.timeIntervalSince(now) / 86400)), 0)
    }

    /// Dépense quotidienne qui vide exactement le solde à l'expiration.
    func dailyBudget(now: Date = AppClock.now) -> Double? {
        let days = daysLeft(now: now)
        return days > 0 ? remaining / Double(days) : nil
    }
}
