import SwiftUI

private struct PopoverHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Contenu du popover : en-tête, la disposition choisie, détails secondaires, statut des services, fraîcheur.
struct PopoverView: View {
    @ObservedObject var usageManager: UsageManager
    @ObservedObject var statusManager: StatusManager
    @State private var measuredHeight: CGFloat = 250
    @Environment(\.colorScheme) private var colorScheme

    private let maxHeight: CGFloat = 640

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
                .padding(16)
                .background(GeometryReader { Color.clear.preference(key: PopoverHeightKey.self, value: $0.size.height) })
        }
        .frame(width: 360, height: min(max(measuredHeight, 100), maxHeight))
        .background(colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.3) : Color.white.opacity(0.85))
        .onPreferenceChange(PopoverHeightKey.self) { if $0 > 0 { measuredHeight = $0 } }
        .onAppear { usageManager.updatePercentages() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let error = usageManager.errorMessage {
                Text(error).font(.caption).foregroundColor(.orange)
            }
            if usageManager.hasFetchedData {
                switch usageManager.popoverLayout {
                case .gauges: GaugesLayout(usageManager: usageManager)
                case .cards:  CardsLayout(usageManager: usageManager)
                }
                WeekPlanDisclosure(usageManager: usageManager)
                HistoryDisclosure(usageManager: usageManager)
                ModelDetails(usageManager: usageManager)
                ExtraUsageRow(usageManager: usageManager)
                LimitResetsLine(usageManager: usageManager)
            } else {
                onboarding
            }
            if statusManager.hasFetched {
                Divider()
                StatusSection(statusManager: statusManager)
            }
            if let update = usageManager.availableUpdate { updateBanner(update) }
            if usageManager.hasFetchedData { footer }
        }
    }

    private var header: some View {
        HStack {
            Text(Brand.name).font(.headline)
            Spacer()
            iconButton("arrow.clockwise", help: "Actualiser") {
                usageManager.fetchUsage()
                statusManager.fetch()
            }
            iconButton("gearshape", help: "Réglages") { (NSApp.delegate as? AppDelegate)?.openSettings() }
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
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
            Button("Ouvrir les réglages") { (NSApp.delegate as? AppDelegate)?.openSettings() }
                .controlSize(.small)
        }
        .popoverCard()
    }

    private func updateBanner(_ update: ReleaseInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version \(update.version) disponible").font(.system(size: 13, weight: .medium))
                    Text("Tu as la \(usageManager.currentVersion).").font(.caption).foregroundColor(Color.secondaryText)
                }
                Spacer()
                updateButtons(update)
            }
            switch usageManager.updateInstallState {
            case .idle: EmptyView()
            case .working(let step):
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text(step).font(.caption).foregroundColor(Color.secondaryText) }
            case .failed(let message):
                Text(message).font(.caption).foregroundColor(UsageTone.danger.color)
            }
        }
        .popoverCard()
    }

    @ViewBuilder
    private func updateButtons(_ update: ReleaseInfo) -> some View {
        let isWorking: Bool = { if case .working = usageManager.updateInstallState { return true } else { return false } }()
        HStack(spacing: 6) {
            Button("Notes") { NSWorkspace.shared.open(update.pageURL) }.controlSize(.small)
            if update.zipURL != nil {
                Button("Installer") { usageManager.installUpdate() }.controlSize(.small).disabled(isWorking)
            }
        }
    }

    private var footer: some View {
        let stale = SyncHelpers.isStale(usageManager.lastUpdated)
        let source = usageManager.usageSource == "claude.ai" ? "claude.ai" : "statusline"
        return HStack(spacing: 6) {
            Circle().fill(stale ? Color.orange : Color.green).frame(width: 7, height: 7)
            Text("\(SyncHelpers.age(since: usageManager.lastUpdated).capitalizedFirst) · \(source)\(usageManager.isRefreshSlowed ? " · ralenti (5 min)" : "")")
                .font(.caption)
                .foregroundColor(stale ? .orange : Color.secondaryText)
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
