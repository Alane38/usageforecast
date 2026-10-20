import Foundation

extension UsageManager {
    func loadDisplaySettings() {
        let defaults = UserDefaults.standard
        for style in MenuBarStyle.allCases {
            let key = style == .spark ? "menubar_mode" : "menubar_mode_\(style.rawValue)"
            menuBarModes[style] = MenuBarMode(rawValue: defaults.string(forKey: key) ?? "") ?? MenuBarMode.defaultMode(for: style)
        }
        menuBarShowReset = defaults.bool(forKey: "menubar_show_reset")
        menuBarShowText = defaults.object(forKey: "menubar_show_text") as? Bool ?? true
        exportsForecast = defaults.object(forKey: "export_forecast") as? Bool ?? true
        mobileSyncEnabled = defaults.bool(forKey: "mobile_sync_enabled")
        mobileRelayText = defaults.string(forKey: "mobile_relay_url") ?? ""
        checksForUpdates = defaults.object(forKey: "check_updates") as? Bool ?? true
        lastUpdateCheck = defaults.object(forKey: "last_update_check") as? Date
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: "menubar_style") ?? "") ?? .spark
        popoverLayout = PopoverLayout(rawValue: defaults.string(forKey: "popover_layout") ?? "") ?? .gauges
        if defaults.object(forKey: "api_credit_monthly") != nil {
            apiCreditMonthly = defaults.double(forKey: "api_credit_monthly")
        }
        apiCreditSpent = defaults.double(forKey: "api_credit_spent")
        apiCreditCycleEnd = defaults.object(forKey: "api_credit_cycle_end") as? Date
    }

    func saveDisplaySettings() {
        let defaults = UserDefaults.standard
        for (style, mode) in menuBarModes {
            defaults.set(mode.rawValue, forKey: style == .spark ? "menubar_mode" : "menubar_mode_\(style.rawValue)")
        }
        defaults.set(menuBarShowReset, forKey: "menubar_show_reset")
        defaults.set(menuBarShowText, forKey: "menubar_show_text")
        defaults.set(exportsForecast, forKey: "export_forecast")
        defaults.set(mobileSyncEnabled, forKey: "mobile_sync_enabled")
        defaults.set(mobileRelayText, forKey: "mobile_relay_url")
        defaults.set(checksForUpdates, forKey: "check_updates")
        if !exportsForecast { try? FileManager.default.removeItem(at: ForecastExport.defaultURL) }
        defaults.set(menuBarStyle.rawValue, forKey: "menubar_style")
        defaults.set(popoverLayout.rawValue, forKey: "popover_layout")
        defaults.set(apiCreditMonthly, forKey: "api_credit_monthly")
        defaults.set(apiCreditSpent, forKey: "api_credit_spent")
        if let cycleEnd = apiCreditCycleEnd {
            defaults.set(cycleEnd, forKey: "api_credit_cycle_end")
        } else {
            defaults.removeObject(forKey: "api_credit_cycle_end")
        }
        refreshMenuBar()
    }
}
