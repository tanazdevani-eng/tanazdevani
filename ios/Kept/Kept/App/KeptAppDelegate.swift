import UIKit

/// UIKit bridge just for the one thing SwiftUI's App protocol has no hook for: receiving
/// the raw APNs device token. Everything else about push (permission, scheduling, the
/// actual send) lives in NotificationScheduler / AppModel / the Edge Function.
final class KeptAppDelegate: NSObject, UIApplicationDelegate {
    weak var appModel: AppModel?

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await appModel?.registerPushToken(token) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}
