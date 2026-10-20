import AppKit

/// Raccourcis vers les réglages macOS. Une app ne peut pas s'accorder elle-même l'Accès complet au disque :
/// on amène l'utilisateur au bon panneau, il n'a plus qu'à activer l'interrupteur.
enum SystemSettings {
    static let fullDiskAccessURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    static func openFullDiskAccess() {
        NSWorkspace.shared.open(fullDiskAccessURL)
    }

    /// Montre l'app dans le Finder : on peut la glisser dans la liste du panneau si elle n'y figure pas encore.
    static func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    /// L'autorisation ne vaut que pour les lancements suivants : on relance l'app une seconde après sa fermeture.
    static func relaunchApp() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
