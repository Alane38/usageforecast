import Foundation

/// Disposition du popover : jauges avec repère de rythme, ou cartes avec anneaux.
enum PopoverLayout: String, CaseIterable {
    case gauges, cards

    var label: String {
        switch self {
        case .gauges: return "Jauges"
        case .cards:  return "Cartes"
        }
    }

    var summary: String {
        switch self {
        case .gauges: return "Barres avec le repère de rythme et la prévision au reset."
        case .cards:  return "Un budget du jour, deux anneaux et les crédits."
        }
    }
}

/// Dessin de l'icône dans la barre de menu.
enum MenuBarStyle: String, CaseIterable {
    case spark, dualRing, twoValues

    var label: String {
        switch self {
        case .spark:     return "Étincelle"
        case .dualRing:  return "Double anneau"
        case .twoValues: return "Deux valeurs"
        }
    }

    var summary: String {
        switch self {
        case .spark:     return "L'étincelle colorée."
        case .dualRing:  return "Anneau externe : semaine. Anneau interne : session."
        case .twoValues: return "Deux barres fines : session et semaine."
        }
    }
}

/// Tonalité d'un indicateur : sert à choisir la couleur, de façon identique dans le popover et la barre de menu.
enum UsageTone: Equatable {
    case ok, warning, danger, stale

    static func of(percent: Double, pace: Pace?, isStale: Bool) -> UsageTone {
        if isStale { return .stale }
        if percent >= 90 { return .danger }
        if percent >= 70 || pace == .over { return .warning }
        return .ok
    }

    /// La plus grave des tonalités (stale est neutre : elle ne masque jamais une alerte).
    static func worst(_ tones: [UsageTone]) -> UsageTone {
        if tones.contains(.danger) { return .danger }
        if tones.contains(.warning) { return .warning }
        if tones.contains(.stale) { return .stale }
        return .ok
    }
}

enum RingGeometry {
    /// Longueur tracée et longueur vide d'un cercle de rayon donné pour un pourcentage (0 à 100, borné).
    static func dash(percent: Double, radius: Double) -> (on: Double, off: Double) {
        let circumference = 2 * Double.pi * radius
        let fraction = min(max(percent, 0), 100) / 100
        let on = circumference * fraction
        return (on, circumference - on)
    }
}
