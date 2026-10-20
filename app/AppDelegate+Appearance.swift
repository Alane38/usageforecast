import AppKit

extension AppDelegate {
    /// Applique la préférence au lancement, puis la réapplique à chaque bascule clair/sombre de macOS :
    /// un mode forcé identique au système doit revenir au rendu natif.
    func trackAppearancePreference() {
        applyAppearancePreference()
        let themeChanged = NSNotification.Name("AppleInterfaceThemeChangedNotification")
        DistributedNotificationCenter.default.addObserver(forName: themeChanged, object: nil, queue: .main) { [weak self] _ in
            // La clé des réglages système peut arriver après la notification : on relit un instant plus tard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self?.applyAppearancePreference() }
        }
    }

    /// Préférence « system » (défaut), « dark » ou « light ». On pose toujours une apparence explicite, même en mode système :
    /// le rendu « vibrant » hérité fait perdre la teinte des barres de progression et nuance les couleurs, si bien que
    /// Système et Sombre ne se ressemblaient pas. Le popover reçoit aussi l'apparence, car il ne suit pas `NSApp` de façon fiable.
    func applyAppearancePreference() {
        let defaults = UserDefaults.standard
        let wantsDark: Bool
        switch defaults.string(forKey: "appearance_mode") ?? "system" {
        case "dark": wantsDark = true
        case "light": wantsDark = false
        default: wantsDark = defaults.string(forKey: "AppleInterfaceStyle") == "Dark"
        }
        let appearance = NSAppearance(named: wantsDark ? .darkAqua : .aqua)
        NSApp.appearance = appearance
        popover?.appearance = appearance
    }
}
