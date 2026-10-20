import SwiftUI

private extension Date {
    /// « 19 oct. » : jour et mois abrégé, toujours en français.
    var dayAndMonth: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }
}

extension View {
    /// Petit texte grisé des popovers.
    func secondaryCaption() -> some View {
        font(.caption).foregroundColor(Color.secondaryText)
    }
}

/// Détail par modèle (Sonnet, Fable), replié par défaut.
struct ModelDetails: View {
    @ObservedObject var usageManager: UsageManager
    @State private var isOpen = false

    private struct ModelUsage {
        let name: String
        let percent: Int
    }

    /// Fable n'apparaît qu'à partir de 1 % : en dessous, la ligne n'apprend rien.
    private var models: [ModelUsage] {
        var usages: [ModelUsage] = []
        if usageManager.hasWeeklySonnet {
            usages.append(ModelUsage(name: "Sonnet", percent: usageManager.weeklySonnetUsage))
        }
        if usageManager.hasWeeklyFable && usageManager.weeklyFableUsage >= 1 {
            usages.append(ModelUsage(name: "Fable", percent: usageManager.weeklyFableUsage))
        }
        return usages
    }

    var body: some View {
        if !models.isEmpty {
            DisclosureGroup("Par modèle · semaine", isExpanded: $isOpen) {
                VStack(spacing: 8) {
                    ForEach(models, id: \.name, content: row)
                }
                .padding(.top, 6)
            }
            .secondaryCaption()
        }
    }

    private func row(_ model: ModelUsage) -> some View {
        let percent = Double(model.percent)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model.name).font(.caption)
                Spacer()
                Text("\(model.percent) %").secondaryCaption()
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

    var body: some View {
        if usageManager.hasCreditUsage || usageManager.freeCreditsMinor > 0 {
            VStack(alignment: .leading, spacing: 5) {
                titleLine
                if usageManager.hasCreditUsage { paidUsage }
                if usageManager.freeCreditsMinor > 0 {
                    Text("\(money(usageManager.freeCreditsMinor)) de crédits gratuits restants").secondaryCaption()
                }
            }
        }
    }

    private var titleLine: some View {
        HStack {
            Text("Utilisation supplémentaire").secondaryCaption()
            Spacer()
            Button("Gérer →") { NSWorkspace.shared.open(URL(string: "https://claude.ai/new#settings/usage")!) }
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var paidUsage: some View {
        let spent = usageManager.extraSpentMinor
        let cap = usageManager.extraLimitMinor
        if cap > 0 {
            let percent = Double(spent) / Double(cap) * 100
            GaugeBar(used: percent, projected: nil, expected: nil,
                     tone: UsageTone.of(percent: percent, pace: nil, isStale: false))
            Text("\(money(spent)) sur \(money(cap))").secondaryCaption()
        } else {
            Text("\(money(spent)) dépensés").secondaryCaption()
        }
    }
}

/// Réinitialisations de limite disponibles sur le compte (ex. offre de lancement).
struct LimitResetsLine: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View {
        let count = usageManager.limitResetsLeft
        if count > 0 {
            Text(sentence(count: count)).secondaryCaption()
        }
    }

    private func sentence(count: Int) -> String {
        let plural = count > 1 ? "s" : ""
        // La date de fin est exclusive : on affiche la veille, dernier jour où l'offre sert.
        let deadline = usageManager.limitResetsEndAt.map { " jusqu'au \($0.addingTimeInterval(-1).dayAndMonth)" } ?? ""
        return "\(count) réinitialisation\(plural) de limite disponible\(plural)\(deadline)"
    }
}
