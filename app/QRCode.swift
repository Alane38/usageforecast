import AppKit
import CoreImage.CIFilterBuiltins

/// Code QR net (modules entiers, sans lissage) avec la marge blanche que les lecteurs exigent, même en mode sombre.
enum QRCode {
    static func image(for text: String, side: CGFloat = 220, margin: CGFloat = 14) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let inner = side - 2 * margin
        let scale = max(floor(inner / output.extent.width), 1)
        let rep = NSBitmapImageRep(ciImage: output.transformed(by: CGAffineTransform(scaleX: scale, y: scale)))
        let drawn = NSSize(width: output.extent.width * scale, height: output.extent.height * scale)
        let total = NSSize(width: drawn.width + 2 * margin, height: drawn.height + 2 * margin)
        return NSImage(size: total, flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            NSGraphicsContext.current?.imageInterpolation = .none
            rep.draw(in: NSRect(x: margin, y: margin, width: drawn.width, height: drawn.height))
            return true
        }
    }
}
