import AppKit
import SwiftUI

/// Style commun des statistiques. Une seule teinte pour toutes les grandeurs (le vert, le jaune et le rouge restent réservés aux états),
/// plus claire quand une valeur est partielle ou indicative. Le texte garde toujours les couleurs de texte, jamais celle des barres.
enum StatsStyle {
    /// Bleu : assez profond en mode clair (contraste 4,5:1 sur blanc), plus vif en mode sombre.
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 1)
            : NSColor(red: 0.10, green: 0.38, blue: 0.85, alpha: 1)
    })
    /// Barre incomplète ou indicative : même teinte, plus légère, expliquée par la légende.
    static let accentLight = accent.opacity(0.35)
    static let gridLine = Color.primary.opacity(0.10)
    static let baseline = Color.primary.opacity(0.22)

    /// En dessous de ce nombre de jours, une statistique est donnée à titre indicatif (barres claires).
    static let indicativeBelow = 3

    static let maxBarThickness: CGFloat = 24
    static let barCorner: CGFloat = 4

    /// Plafond d'axe arrondi à un multiple de 10 (au moins 10) : des graduations propres, jamais une valeur au hasard.
    static func ceiling(_ maxValue: Double) -> Double { max(10, (maxValue / 10).rounded(.up) * 10) }

    static func points(_ value: Double) -> String {
        if value < 10, value.rounded() != value {
            let text = String(format: "%.1f", value)
            if !text.hasPrefix("10") { return text.replacingOccurrences(of: ".", with: ",") + " pts" }   // 9,96 s'écrit « 10 pts »
        }
        let rounded = Int(value.rounded())
        return rounded == 1 ? "1 pt" : "\(rounded) pts"
    }

    static func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded())) %" }
    static func hour(_ hour: Int) -> String { "\(hour) h" }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE d/MM"
        return formatter
    }()

    /// « lun. 19/10 »
    static func dayLabel(_ date: Date) -> String { weekdayFormatter.string(from: date) }

    static let weekdayNames = ["lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."]

    /// Heures regroupées par plages : [0, 1, 2, 7, 9, 10] devient « 0–2, 7, 9–10 h ».
    static func hoursText(_ hours: [Int]) -> String {
        guard !hours.isEmpty else { return "—" }
        var ranges: [String] = []
        var start = hours[0], previous = hours[0]
        for hour in hours.dropFirst() + [Int.max] {
            if hour == previous + 1 { previous = hour; continue }
            ranges.append(start == previous ? "\(start)" : "\(start)–\(previous)")
            start = hour; previous = hour
        }
        return ranges.joined(separator: ", ") + " h"
    }
}

/// Barre d'histogramme : arrondie de 4 pt en haut, droite à la base (elle part toujours de la ligne de base).
struct TopRoundedBar: Shape {
    var radius: CGFloat = StatsStyle.barCorner

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Carte avec un titre qui dit ce qu'on regarde et une phrase qui explique comment le lire.
struct StatsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
    }
}

/// Légende d'une pastille : une marque de la couleur de la série suivie d'un texte en encre normale.
struct LegendKey: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text).font(.system(size: 11)).foregroundColor(.secondary)
        }
    }
}
