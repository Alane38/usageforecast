import SwiftUI

struct RingCard: View {
    let title: String
    let caption: String
    let percent: Double
    let tone: UsageTone
    /// Libellé du rythme : la couleur de l'anneau ne doit jamais être seule à dire l'état.
    var pace: String?

    var body: some View { card.popoverCard().frame(maxHeight: .infinity, alignment: .top) }

    private var card: some View {
        HStack(spacing: 10) {
            RingView(percent: percent, tone: tone)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(caption).captionStyle().lineLimit(2)
                if let pace { PaceChip(text: pace, tone: tone).padding(.top, 2) }
            }
        }
    }
}

struct BudgetHero: View {
    let forecast: WindowForecast?
    let resetsAt: Date?
    var dayBudget: DayBudget?

    private var headline: String {
        let isMaxed = (forecast?.usedPercent ?? 0) >= 100
        if isMaxed { return "Limite atteinte" }
        let allowance = dayBudget?.allowed ?? forecast?.remainingPerDay ?? 0
        return "\(Int(allowance.rounded())) %"
    }

    private var explanation: String {
        guard let resetsAt else { return "" }
        let lead = dayBudget == nil ? "par jour jusqu'au reset, dans " : "à ne pas dépasser aujourd'hui · reset dans "
        return lead + MenuBarDisplay.countdown(to: resetsAt)
    }

    var body: some View { card.popoverCard() }

    private var card: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Budget d'aujourd'hui").captionStyle()
            Text(headline).font(.system(size: 28, weight: .medium))
            Text(explanation).captionStyle()
            if let dayBudget { DayBudgetRow(budget: dayBudget, showsBar: true).padding(.top, 4) }
        }
    }
}

struct CreditsCard: View {
    let summary: CreditsSummary

    var body: some View { row.popoverCard() }

    private var row: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title).font(.system(size: 13, weight: .medium))
                Text(summary.detail).captionStyle().lineLimit(2)
            }
            Spacer()
            Text(summary.valueText).font(.system(size: 15, weight: .medium))
        }
    }
}

/// Disposition « cartes » : budget du jour, deux anneaux, crédits.
struct CardsLayout: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View { stack }

    private var stack: some View {
        VStack(spacing: 8) {
            BudgetHero(forecast: usageManager.weeklyForecast, resetsAt: usageManager.weeklyResetsAt,
                       dayBudget: usageManager.dayBudget)
            rings
            if let credits = usageManager.creditsSummary { CreditsCard(summary: credits) }
        }
    }

    private var rings: some View {
        HStack(spacing: 8) {
            RingCard(title: "Session", caption: resetCaption(usageManager.sessionResetsAt, percent: usageManager.sessionUsage),
                     percent: Double(usageManager.sessionUsage), tone: usageManager.sessionTone,
                     pace: PaceText.compactChip(for: usageManager.sessionForecast, percent: usageManager.sessionUsage))
            RingCard(title: "Semaine", caption: resetCaption(usageManager.weeklyResetsAt, percent: usageManager.weeklyUsage),
                     percent: Double(usageManager.weeklyUsage), tone: usageManager.weeklyTone,
                     pace: PaceText.compactChip(for: usageManager.weeklyForecast, percent: usageManager.weeklyUsage))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func resetCaption(_ resetDate: Date?, percent: Int) -> String {
        if let resetDate { return "reset \(MenuBarDisplay.countdown(to: resetDate))" }
        return PaceText.idleSession(percent: percent, resetsAt: resetDate) ?? ""
    }
}
