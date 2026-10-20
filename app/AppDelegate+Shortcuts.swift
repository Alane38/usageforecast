import AppKit
import Carbon

/// Raccourci global ⌘U (Carbon) : il fonctionne même quand l'app n'est pas au premier plan.
private enum GlobalHotKey {
    /// « ClUB » en hexadécimal : identifiant d'application attendu par Carbon.
    static let signature: OSType = 0x436C5542
    static let identifier: UInt32 = 1
    static let keyCodeU: UInt32 = 32
    static let accessibilitySettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
}

/// Fonction C : elle ne peut rien capturer, l'`AppDelegate` arrive par `userData`.
private let hotKeyPressedHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return noErr }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { delegate.togglePopover() }
    return noErr
}

extension AppDelegate {
    func installKeyboardShortcut() {
        warnIfAccessibilityIsMissing()
        if usageManager.shortcutEnabled { registerHotKey() }
    }

    func setShortcutEnabled(_ enabled: Bool) { enabled ? registerHotKey() : unregisterHotKey() }

    func warnIfAccessibilityIsMissing() {
        guard !AXIsProcessTrusted() else {
            NSLog("✅ Autorisation d'accessibilité accordée")
            return
        }
        NSLog("⚠️ Autorisation d'accessibilité manquante")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Self.offerAccessibilitySettings() }
    }

    func registerHotKey() {
        guard hotKeyRef == nil else { return }

        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), hotKeyPressedHandler, 1, &pressed, context, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: GlobalHotKey.signature, id: GlobalHotKey.identifier)
        let status = RegisterEventHotKey(GlobalHotKey.keyCodeU, UInt32(cmdKey), hotKeyID,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            NSLog("❌ Échec de l'enregistrement du raccourci, code : \(status)")
            return
        }
        NSLog("✅ Raccourci ⌘U enregistré")
    }

    func unregisterHotKey() {
        guard let registered = hotKeyRef else { return }
        UnregisterEventHotKey(registered)
        hotKeyRef = nil
        NSLog("🗑️ Raccourci ⌘U retiré")
    }

    private static func offerAccessibilitySettings() {
        let dialog = NSAlert()
        dialog.messageText = "Accessibility Permission Required"
        dialog.informativeText = "\(Brand.name) needs Accessibility permission to use the Cmd+U keyboard shortcut.\n\n"
            + "Please enable it in:\nSystem Settings → Privacy & Security → Accessibility"
        dialog.alertStyle = .informational
        dialog.addButton(withTitle: "Open System Settings")
        dialog.addButton(withTitle: "Skip for Now")
        guard dialog.runModal() == .alertFirstButtonReturn,
              let settingsURL = URL(string: GlobalHotKey.accessibilitySettingsURL) else { return }
        NSWorkspace.shared.open(settingsURL)
    }
}
