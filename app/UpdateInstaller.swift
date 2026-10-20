import CryptoKit
import Foundation

/// Installation d'une mise à jour : téléchargement, vérifications, puis remplacement de l'application par un script
/// qui attend la fin de l'app, met l'ancienne à la Corbeille (jamais supprimée) et relance la nouvelle.
enum UpdateInstaller {
    struct Failure: Error { let message: String }

    static let maxDownloadBytes = 80 * 1024 * 1024

    // MARK: - Parties pures

    /// Somme SHA-256 au format de `shasum -a 256` (« <64 hex>  fichier ») ; nil si la ligne n'en contient pas.
    static func parseChecksum(_ text: String) -> String? {
        guard let token = text.split(whereSeparator: \.isWhitespace).first else { return nil }
        let hex = token.lowercased()
        return hex.count == 64 && hex.allSatisfy(\.isHexDigit) ? hex : nil
    }

    /// Lit `Info.plist` d'une application : nil si l'identifiant et la version sont conformes, sinon la raison du refus.
    static func problem(inInfo info: [String: Any]?, bundleID: String, version: String) -> String? {
        guard let info else { return "L'archive ne contient pas d'application valide." }
        guard info["CFBundleIdentifier"] as? String == bundleID else { return "L'archive n'est pas \(Brand.name) (identifiant différent)." }
        guard info["CFBundleShortVersionString"] as? String == version else {
            return "La version de l'archive (\(info["CFBundleShortVersionString"] as? String ?? "?")) ne correspond pas à la release (\(version))."
        }
        return nil
    }

    /// Script de remplacement. Il échoue sans rien casser : l'ancienne application n'est déplacée qu'après la copie réussie
    /// de la nouvelle, et remise en place si le dernier déplacement échoue.
    static func script(pid: Int32, newApp: URL, target: URL, trash: URL, relaunch: Bool) -> String {
        func quoted(_ url: URL) -> String { "'" + url.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let staged = target.deletingLastPathComponent().appendingPathComponent(target.lastPathComponent + ".update")
        let parked = trash.appendingPathComponent("UsageForecast-avant-mise-a-jour-\(Int(Date().timeIntervalSince1970)).app")
        return """
        #!/bin/sh
        while kill -0 \(pid) 2>/dev/null; do sleep 0.5; done
        /usr/bin/ditto \(quoted(newApp)) \(quoted(staged)) || exit 1
        mv \(quoted(target)) \(quoted(parked)) || exit 1
        if ! mv \(quoted(staged)) \(quoted(target)); then mv \(quoted(parked)) \(quoted(target)); exit 1; fi
        \(relaunch ? "/usr/bin/open \(quoted(target))" : "true")
        """
    }

    // MARK: - Entrées-sorties

    /// Télécharge et vérifie : taille, SHA-256 de l'archive, identifiant et version de l'application, signature intacte.
    /// Retourne l'application prête à être installée. Synchrone : à appeler hors du fil principal.
    static func prepare(zip: URL, checksum: URL, version: String, bundleID: String, workDirectory: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        let zipFile = try download(zip, to: workDirectory.appendingPathComponent("update.zip"))
        let sumFile = try download(checksum, to: workDirectory.appendingPathComponent("update.sha256"))

        guard let expected = parseChecksum((try? String(contentsOf: sumFile, encoding: .utf8)) ?? "") else {
            throw Failure(message: "Somme SHA-256 illisible : mise à jour refusée.")
        }
        guard try sha256(of: zipFile) == expected else {
            throw Failure(message: "La somme SHA-256 ne correspond pas : archive corrompue ou modifiée, mise à jour refusée.")
        }

        let unpacked = workDirectory.appendingPathComponent("app")
        try? fileManager.removeItem(at: unpacked)
        guard run("/usr/bin/ditto", ["-x", "-k", zipFile.path, unpacked.path]) else { throw Failure(message: "Archive impossible à ouvrir.") }
        let apps = ((try? fileManager.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "app" }
        guard apps.count == 1, let app = apps.first else { throw Failure(message: "L'archive doit contenir exactement une application.") }

        let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) as? [String: Any]
        if let problem = problem(inInfo: info, bundleID: bundleID, version: version) { throw Failure(message: problem) }
        guard run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]) else {
            throw Failure(message: "La signature de l'application est invalide : mise à jour refusée.")
        }
        return app
    }

    /// Écrit le script et le lance, détaché de l'app (il survit à sa fermeture).
    @discardableResult
    static func launchReplacement(newApp: URL, target: URL, trash: URL, pid: Int32, relaunch: Bool, workDirectory: URL) throws -> Process {
        let scriptURL = workDirectory.appendingPathComponent("replace.sh")
        try script(pid: pid, newApp: newApp, target: target, trash: trash, relaunch: relaunch).write(to: scriptURL, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        process.arguments = ["/bin/sh", scriptURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }

    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func download(_ url: URL, to destination: URL) throws -> URL {
        var result: (URL?, Error?)
        let done = DispatchSemaphore(value: 0)
        var downloadRequest = URLRequest(url: url)
        downloadRequest.timeoutInterval = 60
        URLSession.shared.downloadTask(with: downloadRequest) { location, response, error in
            defer { done.signal() }
            if let error { result = (nil, error); return }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                result = (nil, Failure(message: "Téléchargement refusé (HTTP \(http.statusCode)).")); return
            }
            guard let location else { result = (nil, Failure(message: "Téléchargement vide.")); return }
            let size = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int) ?? 0
            guard size > 0, size <= maxDownloadBytes else { result = (nil, Failure(message: "Taille de téléchargement inattendue.")); return }
            try? FileManager.default.removeItem(at: destination)
            do { try FileManager.default.moveItem(at: location, to: destination); result = (destination, nil) } catch { result = (nil, error) }
        }.resume()
        done.wait()
        if let file = result.0 { return file }
        throw (result.1 as? Failure) ?? Failure(message: "Téléchargement impossible : \(result.1?.localizedDescription ?? "erreur inconnue").")
    }

    private static func run(_ path: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
