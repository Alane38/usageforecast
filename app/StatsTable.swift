import SwiftUI

/// Le tableau complet du journal : la même donnée que les graphiques, lisible ligne à ligne (et par VoiceOver).
struct StatsJournalTable: View {
    let summaries: [DailySummary]
    @State private var isOpen = CommandLine.arguments.contains("--open-journal")

    private let columns: [(title: String, width: CGFloat?)] = [
        ("Jour", 76), ("Semaine", 56), ("Session", 56), ("Pic", 40), ("Heures actives", nil), ("Couverture", 62),
    ]

    var body: some View {
        DisclosureGroup("Journal complet (\(summaries.count) jour\(summaries.count > 1 ? "s" : ""))", isExpanded: $isOpen) {
            VStack(alignment: .leading, spacing: 0) {
                row(columns.map(\.title), isHeader: true)
                Divider().padding(.vertical, 4)
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(summaries.reversed()), id: \.day) { summary in
                            row(cells(summary), isHeader: false, partial: !DailyInsights.isReliable(summary))
                        }
                    }
                }
                .frame(maxHeight: 200)
                Text("Points = % de ta limite hebdomadaire (semaine) ou de la session de 5 h. En gris : journée avec peu de relevés.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.top, 8)
            }
            .padding(.top, 8)
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
    }

    private func cells(_ summary: DailySummary) -> [String] {
        [DailyInsights.date(fromStamp: summary.day).map(StatsStyle.dayLabel) ?? summary.day,
         StatsStyle.points(summary.weeklyUsed), StatsStyle.points(summary.sessionUsed), "\(Int(summary.peakSession)) %",
         StatsStyle.hoursText(summary.activeHours), StatsStyle.percent(min(Double(summary.samples) / 1440, 1))]
    }

    private func row(_ values: [String], isHeader: Bool, partial: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, text in
                Text(text)
                    .font(.system(size: 11, weight: isHeader ? .semibold : .regular).monospacedDigit())
                    .foregroundColor(isHeader || partial ? .secondary : .primary)
                    .lineLimit(2)
                    .frame(width: columns[index].width, alignment: .leading)
                    .frame(maxWidth: columns[index].width == nil ? .infinity : nil, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
