import Foundation

struct Visitor: Codable, Identifiable {
    let id: String
    let visitor: String?
    let host: String?
    let deliveryMethod: String?
    let expiresAt: String?
    let createdAt: Date?
    let validFrom: String?
    let validUntil: String?
    let displayLabel: String?

    enum CodingKeys: String, CodingKey {
        case id, visitor, host
        case deliveryMethod = "delivery_method"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case displayLabel = "display_label"
    }

    var name: String { visitor ?? displayLabel ?? "Visitor" }
    var hostName: String { host ?? "" }

    var isExpired: Bool {
        guard let until = parsedValidUntil else { return false }
        return until < Date()
    }

    var isActive: Bool { !isExpired }

    var timeRemaining: String {
        guard let until = parsedValidUntil else { return "" }
        let interval = until.timeIntervalSinceNow
        guard interval > 0 else {
            return NSLocalizedString("visitors.expired", comment: "")
        }
        let hours = Int(interval / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        if hours > 0 {
            return String(format: NSLocalizedString("visitors.expires_in_hm", comment: ""), hours, minutes)
        }
        return String(format: NSLocalizedString("visitors.expires_in_m", comment: ""), minutes)
    }

    private var parsedValidUntil: Date? {
        guard let str = validUntil ?? expiresAt else { return nil }
        return ISO8601DateFormatter.withFractionalSeconds.date(from: str)
            ?? ISO8601DateFormatter.standard.date(from: str)
    }
}

struct CreateVisitorRequest: Codable {
    let visitor: String
    let deliveryMethod: String
    let buildingId: String?
    let validFrom: String?
    let validUntil: String?
    let ttlHours: Double?

    enum CodingKeys: String, CodingKey {
        case visitor
        case deliveryMethod = "delivery_method"
        case buildingId = "building_id"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case ttlHours = "ttl_hours"
    }
}

// MARK: - Visitor Group

struct VisitorGroup: Codable, Identifiable {
    let id: String
    let name: String
    let placeId: String
    let memberCount: Int
    let autoRemoveExpired: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case placeId = "place_id"
        case memberCount = "member_count"
        case autoRemoveExpired = "auto_remove_expired"
        case createdAt = "created_at"
    }
}

struct VisitorGroupMember: Codable, Identifiable {
    let id: String
    let visitorId: String
    let visitorName: String
    let expiresAt: Date
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case visitorId = "visitor_id"
        case visitorName = "visitor_name"
        case expiresAt = "expires_at"
        case isActive = "is_active"
    }

    var isExpired: Bool { expiresAt < Date() }
}
