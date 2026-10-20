import AppKit
import SwiftUI

/// Fenêtre de réglages séparée du popover.
final class SettingsWindowController {
    private var window: NSWindow?

    func show(usageManager: UsageManager, statusManager: StatusManager) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView(usageManager: usageManager, statusManager: statusManager))
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "Réglages de \(Brand.name)"
        newWindow.styleMask = [.titled, .closable]
        newWindow.setContentSize(NSSize(width: 560, height: 560))
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject var usageManager: UsageManager
    @ObservedObject var statusManager: StatusManager

    @State private var tab = Snapshot.option("--tab") ?? "display"

    var body: some View {
        TabView(selection: $tab) {
            DisplayTab(usageManager: usageManager)
                .tabItem { Label("Affichage", systemImage: "paintbrush") }
                .tag("display")
            StatsTab(usageManager: usageManager)
                .tabItem { Label("Statistiques", systemImage: "chart.bar") }
                .tag("stats")
            ConnectionsTab(usageManager: usageManager)
                .tabItem { Label("Connexions", systemImage: "link") }
                .tag("connections")
            CreditsTab(usageManager: usageManager)
                .tabItem { Label("Crédits", systemImage: "creditcard") }
                .tag("credits")
            MobileTab(usageManager: usageManager)
                .tabItem { Label("Mobile", systemImage: "iphone") }
                .tag("mobile")
            AlertsTab(usageManager: usageManager, statusManager: statusManager)
                .tabItem { Label("Alertes", systemImage: "bell") }
                .tag("alerts")
            GeneralTab(usageManager: usageManager)
                .tabItem { Label("Général", systemImage: "gearshape") }
                .tag("general")
        }
        .frame(width: 560, height: Snapshot.option("--height").flatMap(Double.init).map { CGFloat($0) } ?? 560)
    }
}
