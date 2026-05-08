import Foundation

/// Request body for `POST /app/access/unlock`.
/// Field names match the Go backend (`appUnlockDoor`) and Android `UnlockRequest`.
struct UnlockRequestBody: Codable {
    let lockId: String
    let bleToken: String?

    enum CodingKeys: String, CodingKey {
        case lockId = "lock_id"
        case bleToken = "ble_token"
    }
}

/// Request body for `POST /app/credentials/register`.
/// Field names match the Go backend and Android `RegisterMobileCredentialRequest`.
struct RegisterMobileCredentialBody: Codable {
    let publicKeyPem: String
    let platform: String
    let deviceId: String
    let deviceModel: String
    let keystoreLevel: String
    let attestationCertChain: [String]

    enum CodingKeys: String, CodingKey {
        case publicKeyPem = "public_key_pem"
        case platform
        case deviceId = "device_id"
        case deviceModel = "device_model"
        case keystoreLevel = "keystore_level"
        case attestationCertChain = "attestation_cert_chain"
    }
}

/// Response from `POST /app/credentials/register`.
struct RegisterMobileCredentialResponse: Codable {
    let credential: Credential
}

/// Response from `GET /app/access/pin-code`.
/// TOTP-based dynamic PIN, refreshes every `periodSecs` (typically 30s).
struct PinCodeResponse: Codable {
    let pin: String
    let validUntil: String
    let periodSecs: Int

    enum CodingKeys: String, CodingKey {
        case pin
        case validUntil = "valid_until"
        case periodSecs = "period_secs"
    }
}
