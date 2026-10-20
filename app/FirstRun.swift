import Foundation

/// Règles du premier lancement : sans données, un nouvel utilisateur voit l'assistant de démarrage une seule fois.
enum FirstRun {
    static let seenKey = "welcomeSeen"

    static func isNeeded(seen: Bool, hasData: Bool) -> Bool { !seen && !hasData }

    /// Là où l'app lit en premier le JSON envoyé par Claude Code à son statusline.
    static let statuslineFileHint = "~/Library/Application Support/UsageForecast/statusline.json"

    /// Bloc à fusionner dans `~/.claude/settings.json` : Claude Code garde une copie du JSON de son statusline,
    /// l'app y lit les limites officielles (aucun cookie, aucun réseau). La commande affiche « UsageForecast » dans le statusline.
    static let statuslineSetting = """
    "statusLine": {
      "type": "command",
      "command": "mkdir -p \\"$HOME/Library/Application Support/UsageForecast\\" && tee \\"$HOME/Library/Application Support/UsageForecast/statusline.json\\" > /dev/null && echo UsageForecast"
    }
    """
}
