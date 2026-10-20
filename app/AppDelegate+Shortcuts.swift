import SwiftUI
import AppKit
import Carbon

/// Réception du raccourci global : fonction libre car un rappel Carbon ne peut rien capturer ;
/// l'instance arrive par le pointeur `userData`.
private func hotKeyPressed(_ nextHandler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        delegate.togglePopover()
    }
    return noErr
}

extension AppDelegate {
    /// Thème : « system » suit macOS, « dark » et « light » le forcent.
    func applyAppearancePreference() {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: "appearance_mode") ?? "system"
        let isDark: Bool
        switch mode {
        case "dark": isDark = true
        case "light": isDark = false
        default: isDark = defaults.string(forKey: "AppleInterfaceStyle") == "Dark"
        }
        // On pose toujours une apparence explicite, même en mode « system » : le rendu hérité (vibrant)
        // perd la teinte des barres de progression (elles passent au bleu d'accentuation) et nuance
        // légèrement les couleurs, si bien que Système et Sombre ne se ressemblaient pas.
        // Le popover reçoit la sienne : NSApp.appearance seule ne le restyle pas une fois créé.
        let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        NSApp.appearance = appearance
        popover?.appearance = appearance
    }

    func setupKeyboardShortcut() {
        checkAccessibilityPermissions()
        if usageManager.shortcutEnabled {
            registerGlobalHotKey()
        }
    }

    func setShortcutEnabled(_ enabled: Bool) {
        if enabled {
            registerGlobalHotKey()
        } else {
            unregisterGlobalHotKey()
        }
    }

    func checkAccessibilityPermissions() {
        guard !AXIsProcessTrusted() else {
            NSLog("✅ Permission Accessibilité accordée")
            return
        }
        NSLog("⚠️ Permission Accessibilité non accordée")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "\(Brand.name) needs Accessibility permission to use the Cmd+U keyboard shortcut.\n\nPlease enable it in:\nSystem Settings → Privacy & Security → Accessibility"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Skip for Now")

            guard alert.runModal() == .alertFirstButtonReturn else { return }
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    /// ⌘U, enregistré une seule fois pour toute l'app.
    func registerGlobalHotKey() {
        guard hotKeyRef == nil else { return }

        let target = GetApplicationEventTarget()
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(target, hotKeyPressed, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), nil)

        let identifier = EventHotKeyID(signature: 0x436C5542, id: 1)
        let keyCodeU: UInt32 = 32
        let status = RegisterEventHotKey(keyCodeU, UInt32(cmdKey), identifier, target, 0, &hotKeyRef)

        if status == noErr {
            NSLog("✅ Raccourci ⌘U enregistré")
        } else {
            NSLog("❌ Échec de l'enregistrement du raccourci, code : \(status)")
        }
    }

    func unregisterGlobalHotKey() {
        guard let hotKey = hotKeyRef else { return }
        UnregisterEventHotKey(hotKey)
        hotKeyRef = nil
        NSLog("🗑️ Raccourci ⌘U retiré")
    }
}
