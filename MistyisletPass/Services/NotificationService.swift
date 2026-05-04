import Foundation
import UserNotifications
import UIKit

final class NotificationService: NSObject {
    static let shared = NotificationService()
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
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()

        guard let url = URL(string: Constants.API.baseURL + "/app/devices/apns") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken = KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let body = ["device_token": tokenString, "platform": "ios"]
        request.httpBody = try? JSONEncoder().encode(body)

        _ = try? await URLSession.shared.data(for: request)
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

        // Navigate based on notification type
        if let type = userInfo["type"] as? String {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .didReceiveDeepLink,
                    object: nil,
                    userInfo: ["type": type, "payload": userInfo]
                )
            }
        }
    }
}

extension Notification.Name {
    static let didReceiveDeepLink = Notification.Name("didReceiveDeepLink")
}
