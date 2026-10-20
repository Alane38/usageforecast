import SwiftUI

extension View {
    /// Petit texte grisé, utilisé pour toutes les légendes du popover.
    func captionStyle() -> some View {
        font(.caption).foregroundColor(Color.secondaryText)
    }
}

/// Détail par modèle (Sonnet, Fable), replié par défaut.
struct ModelDetails: View {
    @ObservedObject var usageManager: UsageManager
    @State private var isOpen = false

    private struct ModelShare: Identifiable {
        let name: String
        let percent: Int
        var id: String { name }
    }

    private var shares: [ModelShare] {
        var found: [ModelShare] = []
        if usageManager.hasWeeklySonnet {
            found.append(ModelShare(name: "Sonnet", percent: usageManager.weeklySonnetUsage))
        }
        if usageManager.hasWeeklyFable && usageManager.weeklyFableUsage >= 1 {
            found.append(ModelShare(name: "Fable", percent: usageManager.weeklyFableUsage))
        }
        return found
    }

    @ViewBuilder var body: some View { if !shares.isEmpty { disclosure } }

    private var disclosure: some View {
        DisclosureGroup("Par modèle · semaine", isExpanded: $isOpen) {
            VStack(spacing: 8) {
                ForEach(shares) { share in row(for: share) }
            }
            .padding(.top, 6)
        }
        .captionStyle()
    }

    private func row(for share: ModelShare) -> some View {
        let percent = Double(share.percent)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(share.name).font(.caption)
                Spacer()
                Text("\(share.percent) %").captionStyle()
            }
            GaugeBar(used: percent, projected: nil, expected: nil,
                     tone: UsageTone.of(percent: percent, pace: nil, isStale: false))
        }
    }
}

/// Utilisation supplémentaire (paiement à l'usage) et crédits gratuits de claude.ai, seulement s'ils servent.
struct ExtraUsageRow: View {
    @ObservedObject var usageManager: UsageManager

    private func money(_ minorUnits: Int) -> String {
        CreditsSummary.money(Double(minorUnits) / 100, usageManager.creditCurrency)
    }

    private var hasFreeCredits: Bool { usageManager.freeCreditsMinor > 0 }
    private var isRelevant: Bool { usageManager.hasCreditUsage || hasFreeCredits }

    @ViewBuilder var body: some View { if isRelevant { details } }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            titleLine
            if usageManager.hasCreditUsage { paidUsage }
            if hasFreeCredits {
                Text("\(money(usageManager.freeCreditsMinor)) de crédits gratuits restants").captionStyle()
            }
        }
    }

    private var titleLine: some View {
        HStack {
            Text("Utilisation supplémentaire").captionStyle()
            Spacer()
            Button("Gérer →") { NSWorkspace.shared.open(URL(string: "https://claude.ai/new#settings/usage")!) }
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var paidUsage: some View {
        let spent = usageManager.extraSpentMinor
        let limit = usageManager.extraLimitMinor
        let percent = limit > 0 ? Double(spent) / Double(limit) * 100 : 0
        if limit > 0 {
            GaugeBar(used: percent, projected: nil, expected: nil,
                     tone: UsageTone.of(percent: percent, pace: nil, isStale: false))
        }
        Text(limit > 0 ? "\(money(spent)) sur \(money(limit))" : "\(money(spent)) dépensés").captionStyle()
    }
}

/// Réinitialisations de limite disponibles sur le compte (ex. offre de lancement).
struct LimitResetsLine: View {
    @ObservedObject var usageManager: UsageManager

    private var sentence: String {
        let count = usageManager.limitResetsLeft
        let plural = count > 1 ? "s" : ""
        let deadline = usageManager.limitResetsEndAt.map { " jusqu'au \(Self.dayAndMonth($0.addingTimeInterval(-1)))" } ?? ""
        return "\(count) réinitialisation\(plural) de limite disponible\(plural)\(deadline)"
    }

    @ViewBuilder var body: some View { if usageManager.limitResetsLeft > 0 { Text(sentence).captionStyle() } }

    private static func dayAndMonth(_ date: Date) -> String {
        let french = DateFormatter()
        french.locale = Locale(identifier: "fr_FR")
        french.dateFormat = "d MMM"
        return french.string(from: date)
    }
}

/// Bandeau proposant une mise à jour, avec l'avancement de l'installation.
struct UpdateBanner: View {
    let release: ReleaseInfo
    let currentVersion: String
    let installState: UpdateInstallState
    let install: () -> Void

    private var isInstalling: Bool {
        guard case .working = installState else { return false }
        return true
    }

    var body: some View { banner.popoverCard() }

    private var banner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version \(release.version) disponible").font(.system(size: 13, weight: .medium))
                    Text("Tu as la \(currentVersion).").captionStyle()
                }
                Spacer()
                actions
            }
            progress
        }
    }

    private var actions: some View {
        HStack(spacing: 6) {
            Button("Notes") { NSWorkspace.shared.open(release.pageURL) }.controlSize(.small)
            if release.zipURL != nil {
                Button("Installer", action: install).controlSize(.small).disabled(isInstalling)
            }
        }
    }

    @ViewBuilder
    private var progress: some View {
        switch installState {
        case .idle:
            EmptyView()
        case .working(let step):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(step).captionStyle()
            }
        case .failed(let message):
            Text(message).font(.caption).foregroundColor(UsageTone.danger.color)
        }
    }
}
