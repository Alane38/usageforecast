import SwiftUI
import AppKit
import WebKit
import Carbon
import ServiceManagement

private enum SettingsKey {
    static let usageNotifications = "usage_notifications_enabled"
    static let statusNotifications = "status_notifications_enabled"
    static let legacyNotifications = "notifications_enabled"
    static let openAtLogin = "open_at_login"
    static let shortcut = "shortcut_enabled"
    static let lastNotifiedThreshold = "last_notified_threshold"
    static let legacyCookie = "claude_session_cookie"
}

private extension UserDefaults {
    func hasValue(forKey key: String) -> Bool { object(forKey: key) != nil }
}

extension UsageManager {
    func checkAccessibilityStatus() { isAccessibilityEnabled = AXIsProcessTrusted() }

    static let cookieStore = AppSecrets.store
    static let cookieAccount = AppSecrets.claudeAccount

    /// Lit le cookie dans le Keychain. Un cookie resté en clair dans UserDefaults (anciennes versions)
    /// est migré une fois, puis effacé du .plist.
    func loadSessionCookie() { restoreCookieFromSecretStore() }

    private func restoreCookieFromSecretStore() {
        guard !CommandLine.arguments.contains("--no-keychain") else { return }
        let stored = Self.cookieStore.readResult(account: Self.cookieAccount)
        if let value = stored.value {
            sessionCookie = value
            return
        }
        if stored.status != errSecItemNotFound {
            // L'élément existe mais la lecture est refusée (autorisation du trousseau non accordée).
            keychainIssue = "Stockage des secrets : accès refusé (code \(stored.status))"
        }
        guard let legacyCookie = UserDefaults.standard.string(forKey: SettingsKey.legacyCookie) else { return }
        sessionCookie = legacyCookie
        if Self.cookieStore.write(legacyCookie, account: Self.cookieAccount) {
            UserDefaults.standard.removeObject(forKey: SettingsKey.legacyCookie)
        }
    }

    func loadSettings() { restorePreferences() }

    private func restorePreferences() {
        let defaults = UserDefaults.standard
        migrateLegacyNotificationFlag(defaults)

        if defaults.hasValue(forKey: SettingsKey.usageNotifications) {
            usageNotificationsEnabled = defaults.bool(forKey: SettingsKey.usageNotifications)
        }
        if defaults.hasValue(forKey: SettingsKey.statusNotifications) {
            statusNotificationsEnabled = defaults.bool(forKey: SettingsKey.statusNotifications)
        }

        // L'état réel de l'élément de connexion système prime sur la valeur mémorisée.
        if #available(macOS 13, *) {
            openAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            openAtLogin = defaults.bool(forKey: SettingsKey.openAtLogin)
        }
        lastNotifiedThreshold = defaults.integer(forKey: SettingsKey.lastNotifiedThreshold)
        shortcutEnabled = defaults.hasValue(forKey: SettingsKey.shortcut)
            ? defaults.bool(forKey: SettingsKey.shortcut)
            : true
        loadDisplaySettings()
        loadSelectedOrganization()
    }

    /// Avant la v1.1, un seul réglage `notifications_enabled` couvrait les deux familles d'alertes.
    private func migrateLegacyNotificationFlag(_ defaults: UserDefaults) {
        let missingKeys = [SettingsKey.usageNotifications, SettingsKey.statusNotifications]
            .filter { !defaults.hasValue(forKey: $0) }
        guard !missingKeys.isEmpty else { return }

        let legacyValue = defaults.hasValue(forKey: SettingsKey.legacyNotifications)
            ? defaults.bool(forKey: SettingsKey.legacyNotifications)
            : true
        for key in missingKeys {
            defaults.set(legacyValue, forKey: key)
        }
        if missingKeys.contains(SettingsKey.usageNotifications) { self.usageNotificationsEnabled = legacyValue }
        if missingKeys.contains(SettingsKey.statusNotifications) { self.statusNotificationsEnabled = legacyValue }
    }

    var sessionForecast: WindowForecast? {
        guard let resetsAt = sessionResetsAt else { return nil }
        return UsageForecast.forecast(usedPercent: Double(sessionUsage), resetsAt: resetsAt, windowLength: UsageForecast.sessionLength)
    }

    var weeklyForecast: WindowForecast? {
        guard let resetsAt = weeklyResetsAt else { return nil }
        return UsageForecast.forecast(usedPercent: Double(weeklyUsage), resetsAt: resetsAt, windowLength: UsageForecast.weekLength)
    }

    var apiCredits: ApiCredits? {
        guard let cycleEnd = apiCreditCycleEnd else { return nil }
        return ApiCredits(monthlyAmount: apiCreditMonthly, spent: apiCreditSpent, cycleEndsAt: cycleEnd)
    }

    func saveSettings() { persistPreferences() }

    private func persistPreferences() {
        let defaults = UserDefaults.standard
        defaults.set(usageNotificationsEnabled, forKey: SettingsKey.usageNotifications)
        defaults.set(statusNotificationsEnabled, forKey: SettingsKey.statusNotifications)
        defaults.set(openAtLogin, forKey: SettingsKey.openAtLogin)
        defaults.set(shortcutEnabled, forKey: SettingsKey.shortcut)
        defaults.synchronize()
    }

    /// Inscrit ou retire réellement l'app des éléments de connexion de macOS.
    func applyLoginItem(_ enabled: Bool) { syncLoginItem(wanted: enabled) }

    private func syncLoginItem(wanted enabled: Bool) {
        guard #available(macOS 13, *) else { return }
        let service = SMAppService.mainApp
        let isRegistered = service.status == .enabled
        do {
            if enabled && !isRegistered {
                try service.register()
            } else if !enabled && isRegistered {
                try service.unregister()
            }
            NSLog("🔑 Lancement à la connexion \(enabled ? "activé" : "désactivé")")
        } catch {
            NSLog("❌ Lancement à la connexion impossible : \(error.localizedDescription)")
        }
    }

    func saveSessionCookie(_ cookie: String) { storeCookie(cookie) }

    private func storeCookie(_ cookie: String) {
        NSLog("Cookie enregistré (\(cookie.count) caractères)")
        self.sessionCookie = cookie
        let stored = Self.cookieStore.write(cookie, account: Self.cookieAccount)
        if !stored { NSLog("Écriture dans le stockage des secrets impossible : cookie gardé en mémoire seulement") }
    }

    func clearSessionCookie() { eraseCookieAndData() }

    private func eraseCookieAndData() {
        NSLog("Cookie effacé, données remises à zéro")
        self.sessionCookie = ""
        Self.cookieStore.delete(account: Self.cookieAccount)
        UserDefaults.standard.removeObject(forKey: SettingsKey.legacyCookie)
        resetUsageData()
        self.lastNotifiedThreshold = 0
        UserDefaults.standard.set(0, forKey: SettingsKey.lastNotifiedThreshold)
        self.delegate?.updateStatusIcon(percentage: 0)
    }

    private func resetUsageData() {
        (sessionUsage, weeklyUsage, weeklySonnetUsage, weeklyFableUsage) = (0, 0, 0, 0)
        (sessionResetsAt, weeklyResetsAt) = (nil, nil)
        (weeklySonnetResetsAt, weeklyFableResetsAt) = (nil, nil)
        (extraSpentMinor, extraLimitMinor, extraResetsAt) = (0, 0, nil)
        (freeCreditsMinor, limitResetsLeft, limitResetsEndAt) = (0, 0, nil)
        (hasCreditUsage, hasFetchedData) = (false, false)
        (hasWeeklySonnet, hasWeeklyFable) = (false, false)
        self.errorMessage = nil
    }
}
