import Foundation
import CoreBluetooth

enum Constants {
    // MARK: - Environment
    /// App environment. Resolves base URL from `APP_ENV` Info.plist key (set per
    /// scheme) or falls back to production. Mirrors Android build variants.
    enum AppEnvironment: String {
        case mock, staging, production

        var baseURL: String {
            switch self {
            case .mock: return "http://localhost:4010/api/v1"
            case .staging: return "https://staging-api.mistyislet.com/api/v1"
            case .production: return "https://api.mistyislet.com/api/v1"
            }
        }

        static let current: AppEnvironment = {
            let raw = (Bundle.main.object(forInfoDictionaryKey: "APP_ENV") as? String)
                ?? ProcessInfo.processInfo.environment["APP_ENV"]
                ?? ""
            return AppEnvironment(rawValue: raw.lowercased()) ?? .production
        }()
    }

    // MARK: - API
    /// Endpoint paths must match `api/internal/http/router.go` (mobile routes
    /// nested under `/app`, mounted at `/api/v1` on the backend).
    enum API {
        static var baseURL: String { AppEnvironment.current.baseURL }
        static let loginPath = "/app/auth/login"
        static let refreshPath = "/app/auth/refresh"
        static let mePath = "/app/me"
        static let doorsPath = "/app/access/my-doors"
        static let unlockPath = "/app/access/unlock"
        static let qrUnlockPath = "/app/access/qr-unlock"
        static let bleTokenPath = "/app/access/ble-token"
        static let logsPath = "/app/access/logs"
        static let visitorPassesPath = "/app/visitor-passes"
        static let credentialsPath = "/app/credentials"
        static let mobileCredentialRegisterPath = "/app/credentials/register"
        static let mobileCredentialsPath = "/app/credentials/mobile"
    }

    // MARK: - BLE
    /// GATT UUIDs are derived from ASCII strings to keep the protocol identifiable
    /// across platforms. Each segment encodes 6 ASCII chars (12 hex digits).
    /// Canonical source: `api/cmd/gateway-agent/ble_protocol.go`.
    enum BLE {
        /// Service UUID: "MISTYPASS-BLEAUT"
        static let serviceUUID = CBUUID(string: "4D495354-5950-4153-532D-424C45415554")

        // GATT Characteristics — must match Go backend and Android exactly.
        /// "MISTYPASS-CHALLN"
        static let challengeUUID = CBUUID(string: "4D495354-5950-4153-532D-4348414C4C4E")
        /// "MISTYPASS-AUTHRE"
        static let authResponseUUID = CBUUID(string: "4D495354-5950-4153-532D-415554485245")
        /// "MISTYPASS-READER"
        static let readerIdentityUUID = CBUUID(string: "4D495354-5950-4153-532D-524541444552")
        /// "MISTYPASS-RESULT"
        static let authResultUUID = CBUUID(string: "4D495354-5950-4153-532D-524553554C54")

        static let connectionTimeout: TimeInterval = 5.0
        static let scanDebounceDuration: TimeInterval = 3.0

        /// BLE auth result codes (must match `BLEResult*` in ble_protocol.go)
        static let resultGranted: UInt8 = 0x01
        static let resultDenied: UInt8 = 0x02
    }

    // MARK: - Keychain
    enum Keychain {
        static let accessTokenKey = "com.mistyislet.accessToken"
        static let refreshTokenKey = "com.mistyislet.refreshToken"
        static let credentialTag = "com.mistyislet.credential"
    }

    // MARK: - UI
    enum UI {
        static let unlockHoldDuration: TimeInterval = 0.5
        static let unlockOverlayDismissDelay: TimeInterval = 2.0
        static let qrScanDebounce: TimeInterval = 3.0
        static let minimumTouchTarget: CGFloat = 44.0
    }

    // MARK: - Cache
    enum Cache {
        static let offlineMaxAge: TimeInterval = 72 * 3600 // 72 hours
    }
}
