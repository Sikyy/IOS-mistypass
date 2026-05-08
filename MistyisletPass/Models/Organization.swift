import Foundation

struct Organization: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let domain: String?
    let logo: String?
    let role: String?
    let lastUsedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, domain, logo, role
        case lastUsedAt = "last_used_at"
    }
}
