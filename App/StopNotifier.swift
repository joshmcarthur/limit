import Foundation
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

    // The completion-handler forms, not the async ones: for an async delegate method the system's completion
    // handler is called from whatever thread the task ends on, and UIKit asserts it's the main thread when a
    // notification action is answered (a TestFlight crash on tapping End drive or Keep driving).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async { completionHandler([.banner]) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if action == ActionID.end { self.onEnd?() } else if action == ActionID.keep { self.onKeep?() }
            }
            completionHandler()
        }
    }
}
