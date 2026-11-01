import SwiftUI

/// Onglet « Prêt » : prêter une part de la semaine à une autre personne, suivre le prêt, le terminer (ADR 003).
struct LoanTab: View {
    @ObservedObject var usageManager: UsageManager
    @State private var name = ""
    @State private var share = 0.7
    @State private var endsAt = Date().addingTimeInterval(7 * 86400)
    @State private var link = ""
    @State private var problem = ""
    @State private var confirmsEnd = false

    var body: some View { form }

    private var form: some View {
        Form {
            if let loan = usageManager.loan { current(loan) } else { creation }
            Section("Alertes du prêt") {
                Toggle("Notifications du prêt", isOn: Binding(get: { usageManager.loanAlertsEnabled }, set: { usageManager.setLoanAlerts($0) }))
                Text("80 % de sa part atteints, dépassement prévu avant la fin du prêt, ta réserve entamée, collecteur muet depuis plus de 7 h.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("Comment c'est compté") {
                Text("Chaque hausse de la semaine va à celui qui utilisait Claude Code à ce moment : mesuré. Aux deux en même temps : réparti au prorata des tokens, estimé. À personne (par exemple claude.ai sur ton téléphone) : compté à l'invité, estimé.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Le collecteur de l'invité n'envoie que des heures et des nombres de tokens, chiffrés : jamais ses conversations.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { if let reset = usageManager.weeklyResetsAt, reset > Date() { endsAt = reset } }
    }

    @ViewBuilder
    private var creation: some View {
        Section("Prêter une part de ta semaine") {
            TextField("Prénom", text: $name, prompt: Text("Prénom de la personne"))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sa part de la semaine")
                    Spacer()
                    Text("\(Int((share * 100).rounded())) %").monospacedDigit().fontWeight(.semibold)
                }
                Slider(value: $share, in: Loan.shareRange, step: 0.05)
                Text("Tu gardes \(Int(((1 - share) * 100).rounded())) % de la limite hebdomadaire. La limite de 5 h n'est pas partagée.")
                    .font(.caption).foregroundColor(.secondary)
            }
            DatePicker("Fin du prêt", selection: $endsAt, in: Date()...)
            TextField("Lien du collecteur", text: $link, prompt: Text(verbatim: "https://…/#v1.…"))
            Text("Sur sa machine, la personne lance « collecteur associer <adresse de ton relais> » et te transmet le lien affiché (il contient la clé de son coffre).")
                .font(.caption).foregroundColor(.secondary)
            if !problem.isEmpty { Text(problem).font(.caption).foregroundColor(.red) }
            Button("Démarrer le prêt") {
                problem = usageManager.startLoan(guestName: name, share: share, endsAt: endsAt, link: link) ?? ""
                if problem.isEmpty { link = "" }
            }
            .disabled(link.isEmpty)
        }
    }

    @ViewBuilder
    private func current(_ loan: Loan) -> some View {
        Section("Prêt en cours") {
            LabeledContent(loan.displayName, value: "\(Int(loan.sharePoints.rounded())) % de la semaine · tu gardes \(Int(loan.reservePoints.rounded())) %")
            LabeledContent("Période", value: "\(AlertRules.moment(loan.startsAt)) → \(AlertRules.moment(loan.endsAt))")
            LabeledContent("Collecteur", value: collectorText)
            if let state = usageManager.loanState {
                LabeledContent("Utilisé", value: "\(LoanRules.points(state.tally.guest)) pour \(loan.displayName), \(LoanRules.points(state.tally.owner)) pour toi")
                LabeledContent("Provenance", value: LoanRules.provenance(measured: state.tally.measured, estimated: state.tally.estimated))
            }
            if !usageManager.loanStatus.isEmpty { Text(usageManager.loanStatus).font(.caption).foregroundColor(.orange) }
        }
        Section("Terminer le prêt") {
            Text("L'app ne peut pas couper l'accès elle-même : sur claude.ai, Settings › Claude Code, clique sur la corbeille à côté de sa connexion (sinon Settings › Account, avec tes autres sessions). « Log Out » dans Settings › Account déconnecte tout, Claude Code compris.")
                .font(.caption).foregroundColor(.secondary)
            HStack {
                Link("Ouvrir les réglages de claude.ai", destination: URL(string: "https://claude.ai/settings")!)
                Spacer()
                Button("Terminer le prêt…", role: .destructive) { confirmsEnd = true }
            }
            .confirmationDialog("Terminer le prêt à \(loan.displayName) ?", isPresented: $confirmsEnd) {
                Button("Terminer", role: .destructive) { usageManager.endLoan() }
            } message: {
                Text("Le suivi s'arrête et la clé de son coffre est effacée de ce Mac. As-tu retiré son accès sur claude.ai ?")
            }
        }
    }

    private var collectorText: String {
        guard let report = usageManager.guestReport else { return "pas encore entendu" }
        return "\(report.platformLabel), \(SyncHelpers.age(since: report.updatedAt))"
    }
}
