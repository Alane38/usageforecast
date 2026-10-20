import AppKit

/// Filet de sécurité : quand la barre de menu est pleine, macOS déplace l'icône hors écran et le popover
/// s'ouvrirait invisible. On l'ancre alors en haut à droite de l'écran.
extension AppDelegate {
    var isStatusItemVisible: Bool {
        if CommandLine.arguments.contains("--force-anchor") { return false }
        guard let frame = statusItem.button?.window?.frame else { return false }
        return NSScreen.screens.contains { $0.frame.intersects(frame) }
    }

    func showPopoverAtScreenCorner() {
        guard let screen = NSScreen.main else { return }
        let origin = NSPoint(x: screen.visibleFrame.maxX - 60, y: screen.visibleFrame.maxY - 1)
        let window = NSWindow(contentRect: NSRect(origin: origin, size: NSSize(width: 1, height: 1)),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.orderFrontRegardless()
        anchorWindow = window
        if let view = window.contentView { popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY) }
    }

    func removeAnchorWindow() {
        anchorWindow?.orderOut(nil)
        anchorWindow = nil
    }

    func popoverDidClose(_ notification: Notification) {
        removeAnchorWindow()
    }
}
