import SwiftUI

extension UsageTone {
    var color: Color { Color(nsColor: MenuBarIcons.color(for: self)) }
}

/// Barre de jauge : valeur actuelle, projection au reset (voile) et repère du rythme régulier (trait).
/// Seule la piste a des bouts ronds : remplissage et voile sont plats et découpés dans la piste.
struct GaugeBar: View {
    let used: Double
    let projected: Double?
    let expected: Double?
    let tone: UsageTone

    private func width(_ percent: Double, _ total: CGFloat) -> CGFloat {
        total * CGFloat(min(max(percent, 0), 100) / 100)
    }

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.width
            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.primary.opacity(0.12))
                    if let projected, projected > used {
                        Rectangle().fill(tone.color.opacity(0.3)).frame(width: width(projected, total))
                    }
                    Rectangle().fill(tone.color).frame(width: used > 0 ? max(width(used, total), 3) : 0)
                }
                .clipShape(Capsule())
                if let expected {
                    Rectangle().fill(Color.primary.opacity(0.9)).frame(width: 2, height: 12)
                        .offset(x: min(max(width(expected, total) - 1, 0), total - 2))
                }
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .help("Trait : où tu en serais à rythme régulier. Zone claire : projection au reset.")
    }

    private var accessibilityText: String {
        var text = "\(Int(used.rounded())) % utilisé"
        if let projected { text += ", \(Int(projected.rounded())) % prévu au reset" }
        if let expected { text += ", \(Int(expected.rounded())) % à rythme régulier" }
        return text
    }
}

/// Libellé de rythme : un point de couleur et le texte, sans pastille.
struct PaceChip: View {
    let text: String
    let tone: UsageTone

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundColor(tone.color)
        }
    }
}

/// Anneau de progression avec une valeur au centre.
struct RingView: View {
    let percent: Double
    let tone: UsageTone
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(percent, 0), 100) / 100))
                .stroke(tone.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent.rounded())) %").font(.system(size: 12, weight: .medium))
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(percent.rounded())) % utilisé")
    }
}

/// Fond des cartes du popover.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(10)
    }
}

extension View {
    func popoverCard() -> some View { modifier(CardBackground()) }
}
