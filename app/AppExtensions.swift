import SwiftUI

private extension NSColor {
    /// En thème clair, le gris translucide du système paraît délavé sur le fond vibrant du popover :
    /// on impose un gris foncé opaque.
    static let adaptiveSecondary = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .secondaryLabelColor : NSColor(white: 0.24, alpha: 1)
    }
}

extension Color {
    static let secondaryText = Color(nsColor: .adaptiveSecondary)
}

extension NSColor {
    /// Couleur au format `#RRGGBB` (noir si la conversion en RVB échoue).
    var hexString: String { hexDescription ?? "#000000" }

    private var hexDescription: String? {
        guard let rgb = usingColorSpace(.deviceRGB) else { return nil }
        let channels = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
        return "#" + channels.map { String(format: "%02X", Int($0 * 255)) }.joined()
    }
}
