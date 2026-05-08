import Foundation

struct Guest: Codable, Identifiable {
    let id: String
    let tenantId: String
    let buildingId: String?
    let name: String
    let email: String?
    let phone: String
    let company: String?
    let purpose: String?
    let hostName: String
    let hostEmail: String?
    let hostPhone: String?
    let idDocumentType: String?
    let idDocumentNumber: String?
    let expectedAt: String?
    var status: String
    let accessToken: String?
    let accessTokenExpiresAt: String?
    let hostNotifiedAt: String?
    let doorIds: [String]?
    let checkedInAt: String?
    let checkedOutAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, company, purpose, status
        case tenantId = "tenant_id"
        case buildingId = "building_id"
        case hostName = "host_name"
        case hostEmail = "host_email"
        case hostPhone = "host_phone"
        case idDocumentType = "id_document_type"
        case idDocumentNumber = "id_document_number"
        case expectedAt = "expected_at"
        case accessToken = "access_token"
        case accessTokenExpiresAt = "access_token_expires_at"
        case hostNotifiedAt = "host_notified_at"
        case doorIds = "door_ids"
        case checkedInAt = "checked_in_at"
        case checkedOutAt = "checked_out_at"
        case createdAt = "created_at"
    }

    var statusColor: String {
        switch status {
        case "expected": return "orange"
        case "checked_in": return "green"
        case "checked_out": return "gray"
        case "cancelled": return "red"
        default: return "gray"
        }
    }

    var statusIcon: String {
        switch status {
        case "expected": return "clock"
        case "checked_in": return "arrow.right.circle.fill"
        case "checked_out": return "arrow.left.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    var displayTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) {
            return date.formatted(.relative(presentation: .named))
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: createdAt) {
            return date.formatted(.relative(presentation: .named))
        }
        return createdAt
    }

    var expectedAtDisplay: String? {
        guard let expectedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: expectedAt) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: expectedAt) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return nil
    }

    var canCheckIn: Bool { status == "expected" }
    var canCheckOut: Bool { status == "checked_in" }
    var canCancel: Bool { status == "expected" || status == "checked_in" }
}

struct CreateGuestRequest: Encodable {
    let name: String
    let email: String?
    let phone: String
    let company: String?
    let purpose: String?
    let hostName: String
    let hostEmail: String?
    let hostPhone: String?
    let idDocumentType: String?
    let idDocumentNumber: String?
    let expectedAt: String?
    let notifyHost: Bool
    let doorIds: [String]
    let accessTtlHours: Int

    enum CodingKeys: String, CodingKey {
        case name, email, phone, company, purpose
        case hostName = "host_name"
        case hostEmail = "host_email"
        case hostPhone = "host_phone"
        case idDocumentType = "id_document_type"
        case idDocumentNumber = "id_document_number"
        case expectedAt = "expected_at"
        case notifyHost = "notify_host"
        case doorIds = "door_ids"
        case accessTtlHours = "access_ttl_hours"
    }
}
