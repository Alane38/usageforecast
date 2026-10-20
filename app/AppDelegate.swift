import CryptoKit
import SwiftUI
import AppKit
import WebKit
import Carbon
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var anchorWindow: NSWindow?
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var usageManager: UsageManager!
    var statusManager: StatusManager!
    var eventMonitor: Any?
    let settingsController = SettingsWindowController()
    let welcomeController = WelcomeWindowController()
    var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.install()
        NSLog("✅ App launched, notifications ready")

        // Create status bar item with variable length for compact display
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Create Claude logo as initial icon
            updateStatusIcon(percentage: 0)
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self

            // Force the button to be visible
            button.appearsDisabled = false
            button.isEnabled = true
        }

        // Initialize managers
        usageManager = UsageManager(statusItem: statusItem, delegate: self)
        statusManager = StatusManager()

        // Create popover
        popover = NSPopover()
        // Initial guess; SwiftUI's intrinsic size (capped at 600) will drive the actual size.
        popover.contentSize = NSSize(width: 360, height: 320)
        popover.behavior = .transient
        popover.delegate = self
        let hostingController = NSHostingController(rootView: PopoverView(
            usageManager: usageManager,
            statusManager: statusManager
        ))
        // Sans cela le contrôleur ne propage jamais sa taille : le popover reste à 320 pt
        // alors que le contenu est plus haut, et l'en-tête est rogné en haut.
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController

        // Appearance preference: "system" (default) tracks the macOS light/dark
        // setting; "dark"/"light" force one (dark was hard-forced in v1.3.2 and
        // users complained about losing light mode). Applied after the popover
        // exists so both NSApp and the popover get styled.
        applyAppearancePreference()

        // Re-apply when macOS flips light/dark, so a forced mode that matches
        // the system switches back to the native (inherited) rendering.
        DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            // The defaults key can lag the notification; re-resolve a tick later.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.applyAppearancePreference()
            }
        }

        // Fetch initial data
        usageManager.fetchUsage()
        statusManager.fetch()

        // Limites, crédits Console et statut Anthropic : une fois par minute,
        // ralenti à 5 min tant que l'API refuse (voir RefreshPolicy).
        scheduleRefresh()

        if CommandLine.arguments.contains("--test-alerts") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.usageManager.sendDemoAlerts() }
        }

        if CommandLine.arguments.contains("--test-notification") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.usageManager.sendTestNotification() }
        }

        runCommandLineTools()
        setUpWelcome()

        // Options de vérification visuelle : appliquées au lancement, jamais enregistrées dans les réglages.
        if let layout = Snapshot.option("--layout").flatMap(PopoverLayout.init(rawValue:)) { usageManager.popoverLayout = layout }
        if let style = Snapshot.option("--menubar").flatMap(MenuBarStyle.init(rawValue:)) { usageManager.menuBarStyle = style }
        if CommandLine.arguments.contains("--reset-in-menubar") { usageManager.menuBarShowReset = true }
        if CommandLine.arguments.contains("--settings-window") {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Snapshot.option("--wait").flatMap(Double.init) ?? 2)) { self.openSettings() }
        }

        if CommandLine.arguments.contains("--show") {
            // Mode développement : ouvre le popover au lancement, pour le vérifier sans cliquer.
            DispatchQueue.main.asyncAfter(deadline: .now() + (Snapshot.option("--wait").flatMap(Double.init) ?? 2)) { self.openPopover() }
        }

        if let snapshotPath = Snapshot.outputPath {
            // Laisse le temps au statusline/réseau de remplir les données, puis rend le popover et quitte.
            DispatchQueue.main.asyncAfter(deadline: .now() + (Snapshot.option("--wait").flatMap(Double.init) ?? 2)) {
                if let layout = Snapshot.option("--layout").flatMap(PopoverLayout.init(rawValue:)) { self.usageManager.popoverLayout = layout }
                if let style = Snapshot.option("--menubar").flatMap(MenuBarStyle.init(rawValue:)) { self.usageManager.menuBarStyle = style }
                if CommandLine.arguments.contains("--denied") {
                    self.usageManager.browserAccessDenied = true
                    self.usageManager.browserImportReport = "macOS bloque la lecture de ton navigateur : \(Brand.name) a besoin de l'Accès complet au disque."
                }
                if CommandLine.arguments.contains("--real-history") {
                    // Aperçu avec le vrai historique de l'utilisateur (lecture seule).
                    self.usageManager.historySamples = self.usageManager.history.load(since: Date().addingTimeInterval(-24 * 3600))
                    self.usageManager.hasFetchedData = true
                }
                if CommandLine.arguments.contains("--demo") {
                    // Données fictives pour l'aperçu uniquement : jamais écrites ailleurs que dans l'image.
                    // Horloge figée (19/10/2026, 12 h à Paris) : dates, jours du planning et décomptes identiques tous les jours.
                    AppClock.freeze(at: (ISO8601DateFormatter().date(from: "2026-10-19T10:00:00Z") ?? Date())
                        .addingTimeInterval(86400 * (Snapshot.option("--demo-day-shift").flatMap(Double.init) ?? 0)))
                    self.usageManager.sessionUsage = Snapshot.option("--session").flatMap(Int.init) ?? 8
                    self.usageManager.weeklyUsage = Snapshot.option("--weekly").flatMap(Int.init) ?? 37
                    self.usageManager.sessionResetsAt = AppClock.now.addingTimeInterval(Snapshot.option("--session-left").flatMap(Double.init) ?? (2 * 3600 + 14 * 60))
                    self.usageManager.weeklyResetsAt = AppClock.now.addingTimeInterval(2 * 86400 + 14 * 3600)
                    self.usageManager.lastUpdated = AppClock.now
                    self.usageManager.hasFetchedData = true
                    self.usageManager.historySamples = Snapshot.demoHistory(session: Double(self.usageManager.sessionUsage),
                                                                          hours: Snapshot.option("--history-hours").flatMap(Double.init) ?? 24)
                    self.usageManager.usedTodayOverride = Snapshot.option("--used-today").flatMap(Double.init)
                    // La démo n'utilise jamais les vrais identifiants de la synchro mobile.
                    let demoPair = MobileCrypto.demoPairing()
                    self.usageManager.mobilePairingOverride = UsageManager.MobilePairing(id: demoPair.id, cipherKey: SymmetricKey(data: demoPair.secret))
                    if CommandLine.arguments.contains("--demo-mobile") {
                        self.usageManager.mobileSyncEnabled = true
                        self.usageManager.mobileRelayText = "https://claude-usage-relay.exemple.workers.dev"
                        self.usageManager.mobileStatus = "Envoyé (24 Ko chiffrés)."
                        self.usageManager.mobileLastSuccess = AppClock.now.addingTimeInterval(-40)
                    }
                    self.usageManager.dailySummaries = Snapshot.demoDailySummaries(days: Snapshot.option("--demo-days").flatMap(Int.init) ?? 45)
                    self.usageManager.updatePercentages()
                    let deadline = AppClock.now.addingTimeInterval(16 * 86400)
                    self.usageManager.consoleBalance = ConsoleBalance(balance: 87.5, currency: "USD", spentThisPeriod: 12.5,
                                                                      periodResetsAt: deadline, nextExpiry: deadline,
                                                                      promoGranted: 100, promoName: "API credit (Max 5x)")
                    self.usageManager.consoleUpdatedAt = AppClock.now.addingTimeInterval(-120)
                }
                if let relay = Snapshot.option("--mobile-upload") {
                    // Essai de bout en bout : le vrai chemin (snapshot, chiffrement, requête) vers un relais local, avec les données de démonstration.
                    self.usageManager.mobileRelayText = relay
                    let outcome = self.usageManager.mobileUploadRequest().map { MobileUploader.uploadAndWait($0.request, bytes: $0.bytes) }
                    print("envoi mobile :", outcome?.message ?? "requête impossible")
                }
                if CommandLine.arguments.contains("--demo-update") {
                    let base = "https://github.com/Alane38/usageforecast/releases/download/v9.9.9/UsageForecast-9.9.9-arm64.zip"
                    self.usageManager.availableUpdate = ReleaseInfo(version: "9.9.9", pageURL: URL(string: "https://github.com/Alane38/usageforecast/releases")!,
                                                                    zipURL: URL(string: base), checksumURL: URL(string: base + ".sha256"))
                    switch Snapshot.option("--demo-update") {
                    case "working": self.usageManager.updateInstallState = .working("Téléchargement…")
                    case "failed": self.usageManager.updateInstallState = .failed("La somme SHA-256 ne correspond pas : archive corrompue ou modifiée, mise à jour refusée.")
                    default: break
                    }
                }
                if CommandLine.arguments.contains("--menubar-styles") {
                    Snapshot.write(view: VStack(alignment: .leading, spacing: 10) {
                        ForEach(MenuBarStyle.allCases, id: \.self) { style in
                            HStack(spacing: 12) {
                                Text(style.label).font(.caption).frame(width: 90, alignment: .leading)
                                MenuBarPreview(usageManager: self.usageManager, style: style)
                            }
                        }
                    }.padding(16), to: snapshotPath, size: NSSize(width: 320, height: 170))
                } else if CommandLine.arguments.contains("--welcome") {
                    Snapshot.write(view: WelcomeView(usageManager: self.usageManager, openConnections: {}, finish: {}), to: snapshotPath, size: NSSize(width: 520, height: 620))
                } else if CommandLine.arguments.contains("--settings") {
                    Snapshot.write(view: SettingsView(usageManager: self.usageManager, statusManager: self.statusManager),
                                   to: snapshotPath, size: NSSize(width: 560, height: Snapshot.option("--height").flatMap(Double.init).map { CGFloat($0) } ?? 560))
                } else {
                    Snapshot.write(view: PopoverView(usageManager: self.usageManager, statusManager: self.statusManager),
                                   to: snapshotPath, size: NSSize(width: 360, height: 640))
                }
                NSApp.terminate(nil)
            }
        }

        // Le décompte avant reset de la barre de menu avance chaque minute, sans appel réseau.
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.usageManager.refreshMenuBar()
        }

        // Set up Cmd+U keyboard shortcut
        setupKeyboardShortcut()
    }
}
