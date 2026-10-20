import Foundation
import UserNotifications

/// Envoi des notifications macOS (framework UserNotifications).
/// macOS demande l'autorisation une seule fois : elle est liée à l'identifiant de l'app, pas à sa signature.
enum Notifier {
    private final class PresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
        /// Sans cela, une app active (même sans fenêtre) n'afficherait pas ses propres bannières.
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([.banner, .sound])
        }
    }

    private static let delegate = PresentationDelegate()

    static func install() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func send(title: String, body: String, id: String = UUID().uuidString) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { deliver(title: title, body: body, id: id) }
                }
            case .authorized, .provisional:
                deliver(title: title, body: body, id: id)
            default:
                NSLog("🔕 Notifications refusées dans les réglages macOS : « \(title) » non envoyée")
            }
        }
    }

    private static func deliver(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { error in
            if let error { NSLog("❌ Notification non envoyée : \(error.localizedDescription)") }
        }
    }
}
