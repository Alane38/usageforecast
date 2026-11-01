import SwiftUI
import AppKit

/// État central de l'app : limites, crédits, réglages et synchronisations.
/// Les extensions `UsageManager+*` portent la logique ; ici, seulement les données.
class UsageManager: ObservableObject {

    // MARK: Limites d'usage (valeur, plafond, date de remise à zéro)

    @Published var sessionUsage = 0
    @Published var sessionLimit = 100
    @Published var sessionResetsAt: Date? = nil
    @Published var weeklyUsage = 0
    @Published var weeklyLimit = 100
    @Published var weeklyResetsAt: Date? = nil
    @Published var weeklySonnetUsage = 0
    @Published var weeklySonnetLimit = 100
    @Published var weeklySonnetResetsAt: Date? = nil
    @Published var weeklyFableUsage = 0
    @Published var weeklyFableLimit = 100
    @Published var weeklyFableResetsAt: Date? = nil
    @Published var hasWeeklySonnet = false
    @Published var hasWeeklyFable = false

    // Pourcentages dérivés, recalculés par `updatePercentages()`.
    @Published var sessionPercentage = 0.0
    @Published var weeklyPercentage = 0.0
    @Published var weeklySonnetPercentage = 0.0
    @Published var weeklyFablePercentage = 0.0

    // MARK: Dépassement, crédits et remises à zéro

    /// Dépense hors forfait (/overage_spend_limit), affichée seulement s'il y en a.
    @Published var extraSpentMinor = 0
    @Published var extraLimitMinor = 0
    @Published var extraResetsAt: Date? = nil
    /// Crédits gratuits ou promotionnels restants (/prepaid/credits).
    @Published var freeCreditsMinor = 0
    /// Remises à zéro de limite en réserve, utilisables sur claude.ai (ex. l'offre de
    /// lancement d'Opus 5.5). Lecture seule ici : en utiliser une est un POST sur /reset_rate_limits.
    @Published var limitResetsLeft = 0
    @Published var limitResetsEndAt: Date? = nil
    @Published var creditCurrency = "USD"
    @Published var hasCreditUsage = false
    /// Crédits API mensuels (Max/Team) saisis à la main : la tuile n'apparaît qu'une fois la fin de cycle connue.
    @Published var apiCreditMonthly = 100.0
    @Published var apiCreditSpent = 0.0
    @Published var apiCreditCycleEnd: Date? = nil

    // MARK: Chargement et provenance des données

    @Published var lastUpdated = Date()
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var hasFetchedData = false
    @Published var usageSource = ""
    /// Vrai quand l'API a refusé : rafraîchissement ralenti à 5 min jusqu'au prochain succès.
    @Published var isRefreshSlowed = false
    var refreshPolicy = RefreshPolicy()
    var consecutiveAuthFailures = 0

    // MARK: Réglages d'affichage et de notification

    @Published var usageNotificationsEnabled = true
    @Published var statusNotificationsEnabled = true
    @Published var openAtLogin = false
    @Published var isAccessibilityEnabled = false
    @Published var shortcutEnabled = true
    @Published var menuBarShowReset = false
    @Published var menuBarStyle: MenuBarStyle = .spark
    @Published var menuBarShowText = true
    @Published var exportsForecast = true
    @Published var popoverLayout: PopoverLayout = .gauges
    @Published var alertSettings = AlertSettings()
    @Published var menuBarModes: [MenuBarStyle: MenuBarMode] = Dictionary(
        uniqueKeysWithValues: MenuBarStyle.allCases.map { ($0, MenuBarMode.defaultMode(for: $0)) })

    /// Mode du style courant : chaque style mémorise son propre choix.
    var menuBarMode: MenuBarMode {
        get { menuBarModes[menuBarStyle] ?? MenuBarMode.defaultMode(for: menuBarStyle) }
        set { menuBarModes[menuBarStyle] = newValue }
    }

    // MARK: Historique et alertes

    let history = UsageHistory(url: UsageHistory.defaultURL)
    let dailyHistory = DailyHistory(url: DailyHistory.defaultURL)
    @Published var historySamples: [UsageSample] = []
    @Published var dailySummaries: [DailySummary] = []
    var lastRecordedAt: Date? = nil
    var lastDailyUpdate: Date? = nil
    var alertLedger = AlertLedger()
    var previousSessionPercent: Double? = nil
    var lastNotifiedThreshold = 0
    /// Aperçus uniquement (`--used-today`) : remplace la consommation du jour lue dans l'historique.
    var usedTodayOverride: Double? = nil

    // MARK: Sessions, Console et organisations

    var sessionCookie = ""
    var consoleCookie = ""
    var lastAutoImport: Date? = nil
    @Published var consoleBalance: ConsoleBalance? = nil
    @Published var consoleUpdatedAt: Date? = nil
    @Published var consoleStatus = ""
    @Published var browserImportReport = ""
    @Published var browserAccessDenied = false
    @Published var legacyImportReport = ""
    @Published var keychainIssue = ""
    @Published var organizations: [Organization] = []
    @Published var selectedOrganizationId: String? = nil

    // MARK: Mises à jour de l'app

    var checksForUpdates: Bool = true
    var lastUpdateCheck: Date? = nil
    @Published var availableUpdate: ReleaseInfo? = nil
    @Published var updateCheckReport = ""
    @Published var updateInstallState: UpdateInstallState = .idle

    // MARK: Synchronisation mobile (désactivée par défaut : rien ne quitte la machine sinon)

    @Published var mobileSyncEnabled = false
    @Published var mobileRelayText = ""
    @Published var mobileStatus = ""
    @Published var mobileLastSuccess: Date? = nil
    var lastMobileUpload: Date? = nil
    var mobileUploadInFlight = false
    /// Démonstrations et essais uniquement : remplace l'identifiant et la clé réels.
    var mobilePairingOverride: MobilePairing? = nil

    // MARK: Prêt de quota (ADR 003) : une part de la semaine prêtée à une autre personne

    @Published var loan: Loan? = nil
    @Published var loanState: LoanState? = nil
    @Published var guestReport: GuestReport? = nil
    @Published var loanStatus = ""
    @Published var loanAlertsEnabled = true
    var lastLoanRefresh: Date? = nil
    let transcriptScanner = TranscriptScanner()

    // MARK: Liaison avec l'app

    var statusItem: NSStatusItem?
    weak var delegate: AppDelegate? = nil

    init(statusItem: NSStatusItem?, delegate: AppDelegate? = nil) {
        (self.statusItem, self.delegate) = (statusItem, delegate)
        AppSecrets.migrateDevFilesToKeychain()
        // Ordre significatif : les réglages se chargent après les secrets et l'historique.
        let restoreSteps = [loadHistory, loadAlertState, loadSessionCookie,
                            loadConsoleCookie, loadSettings, loadLoan, checkAccessibilityStatus]
        restoreSteps.forEach { $0() }
    }
}
