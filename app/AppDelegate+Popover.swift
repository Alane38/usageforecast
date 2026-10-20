import SwiftUI
import AppKit

extension AppDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        unregisterGlobalHotKey()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func openSettings() {
        popover.performClose(nil)
        settingsController.show(usageManager: usageManager, statusManager: statusManager)
    }

    /// Un seul rafraîchissement à la fois : chaque passage programme le suivant avec l'intervalle du moment.
    func scheduleRefresh() {
        Timer.scheduledTimer(withTimeInterval: usageManager.refreshPolicy.interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.usageManager.fetchUsage()
            self.statusManager.fetch()
            self.scheduleRefresh()
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    @objc func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    /// Le menu n'est attaché que le temps du clic : sinon le clic gauche l'ouvrirait aussi.
    private func showContextMenu() {
        let toggleItem = NSMenuItem(title: "Toggle Usage (⌘U)", action: #selector(togglePopover), keyEquivalent: "u")
        toggleItem.keyEquivalentModifierMask = .command

        let menu = NSMenu()
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(Brand.name)", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func openPopover() {
        guard let button = statusItem.button else { return }
        // Force le rafraîchissement de l'affichage avant que le popover ne soit montré.
        DispatchQueue.main.async {
            self.usageManager.updatePercentages()
        }

        if isStatusItemVisible {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        } else {
            showPopoverAtScreenCorner()
        }
        watchClicksOutsidePopover()
    }

    private func watchClicksOutsidePopover() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover()
        }
    }

    func closePopover() {
        popover.performClose(nil)
        removeAnchorWindow()
        guard let monitor = eventMonitor else { return }
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
    }

    /// `image` nil = étincelle, colorée selon `tone` ; sinon le dessin fourni (double anneau, deux valeurs).
    func updateStatusIcon(percentage: Int, title: String? = nil, image: NSImage? = nil, tone: UsageTone = .ok) {
        guard let button = statusItem.button else { return }
        button.image = image ?? createSparkIcon(color: MenuBarIcons.color(for: tone))
        button.title = title ?? " \(percentage)%"
    }

    /// Étincelle à huit branches sur une grille de 16 × 16 points.
    func createSparkIcon(color: NSColor) -> NSImage {
        let outline: [NSPoint] = [
            (8, 1), (9, 6), (13, 3), (10, 7), (15, 8), (10, 9), (13, 13), (9, 10),
            (8, 15), (7, 10), (3, 13), (6, 9), (1, 8), (6, 7), (3, 3), (7, 6),
        ].map { NSPoint(x: $0.0, y: $0.1) }

        let spark = NSBezierPath()
        spark.move(to: outline[0])
        outline.dropFirst().forEach { spark.line(to: $0) }
        spark.close()

        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        color.setFill()
        spark.fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
