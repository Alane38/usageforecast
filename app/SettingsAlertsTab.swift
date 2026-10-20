import SwiftUI

struct AlertsTab: View {
    @ObservedObject var usageManager: UsageManager
    @ObservedObject var statusManager: StatusManager

    var body: some View {
        Form {
            Section("Notifications") { notificationToggles }
            Section("Alertes anticipées") { earlyAlerts }
            Section("Services suivis") { trackedServices }
        }
        .formStyle(.grouped)
    }

    private func settingToggle(_ title: String, _ keyPath: ReferenceWritableKeyPath<UsageManager, Bool>) -> some View {
        let persist = usageManager.saveSettings
        let isOn = Binding(
            get: { usageManager[keyPath: keyPath] },
            set: { (newValue: Bool) in
                usageManager[keyPath: keyPath] = newValue
                persist()
            }
        )
        return Toggle(title, isOn: isOn)
    }

    @ViewBuilder
    private var notificationToggles: some View {
        settingToggle("Seuils d'utilisation (25, 50, 75 et 90 % de la session)", \.usageNotificationsEnabled)
        settingToggle("Pannes des services Claude suivis", \.statusNotificationsEnabled)
        Button("Envoyer une notification de test", action: usageManager.sendTestNotification)
    }

    @ViewBuilder
    private var earlyAlerts: some View {
        Button("Voir des exemples d'alertes", action: usageManager.sendDemoAlerts)
        ForEach(AlertKind.allCases, id: \.self) { kind in
            alertRow(kind)
        }
    }

    private func alertRow(_ kind: AlertKind) -> some View {
        let isEnabled = Binding(
            get: { usageManager.alertSettings.isOn(kind) },
            set: { usageManager.setAlert(kind, enabled: $0) }
        )
        return VStack(alignment: .leading, spacing: 2) {
            Toggle(kind.label, isOn: isEnabled)
            Text(kind.detail).helpStyle()
        }
    }

    @ViewBuilder
    private var trackedServices: some View {
        Text("Seuls les services cochés déclenchent des alertes et apparaissent dans le popover.").helpStyle()
        ForEach(statusManager.allComponents) { service in
            let isTracked = Binding(
                get: { statusManager.isTracked(service.id) },
                set: { _ in statusManager.toggleComponent(service.id) }
            )
            Toggle(service.name, isOn: isTracked)
        }
    }
}
