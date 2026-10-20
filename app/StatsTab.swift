import AppKit
import SwiftUI

/// Onglet « Statistiques » : ton rythme habituel, lu dans le journal quotidien. Du plus important au détail :
/// quatre chiffres clés, les 14 derniers jours, les heures de travail, les jours de la semaine, la comparaison de semaines, le tableau complet.
struct StatsTab: View {
    @ObservedObject var usageManager: UsageManager

    private var summaries: [DailySummary] { usageManager.dailySummaries }

    var body: some View {
        let recent = DailyInsights.recentDays(summaries, count: 14)
        let average = DailyInsights.averagePerDay(summaries)
        let hours = DailyInsights.hourStats(summaries)
        let peak = DailyInsights.peakHour(hours)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if summaries.isEmpty {
                    Text("Aucune journée enregistrée pour l'instant. Laisse l'app ouverte : une ligne s'ajoute chaque jour.")
                        .font(.callout).foregroundColor(.secondary)
                } else {
                    keyFigures(today: recent.last?.summary?.weeklyUsed, average: average, peak: peak)
                    StatsCard(title: "Les 14 derniers jours",
                              subtitle: "Points de ta limite hebdomadaire consommés chaque jour (1 pt = 1 % de la limite). Survole une colonne pour le détail.") {
                        DayColumnsChart(days: recent, average: average?.value)
                    }
                    StatsCard(title: "Quand tu travailles",
                              subtitle: "Part des jours où ton usage a augmenté à chaque heure, sur les 28 derniers jours complets."
                                  + (hours.first.map { $0.totalDays > 0 && $0.totalDays < StatsStyle.indicativeBelow ? " Indicatif : \($0.totalDays) jour(s) seulement." : "" } ?? "")) {
                        HourColumnsChart(stats: hours, peak: peak)
                    }
                    StatsCard(title: "Par jour de la semaine",
                              subtitle: "Consommation moyenne de chaque jour. Elle devient fiable à partir de 3 jours identiques observés (3 lundis, 3 mardis…).") {
                        WeekdayColumnsChart(stats: DailyInsights.weekdayStats(summaries))
                    }
                    StatsCard(title: "Cette semaine et la précédente",
                              subtitle: "Semaines du lundi au dimanche (indépendantes du reset de ta limite), comparées à jours égaux.") {
                        WeekCompareView(comparison: DailyInsights.weekComparison(summaries))
                    }
                    StatsJournalTable(summaries: summaries)
                }
                footer
            }
            .padding(20)
        }
    }

    // MARK: - En-tête et chiffres clés

    private var header: some View {
        let confidence = DailyInsights.confidence(summaries)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ton rythme").font(.title3.weight(.semibold))
                Spacer()
                Text("Fiabilité").font(.caption).foregroundColor(.secondary)
                ConfidenceMeter(level: confidence)
                Text(confidence.label).font(.system(size: 12, weight: .medium))
            }
            Text(confidence.detail).font(.caption).foregroundColor(.secondary)
            if let first = summaries.first {
                Text("\(summaries.count) jour\(summaries.count > 1 ? "s" : "") enregistré\(summaries.count > 1 ? "s" : "") depuis le \(StatsStyle.dayLabel(DailyInsights.date(fromStamp: first.day) ?? Date())).")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func keyFigures(today: Double?, average: (value: Double, days: Int)?, peak: HourStat?) -> some View {
        let busiest = DailyInsights.busiestDay(summaries)
        return HStack(alignment: .top, spacing: 10) {
            KpiTile(label: "Aujourd'hui", value: today.map(StatsStyle.points) ?? "—",
                    detail: average.map { "moyenne \(StatsStyle.points($0.value))" } ?? "en cours")
            KpiTile(label: "Moyenne par jour", value: average.map { StatsStyle.points($0.value) } ?? "—",
                    detail: average.map { "sur \($0.days) jour\($0.days > 1 ? "s" : "") complet\($0.days > 1 ? "s" : "")" } ?? "pas encore de jour complet")
            KpiTile(label: "Jour record", value: busiest.map { StatsStyle.points($0.weeklyUsed) } ?? "—",
                    detail: busiest.flatMap { DailyInsights.date(fromStamp: $0.day) }.map(StatsStyle.dayLabel) ?? "—")
            KpiTile(label: "Heure de pointe", value: peak.map { StatsStyle.hour($0.hour) } ?? "—",
                    detail: peak.map { "active \(StatsStyle.percent($0.fraction)) des jours" } ?? "pas encore de jour complet")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Text("Source : daily.jsonl, gardé 400 jours. Rien ne quitte ta machine.").font(.caption).foregroundColor(.secondary)
            Spacer()
            Button("Afficher le fichier") { NSWorkspace.shared.activateFileViewerSelecting([DailyHistory.defaultURL]) }
                .controlSize(.small)
        }
    }
}

/// Un chiffre clé : intitulé, valeur, précision.
struct KpiTile: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            Text(value).font(.system(size: 21, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(detail).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
    }
}

/// Quatre crans pour la fiabilité des statistiques : le niveau est écrit à côté, jamais porté par la couleur seule.
struct ConfidenceMeter: View {
    let level: DataConfidence

    private var filled: Int {
        switch level {
        case .veryLow: return 1
        case .building: return 2
        case .good: return 3
        case .solid: return 4
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2).fill(index < filled ? StatsStyle.accent : Color.primary.opacity(0.15)).frame(width: 14, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Deux barres horizontales à jours égaux : la semaine en cours (mise en avant) et la précédente (grise), avec l'écart en toutes lettres.
struct WeekCompareView: View {
    let comparison: WeekComparison

    private var dayCount: String { "\(comparison.completedDays) jour\(comparison.completedDays > 1 ? "s" : "")" }

    var body: some View {
        if comparison.completedDays == 0 {
            Text("La semaine commence : la comparaison apparaît dès mardi, sur le jour complet écoulé.").font(.caption).foregroundColor(.secondary)
        } else {
            let scale = max(comparison.current, comparison.previous ?? 0, 1)
            VStack(alignment: .leading, spacing: 8) {
                row("Cette semaine", value: comparison.current, scale: scale, fill: StatsStyle.accent)
                if let previous = comparison.previous {
                    row("Semaine précédente", value: previous, scale: scale, fill: Color.primary.opacity(0.28))
                    if let delta = comparison.delta { Text(deltaText(delta, previous: previous)).font(.system(size: 12, weight: .medium)) }
                } else {
                    Text("Pas de comparaison : la semaine précédente n'a pas ces \(dayCount) avec assez de relevés.").font(.caption).foregroundColor(.secondary)
                }
                Text("Sur les mêmes \(dayCount) complet\(comparison.completedDays > 1 ? "s" : "") (du lundi à hier).").font(.caption).foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func row(_ title: String, value: Double, scale: Double, fill: Color) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 12)).frame(width: 122, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(fill).frame(width: max(geo.size.width * CGFloat(value / scale), value > 0 ? 6 : 0))
                }
            }
            .frame(height: 10)
            Text(StatsStyle.points(value)).font(.system(size: 11)).foregroundColor(.secondary).frame(width: 64, alignment: .leading)
        }
    }

    private func deltaText(_ delta: Double, previous: Double) -> String {
        let percent = previous > 0 ? " (\(delta >= 0 ? "+" : "−")\(Int((abs(delta) / previous * 100).rounded())) %)" : ""
        return delta == 0 ? "Identique à la semaine précédente." : "\(delta > 0 ? "+" : "−")\(StatsStyle.points(abs(delta)))\(percent) par rapport à la semaine précédente."
    }
}
