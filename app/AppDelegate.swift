import AppKit
import Carbon
import SwiftUI

/// Point d'entrée de l'app : possède l'item de la barre de menu, le popover et les gestionnaires de données.
/// Les comportements sont répartis dans les extensions `AppDelegate+…`.
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var anchorWindow: NSWindow?
    private(set) var statusItem: NSStatusItem!
    private(set) var popover: NSPopover!
    private(set) var usageManager: UsageManager!
    private(set) var statusManager: StatusManager!
    var eventMonitor: Any? = nil
    var hotKeyRef: EventHotKeyRef? = nil
    let settingsController = SettingsWindowController()
    let welcomeController = WelcomeWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.install()
        NSLog("✅ Application lancée, notifications prêtes")

        installStatusItem()
        installManagers()
        installPopover()

        trackAppearancePreference()

        refreshAll()
        scheduleRefresh()

        runNotificationTests()
        runCommandLineTools()
        setUpWelcome()
        applyDevelopmentOptions()

        scheduleCountdownTick()
        installKeyboardShortcut()
    }

    func refreshAll() {
        usageManager.fetchUsage()
        statusManager.fetch()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let barButton = item.button else { return }
        updateStatusIcon(percentage: 0, tone: .ok)
        barButton.target = self
        barButton.action = #selector(statusItemClicked)
        barButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
        barButton.appearsDisabled = false
        barButton.isEnabled = true
    }

    /// Les gestionnaires ont besoin de l'item de la barre de menu : il doit donc exister avant eux.
    private func installManagers() {
        let usage = UsageManager(statusItem: statusItem, delegate: self)
        let statuses = StatusManager()
        usageManager = usage
        statusManager = statuses
    }

    private func installPopover() {
        let content = NSHostingController(rootView: PopoverView(usageManager: usageManager, statusManager: statusManager))
        // Sans `preferredContentSize`, le contrôleur ne propage pas sa taille : le popover resterait à 320 pt
        // et l'en-tête serait rogné quand le contenu est plus haut.
        content.sizingOptions = [.preferredContentSize]

        let panel = NSPopover()
        panel.contentSize = NSSize(width: 360, height: 320)
        panel.behavior = .transient
        panel.delegate = self
        panel.contentViewController = content
        popover = panel
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

    /// Le décompte avant reset de la barre de menu avance chaque minute, sans appel réseau.
    private func scheduleCountdownTick() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.usageManager.refreshMenuBar()
        }
    }
}
