import SwiftUI

/// État des services Claude : une ligne, avec le détail des incidents au clic quand il y en a.
struct StatusSection: View {
    @ObservedObject var statusManager: StatusManager
    @State private var showingDetails = false

    private var effective: String { statusManager.effectiveIndicator }
    private var incidents: [StatusIncident] { statusManager.filteredIncidents }
    private var affected: [AffectedComponent] { statusManager.filteredAffectedComponents }
    private var hasIssue: Bool { effective != "none" && (!incidents.isEmpty || !affected.isEmpty) }

    private var indicatorColor: Color {
        switch effective {
        case "none":     return .green
        case "minor":    return .yellow
        case "major":    return .orange
        case "critical": return .red
        default:         return .gray
        }
    }

    private var contextLine: String {
        let tracked = statusManager.allComponents.filter { statusManager.selectedComponentIds.contains($0.id) }
        let checked = statusManager.lastUpdated.map { "vérifié \(SyncHelpers.age(since: $0))" }
        if effective != "none", !affected.isEmpty {
            let names = affected.prefix(3).map { $0.name.components(separatedBy: " (").first ?? $0.name }
            return "Touche : " + names.joined(separator: ", ") + (affected.count > 3 ? " +\(affected.count - 3)" : "")
        }
        let summary = tracked.isEmpty ? "Aucun service suivi" : "\(tracked.count) services suivis"
        return [summary, checked].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Circle().fill(indicatorColor).frame(width: 8, height: 8).padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(effective == "none" ? "Tous les services Claude fonctionnent" : statusManager.statusDescription)
                        .font(.caption)
                        .foregroundColor(Color.secondaryText)
                    Text(contextLine).font(.system(size: 10)).foregroundColor(Color.secondaryText)
                }
                Spacer()
                if hasIssue {
                    Button(showingDetails ? "Masquer" : "Détails") { showingDetails.toggle() }
                        .buttonStyle(.borderless)
                        .font(.caption2)
                }
            }
            if hasIssue && showingDetails { details }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(incidents) { incident in
                VStack(alignment: .leading, spacing: 4) {
                    Text(incident.name).font(.system(size: 12, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(Self.statusLabel(incident.status))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Self.badgeColor(incident.status))
                        .cornerRadius(3)
                    if !incident.latestUpdate.isEmpty {
                        Text(incident.latestUpdate).font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if incidents.isEmpty {
                ForEach(affected) { component in
                    HStack {
                        Text(component.name).font(.caption2)
                        Spacer()
                        Text(Self.componentLabel(component.status)).font(.caption2).foregroundColor(Color.secondaryText)
                    }
                }
            }
            Button("Ouvrir la page de statut →") { NSWorkspace.shared.open(URL(string: "https://status.claude.com")!) }
                .buttonStyle(.borderless)
                .font(.caption2)
        }
        .padding(10)
        .background(Color.orange.opacity(0.10))
        .cornerRadius(6)
    }

    static func statusLabel(_ status: String) -> String {
        switch status {
        case "investigating": return "EN ANALYSE"
        case "identified":    return "IDENTIFIÉ"
        case "monitoring":    return "SURVEILLÉ"
        case "resolved":      return "RÉSOLU"
        default:              return status.uppercased()
        }
    }

    static func badgeColor(_ status: String) -> Color {
        switch status {
        case "investigating": return Color.red.opacity(0.8)
        case "identified":    return .orange
        case "monitoring":    return .blue
        case "resolved":      return .green
        default:              return .gray
        }
    }

    static func componentLabel(_ status: String) -> String {
        switch status {
        case "degraded_performance": return "dégradé"
        case "partial_outage":       return "panne partielle"
        case "major_outage":         return "panne majeure"
        case "under_maintenance":    return "maintenance"
        default:                     return status
        }
    }
}
