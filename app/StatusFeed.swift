import Foundation

/// Lecture de `summary.json` : un incident ou un service incomplet est ignoré sans invalider le reste.
struct StatusFeed {
    let indicator: String
    let description: String
    let incidents: [StatusIncident]
    let components: [StatusComponent]

    var affectedComponents: [AffectedComponent] {
        components
            .filter { $0.status != "operational" }
            .map { AffectedComponent(id: $0.id, name: $0.name, status: $0.status) }
    }

    static func decode(_ data: Data) -> StatusFeed? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let indicator = payload.status?.indicator,
              let description = payload.status?.description else { return nil }
        return StatusFeed(
            indicator: indicator,
            description: description,
            incidents: (payload.incidents ?? []).compactMap(\.asIncident),
            components: (payload.components ?? []).compactMap(\.asComponent)
        )
    }

    private static let closedIncidentStates: Set<String> = ["resolved", "postmortem"]

    private struct Payload: Decodable {
        struct Global: Decodable { let indicator: String?; let description: String? }
        let status: Global?
        let incidents: [RawIncident]?
        let components: [RawComponent]?
    }

    private struct RawComponent: Decodable {
        let id: String?
        let name: String?
        let status: String?

        var asComponent: StatusComponent? {
            guard let id, let name, let status else { return nil }
            return StatusComponent(id: id, name: name, status: status)
        }
    }

    private struct RawUpdate: Decodable {
        let body: String?
        let created_at: String?
    }

    private struct RawIncident: Decodable {
        let id: String?
        let name: String?
        let status: String?
        let updated_at: String?
        let incident_updates: [RawUpdate]?
        let components: [RawComponent]?

        var asIncident: StatusIncident? {
            guard let id, let name, let status, !StatusFeed.closedIncidentStates.contains(status) else { return nil }
            let newest = incident_updates?.first
            return StatusIncident(
                id: id, name: name, status: status,
                latestUpdate: newest?.body ?? "",
                updatedAt: StatusFeed.date(from: newest?.created_at ?? updated_at),
                componentIds: (components ?? []).compactMap(\.id)
            )
        }
    }

    /// Les horodatages arrivent avec ou sans fractions de seconde selon l'incident.
    private static func date(from text: String?) -> Date? {
        guard let text else { return nil }
        for options in [ISO8601DateFormatter.Options([.withInternetDateTime, .withFractionalSeconds]), [.withInternetDateTime]] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
