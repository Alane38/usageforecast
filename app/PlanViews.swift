import SwiftUI

/// Planning de la semaine : ce qui était consommé avant aujourd'hui, le budget de la journée (une jauge qui se remplit),
/// puis la part utilisable chaque jour suivant jusqu'au reset.
struct WeekPlanDisclosure: View {
    @ObservedObject var usageManager: UsageManager
    @State private var isOpen = CommandLine.arguments.contains("--open-plan")

    /// Avec l'historique du jour : plan depuis minuit. Sans lui : plan depuis maintenant, sans jauge.
    private var plan: DayPlan? {
        guard let resetsAt = usageManager.weeklyResetsAt else { return nil }
        let used = Double(usageManager.weeklyUsage)
        if let usedToday = usageManager.weeklyUsedToday,
           let plan = WeekPlan.makeFromMidnight(used: used, usedToday: usedToday, now: AppClock.now, resetsAt: resetsAt) { return plan }
        let segments = WeekPlan.make(used: used, now: AppClock.now, resetsAt: resetsAt)
        return segments.isEmpty ? nil : DayPlan(usedBeforeToday: used, segments: segments)
    }

    var body: some View {
        if let plan {
            let hasGauge = plan.segments.first?.consumed != nil
            DisclosureGroup("Planning de la semaine", isExpanded: $isOpen) {
                VStack(alignment: .leading, spacing: 6) {
                    if let budget = usageManager.dayBudget { DayBudgetRow(budget: budget) }
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            block(width: width(plan.usedBeforeToday, geo.size.width, count: plan.segments.count),
                                  text: "\(Int(plan.usedBeforeToday.rounded())) %", color: Color.primary.opacity(0.16))
                            ForEach(Array(plan.segments.enumerated()), id: \.offset) { _, segment in
                                dayBlock(segment, width: width(segment.percent, geo.size.width, count: plan.segments.count))
                            }
                        }
                    }
                    .frame(height: 24)
                    labels(plan, greyLabel: hasGauge ? "avant auj." : "utilisé")
                    Text("Part de la limite à ne pas dépasser chaque jour pour arriver au reset (\(usageManager.weeklyResetsAt.map(AlertRules.dayAndClock) ?? "")) sans être bloqué.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.secondaryText)
                }
                .padding(.top, 6)
            }
            .font(.caption)
            .foregroundColor(Color.secondaryText)
        }
    }

    /// Largeur d'un bloc au prorata de son pourcentage, en retirant l'espace entre les blocs.
    private func width(_ percent: Double, _ total: CGFloat, count: Int) -> CGFloat {
        max((total - CGFloat(count) * 2) * CGFloat(percent / 100), 2)
    }

    private func block(width: CGFloat, text: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(color)
            if width >= 34 { Text(text).font(.system(size: 11, weight: .medium)).foregroundColor(.primary) }
        }
        .frame(width: width)
    }

    /// Bloc d'un jour. Celui d'aujourd'hui se remplit de ce qui est consommé et passe au rouge quand il est dépassé.
    @ViewBuilder
    private func dayBlock(_ segment: PlanSegment, width: CGFloat) -> some View {
        if let consumed = segment.consumed, let budget = usageManager.dayBudget {
            let fraction = segment.percent > 0 ? min(consumed / segment.percent, 1) : 1
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(budget.tone.color.opacity(0.22))
                RoundedRectangle(cornerRadius: 4).fill(budget.tone.color.opacity(0.6)).frame(width: max(width * fraction, consumed > 0 ? 3 : 0))
                if width >= 56 {
                    Text("\(Int(consumed.rounded())) / \(Int(segment.percent.rounded())) %")
                        .font(.system(size: 11, weight: .medium)).foregroundColor(.primary).frame(width: width)
                } else if width >= 34 {
                    Text("\(Int(consumed.rounded())) %").font(.system(size: 11, weight: .medium)).foregroundColor(.primary).frame(width: width)
                }
            }
            .frame(width: width)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(DayBudgetText.line(budget))
            .help(DayBudgetText.line(budget))
        } else {
            block(width: width, text: "\(Int(segment.percent.rounded())) %",
                  color: usageManager.weeklyTone.color.opacity(segment.isToday ? 0.55 : 0.28))
        }
    }

    /// Une étiquette par bloc, centrée sous lui, écartée si elle chevaucherait la précédente (blocs étroits en fin de semaine).
    private func labels(_ plan: DayPlan, greyLabel: String) -> some View {
        GeometryReader { geo in
            let count = plan.segments.count
            let widths = [width(plan.usedBeforeToday, geo.size.width, count: count)]
                + plan.segments.map { width($0.percent, geo.size.width, count: count) }
            let texts = [greyLabel] + plan.segments.map(\.label)
            let placed = Self.placeLabels(texts: texts, blockWidths: widths, gap: 2)
            ZStack(alignment: .topLeading) {
                ForEach(placed, id: \.index) { label in
                    Text(texts[label.index]).font(.system(size: 11)).fixedSize().position(x: label.centerX, y: 7)
                }
            }
        }
        .frame(height: 14)
    }

    /// Centres des étiquettes retenues : une étiquette est gardée si elle ne recouvre pas la dernière gardée, et elle reste
    /// dans la largeur disponible (un premier bloc étroit ne la rogne plus).
    static func placeLabels(texts: [String], blockWidths: [CGFloat], gap: CGFloat) -> [(index: Int, centerX: CGFloat)] {
        let total = blockWidths.reduce(0, +) + gap * CGFloat(max(blockWidths.count - 1, 0))
        var result: [(index: Int, centerX: CGFloat)] = []
        var cursor: CGFloat = 0
        var lastRight: CGFloat = -.infinity
        for (index, width) in blockWidths.enumerated() {
            let labelWidth = CGFloat(texts[index].count) * 6.2 + 4
            let center = min(max(cursor + width / 2, labelWidth / 2), max(total - labelWidth / 2, labelWidth / 2))
            if center - labelWidth / 2 >= lastRight + 2 {
                result.append((index, center))
                lastRight = center + labelWidth / 2
            }
            cursor += width + gap
        }
        return result
    }
}
