import AppKit

/// Tonalités et icône de barre de menu dérivées des données du gestionnaire.
extension UsageManager {
    private var isDataStale: Bool { SyncHelpers.isStale(lastUpdated) }

    var sessionTone: UsageTone {
        UsageTone.of(percent: Double(sessionUsage), pace: sessionForecast?.pace, isStale: isDataStale)
    }

    var weeklyTone: UsageTone {
        UsageTone.of(percent: Double(weeklyUsage), pace: weeklyForecast?.pace, isStale: isDataStale)
    }

    func menuBarIcon(style: MenuBarStyle? = nil) -> (image: NSImage?, tone: UsageTone) {
        switch style ?? menuBarStyle {
        case .dualRing:
            return (MenuBarIcons.dualRing(session: Double(sessionUsage), weekly: Double(weeklyUsage),
                                          sessionTone: sessionTone, weeklyTone: weeklyTone), .ok)
        case .twoValues:
            return (MenuBarIcons.twoValues(session: Double(sessionUsage), weekly: Double(weeklyUsage),
                                           sessionTone: sessionTone, weeklyTone: weeklyTone), .ok)
        case .spark:
            switch menuBarMode {
            case .session: return (nil, sessionTone)
            case .weekly:  return (nil, weeklyTone)
            case .worst, .both: return (nil, UsageTone.worst([sessionTone, weeklyTone]))
            }
        }
    }
}
