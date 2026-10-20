import Foundation

/// Dossier de données de l'app (`~/Library/Application Support/UsageForecast`) et reprise de l'ancien dossier
/// des versions antérieures à 1.14 : les fichiers sont déplacés une fois, sans perte, avant toute lecture.
enum AppSupport {
    static let folderName = "UsageForecast"
    static let legacyFolderName = "ClaudeUsageBar"

    enum MigrationResult: Equatable { case nothingToDo, moved(Int), failed(String) }

    static func baseDirectory(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    static func directory(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        baseDirectory(home: home).appendingPathComponent(folderName, isDirectory: true)
    }

    static func file(_ name: String) -> URL { directory().appendingPathComponent(name) }

    /// Déplace chaque élément de l'ancien dossier qui n'existe pas encore dans le nouveau, puis retire l'ancien s'il est vide.
    /// Ne remplace jamais un fichier déjà présent : si les deux dossiers existent, le nouveau l'emporte.
    @discardableResult
    static func migrateLegacy(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> MigrationResult {
        let fileManager = FileManager.default
        let base = baseDirectory(home: home)
        let legacy = base.appendingPathComponent(legacyFolderName, isDirectory: true)
        let current = directory(home: home)
        guard fileManager.fileExists(atPath: legacy.path) else { return .nothingToDo }
        do {
            try fileManager.createDirectory(at: current, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            var moved = 0
            for item in try fileManager.contentsOfDirectory(atPath: legacy.path) {
                let destination = current.appendingPathComponent(item)
                guard !fileManager.fileExists(atPath: destination.path) else { continue }
                try fileManager.moveItem(at: legacy.appendingPathComponent(item), to: destination)
                moved += 1
            }
            if (try? fileManager.contentsOfDirectory(atPath: legacy.path))?.isEmpty == true { try fileManager.removeItem(at: legacy) }
            return moved == 0 ? .nothingToDo : .moved(moved)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
