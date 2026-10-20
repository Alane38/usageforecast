import SwiftUI

extension UsageManager {
    var creditsSummary: CreditsSummary? { CreditsSummary.make(console: consoleBalance, manual: apiCredits) }
}

/// Une limite sous forme de jauge : valeur, barre avec repère de rythme, puce et prévision.
struct GaugeRow: View {
    let title: String
    let percent: Int
    let forecast: WindowForecast?
    let tone: UsageTone
    let resetsAt: Date?
    let showsDailyBudget: Bool
    var recent: RecentForecast?
    var dayBudget: DayBudget?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.caption).foregroundColor(Color.secondaryText)
                Spacer()
                Text("\(percent) %").font(.system(size: 15, weight: .medium))
            }
            GaugeBar(used: Double(percent), projected: forecast?.projectedPercent,
                     expected: forecast?.expectedPercent, tone: tone)
            HStack(spacing: 6) {
                if let chip = PaceText.chip(for: forecast, percent: percent) { PaceChip(text: chip, tone: tone) }
                Spacer()
                if let resetsAt {
                    Text("reset dans \(MenuBarDisplay.countdown(to: resetsAt))").font(.caption).foregroundColor(Color.secondaryText)
                } else if let idle = PaceText.idleSession(percent: percent, resetsAt: resetsAt) {
                    Text(idle).font(.caption).foregroundColor(Color.secondaryText)
                }
            }
            .padding(.top, 2)
            let summary = PaceText.summary(for: forecast, showsDailyBudget: showsDailyBudget && dayBudget == nil)
            if !summary.isEmpty {
                Text(summary).font(.caption).foregroundColor(Color.secondaryText)
            }
            if let dayBudget { DayBudgetRow(budget: dayBudget) }
            if let line = PaceText.recentLine(recent) {
                Text(line).font(.caption).foregroundColor(recent?.exhaustsAt == nil ? Color.secondaryText : UsageTone.warning.color)
            }
        }
    }
}

struct CreditsGaugeRow: View {
    let summary: CreditsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.title).font(.caption).foregroundColor(Color.secondaryText)
                Spacer()
                Text(summary.valueText).font(.system(size: 15, weight: .medium))
            }
            GaugeBar(used: summary.usedFraction * 100, projected: nil, expected: nil, tone: .ok)
            Text(summary.detail).font(.caption).foregroundColor(Color.secondaryText)
        }
    }
}

/// Disposition « jauges ».
struct GaugesLayout: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GaugeRow(title: "Session · 5 h", percent: usageManager.sessionUsage, forecast: usageManager.sessionForecast,
                     tone: usageManager.sessionTone, resetsAt: usageManager.sessionResetsAt, showsDailyBudget: false,
                     recent: usageManager.sessionRecentForecast)
            GaugeRow(title: "Semaine · 7 j", percent: usageManager.weeklyUsage, forecast: usageManager.weeklyForecast,
                     tone: usageManager.weeklyTone, resetsAt: usageManager.weeklyResetsAt, showsDailyBudget: true,
                     recent: usageManager.weeklyRecentForecast, dayBudget: usageManager.dayBudget)
            if let credits = usageManager.creditsSummary {
                Divider()
                CreditsGaugeRow(summary: credits)
            }
        }
    }
}

struct RingCard: View {
    let title: String
    let caption: String
    let percent: Double
    let tone: UsageTone
    /// Libellé du rythme : la couleur de l'anneau ne doit jamais être seule à dire l'état.
    var pace: String?

    var body: some View {
        HStack(spacing: 10) {
            RingView(percent: percent, tone: tone)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(caption).font(.caption).foregroundColor(Color.secondaryText).lineLimit(2)
                if let pace { PaceChip(text: pace, tone: tone).padding(.top, 2) }
            }
        }
        .popoverCard()
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct BudgetHero: View {
    let forecast: WindowForecast?
    let resetsAt: Date?
    var dayBudget: DayBudget?

    private var isMaxed: Bool { (forecast?.usedPercent ?? 0) >= 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Budget d'aujourd'hui").font(.caption).foregroundColor(Color.secondaryText)
            Text(isMaxed ? "Limite atteinte" : "\(Int((dayBudget?.allowed ?? forecast?.remainingPerDay ?? 0).rounded())) %")
                .font(.system(size: 28, weight: .medium))
            Text(resetsAt.map { (dayBudget == nil ? "par jour jusqu'au reset, dans " : "à ne pas dépasser aujourd'hui · reset dans ") + MenuBarDisplay.countdown(to: $0) } ?? "")
                .font(.caption)
                .foregroundColor(Color.secondaryText)
            if let dayBudget { DayBudgetRow(budget: dayBudget, showsBar: true).padding(.top, 4) }
        }
        .popoverCard()
    }
}

struct CreditsCard: View {
    let summary: CreditsSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title).font(.system(size: 13, weight: .medium))
                Text(summary.detail).font(.caption).foregroundColor(Color.secondaryText).lineLimit(2)
            }
            Spacer()
            Text(summary.valueText).font(.system(size: 15, weight: .medium))
        }
        .popoverCard()
    }
}

/// Disposition « cartes » : budget du jour, deux anneaux, crédits.
struct CardsLayout: View {
    @ObservedObject var usageManager: UsageManager

    private func resetCaption(_ date: Date?, percent: Int) -> String {
        date.map { "reset \(MenuBarDisplay.countdown(to: $0))" } ?? (PaceText.idleSession(percent: percent, resetsAt: date) ?? "")
    }

    var body: some View {
        VStack(spacing: 8) {
            BudgetHero(forecast: usageManager.weeklyForecast, resetsAt: usageManager.weeklyResetsAt, dayBudget: usageManager.dayBudget)
            HStack(spacing: 8) {
                RingCard(title: "Session", caption: resetCaption(usageManager.sessionResetsAt, percent: usageManager.sessionUsage),
                         percent: Double(usageManager.sessionUsage), tone: usageManager.sessionTone,
                         pace: PaceText.compactChip(for: usageManager.sessionForecast, percent: usageManager.sessionUsage))
                RingCard(title: "Semaine", caption: resetCaption(usageManager.weeklyResetsAt, percent: usageManager.weeklyUsage),
                         percent: Double(usageManager.weeklyUsage), tone: usageManager.weeklyTone,
                         pace: PaceText.compactChip(for: usageManager.weeklyForecast, percent: usageManager.weeklyUsage))
            }
            .fixedSize(horizontal: false, vertical: true)
            if let credits = usageManager.creditsSummary { CreditsCard(summary: credits) }
        }
    }
}
