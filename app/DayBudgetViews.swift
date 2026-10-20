import SwiftUI

extension DayBudget {
    var tone: UsageTone {
        switch level {
        case .ok: return .ok
        case .close: return .warning
        case .over: return .danger
        }
    }
}

/// Consommation du jour face au budget conseillé : une phrase, et une barre quand la place le permet.
/// L'état ne repose pas sur la seule couleur : « dépassé de N % » est écrit.
struct DayBudgetRow: View {
    let budget: DayBudget
    var showsBar = false

    private var textColor: Color { budget.level == .ok ? Color.secondaryText : budget.tone.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DayBudgetText.line(budget))
                .font(.caption)
                .fontWeight(budget.level == .ok ? .regular : .medium)
                .foregroundColor(textColor)
            if showsBar {
                GaugeBar(used: min(budget.fraction, 1) * 100, projected: nil, expected: nil, tone: budget.tone)
            }
            if let consequence = DayBudgetText.consequence(budget) {
                Text(consequence).font(.caption).foregroundColor(Color.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
