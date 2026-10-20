import Foundation

/// Évalue les règles d'alerte après chaque relevé et envoie les notifications nouvelles.
extension UsageManager {
    private static let ledgerStorageName = "alert_ledger"

    private static func settingsName(_ kind: AlertKind) -> String { "alert_enabled_\(kind.rawValue)" }

    func loadAlertState() {
        let defaults = UserDefaults.standard
        alertLedger = AlertLedger(sent: (defaults.dictionary(forKey: Self.ledgerStorageName) as? [String: Double]) ?? [:])
        alertSettings = AlertSettings(enabled: Set(AlertKind.allCases.filter {
            defaults.object(forKey: Self.settingsName($0)) as? Bool ?? true
        }))
    }

    /// Rythme moyen depuis le début de la fenêtre, quand l'historique récent manque.
    private func averageRate(used: Int, forecast: WindowForecast?) -> Double? {
        guard let forecast, forecast.expectedPercent > 0 else { return nil }
        return Double(used) / (forecast.expectedPercent / 100 * forecast.windowHours)
    }

    func setAlert(_ kind: AlertKind, enabled: Bool) {
        if enabled { alertSettings.enabled.insert(kind) } else { alertSettings.enabled.remove(kind) }
        UserDefaults.standard.set(enabled, forKey: Self.settingsName(kind))
    }

    func evaluateAlerts() {
        guard !isProbeRun else { return }
        let context = AlertContext(
            now: Date(),
            sessionPercent: Double(sessionUsage), sessionResetsAt: sessionResetsAt,
            sessionETA: sessionRecentForecast?.exhaustsAt ?? sessionForecast?.exhaustsAt,
            weeklyPercent: Double(weeklyUsage), weeklyResetsAt: weeklyResetsAt,
            weeklyETA: weeklyRecentForecast?.exhaustsAt ?? weeklyForecast?.exhaustsAt,
            previousSessionPercent: previousSessionPercent,
            consecutiveAuthFailures: consecutiveAuthFailures,
            credits: consoleBalance,
            sessionRatePerHour: sessionRecentRate ?? averageRate(used: sessionUsage, forecast: sessionForecast),
            weeklyRatePerHour: weeklyRecentRate ?? averageRate(used: weeklyUsage, forecast: weeklyForecast),
            weeklyBudgetPerDay: weeklyForecast?.remainingPerDay)
        let ledger = alertLedger
        let messages = AlertRules.evaluate(context, settings: alertSettings, alreadySent: { ledger.has($0) })
        for message in messages {
            Notifier.send(title: message.title, body: message.body, id: message.key)
            alertLedger.mark(message.key)
            NSLog("🔔 Alerte envoyée : \(message.kind.rawValue)")
        }
        if !messages.isEmpty { UserDefaults.standard.set(alertLedger.sent, forKey: Self.ledgerStorageName) }
        if hasFetchedData { previousSessionPercent = Double(sessionUsage) }
    }

    /// Envoie des alertes d'exemple (contexte fictif, registre vide en mémoire, rien n'est enregistré) :
    /// `--test-alerts` au lancement, ou le bouton des réglages pour voir les textes avant qu'une vraie alerte arrive.
    func sendDemoAlerts() {
        let now = Date()
        let credits = ConsoleBalance(balance: 100, currency: "USD", spentThisPeriod: 0, periodResetsAt: nil,
                                     nextExpiry: now.addingTimeInterval(4.2 * 86400), promoGranted: 100, promoName: "API credit (Max 5x)")
        let context = AlertContext(
            now: now, sessionPercent: 61, sessionResetsAt: now.addingTimeInterval(2 * 3600),
            sessionETA: now.addingTimeInterval(40 * 60), weeklyPercent: 60, weeklyResetsAt: now.addingTimeInterval(48 * 3600),
            weeklyETA: now.addingTimeInterval(10 * 3600), previousSessionPercent: nil, consecutiveAuthFailures: 3, credits: credits,
            sessionRatePerHour: 40, weeklyRatePerHour: 3.4, weeklyBudgetPerDay: 26)
        for message in AlertRules.evaluate(context, settings: AlertSettings(), alreadySent: { _ in false }) {
            Notifier.send(title: message.title, body: message.body, id: "demo-\(message.kind.rawValue)")
        }
    }
}

