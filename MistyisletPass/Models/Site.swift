import Foundation

struct Site: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let buildingCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case buildingCount = "building_count"
    }
}
