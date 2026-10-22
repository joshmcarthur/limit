import UserNotifications

/// The "Looks like you've stopped driving" notification, with End drive and Keep driving buttons. It shows
/// as a banner when the app is open too.
@MainActor
final class StopNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private static let category = "driveStop"
    private static let request = "driveStop.suggestion"
    private enum ActionID { static let end = "end", keep = "keep" }

    var onEnd: (() -> Void)?
    var onKeep: (() -> Void)?

    override init() {
        super.init()
        center.delegate = self
        let end = UNNotificationAction(identifier: ActionID.end, title: "End drive", options: [])
        let keep = UNNotificationAction(identifier: ActionID.keep, title: "Keep driving", options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.category, actions: [end, keep], intentIdentifiers: [])])
    }

    func requestAccess() {
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func post() {
        let content = UNMutableNotificationContent()
        content.title = "Looks like you've stopped driving"
        content.body = "End the drive to stop using location."
        content.categoryIdentifier = Self.category
        content.interruptionLevel = .timeSensitive
        center.add(UNNotificationRequest(identifier: Self.request, content: content, trigger: nil))
    }

    func clear() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.request])
        center.removeDeliveredNotifications(withIdentifiers: [Self.request])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        await MainActor.run {
            if action == ActionID.end { onEnd?() } else if action == ActionID.keep { onKeep?() }
        }
    }
}
