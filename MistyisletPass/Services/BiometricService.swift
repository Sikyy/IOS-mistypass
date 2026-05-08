import Foundation
import LocalAuthentication

enum BiometricType {
    case faceID, touchID, opticID, none
}

enum BiometricError: Error, LocalizedError {
    case notAvailable
    case authenticationFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Biometric authentication is not available"
        case .authenticationFailed(let msg): return msg
        case .cancelled: return "Authentication was cancelled"
        }
    }
}

@MainActor
final class BiometricService {
    static let shared = BiometricService()
    private init() {}

    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    var deviceBiometricType: BiometricType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    var isAvailable: Bool {
        biometricType != .none
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Passcode"
        }
    }

    /// Authenticate user with biometrics before sensitive actions (e.g., unlock door)
    func authenticate(reason: String = "Authenticate to unlock door") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if !success {
                throw BiometricError.authenticationFailed("Authentication failed")
            }
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            default:
                throw BiometricError.authenticationFailed(error.localizedDescription)
            }
        }
    }
}
