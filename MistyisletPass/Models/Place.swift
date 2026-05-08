import Foundation

struct Place: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var address: String?
    let orgId: String?
    var isLockdown: Bool
    let doorCount: Int
    let timezone: String?
    let capacity: Int?
    let currentOccupancy: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, address, timezone, capacity
        case orgId = "org_id"
        case isLockdown = "is_lockdown"
        case doorCount = "door_count"
        case currentOccupancy = "current_occupancy"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        orgId = try container.decodeIfPresent(String.self, forKey: .orgId)
        isLockdown = try container.decodeIfPresent(Bool.self, forKey: .isLockdown) ?? false
        doorCount = try container.decodeIfPresent(Int.self, forKey: .doorCount) ?? 0
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
        currentOccupancy = try container.decodeIfPresent(Int.self, forKey: .currentOccupancy)
    }
}

// MARK: - Organization Settings

struct OrganizationSettings: Codable {
    var name: String
    var address: String?
    var timezone: String?
    var domain: String?
    var logoUrl: String?
    var sessionTimeoutMinutes: Int?
    var sendEmails: Bool
    var emailAccessAssignment: Bool
    var emailCredentialAssignment: Bool
    var emailIncidentAlerts: Bool
    var emailReports: Bool
    var whatsappEnabled: Bool
    var whatsappAccessAssignment: Bool
    var whatsappCredentialAssignment: Bool
    var whatsappIncidentAlerts: Bool
    var webauthnEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case name, address, timezone, domain
        case logoUrl = "logo_url"
        case sessionTimeoutMinutes = "session_timeout_minutes"
        case sendEmails = "send_emails"
        case emailAccessAssignment = "email_access_assignment"
        case emailCredentialAssignment = "email_credential_assignment"
        case emailIncidentAlerts = "email_incident_alerts"
        case emailReports = "email_reports"
        case whatsappEnabled = "whatsapp_enabled"
        case whatsappAccessAssignment = "whatsapp_access_assignment"
        case whatsappCredentialAssignment = "whatsapp_credential_assignment"
        case whatsappIncidentAlerts = "whatsapp_incident_alerts"
        case webauthnEnabled = "webauthn_enabled"
    }
}
