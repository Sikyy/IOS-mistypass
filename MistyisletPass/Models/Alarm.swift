import Foundation

struct Alarm: Codable, Identifiable {
    let id: String
    let tenantId: String
    let buildingId: String
    let areaId: String
    let doorId: String
    let type: String
    let severity: String
    let location: String
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tenantId = "tenant_id"
        case buildingId = "building_id"
        case areaId = "area_id"
        case doorId = "door_id"
        case type, severity, location, status
        case createdAt = "created_at"
    }

    var isOpen: Bool {
        status.lowercased() == "open"
    }

    var severityColor: String {
        switch severity.lowercased() {
        case "critical": return "red"
        case "high": return "orange"
        case "medium": return "yellow"
        case "low": return "blue"
        default: return "gray"
        }
    }

    var typeLabel: String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var statusLabel: String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var timeAgo: String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: createdAt) ?? {
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return f2.date(from: createdAt)
        }() else {
            return createdAt
        }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

struct AlarmSchedule: Codable, Identifiable {
    let id: String
    let tenantId: String
    let name: String
    let description: String?
    let daysOfWeek: [Int]
    let startTime: String
    let endTime: String
    let timezone: String
    let alarmTypes: [String]
    let enabled: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tenantId = "tenant_id"
        case name, description
        case daysOfWeek = "days_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case timezone
        case alarmTypes = "alarm_types"
        case enabled
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AlarmCalendarEntry: Codable, Identifiable {
    let scheduleId: String
    let name: String
    let dayOfWeek: Int
    let startTime: String
    let endTime: String
    let alarmTypes: [String]

    var id: String { "\(scheduleId)-\(dayOfWeek)" }

    enum CodingKeys: String, CodingKey {
        case scheduleId = "schedule_id"
        case name
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case alarmTypes = "alarm_types"
    }
}

struct AlarmStreamEvent: Decodable {
    let type: String
    let alarm: Alarm
}

struct UserActivity: Codable, Identifiable {
    let userId: String
    let placeId: String
    let lastSeen: String
    let lastDoor: String
    let eventId: String

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case placeId = "place_id"
        case lastSeen = "last_seen"
        case lastDoor = "last_door"
        case eventId = "event_id"
    }

    var lastSeenAgo: String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        guard let date = fmt.date(from: lastSeen) else { return lastSeen }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
