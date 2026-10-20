import AppKit

extension AppDelegate {
    func applicationWillTerminate(_ notification: Notification) { unregisterHotKey() }

    @objc func quitApp() { NSApp.terminate(nil) }

    /// Un double-clic sur l'app (Applications, Spotlight) ouvre la fenêtre : utile quand l'icône est masquée par un gestionnaire de barre de menu.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { showPopover() }
        return true
    }

    func openSettings() {
        popover.performClose(self)
        settingsController.show(usageManager: usageManager, statusManager: statusManager)
    }

    func scheduleRefresh() {
        let delay = usageManager.refreshPolicy.interval
        Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.refreshAll()
            self.scheduleRefresh()
        }
    }

    @objc func togglePopover() { popover.isShown ? hidePopover() : showPopover() }

    @objc func statusItemClicked() {
        guard let click = NSApp.currentEvent else { return }
        guard click.type == .rightMouseUp else {
            togglePopover()
            return
        }
        showContextMenu()
    }

    func showPopover() {
        guard let barButton = statusItem.button else { return }
        DispatchQueue.main.async { self.usageManager.updatePercentages() }

        if isStatusItemVisible {
            popover.show(relativeTo: barButton.bounds, of: barButton, preferredEdge: .minY)
        } else {
            showPopoverAtScreenCorner()
        }

        // Un popover « transient » ignore les clics dans d'autres apps : on les écoute pour le refermer.
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.hidePopover()
        }
    }

    func hidePopover() {
        defer { eventMonitor = nil }
        popover.performClose(self)
        removeAnchorWindow()
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
    }

    /// Le menu n'est attaché que le temps du clic : sinon il capterait aussi le clic gauche.
    private func showContextMenu() {
        let toggle = NSMenuItem(title: "Toggle Usage (⌘U)", action: #selector(togglePopover), keyEquivalent: "u")
        toggle.keyEquivalentModifierMask = .command
        let quit = NSMenuItem(title: "Quit \(Brand.name)", action: #selector(quitApp), keyEquivalent: "q")

        let contextMenu = NSMenu()
        contextMenu.items = [toggle, .separator(), quit]
        defer { statusItem.menu = nil }
        statusItem.menu = contextMenu
        statusItem.button?.performClick(self)
    }
}
