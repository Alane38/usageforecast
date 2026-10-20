import Foundation
import CryptoKit

/// Données fictives des aperçus (`--demo`) : jamais écrites ailleurs que dans l'image rendue.
extension AppDelegate {
    private func demoNumber(_ option: String) -> Double? { Snapshot.option(option).flatMap(Double.init) }

    func loadDemoData() {
        // Horloge figée (19/10/2026, 12 h à Paris) : dates, jours du planning et décomptes identiques tous les jours.
        let reference = ISO8601DateFormatter().date(from: "2026-10-19T10:00:00Z") ?? Date()
        AppClock.freeze(at: reference.addingTimeInterval(86400 * (demoNumber("--demo-day-shift") ?? 0)))
        loadDemoLimits()
        loadDemoMobile()
        loadDemoJournal()
        loadDemoConsole()
    }

    private func loadDemoLimits() {
        let now = AppClock.now
        usageManager.sessionUsage = Snapshot.option("--session").flatMap(Int.init) ?? 8
        usageManager.weeklyUsage = Snapshot.option("--weekly").flatMap(Int.init) ?? 37
        usageManager.sessionResetsAt = now.addingTimeInterval(demoNumber("--session-left") ?? (2 * 3600 + 14 * 60))
        usageManager.weeklyResetsAt = now.addingTimeInterval(2 * 86400 + 14 * 3600)
        usageManager.lastUpdated = now
        usageManager.hasFetchedData = true
        usageManager.historySamples = Snapshot.demoHistory(session: Double(usageManager.sessionUsage),
                                                           hours: demoNumber("--history-hours") ?? 24)
        usageManager.usedTodayOverride = demoNumber("--used-today")
    }

    private func loadDemoMobile() {
        // Les vrais identifiants de la synchro mobile ne servent jamais à la démo.
        let pairing = MobileCrypto.demoPairing()
        usageManager.mobilePairingOverride = UsageManager.MobilePairing(id: pairing.id, cipherKey: SymmetricKey(data: pairing.secret))
        guard CommandLine.arguments.contains("--demo-mobile") else { return }
        usageManager.mobileSyncEnabled = true
        usageManager.mobileRelayText = "https://claude-usage-relay.exemple.workers.dev"
        usageManager.mobileStatus = "Envoyé (24 Ko chiffrés)."
        usageManager.mobileLastSuccess = AppClock.now.addingTimeInterval(-40)
    }

    private func loadDemoJournal() {
        let days = Snapshot.option("--demo-days").flatMap(Int.init) ?? 45
        usageManager.dailySummaries = Snapshot.demoDailySummaries(days: days)
        usageManager.updatePercentages()
    }

    private func loadDemoConsole() {
        let deadline = AppClock.now.addingTimeInterval(16 * 86400)
        usageManager.consoleBalance = ConsoleBalance(balance: 87.5, currency: "USD", spentThisPeriod: 12.5,
                                                     periodResetsAt: deadline, nextExpiry: deadline,
                                                     promoGranted: 100, promoName: "API credit (Max 5x)")
        usageManager.consoleUpdatedAt = AppClock.now.addingTimeInterval(-120)
    }
}
