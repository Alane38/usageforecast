import SwiftUI

/// Bloc « Prêt » du popover : n'apparaît que pendant un prêt (ADR 003). Part de l'invité, ta réserve, prévision et provenance des chiffres.
struct LoanBlock: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View {
        if let loan = usageManager.loan { content(loan) }
    }

    private func content(_ loan: Loan) -> some View {
        let now = AppClock.now
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(loan.isActive(at: now) ? "Prêt à \(loan.displayName) · jusqu'à \(AlertRules.moment(loan.endsAt, now: now))" : "Prêt à \(loan.displayName) terminé")
                    .font(.system(size: 12, weight: .medium)).foregroundColor(Color.secondaryText)
                Spacer()
                Text("\(Int(loan.sharePoints.rounded())) / \(Int(loan.reservePoints.rounded()))").captionStyle()
            }
            if let state = usageManager.loanState {
                row(label: "Part de \(loan.displayName)", used: state.tally.guest, of: state.sharePoints, tone: guestTone(state))
                row(label: "Ta réserve", used: state.tally.owner + max(state.tally.guest - state.sharePoints, 0), of: state.reservePoints,
                    tone: state.guestOver ? .danger : .ok)
                if let line = forecastLine(loan, state, now: now) {
                    Text(line).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                }
                Text(provenance(state)).captionStyle().fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Calcul en cours : il faut au moins deux relevés depuis le début du prêt.").captionStyle()
            }
            if !loan.isActive(at: now) {
                Text("Pense à retirer son accès : claude.ai › Settings › Claude Code, puis Réglages › Prêt › Terminer.")
                    .font(.system(size: 11, weight: .medium)).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if !usageManager.loanStatus.isEmpty {
                Text(usageManager.loanStatus).font(.caption).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func guestTone(_ state: LoanState) -> UsageTone {
        if state.guestOver { return .danger }
        if state.tally.guest >= state.sharePoints * 0.8 || state.guestExhaustsAt != nil { return .warning }
        return .ok
    }

    private func row(label: String, used: Double, of total: Double, tone: UsageTone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12))
                Spacer()
                Text("\(Int(used.rounded())) / \(Int(total.rounded()))").font(.system(size: 12, weight: .semibold)).monospacedDigit()
            }
            GaugeBar(used: total > 0 ? used / total * 100 : 0, projected: nil, expected: nil, tone: tone)
        }
    }

    private func forecastLine(_ loan: Loan, _ state: LoanState, now: Date) -> String? {
        if state.guestOver { return "Part dépassée de \(Int((state.tally.guest - state.sharePoints).rounded())) points : c'est ta réserve qui paie." }
        guard let eta = state.guestExhaustsAt, let rate = state.guestRatePerDay else { return nil }
        let margin = AlertRules.duration(loan.endsAt.timeIntervalSince(eta))
        return "Au rythme de \(loan.displayName) (≈ \(Int(rate.rounded())) points par jour), sa part est épuisée \(AlertRules.moment(eta, now: now)), \(margin) avant la fin du prêt."
    }

    private func provenance(_ state: LoanState) -> String {
        var parts = [LoanRules.provenance(measured: state.tally.measured, estimated: state.tally.estimated)]
        if let report = usageManager.guestReport {
            parts.append("collecteur \(report.platformLabel) \(SyncHelpers.age(since: report.updatedAt))")
        } else {
            parts.append("collecteur pas encore entendu")
        }
        return parts.joined(separator: " · ")
    }
}

/// Ligne du popover après un prêt : la vérification de la révocation (48 h), en rouge si la semaine monte sans activité de ta part.
struct RevocationLine: View {
    @ObservedObject var usageManager: UsageManager

    var body: some View {
        if let watch = usageManager.revocationWatch, let status = usageManager.revocationStatus {
            HStack(alignment: .top, spacing: 6) {
                Circle().fill(color(status.phase)).frame(width: 7, height: 7).padding(.top, 4)
                Text(LoanRevocation.summary(watch: watch, status: status, now: AppClock.now))
                    .font(.system(size: 11, weight: status.phase == .suspicious ? .semibold : .regular))
                    .foregroundColor(status.phase == .suspicious ? UsageTone.danger.color : Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func color(_ phase: RevocationStatus.Phase) -> Color {
        switch phase {
        case .suspicious: return UsageTone.danger.color
        case .clear: return UsageTone.ok.color
        case .watching: return Color.secondaryText
        }
    }
}
