import SwiftUI

/// Bandeau « nouvelle version » : notes de version, installation et progression de celle-ci.
struct UpdateBanner: View {
    @ObservedObject var usageManager: UsageManager
    let update: ReleaseInfo

    private var isInstalling: Bool {
        guard case .working = usageManager.updateInstallState else { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version \(update.version) disponible").font(.system(size: 13, weight: .medium))
                    Text("Tu as la \(usageManager.currentVersion).").font(.caption).foregroundColor(Color.secondaryText)
                }
                Spacer()
                buttons
            }
            installProgress
        }
        .popoverCard()
    }

    private var buttons: some View {
        HStack(spacing: 6) {
            Button("Notes") { NSWorkspace.shared.open(update.pageURL) }.controlSize(.small)
            if update.zipURL != nil {
                Button("Installer") { usageManager.installUpdate() }.controlSize(.small).disabled(isInstalling)
            }
        }
    }

    @ViewBuilder
    private var installProgress: some View {
        switch usageManager.updateInstallState {
        case .idle:
            EmptyView()
        case .working(let step):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(step).font(.caption).foregroundColor(Color.secondaryText)
            }
        case .failed(let message):
            Text(message).font(.caption).foregroundColor(UsageTone.danger.color)
        }
    }
}
