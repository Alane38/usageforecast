import AppKit
import SwiftUI

/// Onglet « Mobile » : activer la synchro, indiquer le relais, associer le téléphone Android par un code QR.
struct MobileTab: View {
    @ObservedObject var usageManager: UsageManager
    @State private var showsCode = CommandLine.arguments.contains("--show-code")
    @State private var confirmsRotation = false
    @State private var copied = false

    private var relayIsInvalid: Bool { !usageManager.mobileRelayText.isEmpty && usageManager.mobileRelay == nil }

    var body: some View {
        Form {
            Section("Synchronisation avec ton téléphone") {
                Toggle("Activer la synchro mobile", isOn: Binding(get: { usageManager.mobileSyncEnabled }, set: { usageManager.setMobileSync($0) }))
                Text("Ton téléphone affiche ton usage, tes prévisions et tes statistiques comme ce Mac. Désactivée, rien ne quitte ta machine.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("Relais") {
                TextField("Adresse du relais", text: $usageManager.mobileRelayText,
                          prompt: Text(verbatim: "Colle ici l'adresse de ton relais").foregroundColor(.secondary))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { usageManager.saveDisplaySettings() }
                if usageManager.mobileSyncEnabled && usageManager.mobileRelayText.isEmpty {
                    Text("Le champ est vide : colle l'adresse de ton relais (celle affichée à la fin du déploiement).")
                        .font(.caption).foregroundColor(.orange)
                }
                if relayIsInvalid {
                    Text("Adresse invalide : elle doit commencer par https://.").font(.caption).foregroundColor(.red)
                }
                HStack {
                    Button("Enregistrer l'adresse") { usageManager.saveDisplaySettings(); usageManager.sendMobileSnapshotIfEnabled(now: Date(), force: true) }
                        .disabled(usageManager.mobileRelay == nil)
                    Link("Comment créer le relais", destination: URL(string: "https://github.com/Alane38/usageforecast/tree/main/mobile")!)
                        .font(.caption)
                }
                Text("Un petit service à toi (Cloudflare Worker, gratuit) qui ne garde que du texte chiffré pendant 30 jours.")
                    .font(.caption).foregroundColor(.secondary)
                // En texte brut : sans cela macOS colore l'adresse comme un lien et on la prend pour une valeur saisie.
                Text(verbatim: "Elle ressemble à : https://claude-usage-relay.ton-compte.workers.dev")
                    .font(.caption).foregroundColor(.secondary)
            }
            if usageManager.mobileSyncEnabled, usageManager.mobileRelay != nil { pairingSection }
            Section("Ce qui est envoyé") {
                Text("Tes pourcentages, prévisions, le solde de tes crédits, l'état des services et le journal quotidien (120 jours). Jamais tes cookies ni ton compte.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Tout est chiffré ici (AES-256) avant l'envoi : le relais ne peut rien lire, seule la clé de ton téléphone déchiffre.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onDisappear { usageManager.saveDisplaySettings() }   // l'adresse tapée n'est jamais perdue, même sans clic sur « Enregistrer »
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section("Associer ton téléphone Android") {
            LabeledContent("État", value: statusText)
            if showsCode, let link = usageManager.mobilePairingURL {
                VStack(spacing: 8) {
                    if let image = QRCode.image(for: link.absoluteString) {
                        Image(nsImage: image).interpolation(.none).resizable().frame(width: image.size.width, height: image.size.height)
                            .accessibilityLabel("Code QR d'association")
                    }
                    Text("Scanne avec l'appareil photo : l'application s'ouvre déjà associée.").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                HStack {
                    Button(copied ? "Lien copié" : "Copier le lien") { copy(link) }
                    Button("Masquer le code") { showsCode = false }
                }
                Text("Ce code contient la clé de chiffrement : ne le partage pas. Il se masque seul après une minute.")
                    .font(.caption).foregroundColor(.secondary)
                    .task(id: showsCode) { try? await Task.sleep(nanoseconds: 60_000_000_000); showsCode = false }
            } else {
                Button("Afficher le code d'association") { showsCode = true; copied = false }
            }
            Button("Réassocier (nouvelle clé)…", role: .destructive) { confirmsRotation = true }
                .confirmationDialog("Générer une nouvelle clé ?", isPresented: $confirmsRotation) {
                    Button("Nouvelle clé", role: .destructive) { usageManager.rotateMobilePairing(); showsCode = false }
                } message: {
                    Text("Le téléphone actuel perdra l'accès : il faudra rescanner le code.")
                }
        }
    }

    private var statusText: String {
        if let last = usageManager.mobileLastSuccess { return "\(SyncHelpers.age(since: last)) · \(usageManager.mobileStatus)" }
        return usageManager.mobileStatus.isEmpty ? "en attente du premier envoi" : usageManager.mobileStatus
    }

    private func copy(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        copied = true
    }
}
