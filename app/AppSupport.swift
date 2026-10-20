import Foundation

/// Dossier de données de l'app : `~/Library/Application Support/UsageForecast`.
enum AppSupport {
    static let folderName = "UsageForecast"

    static func directory(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
    }

    static func file(_ name: String) -> URL { directory().appendingPathComponent(name) }
}
