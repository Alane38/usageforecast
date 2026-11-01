import Foundation

/// Après un prêt, le Mac surveille la semaine pendant 48 h (ADR 003) : une hausse sans activité Claude Code sur ce Mac peut venir
/// d'un accès de l'invité resté ouvert. La vérification ne dépend pas de l'invité (il peut arrêter son collecteur).
struct RevocationWatch: Codable, Equatable {
    let endedAt: Date
    let guestName: String

    var watchEndsAt: Date { endedAt.addingTimeInterval(LoanRevocation.duration) }
}

struct RevocationStatus: Equatable {
    enum Phase: String, Codable { case watching, clear, suspicious }

    let phase: Phase
    /// Points de la semaine pris sans activité Claude Code sur ce Mac depuis la fin du prêt.
    let unexplained: Double
    /// Points pris pendant que Claude Code tournait sur ce Mac (ton propre usage).
    let ownerPoints: Double
    let watchEndsAt: Date
}

/// Résumé envoyé au téléphone (champ facultatif `revocation` du snapshot, lu par mobile/pwa/lib/loan-view.js).
struct RevocationInfo: Codable, Equatable {
    let guestName: String
    let endedAt: Date
    let watchEndsAt: Date
    let phase: String
    let unexplained: Double
}

enum LoanRevocation {
    static let duration: TimeInterval = 48 * 3600
    /// Hypothèse : moins de 2 points peuvent venir d'un petit usage de claude.ai (web, téléphone), que ce Mac ne voit pas encore.
    static let threshold = 2.0
    /// Le résultat reste affiché une semaine après la fin de la surveillance, puis disparaît.
    static let keepFor: TimeInterval = 7 * 86400

    static func status(watch: RevocationWatch, samples: [UsageSample], owner: [ActivityBucket], now: Date) -> RevocationStatus {
        let end = min(now, watch.watchEndsAt)
        let tally = LoanAttribution.tally(samples: samples, guest: [], owner: owner, from: watch.endedAt, to: end)
        let phase: RevocationStatus.Phase = tally.unexplained >= threshold ? .suspicious : (now >= watch.watchEndsAt ? .clear : .watching)
        return RevocationStatus(phase: phase, unexplained: tally.unexplained, ownerPoints: tally.ownerMeasured, watchEndsAt: watch.watchEndsAt)
    }

    /// L'alerte « activité inexpliquée » : toujours active (pas d'interrupteur), une seule fois par fin de prêt.
    static func alert(watch: RevocationWatch, status: RevocationStatus, now: Date, calendar: Calendar = .current) -> LoanAlert? {
        guard status.phase == .suspicious else { return nil }
        let name = watch.guestName.isEmpty ? "l'invité" : watch.guestName
        return LoanAlert(key: "loan-revocation-\(Int(watch.endedAt.timeIntervalSince1970))", title: "Activité inexpliquée après la fin du prêt",
            body: "La semaine a pris \(LoanRules.points(status.unexplained)) points depuis la fin du prêt à \(name) (\(AlertRules.moment(watch.endedAt, now: now, calendar: calendar))) sans activité Claude Code sur ce Mac. Si ce n'était pas toi sur claude.ai, son accès n'est peut-être pas coupé : claude.ai › Settings › Account › Log Out déconnecte tout.")
    }

    static func info(watch: RevocationWatch, status: RevocationStatus) -> RevocationInfo {
        RevocationInfo(guestName: watch.guestName, endedAt: watch.endedAt, watchEndsAt: watch.watchEndsAt, phase: status.phase.rawValue, unexplained: status.unexplained)
    }

    /// Texte d'une ligne pour le popover et les réglages.
    static func summary(watch: RevocationWatch, status: RevocationStatus, now: Date) -> String {
        switch status.phase {
        case .suspicious:
            return "\(LoanRules.points(status.unexplained)) points pris sans activité de ta part depuis la fin du prêt : vérifie que son accès est coupé."
        case .watching:
            return "Vérification de la révocation : rien d'inexpliqué pour l'instant, encore \(AlertRules.duration(status.watchEndsAt.timeIntervalSince(now)))."
        case .clear:
            return "Révocation vérifiée : rien d'inexpliqué pendant les 48 h qui ont suivi le prêt."
        }
    }
}
