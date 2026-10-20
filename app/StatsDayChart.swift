import SwiftUI

/// Colonnes des derniers jours : points de la limite hebdomadaire consommés chaque jour.
/// Une teinte, des barres de 22 pt au plus, une légère pour les journées incomplètes ; étiquettes seulement sur le maximum et aujourd'hui.
struct DayColumnsChart: View {
    let days: [DayPoint]
    let average: Double?

    private let plotHeight: CGFloat = 96
    private let topRoom: CGFloat = 16
    private let axisWidth: CGFloat = 24

    private var ceiling: Double {
        StatsStyle.ceiling(max(days.compactMap { $0.summary?.weeklyUsed }.max() ?? 0, average ?? 0))
    }

    private var tallest: String? {
        days.filter { $0.summary != nil }.max { ($0.summary?.weeklyUsed ?? 0) < ($1.summary?.weeklyUsed ?? 0) }?.day
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                axis
                GeometryReader { geo in plot(width: geo.size.width) }
                    .frame(height: topRoom + plotHeight + 30)
            }
            HStack(spacing: 14) {
                LegendKey(color: StatsStyle.accent, text: "Journée complète")
                LegendKey(color: StatsStyle.accentLight, text: "En cours ou peu de relevés")
            }
            .padding(.leading, axisWidth + 6)
        }
        .accessibilityElement(children: .contain)
    }

    private func y(_ value: Double) -> CGFloat { topRoom + plotHeight * CGFloat(1 - min(max(value, 0), ceiling) / ceiling) }

    private var axis: some View {
        ZStack(alignment: .topTrailing) {
            ForEach([0.0, ceiling / 2, ceiling], id: \.self) { level in
                Text("\(Int(level))").font(.system(size: 9)).foregroundColor(.secondary).offset(y: y(level) - 6)
            }
        }
        .frame(width: axisWidth, height: topRoom + plotHeight, alignment: .topTrailing)
    }

    private func plot(width: CGFloat) -> some View {
        let slot = width / CGFloat(max(days.count, 1))
        let barWidth = min(StatsStyle.maxBarThickness - 2, slot - 8)
        return ZStack(alignment: .topLeading) {
            ForEach([0.0, ceiling / 2, ceiling], id: \.self) { level in
                Rectangle().fill(level == 0 ? StatsStyle.baseline : StatsStyle.gridLine).frame(width: width, height: 1).offset(y: y(level))
            }
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                column(day, slot: slot, barWidth: barWidth).offset(x: CGFloat(index) * slot)
            }
            if let average { averageMark(average, width: width) }
        }
    }

    @ViewBuilder
    private func column(_ day: DayPoint, slot: CGFloat, barWidth: CGFloat) -> some View {
        let used = day.summary?.weeklyUsed
        let height = used.map { max(plotHeight * CGFloat(min($0, ceiling) / ceiling), 2) } ?? 0
        ZStack(alignment: .topLeading) {
            if let used {
                TopRoundedBar()
                    .fill(day.isReliable && !day.isToday ? StatsStyle.accent : StatsStyle.accentLight)
                    .frame(width: barWidth, height: height)
                    .overlay(alignment: .top) {
                        if day.isToday || day.day == tallest {
                            Text("\(Int(used.rounded()))").font(.system(size: 11, weight: .medium)).fixedSize().offset(y: -15)
                        }
                    }
                    .offset(x: (slot - barWidth) / 2, y: topRoom + plotHeight - height)
            } else {
                Rectangle().fill(StatsStyle.baseline).frame(width: barWidth, height: 2).offset(x: (slot - barWidth) / 2, y: topRoom + plotHeight - 2)
            }
            VStack(spacing: 1) {
                Text(String(StatsStyle.weekdayNames[DailyInsights.weekdayIndex(of: day.date)].dropLast()))
                Text(String(Calendar.current.component(.day, from: day.date)))
            }
            .font(.system(size: 10, weight: day.isToday ? .semibold : .regular))
            .foregroundColor(day.isToday ? .primary : .secondary)
            .frame(width: slot)
            .offset(y: topRoom + plotHeight + 5)
        }
        .frame(width: slot, height: topRoom + plotHeight + 30, alignment: .topLeading)
        .contentShape(Rectangle())
        .help(tooltip(day))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tooltip(day))
    }

    private func averageMark(_ value: Double, width: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Rectangle().fill(Color.primary.opacity(0.45)).frame(width: width, height: 1).offset(y: y(value))
            Text("moy. \(StatsStyle.points(value))")
                .font(.system(size: 10)).foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                .offset(y: y(value) - 13)
        }
        .frame(width: width, alignment: .topTrailing)
        .allowsHitTesting(false)
    }

    private func tooltip(_ day: DayPoint) -> String {
        guard let summary = day.summary else { return "\(StatsStyle.dayLabel(day.date)) : aucune donnée (app fermée ou Mac en veille)." }
        let coverage = StatsStyle.percent(min(Double(summary.samples) / 1440, 1))
        let state = day.isToday ? "en cours" : (day.isReliable ? "journée complète" : "peu de relevés")
        return "\(StatsStyle.dayLabel(day.date)) (\(state)) : \(StatsStyle.points(summary.weeklyUsed)) de semaine, "
            + "\(StatsStyle.points(summary.sessionUsed)) de session, pic de session \(Int(summary.peakSession)) %, "
            + "actif à \(StatsStyle.hoursText(summary.activeHours)), \(coverage) de la journée enregistrée."
    }
}
