import SwiftUI

extension UsageManager {
    var creditsSummary: CreditsSummary? { CreditsSummary.make(console: consoleBalance, manual: apiCredits) }
}

private extension View {
    func emphasizedValue() -> some View { font(.system(size: 15, weight: .medium)) }
    func cardTitle() -> some View { font(.system(size: 13, weight: .medium)) }
}

// MARK: - Disposition « jauges »

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
                Text(title).secondaryCaption()
                Spacer()
                Text("\(percent) %").emphasizedValue()
            }
            GaugeBar(used: Double(percent), projected: forecast?.projectedPercent,
                     expected: forecast?.expectedPercent, tone: tone)
            paceLine
            paceSummary
            if let dayBudget { DayBudgetRow(budget: dayBudget) }
            recentLine
        }
    }

    private var paceLine: some View {
        HStack(spacing: 6) {
            if let chip = PaceText.chip(for: forecast, percent: percent) { PaceChip(text: chip, tone: tone) }
            Spacer()
            if let resetsAt {
                Text("reset dans \(MenuBarDisplay.countdown(to: resetsAt))").secondaryCaption()
            } else if let idle = PaceText.idleSession(percent: percent, resetsAt: resetsAt) {
                Text(idle).secondaryCaption()
            }
        }
        .padding(.top, 2)
    }

    /// Le budget du jour a sa propre ligne quand il existe : on n'en répète pas le résumé.
    @ViewBuilder
    private var paceSummary: some View {
        let text = PaceText.summary(for: forecast, showsDailyBudget: showsDailyBudget && dayBudget == nil)
        if !text.isEmpty {
            Text(text).secondaryCaption()
        }
    }

    @ViewBuilder
    private var recentLine: some View {
        if let line = PaceText.recentLine(recent) {
            let isExhausting = recent?.exhaustsAt != nil
            Text(line).font(.caption).foregroundColor(isExhausting ? UsageTone.warning.color : Color.secondaryText)
        }
    }
}

struct CreditsGaugeRow: View {
    let summary: CreditsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.title).secondaryCaption()
                Spacer()
                Text(summary.valueText).emphasizedValue()
            }
            GaugeBar(used: summary.usedFraction * 100, projected: nil, expected: nil, tone: .ok)
            Text(summary.detail).secondaryCaption()
        }
    }
}

/// Disposition « jauges ».
struct GaugesLayout: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sessionGauge
            weekGauge
            if let credits = usageManager.creditsSummary {
                Divider()
                CreditsGaugeRow(summary: credits)
            }
        }
    }

    private var sessionGauge: some View {
        GaugeRow(title: "Session · 5 h", percent: usageManager.sessionUsage, forecast: usageManager.sessionForecast,
                 tone: usageManager.sessionTone, resetsAt: usageManager.sessionResetsAt, showsDailyBudget: false,
                 recent: usageManager.sessionRecentForecast)
    }

    private var weekGauge: some View {
        GaugeRow(title: "Semaine · 7 j", percent: usageManager.weeklyUsage, forecast: usageManager.weeklyForecast,
                 tone: usageManager.weeklyTone, resetsAt: usageManager.weeklyResetsAt, showsDailyBudget: true,
                 recent: usageManager.weeklyRecentForecast, dayBudget: usageManager.dayBudget)
    }
}

// MARK: - Disposition « cartes »

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
                Text(title).cardTitle()
                Text(caption).secondaryCaption().lineLimit(2)
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

    private var headline: String {
        if (forecast?.usedPercent ?? 0) >= 100 { return "Limite atteinte" }
        let allowedToday = dayBudget?.allowed ?? forecast?.remainingPerDay ?? 0
        return "\(Int(allowedToday.rounded())) %"
    }

    private var countdownLine: String {
        guard let resetsAt else { return "" }
        let prefix = dayBudget == nil ? "par jour jusqu'au reset, dans " : "à ne pas dépasser aujourd'hui · reset dans "
        return prefix + MenuBarDisplay.countdown(to: resetsAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Budget d'aujourd'hui").secondaryCaption()
            Text(headline).font(.system(size: 28, weight: .medium))
            Text(countdownLine).secondaryCaption()
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
                Text(summary.title).cardTitle()
                Text(summary.detail).secondaryCaption().lineLimit(2)
            }
            Spacer()
            Text(summary.valueText).emphasizedValue()
        }
        .popoverCard()
    }
}

/// Disposition « cartes » : budget du jour, deux anneaux, crédits.
struct CardsLayout: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View {
        VStack(spacing: 8) {
            BudgetHero(forecast: usageManager.weeklyForecast, resetsAt: usageManager.weeklyResetsAt, dayBudget: usageManager.dayBudget)
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

    private func resetCaption(_ resetsAt: Date?, percent: Int) -> String {
        if let resetsAt { return "reset \(MenuBarDisplay.countdown(to: resetsAt))" }
        return PaceText.idleSession(percent: percent, resetsAt: nil) ?? ""
    }
}
