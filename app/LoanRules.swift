import Foundation

/// Où en est un prêt : ce que chacun a consommé de la semaine, ce qu'il lui reste, et la prévision pour l'invité.
struct LoanState: Equatable {
    let tally: LoanTally
    let sharePoints: Double
    let reservePoints: Double
    /// Points par jour de l'invité, en moyenne depuis le début du prêt (ou de la semaine) ; nil trop tôt pour être parlant.
    let guestRatePerDay: Double?
    /// Quand l'invité aura épuisé sa part à ce rythme ; nil s'il ne l'épuisera pas avant la fin du prêt, ou si c'est déjà fait.
    let guestExhaustsAt: Date?
    /// Âge du dernier rapport du collecteur ; nil s'il n'a encore rien envoyé.
    let collectorAge: TimeInterval?

    var guestLeft: Double { max(sharePoints - tally.guest, 0) }
    var ownerLeft: Double { max(reservePoints - tally.owner - max(tally.guest - sharePoints, 0), 0) }
    var guestOver: Bool { tally.guest > sharePoints }
    var isCollectorSilent: Bool { (collectorAge ?? .infinity) > LoanRules.silentAfter }
}

/// Une notification liée au prêt. La clé évite de répéter un même message (registre des alertes).
struct LoanAlert: Equatable {
    let key: String
    let title: String
    let body: String
}

enum LoanRules {
    /// Le collecteur envoie un signe de vie toutes les 6 h : au-delà de 7 h sans nouvelles, il est muet.
    static let silentAfter: TimeInterval = 7 * 3600
    /// En dessous de 12 h de prêt, une moyenne par jour ne veut rien dire.
    static let minimumElapsed: TimeInterval = 12 * 3600

    static func state(loan: Loan, tally: LoanTally, since start: Date, now: Date, reportAt: Date?) -> LoanState {
        let elapsed = now.timeIntervalSince(start)
        let rate = elapsed >= minimumElapsed ? tally.guest / (elapsed / 86400) : nil
        var exhaustsAt: Date? = nil
        if let rate, rate > 0, tally.guest < loan.sharePoints {
            let eta = now.addingTimeInterval((loan.sharePoints - tally.guest) / rate * 86400)
            if eta < loan.endsAt { exhaustsAt = eta }
        }
        return LoanState(tally: tally, sharePoints: loan.sharePoints, reservePoints: loan.reservePoints, guestRatePerDay: rate,
                         guestExhaustsAt: exhaustsAt, collectorAge: reportAt.map { now.timeIntervalSince($0) })
    }

    static func points(_ value: Double) -> String { "\(Int(value.rounded()))" }

    /// « 35 mesurés, 3 estimés » : chaque chiffre dit d'où il vient.
    static func provenance(measured: Double, estimated: Double) -> String {
        "\(points(measured)) mesurés, \(points(estimated)) estimés"
    }

    /// Alertes du prêt. Chacune dit la limite, l'échéance et l'hypothèse de calcul.
    static func alerts(loan: Loan, state: LoanState, now: Date, threshold: Double = 0.8, calendar: Calendar = .current) -> [LoanAlert] {
        guard loan.isActive(at: now) else { return [] }
        let name = loan.displayName, share = points(state.sharePoints), end = AlertRules.moment(loan.endsAt, now: now, calendar: calendar)
        let day = Int(now.timeIntervalSince1970 / 86400)
        var result: [LoanAlert] = []
        if state.guestOver {
            result.append(LoanAlert(key: "loan-\(loan.id)-reserve", title: "Ta réserve est entamée",
                body: "\(name) a utilisé \(points(state.tally.guest)) points pour une part de \(share). Il te reste \(points(state.ownerLeft)) points jusqu'à \(end) (\(provenance(measured: state.tally.guestMeasured, estimated: state.tally.guestEstimated)))."))
        } else if state.tally.guest >= state.sharePoints * threshold {
            result.append(LoanAlert(key: "loan-\(loan.id)-seuil-\(Int(threshold * 100))", title: "\(name) a utilisé \(Int(threshold * 100)) % de sa part",
                body: "\(points(state.tally.guest)) points sur \(share) de la semaine, prêt jusqu'à \(end) (\(provenance(measured: state.tally.guestMeasured, estimated: state.tally.guestEstimated)))."))
        }
        if let eta = state.guestExhaustsAt, let rate = state.guestRatePerDay, !state.guestOver {
            result.append(LoanAlert(key: "loan-\(loan.id)-prevision-\(day)", title: "\(name) va dépasser sa part",
                body: "Au rythme moyen depuis le début du prêt (≈ \(points(rate)) points par jour), ses \(share) points sont épuisés \(AlertRules.moment(eta, now: now, calendar: calendar)), avant la fin du prêt (\(end))."))
        }
        if state.isCollectorSilent, now.timeIntervalSince(loan.startsAt) >= silentAfter {
            let since = state.collectorAge.map { "depuis \(AlertRules.duration($0))" } ?? "depuis le début du prêt"
            result.append(LoanAlert(key: "loan-\(loan.id)-muet-\(day)", title: "Collecteur de \(name) muet \(since)",
                body: "Sans ses données, les hausses de la semaine lui sont attribuées par estimation. Vérifie que « collecteur lancer » tourne sur sa machine."))
        }
        return result
    }
}
