import UIKit

@MainActor
final class HapticService {
    static let shared = HapticService()

    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        impactMedium.prepare()
        impactLight.prepare()
        notification.prepare()
    }

    func holdStart() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    func unlockGranted() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    func unlockDenied() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    func buttonTap() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }
}
