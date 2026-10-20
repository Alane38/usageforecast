import SwiftUI

/// État des services Claude : une ligne, avec le détail des incidents au clic quand il y en a.
struct StatusSection: View {
    @ObservedObject private var statusManager: StatusManager
    @State private var showingDetails = false

    init(statusManager: StatusManager) {
        _statusManager = ObservedObject(wrappedValue: statusManager)
    }

    private enum Style {
        static let titleFont = Font.system(size: 12, weight: .semibold)
        static let badgeFont = Font.system(size: 9, weight: .bold)
        static let contextFont = Font.system(size: 10)
        static let badgeInsets = EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
        static let sectionGap: CGFloat = 8
        static let rowGap: CGFloat = 6
        static let textGap: CGFloat = 2
        static let cardGap: CGFloat = 4
        static let panelTint = Color.orange.opacity(0.1)
    }

    private static let statusPageURL = URL(string: "https://status.claude.com")!
    private static let maxNamedServices = 3

    private static let indicatorColors: [String: Color] = [
        "none": .green, "minor": .yellow, "major": .orange, "critical": .red,
    ]

    private static let incidentLabels = [
        "investigating": "EN ANALYSE", "identified": "IDENTIFIÉ", "monitoring": "SURVEILLÉ", "resolved": "RÉSOLU",
    ]

    private static let incidentColors: [String: Color] = [
        "investigating": Color.red.opacity(0.8), "identified": .orange, "monitoring": .blue, "resolved": .green,
    ]

    private static let componentLabels = [
        "degraded_performance": "dégradé", "partial_outage": "panne partielle",
        "major_outage": "panne majeure", "under_maintenance": "maintenance",
    ]

    private var effective: String { statusManager.effectiveIndicator }
    private var incidents: [StatusIncident] { statusManager.filteredIncidents }
    private var affected: [AffectedComponent] { statusManager.filteredAffectedComponents }
    private var isAllClear: Bool { effective == "none" }
    private var hasIssue: Bool { !isAllClear && !(incidents.isEmpty && affected.isEmpty) }
    private var indicatorColor: Color { Self.indicatorColors[effective] ?? .gray }

    private var headline: String {
        isAllClear ? "Tous les services Claude fonctionnent" : statusManager.statusDescription
    }

    private var contextLine: String {
        if !isAllClear, !affected.isEmpty { return affectedSummary }
        let trackedCount = statusManager.allComponents.filter { statusManager.isTracked($0.id) }.count
        let tracked = trackedCount == 0 ? "Aucun service suivi" : "\(trackedCount) services suivis"
        guard let checkedAt = statusManager.lastUpdated else { return tracked }
        return "\(tracked) · vérifié \(SyncHelpers.age(since: checkedAt))"
    }

    private var affectedSummary: String {
        let shortNames = affected.prefix(Self.maxNamedServices).map { component in
            component.name.components(separatedBy: " (").first ?? component.name
        }
        let hidden = affected.count - Self.maxNamedServices
        return "Touche : " + shortNames.joined(separator: ", ") + (hidden > 0 ? " +\(hidden)" : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Style.sectionGap) {
            summaryRow
            if hasIssue && showingDetails { details }
        }
    }

    private var summaryRow: some View {
        HStack(alignment: .top, spacing: Style.rowGap) {
            Circle().fill(indicatorColor).frame(width: 8, height: 8).padding(.top, 4)
            VStack(alignment: .leading, spacing: Style.textGap) {
                Text(headline).font(.caption).foregroundColor(Color.secondaryText)
                Text(contextLine).font(Style.contextFont).foregroundColor(Color.secondaryText)
            }
            Spacer()
            if hasIssue {
                linkButton(showingDetails ? "Masquer" : "Détails") { showingDetails.toggle() }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(incidents) { incidentCard($0) }
            if incidents.isEmpty {
                ForEach(affected) { componentRow($0) }
            }
            linkButton("Ouvrir la page de statut →") { NSWorkspace.shared.open(Self.statusPageURL) }
        }
        .padding(10)
        .background(Style.panelTint)
        .cornerRadius(6)
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).buttonStyle(.borderless).font(.caption2)
    }

    private func incidentCard(_ incident: StatusIncident) -> some View {
        VStack(alignment: .leading, spacing: Style.cardGap) {
            Text(incident.name).font(Style.titleFont).fixedSize(horizontal: false, vertical: true)
            badge(for: incident.status)
            if incident.latestUpdate.isEmpty == false {
                Text(incident.latestUpdate).font(.caption).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func badge(for status: String) -> some View {
        Text(Self.statusLabel(status))
            .font(Style.badgeFont)
            .foregroundStyle(.white)
            .padding(Style.badgeInsets)
            .background(Self.badgeColor(status))
            .cornerRadius(3)
    }

    private func componentRow(_ component: AffectedComponent) -> some View {
        HStack {
            Text(component.name).font(.caption2)
            Spacer()
            Text(Self.componentLabel(component.status)).font(.caption2).foregroundColor(Color.secondaryText)
        }
    }

    // MARK: - Libellés et couleurs

    static func statusLabel(_ status: String) -> String {
        incidentLabels[status] ?? status.uppercased()
    }

    static func badgeColor(_ status: String) -> Color {
        incidentColors[status] ?? .gray
    }

    static func componentLabel(_ status: String) -> String {
        componentLabels[status] ?? status
    }
}
