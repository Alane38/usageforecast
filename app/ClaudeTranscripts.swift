import Foundation

/// Activité Claude Code de CE Mac (celle d'Alane), lue dans les journaux de session comme le fait le collecteur de l'invité
/// (`mobile/collector/lib/transcripts.js`) : heures et tokens seulement, jamais le texte. Sert à l'attribution d'un prêt.
enum ClaudeTranscripts {
    struct Record: Equatable {
        let key: String
        let time: TimeInterval
        let model: String
        let input: Int, output: Int, cacheWrite: Int, cacheRead: Int
    }

    private static func count(_ value: Any?) -> Int {
        guard let number = value as? NSNumber, number.doubleValue > 0 else { return 0 }
        return Int(number.doubleValue.rounded())
    }

    /// Une ligne de journal → un relevé, ou nil (autre type, JSON invalide, message synthétique, tout à zéro). Mêmes règles que le collecteur.
    static func parse(line: Substring) -> Record? {
        guard line.count > 1, let entry = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              entry["type"] as? String == "assistant", let message = entry["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else { return nil }
        let model = message["model"] as? String ?? "inconnu"
        guard model != "<synthetic>", let stamp = entry["timestamp"] as? String, let date = GuestReport.date(stamp),
              let id = (message["id"] as? String) ?? (entry["uuid"] as? String), !id.isEmpty else { return nil }
        let record = Record(key: "\(id):\(entry["requestId"] as? String ?? "")", time: date.timeIntervalSince1970, model: model,
                            input: count(usage["input_tokens"]), output: count(usage["output_tokens"]),
                            cacheWrite: count(usage["cache_creation_input_tokens"]), cacheRead: count(usage["cache_read_input_tokens"]))
        return record.input + record.output + record.cacheWrite + record.cacheRead > 0 ? record : nil
    }

    /// Tranches de 5 minutes, réponses dédoublonnées (la même réponse est souvent écrite plusieurs fois : on garde la plus complète).
    static func buckets(_ records: [Record]) -> [ActivityBucket] {
        var unique: [String: Record] = [:]
        for record in records {
            let total = record.input + record.output + record.cacheWrite + record.cacheRead
            if let known = unique[record.key], known.input + known.output + known.cacheWrite + known.cacheRead >= total { continue }
            unique[record.key] = record
        }
        var grouped: [TimeInterval: [Record]] = [:]
        for record in unique.values { grouped[(record.time / ActivityBucket.duration).rounded(.down) * ActivityBucket.duration, default: []].append(record) }
        return grouped.map { start, items in
            ActivityBucket(t: start, n: items.count, input: items.reduce(0) { $0 + $1.input }, output: items.reduce(0) { $0 + $1.output },
                           cacheWrite: items.reduce(0) { $0 + $1.cacheWrite }, cacheRead: items.reduce(0) { $0 + $1.cacheRead },
                           models: Dictionary(items.map { ($0.model, $0.input + $0.output + $0.cacheWrite + $0.cacheRead) }, uniquingKeysWith: +))
        }.sorted { $0.t < $1.t }
    }

    /// Dossiers `projects` : `CLAUDE_CONFIG_DIR` (liste séparée par des virgules), sinon `~/.config/claude` et `~/.claude`.
    static func projectDirectories(environment: [String: String], home: URL) -> [URL] {
        let roots: [URL]
        if let configured = environment["CLAUDE_CONFIG_DIR"]?.trimmingCharacters(in: .whitespaces), !configured.isEmpty {
            roots = configured.split(separator: ",").map { URL(fileURLWithPath: $0.trimmingCharacters(in: .whitespaces)) }
        } else {
            let xdg = environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".config")
            roots = [xdg.appendingPathComponent("claude"), home.appendingPathComponent(".claude")]
        }
        var seen = Set<String>()
        return roots.map { $0.appendingPathComponent("projects") }.filter { seen.insert($0.path).inserted }
    }
}

/// Lecture incrémentale des journaux de ce Mac : chaque fichier reprend là où il s'était arrêté, ligne en cours laissée pour plus tard.
/// Garde les relevés depuis `since` en mémoire (une semaine de prêt) ; rien n'est écrit sur le disque.
final class TranscriptScanner {
    private var offsets: [String: UInt64] = [:]
    private var records: [Record] = []
    typealias Record = ClaudeTranscripts.Record

    func scan(directories: [URL], since: Date) -> [ActivityBucket] {
        let manager = FileManager.default
        let floor = since.timeIntervalSince1970
        for directory in directories {
            guard let walker = manager.enumerator(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { continue }
            for case let file as URL in walker where file.pathExtension == "jsonl" {
                let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                guard let modified = values?.contentModificationDate, modified.timeIntervalSince1970 >= floor,
                      let size = values?.fileSize else { continue }
                read(file, size: UInt64(size))
            }
        }
        records.removeAll { $0.time < floor }
        return ClaudeTranscripts.buckets(records)
    }

    private func read(_ file: URL, size: UInt64) {
        var offset = offsets[file.path] ?? 0
        if size < offset { offset = 0 }   // fichier raccourci ou remplacé
        guard size > offset, let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }
        try? handle.seek(toOffset: offset)
        guard let data = try? handle.read(upToCount: Int(min(size - offset, 64 * 1024 * 1024))),
              let end = data.lastIndex(of: 0x0a) else { return }
        let complete = data[data.startIndex...end]
        records += String(decoding: complete, as: UTF8.self).split(separator: "\n").compactMap(ClaudeTranscripts.parse(line:))
        offsets[file.path] = offset + UInt64(complete.count)
    }
}
