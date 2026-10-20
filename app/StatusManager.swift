import SwiftUI

/// Suit l'état des services Claude et prévient quand l'état des seuls services suivis change.
final class StatusManager: ObservableObject {
    @Published private(set) var indicator = "none"
    @Published private(set) var statusDescription = "All systems operational"
    @Published private(set) var incidents = [StatusIncident]()
    @Published private(set) var affectedComponents = [AffectedComponent]()
    @Published private(set) var allComponents = defaultTrackedComponents
    @Published private(set) var selectedComponentIds = defaultTrackedComponentIdSet
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var hasFetched = false

    /// Adresse canonique : status.anthropic.com redirige ici.
    let endpoint = URL(string: "https://status.claude.com/api/v2/summary.json")!

    private enum Key {
        static let tracked = "tracked_component_ids"
        static let lastEffective = "last_effective_indicator"
        static let notifications = "status_notifications_enabled"
        static let obsoletePreview = "status_preview_mode"
    }

    /// Indexé par gravité : 0 = rien à signaler, 3 = panne majeure.
    private static let indicatorBySeverity = ["none", "minor", "major", "critical"]

    private static let severityByComponentStatus = [
        "under_maintenance": 1, "degraded_performance": 1,
        "partial_outage": 2,
        "major_outage": 3,
    ]

    private let defaults = UserDefaults.standard

    init() {
        if let saved = defaults.stringArray(forKey: Key.tracked) {
            selectedComponentIds = .init(saved)
        }
        defaults.removeObject(forKey: Key.obsoletePreview)
    }

    // MARK: - Choix des services suivis

    func isTracked(_ id: String) -> Bool { selectedComponentIds.contains(id) }

    func toggleComponent(_ id: String) {
        selectedComponentIds.formSymmetricDifference([id])
        persistTrackedSelection()
    }

    private func persistTrackedSelection() {
        defaults.set(Array(selectedComponentIds), forKey: Key.tracked)
    }

    // MARK: - Vues limitées aux services suivis

    var filteredAffectedComponents: [AffectedComponent] { affectedComponents.filter { isTracked($0.id) } }

    /// Un incident sans service rattaché reste visible : mieux vaut un doute qu'un silence.
    var filteredIncidents: [StatusIncident] { incidents.filter(concernsTrackedService) }

    private func concernsTrackedService(_ incident: StatusIncident) -> Bool {
        incident.componentIds.isEmpty || !selectedComponentIds.isDisjoint(with: incident.componentIds)
    }

    var effectiveIndicator: String { Self.indicatorBySeverity[min(worstTrackedSeverity, 3)] }

    private var worstTrackedSeverity: Int {
        allComponents.filter { isTracked($0.id) }.map { severity(for: $0.status) }.max() ?? 0
    }

    func severity(for componentStatus: String) -> Int {
        Self.severityByComponentStatus[componentStatus] ?? 0
    }

    // MARK: - Réseau

    private var summaryRequest: URLRequest {
        URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    }

    func fetch() {
        let task = URLSession.shared.dataTask(with: summaryRequest) { [weak self] data, _, _ in
            guard let data else { return }
            self?.parse(data)
        }
        task.resume()
    }

    func parse(_ data: Data) {
        guard let feed = StatusFeed.decode(data) else { return }
        DispatchQueue.main.async { self.apply(feed) }
    }

    private func apply(_ feed: StatusFeed) {
        let isFirstFetch = !hasFetched

        indicator = feed.indicator
        statusDescription = feed.description
        incidents = feed.incidents
        affectedComponents = feed.affectedComponents
        adoptComponents(feed.components)
        lastUpdated = .now
        hasFetched = true

        let current = effectiveIndicator
        let previous = defaults.string(forKey: Key.lastEffective)
        defaults.set(current, forKey: Key.lastEffective)
        guard !isFirstFetch, let previous, previous != current else { return }
        notifyStatusChange(to: current, description: feed.description)
    }

    /// Au premier contact réel, tout est suivi sauf l'offre Government, réservée à un usage à part.
    private func adoptComponents(_ components: [StatusComponent]) {
        guard !components.isEmpty else { return }
        allComponents = components
        guard defaults.object(forKey: Key.tracked) == nil else { return }
        selectedComponentIds = Set(
            components.filter { !$0.name.localizedCaseInsensitiveContains("Government") }.map(\.id)
        )
        persistTrackedSelection()
    }

    func notifyStatusChange(to indicator: String, description: String) {
        guard defaults.bool(forKey: Key.notifications) else { return }

        let isBackToNormal = indicator == "none"
        Notifier.send(
            title: isBackToNormal ? "Claude est de nouveau en ligne" : "Statut Claude : \(description)",
            body: isBackToNormal ? "Tous les services fonctionnent." : "Détails sur status.claude.com.",
            id: "status-change"
        )
        NSLog("📬 Notification de changement de statut envoyée : \(indicator)")
    }
}
