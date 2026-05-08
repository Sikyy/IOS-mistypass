import Foundation

struct BookableSpace: Codable, Identifiable {
    let id: String
    let tenantId: String
    let name: String
    let description: String
    let spaceType: String
    let capacityMode: String
    let maxCapacity: Int
    let currentOccupancy: Int
    let lockId: String?
    let requiresBooking: Bool
    let enabled: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tenantId = "tenant_id"
        case name, description
        case spaceType = "space_type"
        case capacityMode = "capacity_mode"
        case maxCapacity = "max_capacity"
        case currentOccupancy = "current_occupancy"
        case lockId = "lock_id"
        case requiresBooking = "requires_booking"
        case enabled
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var spaceTypeLabel: String {
        switch spaceType {
        case "meeting_room": return "Meeting Room"
        case "prayer_room": return "Prayer Room"
        case "phone_booth": return "Phone Booth"
        default: return spaceType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var spaceTypeIcon: String {
        switch spaceType {
        case "meeting_room": return "person.3"
        case "prayer_room": return "hands.and.sparkles"
        case "phone_booth": return "phone"
        default: return "square.grid.2x2"
        }
    }

    var availableSlots: Int {
        guard capacityMode != "unlimited" else { return .max }
        return max(0, maxCapacity - currentOccupancy)
    }

    var isFull: Bool {
        capacityMode != "unlimited" && currentOccupancy >= maxCapacity
    }
}

struct Booking: Codable, Identifiable {
    let id: String
    let tenantId: String
    let spaceId: String
    let userId: String
    let userName: String
    let title: String?
    let startTime: String
    let endTime: String
    let status: String
    let checkedInAt: String?
    let checkedOutAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tenantId = "tenant_id"
        case spaceId = "space_id"
        case userId = "user_id"
        case userName = "user_name"
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case status
        case checkedInAt = "checked_in_at"
        case checkedOutAt = "checked_out_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isActive: Bool {
        status == "confirmed" || status == "checked_in"
    }

    var canCheckIn: Bool {
        status == "confirmed"
    }

    var canCheckOut: Bool {
        status == "checked_in"
    }

    var canCancel: Bool {
        status == "confirmed"
    }

    var statusColor: String {
        switch status {
        case "confirmed": return "blue"
        case "checked_in": return "green"
        case "completed": return "gray"
        case "cancelled": return "red"
        case "no_show": return "orange"
        default: return "gray"
        }
    }

    var displayTime: String {
        let start = formatTime(startTime)
        let end = formatTime(endTime)
        return "\(start) – \(end)"
    }

    private func formatTime(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: iso) {
            let display = DateFormatter()
            display.dateStyle = .short
            display.timeStyle = .short
            return display.string(from: date)
        }
        fmt.formatOptions = [.withInternetDateTime]
        if let date = fmt.date(from: iso) {
            let display = DateFormatter()
            display.dateStyle = .short
            display.timeStyle = .short
            return display.string(from: date)
        }
        return String(iso.prefix(16))
    }
}

struct BookableSpaceStatus: Codable {
    let spaceId: String
    let currentOccupancy: Int
    let maxCapacity: Int
    let isAvailable: Bool
    let activeBookings: Int
    let nextAvailableSlot: String?

    enum CodingKeys: String, CodingKey {
        case spaceId = "space_id"
        case currentOccupancy = "current_occupancy"
        case maxCapacity = "max_capacity"
        case isAvailable = "is_available"
        case activeBookings = "active_bookings"
        case nextAvailableSlot = "next_available_slot"
    }

    var nextSlotFormatted: String? {
        guard let slot = nextAvailableSlot else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: slot) {
            let df = DateFormatter()
            df.dateStyle = .none
            df.timeStyle = .short
            return df.string(from: date)
        }
        fmt.formatOptions = [.withInternetDateTime]
        if let date = fmt.date(from: slot) {
            let df = DateFormatter()
            df.dateStyle = .none
            df.timeStyle = .short
            return df.string(from: date)
        }
        return nil
    }
}

struct CreateBookingRequest: Encodable {
    let spaceId: String
    let title: String
    let startTime: String
    let endTime: String

    enum CodingKeys: String, CodingKey {
        case spaceId = "space_id"
        case title
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
