import Foundation

/// La valeur écrite à côté de l'icône : la session, l'hebdo, la plus haute des deux, ou les deux.
/// Chaque style de barre de menu garde son propre choix (voir `defaultMode(for:)`).
enum MenuBarMode: String, CaseIterable {
    case session, weekly, worst, both

    var label: String {
        switch self {
        case .session: return "Session (5 h)"
        case .weekly:  return "Hebdo (7 j)"
        case .worst:   return "La plus haute"
        case .both:    return "Les deux"
        }
    }

    static func defaultMode(for style: MenuBarStyle) -> MenuBarMode {
        style == .twoValues ? .both : .session
    }
}

struct MenuBarState: Equatable {
    let title: String
    /// Pourcentage qui pilote la couleur de l'icône.
    let percent: Int
}

enum MenuBarDisplay {
    /// Titre à droite de l'icône, selon la valeur choisie. Le style ne change que le dessin, pas le texte.
    static func state(mode: MenuBarMode,
                      sessionPercent: Int, sessionResetsAt: Date?,
                      weeklyPercent: Int, weeklyResetsAt: Date?,
                      showReset: Bool, showText: Bool = true, now: Date = AppClock.now) -> MenuBarState {
        var title: String
        var percent = sessionPercent
        var resetsAt = sessionResetsAt

        switch mode {
        case .session:
            title = " \(sessionPercent)%"
        case .weekly:
            percent = weeklyPercent
            resetsAt = weeklyResetsAt
            title = " \(weeklyPercent)%"
        case .worst:
            let showsWeekly = weeklyPercent > sessionPercent
            percent = showsWeekly ? weeklyPercent : sessionPercent
            resetsAt = showsWeekly ? weeklyResetsAt : sessionResetsAt
            title = " \(percent)%" + (showsWeekly ? " 7j" : " 5h")
        case .both:
            percent = max(sessionPercent, weeklyPercent)
            title = " \(sessionPercent) · \(weeklyPercent)"
        }

        if showReset, let resetsAt {
            title += " · \(countdown(to: resetsAt, now: now))"
        }
        return MenuBarState(title: showText ? title : "", percent: percent)
    }

    /// « 45 min », « 2h14 », « 3j 4h » : le plus court lisible d'un coup d'œil.
    static func countdown(to date: Date, now: Date = AppClock.now) -> String {
        let totalMinutes = max(Int(date.timeIntervalSince(now) / 60), 0)
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return "\(days)j \(hours)h" }
        if hours > 0 { return String(format: "%dh%02d", hours, minutes) }
        return "\(minutes) min"
    }
}
