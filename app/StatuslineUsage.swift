import Foundation

/// Limites d'usage lues dans le JSON que Claude Code envoie à son statusline
/// (`rate_limits.five_hour` / `rate_limits.seven_day`). Source officielle : aucun cookie, aucun appel réseau.
struct StatuslineUsage: Equatable {
    struct Window: Equatable {
        let usedPercentage: Double
        let resetsAt: Date
    }

    let fiveHour: Window?
    let sevenDay: Window?
    /// Date d'écriture du fichier : sert à signaler une donnée ancienne.
    let capturedAt: Date

    static let defaultPath = NSString(string: "~/.claude/scripts/statusline/data/last_payload.txt").expandingTildeInPath
    /// Copie posée par la commande de l'assistant de démarrage (voir `FirstRun.statuslineSetting`).
    static let standardPath = NSString(string: FirstRun.statuslineFileHint).expandingTildeInPath

    /// Une fenêtre dont l'heure de reset est passée est abandonnée (Claude Code fait pareil) :
    /// son pourcentage ne dit plus rien sur la fenêtre en cours.
    static func parse(_ data: Data, capturedAt: Date, now: Date = AppClock.now) -> StatuslineUsage? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limits = root["rate_limits"] as? [String: Any] else { return nil }

        func window(_ key: String) -> Window? {
            guard let raw = limits[key] as? [String: Any],
                  let used = raw["used_percentage"] as? Double ?? (raw["used_percentage"] as? Int).map(Double.init),
                  let resetEpoch = raw["resets_at"] as? Double ?? (raw["resets_at"] as? Int).map(Double.init) else { return nil }
            let resetsAt = Date(timeIntervalSince1970: resetEpoch)
            guard resetsAt > now else { return nil }
            return Window(usedPercentage: min(max(used, 0), 100), resetsAt: resetsAt)
        }

        let fiveHour = window("five_hour")
        let sevenDay = window("seven_day")
        guard fiveHour != nil || sevenDay != nil else { return nil }
        return StatuslineUsage(fiveHour: fiveHour, sevenDay: sevenDay, capturedAt: capturedAt)
    }

    /// Le statusline ne remplace l'affichage que s'il est plus récent que la dernière donnée montrée.
    static func shouldReplace(displayedAt: Date, hasDisplayedData: Bool, capturedAt: Date) -> Bool {
        !hasDisplayedData || capturedAt > displayedAt
    }

    static func load(path: String = defaultPath, now: Date = AppClock.now) -> StatuslineUsage? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let modified = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? now
        return parse(data, capturedAt: modified, now: now)
    }

    /// Lit chaque emplacement connu et garde la donnée la plus récente.
    static func loadNewest(paths: [String] = [standardPath, defaultPath], now: Date = AppClock.now) -> StatuslineUsage? {
        paths.compactMap { load(path: $0, now: now) }.max { $0.capturedAt < $1.capturedAt }
    }
}
