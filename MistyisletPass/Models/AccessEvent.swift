import Foundation
import SwiftData

// MARK: - API Response Model

struct AccessEvent: Codable, Identifiable {
    let id: String
    let doorId: String
    let doorName: String
    let timestamp: Date
    let result: AccessResult
    let method: AccessMethod
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case doorId = "door_id"
        case doorName = "door_name"
        case timestamp
        case result
        case method
        case reason
    }
}

enum AccessResult: String, Codable {
    case granted
    case denied
}

enum AccessMethod: String, Codable {
    case ble
    case qr
    case remote
    case nfc
}

// MARK: - SwiftData Cache Model

@Model
final class CachedAccessEvent {
    @Attribute(.unique) var id: String
    var doorId: String
    var doorName: String
    var timestamp: Date
    var resultRaw: String
    var methodRaw: String
    var reason: String?

    init(from event: AccessEvent) {
        self.id = event.id
        self.doorId = event.doorId
        self.doorName = event.doorName
        self.timestamp = event.timestamp
        self.resultRaw = event.result.rawValue
        self.methodRaw = event.method.rawValue
        self.reason = event.reason
    }

    func toAccessEvent() -> AccessEvent {
        AccessEvent(
            id: id,
            doorId: doorId,
            doorName: doorName,
            timestamp: timestamp,
            result: AccessResult(rawValue: resultRaw) ?? .denied,
            method: AccessMethod(rawValue: methodRaw) ?? .ble,
            reason: reason
        )
    }
}
