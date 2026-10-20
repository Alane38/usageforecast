import AppKit

extension AppDelegate {
    /// `image` nil = étincelle, colorée selon `tone` ; sinon le dessin fourni (double anneau, deux valeurs).
    func updateStatusIcon(percentage: Int, title: String? = nil, image: NSImage? = nil, tone: UsageTone = .ok) {
        guard let button = statusItem.button else { return }
        button.image = image ?? createSparkIcon(color: MenuBarIcons.color(for: tone))
        button.title = title ?? " \(percentage)%"
    }

    /// Étincelle à huit branches, dessinée dans une grille de 16 × 16 points.
    func createSparkIcon(color: NSColor) -> NSImage {
        let outline: [(x: CGFloat, y: CGFloat)] = [
            (8, 1), (9, 6), (13, 3), (10, 7), (15, 8), (10, 9), (13, 13), (9, 10),
            (8, 15), (7, 10), (3, 13), (6, 9), (1, 8), (6, 7), (3, 3), (7, 6),
        ]
        let shape = NSBezierPath()
        for (index, corner) in outline.enumerated() {
            let point = NSPoint(x: corner.x, y: corner.y)
            index == 0 ? shape.move(to: point) : shape.line(to: point)
        }
        shape.close()

        let icon = NSImage(size: NSSize(width: 16, height: 16))
        icon.lockFocus()
        color.setFill()
        shape.fill()
        icon.unlockFocus()
        icon.isTemplate = false
        return icon
    }
}
