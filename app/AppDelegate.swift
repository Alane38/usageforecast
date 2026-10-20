import SwiftUI
import AppKit
import Carbon

/// Point d'entrée de l'app de barre de menu : crée l'icône, le popover et les gestionnaires, puis branche
/// les rafraîchissements périodiques. Les autres responsabilités vivent dans les extensions `AppDelegate+…`.
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
        NSLog("✅ Application lancée, notifications prêtes")

        installStatusItem()
        usageManager = UsageManager(statusItem: statusItem, delegate: self)
        statusManager = StatusManager()
        installPopover()
        applyAppearancePreference()
        followSystemAppearance()

        usageManager.fetchUsage()
        statusManager.fetch()
        // Limites, crédits Console et statut Anthropic : une fois par minute,
        // ralenti à 5 min tant que l'API refuse (voir RefreshPolicy).
        scheduleRefresh()

        runNotificationTests()
        runCommandLineTools()
        setUpWelcome()
        runDevelopmentModes()

        // Le décompte avant reset de la barre de menu avance chaque minute, sans appel réseau.
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.usageManager.refreshMenuBar()
        }

        setupKeyboardShortcut()
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        updateStatusIcon(percentage: 0)
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
        button.appearsDisabled = false
        button.isEnabled = true
    }

    private func installPopover() {
        let content = NSHostingController(rootView: PopoverView(usageManager: usageManager, statusManager: statusManager))
        // Sans cette option le contrôleur ne propage jamais sa taille : le popover reste à 320 pt
        // alors que le contenu est plus haut, et l'en-tête est rogné en haut.
        content.sizingOptions = [.preferredContentSize]

        popover = NSPopover()
        // Taille de départ : la taille intrinsèque de SwiftUI (plafonnée à 600) prend ensuite le relais.
        popover.contentSize = NSSize(width: 360, height: 320)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = content
    }

    /// Quand macOS bascule clair/sombre, un mode forcé identique au système doit revenir au rendu natif.
    private func followSystemAppearance() {
        DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            // La clé des préférences peut avoir un léger retard sur la notification : on relit un instant plus tard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.applyAppearancePreference()
            }
        }
    }

    private func runNotificationTests() {
        let arguments = CommandLine.arguments
        if arguments.contains("--test-alerts") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.usageManager.sendDemoAlerts() }
        }
        if arguments.contains("--test-notification") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.usageManager.sendTestNotification() }
        }
    }
}
