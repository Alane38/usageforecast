import Foundation

/// Prêt fictif pour les aperçus (`--demo --demo-loan`) : aucun réseau, aucun secret, rien d'enregistré.
/// Options : `--loan-guest N` (points de l'invité, 38 par défaut), `--loan-owner N` (14), `--loan-silent` (collecteur muet).
extension AppDelegate {
    func fillDemoLoan() {
        let now = AppClock.now
        let start = now.addingTimeInterval(-(3 * 86400 + 4 * 3600))
        let loan = Loan(id: "demo", guestName: "Sam", share: 0.7, startsAt: start, endsAt: usageManager.weeklyResetsAt ?? now.addingTimeInterval(4 * 86400),
                        relay: "https://usageforecast-relay.exemple.workers.dev", vaultID: String(repeating: "0", count: 32))
        let guest = DevFlags.number("--loan-guest") ?? 38
        let tally = LoanTally(guestMeasured: max(guest - 3, 0), guestEstimated: min(guest, 3), ownerMeasured: DevFlags.number("--loan-owner") ?? 14)
        let silent = DevFlags.isSet("--loan-silent")
        let reportAt = silent ? now.addingTimeInterval(-9 * 3600) : now.addingTimeInterval(-4 * 60)
        usageManager.loan = loan
        usageManager.weeklyUsage = Int((tally.guest + tally.owner).rounded())
        usageManager.guestReport = GuestReport(updatedAt: reportAt, reason: "activity", collectorVersion: "0.1.0", platform: "win32",
                                               lastActivityAt: reportAt, buckets: [])
        usageManager.loanState = LoanRules.state(loan: loan, tally: tally, since: start, now: now, reportAt: reportAt)
        usageManager.loanStatus = silent ? "Le collecteur de Sam n'a rien envoyé depuis 9 h : attribution par estimation." : ""
        usageManager.updatePercentages()
    }
}

extension AppDelegate {
    /// `--demo --demo-revocation [watching|clear|suspicious]` : l'après-prêt, sans réseau ni journaux.
    func fillDemoRevocation() {
        let now = AppClock.now
        let phase = RevocationStatus.Phase(rawValue: Snapshot.option("--demo-revocation") ?? "") ?? .watching
        let endedAt = phase == .clear ? now.addingTimeInterval(-50 * 3600) : now.addingTimeInterval(-2 * 3600 - 600)
        let watch = RevocationWatch(endedAt: endedAt, guestName: "Sam")
        usageManager.loan = nil
        usageManager.revocationWatch = watch
        usageManager.revocationStatus = RevocationStatus(phase: phase, unexplained: phase == .suspicious ? 3 : 0, ownerPoints: 1, watchEndsAt: watch.watchEndsAt)
    }
}
