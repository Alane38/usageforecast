import SwiftUI

private struct MeasuredHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(nextValue(), value)
    }
}

/// Contenu du popover : en-tête, la disposition choisie, détails secondaires, statut des services, fraîcheur.
struct PopoverView: View {
    @ObservedObject var usageManager: UsageManager
    @ObservedObject var statusManager: StatusManager
    @State private var contentHeight: CGFloat = 250
    @Environment(\.colorScheme) private var scheme

    private static let width: CGFloat = 360
    private static let heightRange: ClosedRange<CGFloat> = 100...640

    private var visibleHeight: CGFloat {
        min(max(contentHeight, Self.heightRange.lowerBound), Self.heightRange.upperBound)
    }

    private var backgroundTint: Color {
        scheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.3) : Color.white.opacity(0.85)
    }

    var body: some View { scrollingContent }

    private var scrollingContent: some View {
        ScrollView(showsIndicators: false) {
            sections
                .padding(16)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: MeasuredHeightKey.self, value: proxy.size.height)
                })
        }
        .frame(width: Self.width, height: visibleHeight)
        .background(backgroundTint)
        .onPreferenceChange(MeasuredHeightKey.self) { height in
            if height > 0 { contentHeight = height }
        }
        .onAppear { usageManager.updatePercentages() }
    }

    private var hasData: Bool { usageManager.hasFetchedData }
    private var showsServiceStatus: Bool { statusManager.hasFetched }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let message = usageManager.errorMessage {
                Text(message).font(.caption).foregroundColor(.orange)
            }
            usageOrOnboarding
            if showsServiceStatus {
                Divider()
                StatusSection(statusManager: statusManager)
            }
            if let release = usageManager.availableUpdate { updateBanner(for: release) }
            if hasData { footer }
        }
    }

    @ViewBuilder
    private var usageOrOnboarding: some View {
        if hasData {
            switch usageManager.popoverLayout {
            case .gauges: GaugesLayout(usageManager: usageManager)
            case .cards: CardsLayout(usageManager: usageManager)
            }
            if usageManager.loan != nil {
                Divider()
                LoanBlock(usageManager: usageManager)
                Divider()
            } else if usageManager.revocationStatus != nil {
                RevocationLine(usageManager: usageManager)
            }
            WeekPlanDisclosure(usageManager: usageManager)
            HistoryDisclosure(usageManager: usageManager)
            ModelDetails(usageManager: usageManager)
            ExtraUsageRow(usageManager: usageManager)
            LimitResetsLine(usageManager: usageManager)
        } else {
            PopoverOnboarding()
        }
    }

    private var header: some View {
        HStack {
            Text(Brand.name).font(.headline)
            Spacer()
            HeaderButton(symbol: "arrow.clockwise", help: "Actualiser") { refreshEverything() }
            HeaderButton(symbol: "gearshape", help: "Réglages") { showSettings() }
        }
    }

    private func updateBanner(for release: ReleaseInfo) -> some View {
        UpdateBanner(release: release, currentVersion: usageManager.currentVersion,
                     installState: usageManager.updateInstallState,
                     install: { usageManager.installUpdate() })
    }

    private var footer: some View {
        let age = SyncHelpers.age(since: usageManager.lastUpdated)
        let source = usageManager.usageSource == "claude.ai" ? "claude.ai" : "statusline"
        let slowedNote = usageManager.isRefreshSlowed ? " · ralenti (5 min)" : ""
        return FreshnessLine(text: "\(age.prefix(1).uppercased() + age.dropFirst()) · \(source)\(slowedNote)",
                             isStale: SyncHelpers.isStale(usageManager.lastUpdated))
    }
}

private func showSettings() {
    (NSApp.delegate as? AppDelegate)?.openSettings()
}

private func refreshEverything() {
    (NSApp.delegate as? AppDelegate)?.refreshAll()
}

private struct HeaderButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundColor(Color.secondaryText)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

private struct PopoverOnboarding: View {
    var body: some View { card.popoverCard() }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pas encore de données").font(.system(size: 13, weight: .medium))
            Text("Connecte ta session claude.ai dans les réglages, ou lance Claude Code pour lire ses limites.")
                .captionStyle()
            Button("Ouvrir les réglages") { showSettings() }.controlSize(.small)
        }
    }
}

/// Ligne de fraîcheur : pastille verte, ou orange quand les données sont périmées.
private struct FreshnessLine: View {
    let text: String
    let isStale: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(isStale ? Color.orange : Color.green).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundColor(isStale ? .orange : Color.secondaryText)
        }
    }
}
