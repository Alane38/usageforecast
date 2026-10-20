import SwiftUI

/// Part des jours où tu es actif à chaque heure : 24 colonnes, étiquette seulement sur l'heure de pointe.
struct HourColumnsChart: View {
    let stats: [HourStat]
    let peak: HourStat?

    private let plotHeight: CGFloat = 64
    private let topRoom: CGFloat = 16
    private let axisWidth: CGFloat = 32

    private var totalDays: Int { stats.first?.totalDays ?? 0 }

    var body: some View {
        if totalDays == 0 {
            Text("Pas encore de journée exploitable (au moins 5 h de relevés dans la journée).")
                .font(.caption).foregroundColor(.secondary)
        } else {
            HStack(alignment: .top, spacing: 6) {
                axis
                GeometryReader { geo in plot(width: geo.size.width) }.frame(height: topRoom + plotHeight + 20)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func y(_ fraction: Double) -> CGFloat { topRoom + plotHeight * CGFloat(1 - fraction) }

    private var axis: some View {
        ZStack(alignment: .topTrailing) {
            ForEach([(1.0, "100 %"), (0.5, "50 %"), (0.0, "0")], id: \.0) { level, text in
                Text(text).font(.system(size: 9)).foregroundColor(.secondary).offset(y: y(level) - 6)
            }
        }
        .frame(width: axisWidth, height: topRoom + plotHeight, alignment: .topTrailing)
    }

    private func plot(width: CGFloat) -> some View {
        let slot = width / 24
        let barWidth = min(14, slot - 3)
        let fill = totalDays >= StatsStyle.indicativeBelow ? StatsStyle.accent : StatsStyle.accentLight
        return ZStack(alignment: .topLeading) {
            ForEach([0.0, 0.5, 1.0], id: \.self) { level in
                Rectangle().fill(level == 0 ? StatsStyle.baseline : StatsStyle.gridLine).frame(width: width, height: 1).offset(y: y(level))
            }
            ForEach(stats, id: \.hour) { stat in
                let height = stat.activeDays > 0 ? max(plotHeight * CGFloat(stat.fraction), 2) : 0
                ZStack(alignment: .topLeading) {
                    if stat.activeDays > 0 {
                        TopRoundedBar().fill(fill).frame(width: barWidth, height: height)
                            .overlay(alignment: .top) {
                                if stat.hour == peak?.hour {
                                    Text(StatsStyle.hour(stat.hour)).font(.system(size: 11, weight: .medium)).fixedSize().offset(y: -15)
                                }
                            }
                            .offset(x: (slot - barWidth) / 2, y: topRoom + plotHeight - height)
                    }
                    if stat.hour % 6 == 0 {
                        Text(StatsStyle.hour(stat.hour)).font(.system(size: 10)).foregroundColor(.secondary)
                            .fixedSize().frame(width: slot, alignment: .leading).offset(x: 0, y: topRoom + plotHeight + 5)
                    }
                }
                .frame(width: slot, height: topRoom + plotHeight + 20, alignment: .topLeading)
                .contentShape(Rectangle())
                .help("\(StatsStyle.hour(stat.hour)) : actif \(stat.activeDays) jour\(stat.activeDays > 1 ? "s" : "") sur \(stat.totalDays) (\(StatsStyle.percent(stat.fraction)))")
                .accessibilityLabel("\(StatsStyle.hour(stat.hour)) : actif \(stat.activeDays) jours sur \(stat.totalDays)")
                .offset(x: CGFloat(stat.hour) * slot)
            }
        }
    }
}

/// Consommation moyenne pour chaque jour de la semaine. Les barres pleines reposent sur 3 jours observés ou plus ;
/// les barres claires sont indicatives (1 ou 2 jours) ; un trait seul = aucun jour fiable.
struct WeekdayColumnsChart: View {
    let stats: [WeekdayStat]

    private let plotHeight: CGFloat = 76
    private let topRoom: CGFloat = 16
    private static let names = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]

    private var ceiling: Double { StatsStyle.ceiling(stats.compactMap(\.average).max() ?? 0) }
    private var tallest: Int? { stats.filter { $0.average != nil }.max { ($0.average ?? 0) < ($1.average ?? 0) }?.weekday }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in plot(width: geo.size.width) }.frame(height: topRoom + plotHeight + 32)
            HStack(spacing: 14) {
                LegendKey(color: StatsStyle.accent, text: "3 jours observés ou plus")
                LegendKey(color: StatsStyle.accentLight, text: "Indicatif (1 ou 2 jours)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func plot(width: CGFloat) -> some View {
        let slot = width / 7
        let barWidth = min(StatsStyle.maxBarThickness, slot - 14)
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(StatsStyle.baseline).frame(width: width, height: 1).offset(y: topRoom + plotHeight)
            ForEach(stats, id: \.weekday) { stat in
                let height = stat.average.map { max(plotHeight * CGFloat($0 / ceiling), 2) } ?? 0
                ZStack(alignment: .topLeading) {
                    if let average = stat.average {
                        TopRoundedBar().fill(stat.isSolid ? StatsStyle.accent : StatsStyle.accentLight).frame(width: barWidth, height: height)
                            .overlay(alignment: .top) {
                                if stat.weekday == tallest {
                                    Text(StatsStyle.points(average)).font(.system(size: 11, weight: .medium)).fixedSize().offset(y: -15)
                                }
                            }
                            .offset(x: (slot - barWidth) / 2, y: topRoom + plotHeight - height)
                    } else {
                        Rectangle().fill(StatsStyle.baseline).frame(width: barWidth, height: 2)
                            .offset(x: (slot - barWidth) / 2, y: topRoom + plotHeight - 2)
                    }
                    VStack(spacing: 1) {
                        Text(StatsStyle.weekdayNames[stat.weekday]).font(.system(size: 10)).foregroundColor(.primary)
                        Text(stat.count > 0 ? "\(stat.count) j" : "—").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    .frame(width: slot).offset(y: topRoom + plotHeight + 5)
                }
                .frame(width: slot, height: topRoom + plotHeight + 32, alignment: .topLeading)
                .contentShape(Rectangle())
                .help(tooltip(stat))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tooltip(stat))
                .offset(x: CGFloat(stat.weekday) * slot)
            }
        }
    }

    private func tooltip(_ stat: WeekdayStat) -> String {
        let name = Self.names[stat.weekday]
        guard let average = stat.average else { return "\(name) : aucun jour exploitable observé pour l'instant." }
        let quality = stat.isSolid ? "moyenne fiable" : "indicatif, il faut au moins \(DailyInsights.solidWeekdayCount) jours"
        return "\(name) : \(StatsStyle.points(average)) en moyenne sur \(stat.count) jour\(stat.count > 1 ? "s" : "") (\(quality))."
    }
}
