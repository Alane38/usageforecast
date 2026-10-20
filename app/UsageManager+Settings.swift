import SwiftUI
import AppKit
import WebKit
import Carbon
import ServiceManagement

extension UsageManager {
    func checkAccessibilityStatus() {
        isAccessibilityEnabled = AXIsProcessTrusted()
    }

    static let cookieStore = AppSecrets.store
    static let cookieAccount = AppSecrets.claudeAccount

    /// Lit le cookie dans le Keychain. Un cookie resté en clair dans UserDefaults (anciennes versions)
    /// est migré une fois, puis effacé du .plist.
    func loadSessionCookie() {
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
        guard let legacy = UserDefaults.standard.string(forKey: "claude_session_cookie") else { return }
        sessionCookie = legacy
        if Self.cookieStore.write(legacy, account: Self.cookieAccount) {
            UserDefaults.standard.removeObject(forKey: "claude_session_cookie")
        }
    }

    func loadSettings() {
        // Migrate from legacy single notifications_enabled flag (pre-v1.1) to split flags
        let hasUsageKey  = UserDefaults.standard.object(forKey: "usage_notifications_enabled")  != nil
        let hasStatusKey = UserDefaults.standard.object(forKey: "status_notifications_enabled") != nil

        if !hasUsageKey || !hasStatusKey {
            let legacyHasKey = UserDefaults.standard.object(forKey: "notifications_enabled") != nil
            let legacyValue  = legacyHasKey ? UserDefaults.standard.bool(forKey: "notifications_enabled") : true
            if !hasUsageKey {
                usageNotificationsEnabled = legacyValue
                UserDefaults.standard.set(legacyValue, forKey: "usage_notifications_enabled")
            }
            if !hasStatusKey {
                statusNotificationsEnabled = legacyValue
                UserDefaults.standard.set(legacyValue, forKey: "status_notifications_enabled")
            }
        }
        if hasUsageKey {
            usageNotificationsEnabled = UserDefaults.standard.bool(forKey: "usage_notifications_enabled")
        }
        if hasStatusKey {
            statusNotificationsEnabled = UserDefaults.standard.bool(forKey: "status_notifications_enabled")
        }

        // Reflect the real system login-item state, not just a stored bool.
        if #available(macOS 13.0, *) {
            openAtLogin = (SMAppService.mainApp.status == .enabled)
        } else {
            openAtLogin = UserDefaults.standard.bool(forKey: "open_at_login")
        }
        lastNotifiedThreshold = UserDefaults.standard.integer(forKey: "last_notified_threshold")
        // Default shortcut to enabled if not previously set
        if UserDefaults.standard.object(forKey: "shortcut_enabled") == nil {
            shortcutEnabled = true
        } else {
            shortcutEnabled = UserDefaults.standard.bool(forKey: "shortcut_enabled")
        }
        loadDisplaySettings()
        loadSelectedOrganization()
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
        apiCreditCycleEnd.map { ApiCredits(monthlyAmount: apiCreditMonthly, spent: apiCreditSpent, cycleEndsAt: $0) }
    }

    func saveSettings() {
        UserDefaults.standard.set(usageNotificationsEnabled,  forKey: "usage_notifications_enabled")
        UserDefaults.standard.set(statusNotificationsEnabled, forKey: "status_notifications_enabled")
        UserDefaults.standard.set(openAtLogin, forKey: "open_at_login")
        UserDefaults.standard.set(shortcutEnabled, forKey: "shortcut_enabled")
        UserDefaults.standard.synchronize()
    }

    // Actually register/unregister the app as a macOS login item.
    func applyLoginItem(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            NSLog("🔑 Login item \(enabled ? "registered" : "unregistered")")
        } catch {
            NSLog("❌ Login item error: \(error.localizedDescription)")
        }
    }

    func saveSessionCookie(_ cookie: String) {
        NSLog("ClaudeUsage: Saving cookie, length: \(cookie.count)")
        sessionCookie = cookie
        if !Self.cookieStore.write(cookie, account: Self.cookieAccount) {
            NSLog("ClaudeUsage: secret storage write failed, cookie kept in memory only")
        }
    }

    func clearSessionCookie() {
        NSLog("ClaudeUsage: Clearing cookie")
        sessionCookie = ""
        Self.cookieStore.delete(account: Self.cookieAccount)
        UserDefaults.standard.removeObject(forKey: "claude_session_cookie")

        // Reset all data
        sessionUsage = 0
        weeklyUsage = 0
        weeklySonnetUsage = 0
        weeklyFableUsage = 0
        sessionResetsAt = nil
        weeklyResetsAt = nil
        weeklySonnetResetsAt = nil
        weeklyFableResetsAt = nil
        extraSpentMinor = 0
        extraLimitMinor = 0
        extraResetsAt = nil
        freeCreditsMinor = 0
        limitResetsLeft = 0
        limitResetsEndAt = nil
        hasCreditUsage = false
        hasFetchedData = false
        hasWeeklySonnet = false
        hasWeeklyFable = false
        errorMessage = nil
        lastNotifiedThreshold = 0
        UserDefaults.standard.set(0, forKey: "last_notified_threshold")

        // Update status bar to show 0%
        delegate?.updateStatusIcon(percentage: 0)

        NSLog("ClaudeUsage: Cookie cleared, data reset")
    }

}
