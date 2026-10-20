import Foundation

/// Incident en cours publié sur la page de statut.
struct StatusIncident: Equatable, Identifiable {
    let id, name: String
    /// investigating, identified ou monitoring (les incidents clos sont écartés à la lecture)
    let status: String
    let latestUpdate: String   // corps du message le plus récent, vide s'il n'y en a pas
    let updatedAt: Date?       // date de ce message, à défaut celle de l'incident
    let componentIds: [String] // services touchés, vide si la page ne les précise pas
}

/// Service dont l'état n'est pas « operational ».
struct AffectedComponent: Equatable, Identifiable {
    let id, name, status: String
}

/// Service suivi par la page de statut, quel que soit son état.
struct StatusComponent: Equatable, Identifiable {
    let id, name, status: String
}

/// Services affichés avant la première réponse du réseau, pour que les réglages ne soient jamais vides.
let defaultTrackedComponents: [StatusComponent] = [
    ("c-claude-ai", "claude.ai"),
    ("c-claude-console", "Claude Console (platform.claude.com)"),
    ("c-claude-api", "Claude API (api.anthropic.com)"),
    ("c-claude-code", "Claude Code"),
    ("c-claude-cowork", "Claude Cowork"),
    ("c-claude-gov", "Claude for Government"),
].map { StatusComponent(id: $0.0, name: $0.1, status: "operational") }

let defaultTrackedComponentIdSet: Set<String> = Set(
    defaultTrackedComponents.map(\.id).filter { $0 != "c-claude-gov" }
)
