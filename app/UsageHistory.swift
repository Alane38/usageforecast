import Foundation

/// Historique local des relevés : un fichier JSON par ligne, gardé 8 jours. Rien ne quitte la machine.
struct UsageHistory {
    let url: URL
    static let retention: TimeInterval = 8 * 86400

    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(AppSupport.folderName)/history.jsonl")
    }

    func append(_ sample: UsageSample) {
        guard let line = try? JSONEncoder().encode(sample) else { return }
        let manager = FileManager.default
        try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !manager.fileExists(atPath: url.path) {
            manager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line + Data("\n".utf8))
    }

    /// Relevés depuis `since`, lignes illisibles ignorées.
    func load(since: Date) -> [UsageSample] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return content.split(separator: "\n").compactMap { line in
            try? decoder.decode(UsageSample.self, from: Data(line.utf8))
        }
        .filter { $0.time >= since.timeIntervalSince1970 }
    }

    /// Réécrit le fichier sans les relevés trop anciens.
    func prune(now: Date = AppClock.now) {
        let kept = load(since: now.addingTimeInterval(-Self.retention))
        let encoder = JSONEncoder()
        let body = kept.compactMap { try? encoder.encode($0) }.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n")
        try? Data((body.isEmpty ? "" : body + "\n").utf8).write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
