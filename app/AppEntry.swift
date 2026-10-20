import SwiftUI
import AppKit

// Main entry point
@main
struct Main {
    static func main() {
        AppSupport.migrateLegacy()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
