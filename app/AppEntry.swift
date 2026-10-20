import AppKit
import SwiftUI

/// Point d'entrée : l'app vit dans la barre de menu, sans icône dans le Dock.
@main
struct Main {
    static func main() {
        AppSupport.migrateLegacy()
        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        application.delegate = appDelegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
