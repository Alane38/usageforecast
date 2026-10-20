import SwiftUI

private func shortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.dateFormat = "d MMM"
    return formatter.string(from: date)
}

/// Détail par modèle (Sonnet, Fable), replié par défaut.
struct ModelDetails: View {
    @ObservedObject var usageManager: UsageManager
    @State private var isOpen = false

    private var rows: [(name: String, percent: Int)] {
        var result: [(String, Int)] = []
        if usageManager.hasWeeklySonnet { result.append(("Sonnet", usageManager.weeklySonnetUsage)) }
        if usageManager.hasWeeklyFable && usageManager.weeklyFableUsage >= 1 { result.append(("Fable", usageManager.weeklyFableUsage)) }
        return result
    }

    var body: some View {
        if !rows.isEmpty {
            DisclosureGroup("Par modèle · semaine", isExpanded: $isOpen) {
                VStack(spacing: 8) {
                    ForEach(rows, id: \.name) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.name).font(.caption)
                                Spacer()
                                Text("\(row.percent) %").font(.caption).foregroundColor(Color.secondaryText)
                            }
                            GaugeBar(used: Double(row.percent), projected: nil, expected: nil,
                                     tone: UsageTone.of(percent: Double(row.percent), pace: nil, isStale: false))
                        }
                    }
                }
                .padding(.top, 6)
            }
            .font(.caption)
            .foregroundColor(Color.secondaryText)
        }
    }
}

/// Utilisation supplémentaire (paiement à l'usage) et crédits gratuits de claude.ai, seulement s'ils servent.
struct ExtraUsageRow: View {
    @ObservedObject var usageManager: UsageManager

    private func money(_ minor: Int) -> String {
        CreditsSummary.money(Double(minor) / 100, usageManager.creditCurrency)
    }

    var body: some View {
        if usageManager.hasCreditUsage || usageManager.freeCreditsMinor > 0 {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Utilisation supplémentaire").font(.caption).foregroundColor(Color.secondaryText)
                    Spacer()
                    Button("Gérer →") { NSWorkspace.shared.open(URL(string: "https://claude.ai/new#settings/usage")!) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                if usageManager.hasCreditUsage {
                    let spent = usageManager.extraSpentMinor
                    let limit = usageManager.extraLimitMinor
                    let fraction = limit > 0 ? Double(spent) / Double(limit) : 0
                    if limit > 0 {
                        GaugeBar(used: fraction * 100, projected: nil, expected: nil,
                                 tone: UsageTone.of(percent: fraction * 100, pace: nil, isStale: false))
                    }
                    Text(limit > 0 ? "\(money(spent)) sur \(money(limit))" : "\(money(spent)) dépensés")
                        .font(.caption)
                        .foregroundColor(Color.secondaryText)
                }
                if usageManager.freeCreditsMinor > 0 {
                    Text("\(money(usageManager.freeCreditsMinor)) de crédits gratuits restants")
                        .font(.caption)
                        .foregroundColor(Color.secondaryText)
                }
            }
        }
    }
}

/// Réinitialisations de limite disponibles sur le compte (ex. offre de lancement).
struct LimitResetsLine: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View {
        if usageManager.limitResetsLeft > 0 {
            let count = usageManager.limitResetsLeft
            let until = usageManager.limitResetsEndAt.map { " jusqu'au \(shortDate($0.addingTimeInterval(-1)))" } ?? ""
            Text("\(count) réinitialisation\(count > 1 ? "s" : "") de limite disponible\(count > 1 ? "s" : "")\(until)")
                .font(.caption)
                .foregroundColor(Color.secondaryText)
        }
    }
}
