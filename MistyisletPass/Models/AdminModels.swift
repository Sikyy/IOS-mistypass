import Foundation
import SwiftUI

// MARK: - Users

struct PlaceUser: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let avatar: String?
    var role: String
    var status: String
    let lastActivity: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, avatar, role, status
        case lastActivity = "last_activity"
        case createdAt = "created_at"
    }
}

// MARK: - Events (admin-scoped, not same as access logs)

struct AdminEvent: Codable, Identifiable {
    let id: String
    let placeId: String
    let timestamp: String
    let actor: String
    let action: String
    let result: String
    let objectName: String
    let objectType: String
    let objectId: String?
    let doorId: String?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, actor, action, result
        case placeId = "place_id"
        case objectName = "object_name"
        case objectType = "object_type"
        case objectId = "object_id"
        case doorId = "door_id"
    }

    var displayTime: String {
        // Parse ISO 8601 and show relative time
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            return date.formatted(.relative(presentation: .named))
        }
        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: timestamp) {
            return date.formatted(.relative(presentation: .named))
        }
        return timestamp
    }

    var resultIcon: String {
        switch result.lowercased() {
        case "granted", "success": return "checkmark.circle.fill"
        case "denied", "failed": return "xmark.circle.fill"
        default: return "circle.fill"
        }
    }

    var resultColor: String {
        switch result.lowercased() {
        case "granted", "success": return "green"
        case "denied", "failed": return "red"
        default: return "gray"
        }
    }
}

// MARK: - Incidents

struct Incident: Codable, Identifiable {
    let id: String
    let placeId: String
    let type: String
    let state: String
    let status: String
    let severity: String
    let description: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, state, status, severity, description
        case placeId = "place_id"
        case createdAt = "created_at"
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
}

// MARK: - Groups

struct AccessGroup: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    let scope: String
    let placeId: String?
    let memberCount: Int
    let doorCount: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, scope
        case placeId = "place_id"
        case memberCount = "member_count"
        case doorCount = "door_count"
        case createdAt = "created_at"
    }
}

struct GroupMember: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let email: String
    let role: String
    let addedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, role
        case userId = "user_id"
        case addedAt = "added_at"
    }
}

struct GroupDoor: Codable, Identifiable {
    let id: String
    let name: String
    let status: String
}

// MARK: - Teams

struct Team: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    var memberCount: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case memberCount = "member_count"
        case createdAt = "created_at"
    }
}

struct TeamMember: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let email: String
    let addedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case userId = "user_id"
        case addedAt = "added_at"
    }
}

struct AccessRightAssignment: Codable, Identifiable {
    let id: String
    let role: String
    let scope: String
    let scopeName: String?
    let scopeId: String?

    enum CodingKeys: String, CodingKey {
        case id, role, scope
        case scopeName = "scope_name"
        case scopeId = "scope_id"
    }
}

// MARK: - Schedules

struct UnlockSchedule: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    var scheduleType: String
    var startTime: String
    var endTime: String
    var daysOfWeek: [Int]
    var isEnabled: Bool?
    let doorId: String?
    let doorName: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case scheduleType = "schedule_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case daysOfWeek = "days_of_week"
        case isEnabled = "is_enabled"
        case doorId = "door_id"
        case doorName = "door_name"
    }

    var daysDisplay: String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return daysOfWeek.compactMap { $0 < dayNames.count ? dayNames[$0] : nil }.joined(separator: ", ")
    }

    var typeIcon: String {
        switch scheduleType.lowercased() {
        case "unlock": return "lock.open"
        case "access_denial": return "hand.raised"
        case "first_to_arrive": return "figure.walk.arrival"
        case "holiday": return "gift"
        default: return "calendar.badge.clock"
        }
    }

    var typeColor: Color {
        switch scheduleType.lowercased() {
        case "unlock": return .green
        case "access_denial": return .red
        case "first_to_arrive": return .orange
        case "holiday": return .purple
        default: return .blue
        }
    }
}

// MARK: - Door Restrictions

struct DoorRestriction: Codable, Identifiable {
    let id: String
    let type: String
    let latitude: Double?
    let longitude: Double?
    let radiusMeters: Int?
    let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, type, latitude, longitude
        case radiusMeters = "radius_meters"
        case isEnabled = "is_enabled"
    }

    var typeLabel: String {
        switch type.lowercased() {
        case "geofence": return "Geofence"
        case "reader_proximity": return "Reader Proximity"
        default: return type.capitalized
        }
    }

    var typeIcon: String {
        switch type.lowercased() {
        case "geofence": return "location.circle"
        case "reader_proximity": return "sensor.tag.radiowaves.forward"
        default: return "shield.checkered"
        }
    }
}

// MARK: - Zones

struct Zone: Codable, Identifiable {
    let id: String
    let placeId: String
    let name: String
    let description: String
    let status: String
    let doorCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case placeId = "place_id"
        case doorCount = "door_count"
    }
}

// MARK: - Cards

struct CardAssignment: Codable, Identifiable {
    let id: String
    let cardUid: String
    let userId: String?
    let userName: String?
    let userEmail: String?
    let status: String
    let type: String
    let cardNumber: String?
    let deviceName: String?
    let issuedAt: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, type
        case cardUid = "card_uid"
        case userId = "user_id"
        case userName = "user_name"
        case userEmail = "user_email"
        case cardNumber = "card_number"
        case deviceName = "device_name"
        case issuedAt = "issued_at"
        case expiresAt = "expires_at"
    }
}

// MARK: - Digital Credentials

struct DigitalCredential: Codable, Identifiable {
    let id: String
    let type: String
    let userEmail: String?
    let userName: String?
    let recipientEmail: String?
    let platform: String?
    let deviceModel: String?
    let status: String?
    let issuedAt: String?
    let expiresAt: String?
    let usageCount: Int

    enum CodingKeys: String, CodingKey {
        case id, type, platform, status
        case userEmail = "user_email"
        case userName = "user_name"
        case recipientEmail = "recipient_email"
        case deviceModel = "device_model"
        case issuedAt = "issued_at"
        case expiresAt = "expires_at"
        case usageCount = "usage_count"
    }
}

// MARK: - Camera

struct Camera: Codable, Identifiable {
    let id: String
    let name: String
    let vendor: String
    let model: String?
    let ipAddress: String?
    let status: String          // online / offline / error
    let doorId: String?
    let doorName: String?
    let streamUrl: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, vendor, model, status
        case ipAddress = "ip_address"
        case doorId = "door_id"
        case doorName = "door_name"
        case streamUrl = "stream_url"
        case createdAt = "created_at"
    }
}

struct CameraVideoLink: Codable {
    let cameraId: String?
    let videoUrl: String
    let `protocol`: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case cameraId = "camera_id"
        case videoUrl = "video_url"
        case `protocol`
        case expiresAt = "expires_at"
    }
}

struct CameraSnapshot: Codable, Identifiable {
    let id: String
    let cameraId: String
    let snapshotUrl: String
    let triggeredBy: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case cameraId = "camera_id"
        case snapshotUrl = "snapshot_url"
        case triggeredBy = "triggered_by"
        case createdAt = "created_at"
    }
}

// MARK: - Event Media (snapshots linked to access events)

struct EventMedia: Codable, Identifiable {
    let id: String
    let eventId: String
    let cameraName: String
    let snapshotUrl: String
    let datetime: String

    enum CodingKeys: String, CodingKey {
        case id, datetime
        case eventId = "event_id"
        case cameraName = "camera_name"
        case snapshotUrl = "snapshot_url"
    }
}

// MARK: - Analytics / Reports

struct AnalyticsSummary: Codable {
    let totalUnlocks: Int
    let uniqueUsers: Int
    let failedAttempts: Int
    let avgDailyUnlocks: Double
    let periodDays: Int
    let topDoors: [DoorUsage]
    let unlocksByMethod: [MethodBreakdown]
    let dailyTrend: [DailyUnlockStat]
    let heatmap: [HeatmapCell]?
    let weeklyUsers: [WeeklyUserCount]?

    enum CodingKeys: String, CodingKey {
        case totalUnlocks = "total_unlocks"
        case uniqueUsers = "unique_users"
        case failedAttempts = "failed_attempts"
        case avgDailyUnlocks = "avg_daily_unlocks"
        case periodDays = "period_days"
        case topDoors = "top_doors"
        case unlocksByMethod = "unlocks_by_method"
        case dailyTrend = "daily_trend"
        case heatmap
        case weeklyUsers = "weekly_users"
    }
}

struct HeatmapCell: Codable, Identifiable {
    let dayOfWeek: Int   // 0=Mon … 6=Sun
    let hour: Int        // 0-23
    let value: Int       // unique users who unlocked

    var id: String { "\(dayOfWeek)-\(hour)" }

    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case hour, value
    }
}

struct WeeklyUserCount: Codable, Identifiable {
    let weekStart: String
    let uniqueUsers: Int

    var id: String { weekStart }

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case uniqueUsers = "unique_users"
    }
}

struct DoorUsage: Codable, Identifiable {
    let id: String
    let name: String
    let count: Int
}

struct MethodBreakdown: Codable {
    let method: String  // "mobile", "card", "pin", "qr", "ble", "visitor"
    let count: Int
}

struct DailyUnlockStat: Codable, Identifiable {
    let date: String
    let unlocks: Int
    let uniqueUsers: Int
    let failed: Int

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date, unlocks, failed
        case uniqueUsers = "unique_users"
    }
}

struct UserPresenceRecord: Codable, Identifiable {
    let id: String
    let userName: String
    let email: String
    let firstUnlock: String?
    let lastUnlock: String?
    let daysPresent: Int
    let totalUnlocks: Int
    let weekdayBreakdown: [Int]?  // [Mon, Tue, Wed, Thu, Fri, Sat, Sun] unlock counts

    enum CodingKeys: String, CodingKey {
        case id, email
        case userName = "user_name"
        case firstUnlock = "first_unlock"
        case lastUnlock = "last_unlock"
        case daysPresent = "days_present"
        case totalUnlocks = "total_unlocks"
        case weekdayBreakdown = "weekday_breakdown"
    }
}

struct ReportExportResponse: Codable {
    let url: String
    let expiresAt: String?
    let format: String

    enum CodingKeys: String, CodingKey {
        case url, format
        case expiresAt = "expires_at"
    }
}

// MARK: - Generic list wrapper (backend returns { items: [...], total: N })

struct AdminListResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([T].self, forKey: .items)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
    }

    enum CodingKeys: String, CodingKey {
        case items, total
    }
}
