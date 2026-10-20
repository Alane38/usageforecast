import Foundation
import SQLite3

/// Lit les cookies de session dans un profil de navigateur basé sur Firefox (Firefox, Zen) : ils sont stockés
/// en clair dans `cookies.sqlite`. Évite de copier un en-tête Cookie depuis les outils de développement.
/// Sur macOS récent, Firefox lui-même est protégé (accès refusé sans « Accès complet au disque »), pas Zen.
enum FirefoxCookies {
    static var profileRoots: [URL] {
        let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return ["zen/Profiles", "Firefox/Profiles"].map { support.appendingPathComponent($0) }
    }

    /// Bases de cookies de tous les profils, la plus récemment modifiée d'abord.
    static func cookieDatabases(roots: [URL] = profileRoots) -> [URL] {
        let profiles = roots.flatMap { (try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
        func modified(_ url: URL) -> Date {
            ((try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date) ?? .distantPast
        }
        return profiles
            .map { $0.appendingPathComponent("cookies.sqlite") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .sorted { modified($0) > modified($1) }
    }

    /// Vrai si macOS refuse la lecture du dossier d'un navigateur installé (Firefox, Chrome : « Operation not permitted »).
    static func accessDenied(roots: [URL] = profileRoots) -> Bool {
        roots.contains { root in
            let appFolder = root.deletingLastPathComponent().path
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: appFolder)
                return false
            } catch {
                return (error as NSError).code == NSFileReadNoPermissionError
            }
        }
    }

    /// Premier profil (le plus récent) qui contient des cookies pour ce domaine.
    static func cookieHeader(domain: String, roots: [URL] = profileRoots) -> String? {
        for database in cookieDatabases(roots: roots) {
            if let header = cookieHeader(database: database, domain: domain) { return header }
        }
        return nil
    }

    /// En-tête `Cookie` pour un domaine (« claude.ai » inclut ses sous-domaines). nil si aucun cookie.
    static func cookieHeader(database: URL, domain: String) -> String? {
        guard let copy = temporaryCopy(of: database) else { return nil }
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }

        var handle: OpaquePointer?
        guard sqlite3_open_v2(copy.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(handle) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "SELECT host, name, value FROM moz_cookies", -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }

        var pairs: [(hostLength: Int, name: String, value: String)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let host = text(statement, 0), let name = text(statement, 1), let value = text(statement, 2) else { continue }
            let bareHost = host.hasPrefix(".") ? String(host.dropFirst()) : host
            guard bareHost == domain || bareHost.hasSuffix("." + domain) else { continue }
            pairs.append((bareHost.count, name, value))
        }

        // À nom égal, le cookie du domaine le plus précis l'emporte.
        var byName: [String: String] = [:]
        for pair in pairs.sorted(by: { $0.hostLength < $1.hostLength }) { byName[pair.name] = pair.value }
        guard !byName.isEmpty else { return nil }
        return byName.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    /// Firefox verrouille la base et garde ses écritures récentes dans le journal WAL : on copie les deux.
    private static func temporaryCopy(of database: URL) -> URL? {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent("cookies.sqlite")
            try FileManager.default.copyItem(at: database, to: target)
            let wal = database.deletingLastPathComponent().appendingPathComponent("cookies.sqlite-wal")
            if FileManager.default.fileExists(atPath: wal.path) {
                try? FileManager.default.copyItem(at: wal, to: folder.appendingPathComponent("cookies.sqlite-wal"))
            }
            return target
        } catch {
            return nil
        }
    }

    private static func text(_ statement: OpaquePointer?, _ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }
    }
}
