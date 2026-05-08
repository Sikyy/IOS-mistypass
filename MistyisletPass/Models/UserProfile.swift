import Foundation

struct UserProfile: Codable {
    let id: String
    let email: String
    let name: String
    let role: String
    let tenantId: String
    let organizationName: String?
    let roleDisplayLabel: String?
    let language: String?
    let avatar: String?
    let buildingIds: [String]?
    let passwordAuthEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id, email, name, role, avatar, language
        case tenantId = "tenant_id"
        case organizationName = "organization_name"
        case roleDisplayLabel = "role_display_label"
        case buildingIds = "building_ids"
        case passwordAuthEnabled = "password_auth_enabled"
    }

    var isAdmin: Bool {
        ["super_admin", "tenant_admin", "building_admin"].contains(role)
    }
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct UserLogin: Codable, Identifiable {
    let id: String
    let deviceName: String
    let platform: String
    let lastActive: String
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case deviceName = "device_name"
        case platform
        case lastActive = "last_active"
        case isCurrent = "is_current"
    }
}

struct UserLoginListResponse: Codable {
    let items: [UserLogin]
}

struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

struct UpdateProfileRequest: Codable {
    let name: String?
}

// MARK: - Auth Flow Models

struct MagicLinkRequest: Codable {
    let email: String
}

struct MagicLinkResponse: Codable {
    let message: String
}

struct OrgAuthConfig: Codable {
    let orgId: String
    let domain: String
    let name: String
    let logo: String?
    let methods: [String]

    enum CodingKeys: String, CodingKey {
        case orgId = "org_id"
        case domain, name, logo, methods
    }
}

struct RestorePasswordRequest: Codable {
    let email: String
}

/// Backend returns tokens at root level alongside user, not nested.
struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: UserProfile

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }

    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)
    }
}
