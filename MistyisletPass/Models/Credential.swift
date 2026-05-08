import Foundation

struct Credential: Codable, Identifiable {
    let id: String
    let userEmail: String?
    let deviceId: String?
    let platform: String?
    let deviceModel: String?
    let keystoreLevel: String?
    let status: String?
    let issuedAt: Date?
    let expiresAt: Date?
    let revokedAt: Date?
    let lastUsedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userEmail = "user_email"
        case deviceId = "device_id"
        case platform
        case deviceModel = "device_model"
        case keystoreLevel = "keystore_level"
        case status
        case issuedAt = "issued_at"
        case expiresAt = "expires_at"
        case revokedAt = "revoked_at"
        case lastUsedAt = "last_used_at"
    }

    var isActive: Bool { status == "active" }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    var isExpiringSoon: Bool {
        guard let expiresAt else { return false }
        let interval = expiresAt.timeIntervalSinceNow
        return interval > 0 && interval < 24 * 3600
    }

    var deviceName: String {
        deviceModel ?? deviceId ?? "Unknown"
    }
}
