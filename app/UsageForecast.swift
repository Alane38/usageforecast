import Foundation

enum Pace: Equatable {
    case under, onTrack, over
}

/// Prévision linéaire sur une fenêtre de limite (session 5 h ou hebdo 7 j).
/// Estimation : Anthropic ne publie pas les limites exactes et la consommation n'est pas régulière.
struct WindowForecast: Equatable {
    let usedPercent: Double
    /// Pourcentage qu'on aurait consommé en régime parfaitement régulier à cet instant.
    let expectedPercent: Double
    /// Pourcentage attendu au reset si le rythme actuel continue. nil trop tôt dans la fenêtre.
    let projectedPercent: Double?
    /// Heure d'atteinte de 100 % si le rythme actuel continue, seulement si c'est avant le reset.
    let exhaustsAt: Date?
    /// Part de la limite utilisable par jour d'ici au reset sans dépasser 100 %.
    let remainingPerDay: Double
    let pace: Pace
    /// Durée totale de la fenêtre en heures (5 pour la session, 168 pour la semaine).
    let windowHours: Double
}

enum UsageForecast {
    static let sessionLength: TimeInterval = 5 * 3600
    static let weekLength: TimeInterval = 7 * 86400
    /// Avant 5 % de la fenêtre écoulée, l'extrapolation n'a pas de sens (un seul message fausse tout).
    static let minElapsedFraction = 0.05
    static let underPaceThreshold = 80.0

    static func forecast(usedPercent: Double, resetsAt: Date, windowLength: TimeInterval, now: Date = AppClock.now) -> WindowForecast {
        let used = min(max(usedPercent, 0), 100)
        let secondsToReset = max(resetsAt.timeIntervalSince(now), 0)
        let elapsed = min(max(windowLength - secondsToReset, 0), windowLength)
        let elapsedFraction = elapsed / windowLength

        let projected: Double? = elapsedFraction >= minElapsedFraction ? used / elapsedFraction : nil

        var exhaustsAt: Date?
        if let projected, projected > 100, used > 0, used < 100 {
            let percentPerSecond = used / elapsed
            exhaustsAt = now.addingTimeInterval((100 - used) / percentPerSecond)
        }

        let daysToReset = secondsToReset / 86400
        let remainingPerDay = daysToReset > 0 ? (100 - used) / daysToReset : 0

        return WindowForecast(usedPercent: used,
                              expectedPercent: elapsedFraction * 100,
                              projectedPercent: projected,
                              exhaustsAt: exhaustsAt,
                              remainingPerDay: remainingPerDay,
                              pace: pace(used: used, projected: projected),
                              windowHours: windowLength / 3600)
    }

    private static func pace(used: Double, projected: Double?) -> Pace {
        if used >= 100 { return .over }
        guard let projected else { return .onTrack }
        if projected > 100 { return .over }
        return projected < underPaceThreshold ? .under : .onTrack
    }
}
