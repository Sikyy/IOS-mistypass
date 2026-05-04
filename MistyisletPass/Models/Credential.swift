import Foundation

struct Credential: Codable, Identifiable {
    let id: String
    let deviceName: String
    let publicKeyFingerprint: String
    let createdAt: Date
    let expiresAt: Date
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case deviceName = "device_name"
        case publicKeyFingerprint = "public_key_fingerprint"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isActive = "is_active"
    }

    var isExpired: Bool {
        expiresAt < Date()
    }

    var isExpiringSoon: Bool {
        let interval = expiresAt.timeIntervalSinceNow
        return interval > 0 && interval < 24 * 3600
    }
}
