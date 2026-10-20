import SwiftUI

extension UsageManager {
    var creditsSummary: CreditsSummary? { CreditsSummary.make(console: consoleBalance, manual: apiCredits) }
}

/// Ligne « titre ... valeur » commune aux jauges.
private struct LabelledValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).captionStyle()
            Spacer()
            Text(value).font(.system(size: 15, weight: .medium))
        }
    }
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

    var body: some View { column }

    private var column: some View {
        VStack(alignment: .leading, spacing: 5) {
            LabelledValue(label: title, value: "\(percent) %")
            GaugeBar(used: Double(percent), projected: forecast?.projectedPercent,
                     expected: forecast?.expectedPercent, tone: tone)
            paceLine
            notes
        }
    }

    private var paceLine: some View {
        HStack(spacing: 6) {
            if let chip = PaceText.chip(for: forecast, percent: percent) { PaceChip(text: chip, tone: tone) }
            Spacer()
            resetNote
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var resetNote: some View {
        if let resetsAt {
            Text("reset dans \(MenuBarDisplay.countdown(to: resetsAt))").captionStyle()
        } else if let idleNote = PaceText.idleSession(percent: percent, resetsAt: resetsAt) {
            Text(idleNote).captionStyle()
        }
    }

    @ViewBuilder
    private var notes: some View {
        let summary = PaceText.summary(for: forecast, showsDailyBudget: showsDailyBudget && dayBudget == nil)
        if !summary.isEmpty { Text(summary).captionStyle() }
        if let dayBudget { DayBudgetRow(budget: dayBudget) }
        if let recentLine = PaceText.recentLine(recent) {
            let isExhausting = recent?.exhaustsAt != nil
            Text(recentLine).font(.caption)
                .foregroundColor(isExhausting ? UsageTone.warning.color : Color.secondaryText)
        }
    }
}

struct CreditsGaugeRow: View {
    let summary: CreditsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            LabelledValue(label: summary.title, value: summary.valueText)
            GaugeBar(used: summary.usedFraction * 100, projected: nil, expected: nil, tone: .ok)
            Text(summary.detail).captionStyle()
        }
    }
}

/// Disposition « jauges ».
struct GaugesLayout: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View { stack }

    private var stack: some View {
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
