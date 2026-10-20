import Foundation

/// Horloge de l'app. Le décalage reste à zéro en usage normal ; les captures de démonstration (`--demo`) le règlent pour figer
/// la date et l'heure, afin que les comparaisons visuelles donnent le même rendu tous les jours.
enum AppClock {
    static var offset: TimeInterval = 0
    static var now: Date { Date().addingTimeInterval(offset) }

    /// Fige l'horloge sur une date donnée (l'heure continue d'avancer ensuite, seconde par seconde).
    static func freeze(at date: Date) { offset = date.timeIntervalSince(Date()) }
}
