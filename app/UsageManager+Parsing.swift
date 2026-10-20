import SwiftUI
import AppKit

/// Lecture d'un nœud de la réponse : pourcentage (entier) et date de remise à zéro, chacun optionnel.
private struct WindowReading {
    var percent: Int?
    var resetDate: Date?

    /// Nœud classique : le pourcentage est dans `utilization`, toujours décimal.
    static func standard(_ node: [String: Any], label: String) -> WindowReading {
        let percent = (node["utilization"] as? Double).map { Int($0) }
        return WindowReading(percent: percent, resetDate: resetDate(in: node, label: label))
    }

    /// Entrée Fable de `limits` : `percent` peut être entier ou décimal selon la charge utile.
    static func fable(_ node: [String: Any]) -> WindowReading {
        let percent = (node["percent"] as? Int) ?? (node["percent"] as? Double).map { Int($0) }
        return WindowReading(percent: percent, resetDate: resetDate(in: node, label: "Weekly Fable"))
    }

    private static func resetDate(in node: [String: Any], label: String) -> Date? {
        guard let text = node["resets_at"] as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = formatter.date(from: text)
        NSLog(parsed == nil ? "❌ \(label) : date de remise à zéro illisible (\(text))"
                            : "🕐 \(label) : remise à zéro le \(parsed!)")
        return parsed
    }
}

extension UsageManager {
    private static let fullScale = 100
    private static let claudeSourceName = "claude.ai"
    private static let notificationSteps = [25, 50, 75, 90]
    private static let thresholdDefaultsKey = "last_notified_threshold"

    func parseUsageData(_ data: Data) { ingestUsagePayload(data) }

    private func ingestUsagePayload(_ data: Data) {
        let decoded: Any
        do {
            decoded = try JSONSerialization.jsonObject(with: data)
        } catch {
            NSLog("❌ Réponse illisible : \(error.localizedDescription)")
            self.errorMessage = "Parse error"
            return
        }
        guard let payload = decoded as? [String: Any] else {
            self.errorMessage = "Invalid JSON"
            return
        }

        readSessionAndWeekly(payload)
        readWeeklySonnet(payload["seven_day_sonnet"] as? [String: Any])
        readWeeklyFable(payload["limits"] as? [[String: Any]] ?? [])
        NSLog("✅ Relevé : session \(sessionUsage) %, semaine \(weeklyUsage) %, Sonnet \(hasWeeklySonnet ? weeklySonnetUsage : -1) %, Fable \(hasWeeklyFable ? weeklyFableUsage : -1) %")

        commitFreshReading()
    }

    private func commitFreshReading() {
        lastUpdated = .now
        usageSource = Self.claudeSourceName
        self.errorMessage = nil
        self.hasFetchedData = true
        recordSample()
        evaluateAlerts()
        self.updatePercentages()
    }

    private func readSessionAndWeekly(_ payload: [String: Any]) {
        if let node = payload["five_hour"] as? [String: Any] {
            let reading = WindowReading.standard(node, label: "Session")
            if let percent = reading.percent { (sessionUsage, sessionLimit) = (percent, Self.fullScale) }
            sessionResetsAt = reading.resetDate ?? sessionResetsAt
        }
        if let node = payload["seven_day"] as? [String: Any] {
            let reading = WindowReading.standard(node, label: "Weekly")
            if let percent = reading.percent { (weeklyUsage, weeklyLimit) = (percent, Self.fullScale) }
            weeklyResetsAt = reading.resetDate ?? weeklyResetsAt
        }
    }

    /// Réservé à certains forfaits : sans nœud, la barre disparaît.
    private func readWeeklySonnet(_ node: [String: Any]?) {
        hasWeeklySonnet = node != nil
        guard let node else { return }
        let reading = WindowReading.standard(node, label: "Weekly Sonnet")
        if let percent = reading.percent { (weeklySonnetUsage, weeklySonnetLimit) = (percent, Self.fullScale) }
        weeklySonnetResetsAt = reading.resetDate ?? weeklySonnetResetsAt
    }

    /// Fable n'a pas de clé propre : c'est une limite hebdomadaire par modèle dans `limits`.
    private func readWeeklyFable(_ limits: [[String: Any]]) {
        let fableEntry = limits.first { entry in
            let model = (entry["scope"] as? [String: Any])?["model"] as? [String: Any]
            return model?["display_name"] as? String == "Fable"
        }
        hasWeeklyFable = fableEntry != nil
        guard let fableEntry else { return }
        let reading = WindowReading.fable(fableEntry)
        weeklyFableUsage = reading.percent ?? weeklyFableUsage
        weeklyFableLimit = Self.fullScale
        weeklyFableResetsAt = reading.resetDate ?? weeklyFableResetsAt
    }

    func updateStatusBar() { refreshMenuBar(); checkNotificationThresholds(percentage: sessionPercentOfLimit) }

    private var sessionPercentOfLimit: Int {
        Int(Double(sessionUsage) / Double(sessionLimit) * 100)
    }

    /// Redessine l'icône et le titre sans toucher aux notifications (appelé aussi chaque minute pour le décompte).
    func refreshMenuBar() {
        let display = MenuBarDisplay.state(mode: menuBarMode,
                                           sessionPercent: sessionUsage, sessionResetsAt: sessionResetsAt,
                                           weeklyPercent: weeklyUsage, weeklyResetsAt: weeklyResetsAt,
                                           showReset: menuBarShowReset, showText: menuBarShowText)
        let icon = menuBarIcon()
        delegate?.updateStatusIcon(percentage: display.percent, title: display.title, image: icon.image, tone: icon.tone)
    }

    func checkNotificationThresholds(percentage: Int) {
        NSLog("🔔 Seuils : \(percentage) %, alertes \(usageNotificationsEnabled ? "actives" : "coupées"), dernier seuil notifié \(lastNotifiedThreshold) %")
        guard usageNotificationsEnabled else { return }

        for step in Self.notificationSteps where percentage >= step && lastNotifiedThreshold < step {
            sendNotification(percentage: percentage, threshold: step)
            rememberNotifiedThreshold(step)
        }

        guard percentage < lastNotifiedThreshold else { return }
        let reachedStep = Self.notificationSteps.last { $0 <= percentage } ?? 0
        NSLog("🔄 Seuil notifié ramené de \(lastNotifiedThreshold) % à \(reachedStep) %")
        rememberNotifiedThreshold(reachedStep)
    }

    private func rememberNotifiedThreshold(_ threshold: Int) {
        self.lastNotifiedThreshold = threshold
        let defaults = UserDefaults.standard
        defaults.set(threshold, forKey: Self.thresholdDefaultsKey)
        defaults.synchronize()
    }

    func sendNotification(percentage: Int, threshold: Int) {
        let title = "Session Claude à \(percentage) %"
        let body = "Tu as consommé \(percentage) % de ta session de 5 h."
        Notifier.send(title: title, body: body, id: "threshold-\(threshold)")
        NSLog("📬 Alerte envoyée pour le seuil de \(threshold) %")
    }

    func sendTestNotification() { postTestNotification() }

    private func postTestNotification() {
        Notifier.send(title: "Notification de test", body: "Les alertes de \(Brand.name) fonctionnent.")
        NSLog("📬 Alerte de test envoyée")
    }

    func updatePercentages() { recomputeProgressRatios() }

    private func recomputeProgressRatios() {
        let readings = [(sessionUsage, sessionLimit), (weeklyUsage, weeklyLimit),
                        (weeklySonnetUsage, weeklySonnetLimit), (weeklyFableUsage, weeklyFableLimit)]
            .map { Double($0.0) / Double($0.1) }
        (sessionPercentage, weeklyPercentage, weeklySonnetPercentage, weeklyFablePercentage)
            = (readings[0], readings[1], readings[2], readings[3])
    }
}
