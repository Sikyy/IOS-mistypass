import Foundation
import SwiftData

// MARK: - API Response Model

struct Door: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let building: String
    let floor: String
    let gatewayOnline: Bool
    let controllerOnline: Bool
    let hasPermission: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case building
        case floor
        case gatewayOnline = "gateway_online"
        case controllerOnline = "controller_online"
        case hasPermission = "has_permission"
    }

    var statusDescription: String {
        if !controllerOnline {
            return "Controller offline"
        } else if !gatewayOnline {
            return "Gateway offline"
        } else {
            return "Online"
        }
    }

    var canUnlock: Bool {
        hasPermission && controllerOnline
    }
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
