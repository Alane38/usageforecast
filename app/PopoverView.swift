import SwiftUI

/// Remonte la hauteur réelle du contenu pour que le popover épouse sa taille sans dépasser le plafond.
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private func openSettingsWindow() {
    (NSApp.delegate as? AppDelegate)?.openSettings()
}

/// Contenu du popover : en-tête, la disposition choisie, détails secondaires, statut des services, fraîcheur.
struct PopoverView: View {
    @ObservedObject var usageManager: UsageManager
    @ObservedObject var statusManager: StatusManager
    @State private var measuredHeight: CGFloat = 250
    @Environment(\.colorScheme) private var colorScheme

    private let width: CGFloat = 360
    private let maxHeight: CGFloat = 640
    private let minHeight: CGFloat = 100

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
                .padding(16)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                })
        }
        .frame(width: width, height: min(max(measuredHeight, minHeight), maxHeight))
        .background(backdrop)
        .onPreferenceChange(ContentHeightKey.self) { height in
            if height > 0 { measuredHeight = height }
        }
        .onAppear { usageManager.updatePercentages() }
    }

    private var backdrop: Color {
        colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.3) : Color.white.opacity(0.85)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let error = usageManager.errorMessage {
                Text(error).font(.caption).foregroundColor(.orange)
            }
            if usageManager.hasFetchedData {
                dataSections
            } else {
                onboarding
            }
            if statusManager.hasFetched {
                Divider()
                StatusSection(statusManager: statusManager)
            }
            if let update = usageManager.availableUpdate {
                UpdateBanner(usageManager: usageManager, update: update)
            }
            if usageManager.hasFetchedData { freshness }
        }
    }

    @ViewBuilder
    private var dataSections: some View {
        switch usageManager.popoverLayout {
        case .gauges: GaugesLayout(usageManager: usageManager)
        case .cards: CardsLayout(usageManager: usageManager)
        }
        WeekPlanDisclosure(usageManager: usageManager)
        HistoryDisclosure(usageManager: usageManager)
        ModelDetails(usageManager: usageManager)
        ExtraUsageRow(usageManager: usageManager)
        LimitResetsLine(usageManager: usageManager)
    }

    private var header: some View {
        HStack {
            Text(Brand.name).font(.headline)
            Spacer()
            toolbarButton("arrow.clockwise", help: "Actualiser") {
                usageManager.fetchUsage()
                statusManager.fetch()
            }
            toolbarButton("gearshape", help: "Réglages", action: openSettingsWindow)
        }
    }

    private func toolbarButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundColor(Color.secondaryText)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pas encore de données").font(.system(size: 13, weight: .medium))
            Text("Connecte ta session claude.ai dans les réglages, ou lance Claude Code pour lire ses limites.")
                .font(.caption)
                .foregroundColor(Color.secondaryText)
            Button("Ouvrir les réglages", action: openSettingsWindow)
                .controlSize(.small)
        }
        .popoverCard()
    }

    private var freshness: some View {
        let isStale = SyncHelpers.isStale(usageManager.lastUpdated)
        let source = usageManager.usageSource == "claude.ai" ? "claude.ai" : "statusline"
        let slowedNote = usageManager.isRefreshSlowed ? " · ralenti (5 min)" : ""
        let age = SyncHelpers.age(since: usageManager.lastUpdated).withCapitalInitial
        return HStack(spacing: 6) {
            Circle().fill(isStale ? Color.orange : Color.green).frame(width: 7, height: 7)
            Text("\(age) · \(source)\(slowedNote)")
                .font(.caption)
                .foregroundColor(isStale ? .orange : Color.secondaryText)
        }
    }
}

private extension String {
    var withCapitalInitial: String { prefix(1).uppercased() + dropFirst() }
}
