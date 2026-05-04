import Foundation

struct Visitor: Codable, Identifiable {
    let id: String
    let name: String
    let phone: String
    let hostName: String
    let company: String?
    let purpose: String?
    let doorIds: [String]
    let doorNames: [String]
    let accessToken: String
    let createdAt: Date
    let expiresAt: Date
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phone
        case hostName = "host_name"
        case company
        case purpose
        case doorIds = "door_ids"
        case doorNames = "door_names"
        case accessToken = "access_token"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isActive = "is_active"
    }

    var isExpired: Bool {
        expiresAt < Date()
    }

    var timeRemaining: String {
        let interval = expiresAt.timeIntervalSinceNow
        guard interval > 0 else { return "Expired" }
        let hours = Int(interval / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        if hours > 0 {
            return "Expires in \(hours)h \(minutes)m"
        }
        return "Expires in \(minutes)m"
    }
}

struct CreateVisitorRequest: Codable {
    let name: String
    let phone: String
    let hostName: String
    let company: String?
    let purpose: String?
    let doorIds: [String]
    let ttlHours: Int

    enum CodingKeys: String, CodingKey {
        case name
        case phone
        case hostName = "host_name"
        case company
        case purpose
        case doorIds = "door_ids"
        case ttlHours = "ttl_hours"
    }
}
