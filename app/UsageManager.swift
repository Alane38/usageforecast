import SwiftUI
import AppKit

class UsageManager: ObservableObject {
    @Published var sessionUsage: Int = 0
    @Published var sessionLimit: Int = 100
    @Published var weeklyUsage: Int = 0
    @Published var weeklyLimit: Int = 100
    @Published var weeklySonnetUsage: Int = 0
    @Published var weeklySonnetLimit: Int = 100
    @Published var weeklyFableUsage: Int = 0
    @Published var weeklyFableLimit: Int = 100
    // Extra usage spend (from /overage_spend_limit). Shown only when there's spend.
    @Published var extraSpentMinor: Int = 0
    @Published var extraLimitMinor: Int = 0
    @Published var extraResetsAt: Date?
    @Published var freeCreditsMinor: Int = 0   // remaining free/promo credits (/prepaid/credits)
    // Banked usage-limit resets the user can trigger on claude.ai (e.g. the Opus 5.5
    // launch grant). Read-only here: using one is a POST on /reset_rate_limits.
    @Published var limitResetsLeft: Int = 0
    @Published var limitResetsEndAt: Date?
    @Published var creditCurrency: String = "USD"
    @Published var hasCreditUsage: Bool = false
    @Published var sessionResetsAt: Date?
    @Published var weeklyResetsAt: Date?
    @Published var weeklySonnetResetsAt: Date?
    @Published var weeklyFableResetsAt: Date?
    @Published var lastUpdated: Date = Date()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var usageNotificationsEnabled: Bool = true
    @Published var statusNotificationsEnabled: Bool = true
    @Published var openAtLogin: Bool = false
    @Published var hasWeeklySonnet: Bool = false
    @Published var hasWeeklyFable: Bool = false
    @Published var hasFetchedData: Bool = false
    @Published var isAccessibilityEnabled: Bool = false
    @Published var shortcutEnabled: Bool = true
    @Published var menuBarModes: [MenuBarStyle: MenuBarMode] = Dictionary(
        uniqueKeysWithValues: MenuBarStyle.allCases.map { ($0, MenuBarMode.defaultMode(for: $0)) })
    /// Valeur affichée du style courant : chaque style garde son propre choix.
    var menuBarMode: MenuBarMode {
        get { menuBarModes[menuBarStyle] ?? MenuBarMode.defaultMode(for: menuBarStyle) }
        set { menuBarModes[menuBarStyle] = newValue }
    }
    @Published var menuBarShowReset: Bool = false
    @Published var menuBarStyle: MenuBarStyle = .spark
    @Published var menuBarShowText: Bool = true
    @Published var exportsForecast: Bool = true
    @Published var popoverLayout: PopoverLayout = .gauges
    // Crédits API mensuels (Max/Team) : saisis à la main, la tuile n'apparaît qu'une fois la fin de cycle définie.
    @Published var apiCreditMonthly: Double = 100
    @Published var apiCreditSpent: Double = 0
    @Published var apiCreditCycleEnd: Date?

    var statusItem: NSStatusItem?
    var sessionCookie: String = ""
    var consoleCookie: String = ""
    var lastAutoImport: Date?
    let history = UsageHistory(url: UsageHistory.defaultURL)
    @Published var historySamples: [UsageSample] = []
    var lastRecordedAt: Date?
    let dailyHistory = DailyHistory(url: DailyHistory.defaultURL)
    @Published var dailySummaries: [DailySummary] = []
    var lastDailyUpdate: Date?
    var alertLedger = AlertLedger()
    var consecutiveAuthFailures = 0
    var previousSessionPercent: Double?
    @Published var alertSettings = AlertSettings()
    @Published var consoleBalance: ConsoleBalance?
    @Published var consoleUpdatedAt: Date?
    @Published var consoleStatus: String = ""
    @Published var browserImportReport: String = ""
    @Published var browserAccessDenied = false
    @Published var legacyImportReport = ""
    @Published var usageSource: String = ""
    /// Vrai quand l'API a refusé : rafraîchissement ralenti à 5 min jusqu'au prochain succès.
    @Published var isRefreshSlowed: Bool = false
    var refreshPolicy = RefreshPolicy()
    @Published var keychainIssue: String = ""
    @Published var availableUpdate: ReleaseInfo?
    @Published var updateCheckReport = ""
    @Published var updateInstallState: UpdateInstallState = .idle
    @Published var organizations: [Organization] = []
    @Published var selectedOrganizationId: String?
    var checksForUpdates = true
    // Synchro mobile (désactivée par défaut : rien ne quitte la machine tant qu'elle ne l'est pas).
    @Published var mobileSyncEnabled = false
    @Published var mobileRelayText = ""
    @Published var mobileStatus = ""
    @Published var mobileLastSuccess: Date?
    var lastMobileUpload: Date?
    var mobileUploadInFlight = false
    /// Démonstrations et essais uniquement : remplace l'identifiant et la clé réels.
    var mobilePairingOverride: MobilePairing?
    /// Aperçus uniquement (`--used-today`) : remplace la consommation du jour lue dans l'historique.
    var usedTodayOverride: Double?
    var lastUpdateCheck: Date?
    weak var delegate: AppDelegate?
    var lastNotifiedThreshold: Int = 0

    init(statusItem: NSStatusItem?, delegate: AppDelegate? = nil) {
        self.statusItem = statusItem
        self.delegate = delegate
        AppSecrets.migrateDevFilesToKeychain()
        loadHistory()
        loadAlertState()
        loadSessionCookie()
        loadConsoleCookie()
        loadSettings()
        checkAccessibilityStatus()
    }

    @Published var sessionPercentage: Double = 0.0
    @Published var weeklyPercentage: Double = 0.0
    @Published var weeklySonnetPercentage: Double = 0.0
    @Published var weeklyFablePercentage: Double = 0.0
}
