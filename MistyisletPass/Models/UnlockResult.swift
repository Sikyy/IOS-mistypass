import Foundation

enum UnlockState: Equatable {
    case idle
    case holding(progress: Double)
    case connecting
    case granted(doorName: String)
    case denied(doorName: String, reason: String)
    case failed(doorName: String, reason: String)
}

/// Response from `POST /app/access/unlock`.
/// Field shape matches Go `appUnlockDoor` handler and Android `UnlockResponse`.
struct RemoteUnlockResponse: Codable {
    let decision: String
    let reason: String?
    let lockId: String
    let lockName: String?
    let requestId: String?
    let dispatched: Bool?

    enum CodingKeys: String, CodingKey {
        case decision
        case reason
        case lockId = "lock_id"
        case lockName = "lock_name"
        case requestId = "request_id"
        case dispatched
    }

    var isGranted: Bool { decision == "grant" || decision == "allow" }
}

enum DoorSortOrder {
    case name, status, building
}
