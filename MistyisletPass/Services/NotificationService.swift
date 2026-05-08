import Foundation
import UserNotifications
import UIKit

final class NotificationService: NSObject {
    nonisolated(unsafe) static let shared = NotificationService()
    private override init() { super.init() }

    /// Request notification permission and register for APNs
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    /// Send device token to backend
    func registerDeviceToken(_ token: Data) async {
        let tokenHex = token.map { String(format: "%02.2hhx", $0) }.joined()
        do {
            _ = try await APIService.shared.registerAPNSToken(tokenHex)
            AppLogger.push.info("APNS token registered")
        } catch {
            AppLogger.push.error("APNS registration failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String {
            let payload = Dictionary(uniqueKeysWithValues: userInfo.compactMap { key, val -> (String, String)? in
                guard let k = key as? String, let v = val as? String else { return nil }
                return (k, v)
            })
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .didReceiveDeepLink,
                    object: nil,
                    userInfo: ["type": type, "payload": payload]
                )
            }
        }
    }
}

extension Notification.Name {
    static let didReceiveDeepLink = Notification.Name("didReceiveDeepLink")
    static let sessionExpired = Notification.Name("sessionExpired")
}
