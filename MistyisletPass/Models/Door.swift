import Foundation
import SwiftData

// MARK: - Legacy flat API response (GET /app/access/my-doors)

struct Door: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let building: String
    let floor: String
    let gatewayOnline: Bool
    let controllerOnline: Bool
    let hasPermission: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, building, floor
        case gatewayOnline = "gateway_online"
        case controllerOnline = "controller_online"
        case hasPermission = "has_permission"
    }

    var statusDescription: String {
        if !controllerOnline { return NSLocalizedString("doors.controller_offline", comment: "") }
        if !gatewayOnline { return NSLocalizedString("doors.gateway_offline", comment: "") }
        return NSLocalizedString("doors.online", comment: "")
    }

    var canUnlock: Bool { hasPermission && controllerOnline }
}

// MARK: - Place-scoped API response (GET /app/places/{placeId}/doors)

struct AccessibleDoor: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    let buildingId: String
    let areaId: String?
    let status: String
    let gatewayStatus: String
    let gatewayId: String?
    let gatewayName: String?
    let groupName: String?
    let canUnlock: Bool
    let isFavorite: Bool
    let lastUnlockAt: String?
    let kind: String?

    enum CodingKeys: String, CodingKey {
        case id, name, status, kind
        case buildingId = "building_id"
        case areaId = "area_id"
        case gatewayStatus = "gateway_status"
        case gatewayId = "gateway_id"
        case gatewayName = "gateway_name"
        case groupName = "group_name"
        case canUnlock = "can_unlock"
        case isFavorite = "is_favorite"
        case lastUnlockAt = "last_unlock_at"
    }

    var displayStatus: DoorDisplayStatus {
        switch (status, gatewayStatus, canUnlock) {
        case ("locked_down", _, _): return .lockedDown
        case (_, _, true): return .onlineUnlockable
        case ("offline", _, _), (_, "offline", _): return .offline
        default: return .disconnected
        }
    }

    var statusDescription: String {
        switch displayStatus {
        case .onlineUnlockable: return NSLocalizedString("doors.online", comment: "")
        case .lockedDown: return NSLocalizedString("doors.lockdown", comment: "")
        case .offline: return NSLocalizedString("doors.offline", comment: "")
        case .disconnected: return NSLocalizedString("doors.disconnected", comment: "")
        }
    }
}

enum DoorDisplayStatus {
    case onlineUnlockable, lockedDown, offline, disconnected
}

// MARK: - Place door list wrapper

struct PlaceDoorListResponse: Codable {
    let items: [AccessibleDoor]
}

// MARK: - SwiftData Cache Model

@Model
final class CachedDoor {
    @Attribute(.unique) var id: String
    var name: String
    var building: String
    var floor: String
    var gatewayOnline: Bool
    var controllerOnline: Bool
    var hasPermission: Bool
    var lastSyncedAt: Date

    init(from door: Door) {
        self.id = door.id
        self.name = door.name
        self.building = door.building
        self.floor = door.floor
        self.gatewayOnline = door.gatewayOnline
        self.controllerOnline = door.controllerOnline
        self.hasPermission = door.hasPermission
        self.lastSyncedAt = Date()
    }

    func toDoor() -> Door {
        Door(
            id: id,
            name: name,
            building: building,
            floor: floor,
            gatewayOnline: gatewayOnline,
            controllerOnline: controllerOnline,
            hasPermission: hasPermission
        )
    }
}
