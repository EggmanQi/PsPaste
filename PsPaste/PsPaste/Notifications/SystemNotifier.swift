import Foundation
import UserNotifications

/// Delivers user notifications.
///
/// Degrades silently to no delivery when the user denies notification
/// permission — the menu bar warning stays the primary conflict indicator.
@MainActor
final class SystemNotifier {

    private let requestAuthorization: (@escaping (Bool) -> Void) -> Void
    private let enqueue: (String, String) -> Void

    private enum Authorization {
        case unknown, granted, denied
    }

    private var authorization: Authorization = .unknown

    init(
        requestAuthorization: @escaping (@escaping (Bool) -> Void) -> Void = { completion in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                completion(granted)
            }
        },
        enqueue: @escaping (String, String) -> Void = { title, body in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    ) {
        self.requestAuthorization = requestAuthorization
        self.enqueue = enqueue
    }

    /// Requests authorization once, then delivers only when granted.
    func deliver(title: String, body: String) {
        switch authorization {
        case .granted:
            enqueue(title, body)
        case .denied:
            return
        case .unknown:
            requestAuthorization { [weak self] granted in
                guard let self else { return }
                self.authorization = granted ? .granted : .denied
                if granted {
                    self.enqueue(title, body)
                }
            }
        }
    }
}
