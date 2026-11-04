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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(summary.valueText).font(.system(size: 15, weight: .medium))
            }
            if summary.lots.isEmpty { Text(summary.detail).captionStyle().lineLimit(2) } else { CreditsLotsView(summary: summary) }
        }
        .popoverCard()
    }
}

/// Crédits en plusieurs lots, à la manière du tableau de la Console : un anneau (part restante), « reste sur accordé »
/// et la date d'expiration ; le premier lot à expirer est en orange.
struct CreditsLotsView: View {
    let summary: CreditsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(summary.lots.enumerated()), id: \.offset) { _, lot in line(lot) }
            if let hint = dailyHint { Text(hint).captionStyle() }
        }
    }

    private func color(_ lot: CreditsSummary.LotRow) -> Color { lot.isNext ? .orange : Color.accentColor }

    private func ring(_ lot: CreditsSummary.LotRow) -> some View {
        ZStack {
            Circle().stroke(Color.secondaryText.opacity(0.25), lineWidth: 3)
            Circle().trim(from: 0, to: lot.remainingFraction ?? 1)
                .stroke(color(lot), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }

    private func line(_ lot: CreditsSummary.LotRow) -> some View {
        HStack(spacing: 8) {
            ring(lot)
            Text(lot.amountText).font(.system(size: 12, weight: .medium))
            Spacer(minLength: 4)
            Text(lot.whenText).captionStyle().foregroundColor(lot.isNext ? .orange : Color.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    /// « ≈ 4,55 $ par jour pour ne rien perdre » : repris du détail, qui le met entre parenthèses.
    private var dailyHint: String? {
        guard let open = summary.detail.range(of: "(≈ "), let close = summary.detail.range(of: " par jour)") else { return nil }
        return "≈ " + summary.detail[open.upperBound..<close.lowerBound] + " par jour pour ne rien perdre"
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
