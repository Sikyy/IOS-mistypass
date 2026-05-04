import Foundation

struct UserProfile: Codable {
    let id: String
    let email: String
    let name: String
    let role: String
    let building: String
    let tenantId: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case role
        case building
        case tenantId = "tenant_id"
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

struct LoginResponse: Codable {
    let tokens: AuthTokens
    let user: UserProfile
}
