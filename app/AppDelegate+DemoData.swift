import CryptoKit
import Foundation

/// Données fictives pour les aperçus (`--demo`) : jamais écrites ailleurs que dans l'image.
extension AppDelegate {
    func installDemoData() {
        freezeClockOnDemoDay()
        fillDemoUsage()
        fillDemoMobileSync()
        fillDemoHistory()
        fillDemoConsoleBalance()
        if DevFlags.isSet("--demo-loan") { fillDemoLoan() }
    }

    /// Horloge figée au 19/10/2026 à 12 h (Paris) : dates, jours du planning et décomptes identiques chaque jour.
    private func freezeClockOnDemoDay() {
        let noonInParis = ISO8601DateFormatter().date(from: "2026-10-19T10:00:00Z") ?? Date()
        let shift = DevFlags.number("--demo-day-shift") ?? 0
        AppClock.freeze(at: noonInParis.addingTimeInterval(86400 * shift))
    }

    private func fillDemoUsage() {
        let sessionLeft = DevFlags.number("--session-left") ?? (2 * 3600 + 14 * 60)
        usageManager.sessionUsage = DevFlags.integer("--session") ?? 8
        usageManager.weeklyUsage = DevFlags.integer("--weekly") ?? 37
        usageManager.sessionResetsAt = AppClock.now.addingTimeInterval(sessionLeft)
        usageManager.weeklyResetsAt = AppClock.now.addingTimeInterval(DevFlags.number("--weekly-left") ?? (2 * 86400 + 14 * 3600))
        usageManager.lastUpdated = AppClock.now
        usageManager.hasFetchedData = true
    }

    /// La démo n'utilise jamais les vrais identifiants de la synchro mobile.
    private func fillDemoMobileSync() {
        let pairing = MobileCrypto.demoPairing()
        usageManager.mobilePairingOverride = UsageManager.MobilePairing(id: pairing.id, cipherKey: SymmetricKey(data: pairing.secret))
        guard DevFlags.isSet("--demo-mobile") else { return }
        usageManager.mobileSyncEnabled = true
        usageManager.mobileRelayText = "https://usageforecast-relay.exemple.workers.dev"
        usageManager.mobileStatus = "Envoyé (24 Ko chiffrés)."
        usageManager.mobileLastSuccess = AppClock.now.addingTimeInterval(-40)
    }

    private func fillDemoHistory() {
        let hours = DevFlags.number("--history-hours") ?? 24
        usageManager.historySamples = Snapshot.demoHistory(session: Double(usageManager.sessionUsage), hours: hours)
        usageManager.usedTodayOverride = DevFlags.number("--used-today")
        usageManager.dailySummaries = Snapshot.demoDailySummaries(days: DevFlags.integer("--demo-days") ?? 45)
        usageManager.updatePercentages()
    }

    private func fillDemoConsoleBalance() {
        let sixteenDaysAhead = AppClock.now.addingTimeInterval(16 * 86400)
        usageManager.consoleBalance = ConsoleBalance(balance: 87.5, currency: "USD", spentThisPeriod: 12.5,
                                                     periodResetsAt: sixteenDaysAhead, nextExpiry: sixteenDaysAhead,
                                                     promoGranted: 100, promoName: "API credit (Max 5x)")
        usageManager.consoleUpdatedAt = AppClock.now.addingTimeInterval(-120)
    }
}
