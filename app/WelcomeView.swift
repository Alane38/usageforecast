import AppKit
import SwiftUI

/// Assistant de premier lancement : deux façons d'alimenter l'app, avec l'état en direct.
struct WelcomeView: View {
    @ObservedObject var usageManager: UsageManager
    var openConnections: () -> Void
    var finish: () -> Void

    @State private var copied = false

    private var connected: Bool { usageManager.hasFetchedData }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bienvenue dans \(Brand.name)").font(.title2.bold())
                Text("Pour afficher tes limites Claude, choisis une des deux sources. Tu peux changer plus tard dans les Réglages.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            statusBanner

            optionCard(
                title: "Avec Claude Code",
                detail: "Limites officielles, aucun cookie, aucun réseau. Fusionne ce réglage dans ~/.claude/settings.json, puis relance Claude Code : un message suffit à remplir l'app. Si tu as déjà un statusline, garde-le : fais seulement passer son entrée par cette copie.",
                badge: "Le plus simple et le plus sûr"
            ) {
                Text(FirstRun.statuslineSetting)
                    .font(.system(size: 10.5, design: .monospaced)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                Button(copied ? "Copié" : "Copier le réglage") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(FirstRun.statuslineSetting, forType: .string)
                    copied = true
                }
                .disabled(copied)
            }

            optionCard(
                title: "Avec ton compte claude.ai",
                detail: "Sans Claude Code : colle le cookie de ta session dans les Réglages, onglet Connexions. Il reste dans le trousseau de ton Mac.",
                badge: nil
            ) {
                Button("Ouvrir les Connexions", action: openConnections)
            }

            HStack {
                Text("Rien ne quitte ton Mac, sauf la lecture de tes limites chez Anthropic.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(connected ? "Terminer" : "Plus tard", action: finish).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Circle().fill(connected ? Color.green : Color.orange).frame(width: 9, height: 9)
            Text(connected ? "Données reçues : tout est prêt." : "En attente de données…")
                .font(.callout.weight(.medium))
            Spacer()
        }
        .padding(10)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func optionCard<Content: View>(title: String, detail: String, badge: String?,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                if let badge {
                    Text(badge).font(.caption2.weight(.semibold)).foregroundStyle(.green)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.15), in: Capsule())
                }
            }
            Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            content()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))
    }
}

extension Notification.Name {
    static let showWelcome = Notification.Name("UsageForecast.showWelcome")
}

/// Fenêtre de l'assistant. Fermée ou terminée, elle ne revient plus (sauf depuis Réglages > Général).
final class WelcomeWindowController {
    private var window: NSWindow?

    func show(usageManager: UsageManager, openConnections: @escaping () -> Void) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = WelcomeView(usageManager: usageManager, openConnections: { [weak self] in
            self?.close()
            openConnections()
        }, finish: { [weak self] in self?.close() })
        let newWindow = NSWindow(contentViewController: NSHostingController(rootView: view))
        newWindow.title = Brand.name
        newWindow.styleMask = [.titled, .closable]
        newWindow.setContentSize(NSSize(width: 520, height: 620))
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        window = newWindow
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: newWindow, queue: .main) { [weak self] _ in
            UserDefaults.standard.set(true, forKey: FirstRun.seenKey)
            self?.window = nil
        }
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func close() { window?.close() }
}
