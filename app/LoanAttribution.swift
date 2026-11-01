import Foundation

/// Points de la semaine (en % de la limite hebdomadaire) attribués à chacun pendant un prêt, mesurés ou estimés (ADR 003).
struct LoanTally: Equatable {
    var guestMeasured = 0.0
    var guestEstimated = 0.0
    var ownerMeasured = 0.0
    var ownerEstimated = 0.0
    /// Hausses sans activité connue de personne : comptées à l'invité (estimées) pendant le prêt, et suivies à part.
    var unexplained = 0.0

    var guest: Double { guestMeasured + guestEstimated }
    var owner: Double { ownerMeasured + ownerEstimated }
    var measured: Double { guestMeasured + ownerMeasured }
    var estimated: Double { guestEstimated + ownerEstimated }
}

/// Attribution des hausses de la semaine : la logique pure, sans réseau ni fichier.
enum LoanAttribution {
    /// Une activité juste avant le relevé précédent compte encore : le pourcentage de claude.ai suit avec un peu de retard.
    static let slack: TimeInterval = 300

    private static func weight(_ buckets: [ActivityBucket], _ start: TimeInterval, _ end: TimeInterval) -> (active: Bool, weight: Int) {
        let touching = buckets.filter { $0.overlaps(start, end) }
        return (!touching.isEmpty, touching.reduce(0) { $0 + $1.weight })
    }

    /// Relevés de la semaine utilisés : le dernier au plus tard à `start` (point de départ), puis tous ceux jusqu'à `end`.
    static func window(_ samples: [UsageSample], from start: Date, to end: Date) -> [(time: TimeInterval, weekly: Double)] {
        let points = samples.compactMap { sample in sample.weekly.map { (time: sample.time, weekly: $0) } }.sorted { $0.time < $1.time }
        let startTime = start.timeIntervalSince1970, endTime = end.timeIntervalSince1970
        let baseline = points.last { $0.time <= startTime }
        let inside = points.filter { $0.time > startTime && $0.time <= endTime }
        return (baseline.map { [$0] } ?? []) + inside
    }

    /// Chaque hausse entre deux relevés va à celui qui était actif ; aux deux, au prorata des tokens ; à personne, à l'invité (estimé).
    /// Une baisse (reset de la semaine) n'est pas une consommation : ignorée. `from` doit être au plus tôt le début de la semaine en cours.
    static func tally(samples: [UsageSample], guest: [ActivityBucket], owner: [ActivityBucket], from start: Date, to end: Date) -> LoanTally {
        var result = LoanTally()
        let points = window(samples, from: start, to: end)
        for (previous, current) in zip(points, points.dropFirst()) {
            let delta = current.weekly - previous.weekly
            guard delta > 0 else { continue }
            let from = previous.time - slack, to = current.time
            let guestSide = weight(guest, from, to), ownerSide = weight(owner, from, to)
            switch (guestSide.active, ownerSide.active) {
            case (true, false):
                result.guestMeasured += delta
            case (false, true):
                result.ownerMeasured += delta
            case (true, true):
                let total = guestSide.weight + ownerSide.weight
                let guestShare = total > 0 ? Double(guestSide.weight) / Double(total) : 0.5
                result.guestEstimated += delta * guestShare
                result.ownerEstimated += delta * (1 - guestShare)
            case (false, false):
                result.unexplained += delta
                result.guestEstimated += delta
            }
        }
        return result
    }
}
