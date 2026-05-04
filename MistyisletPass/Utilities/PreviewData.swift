import Foundation

#if DEBUG
enum PreviewData {

    // MARK: - Doors

    static let doors: [Door] = [
        Door(
            id: "door-001",
            name: "Main Entrance",
            building: "Lobby",
            floor: "Floor 1",
            gatewayOnline: true,
            controllerOnline: true,
            hasPermission: true
        ),
        Door(
            id: "door-002",
            name: "Server Room",
            building: "Data Center",
            floor: "B2",
            gatewayOnline: true,
            controllerOnline: false,
            hasPermission: true
        ),
        Door(
            id: "door-003",
            name: "Parking Gate",
            building: "Parking",
            floor: "G",
            gatewayOnline: false,
            controllerOnline: true,
            hasPermission: true
        ),
        Door(
            id: "door-004",
            name: "Meeting Room A",
            building: "Office",
            floor: "Floor 3",
            gatewayOnline: true,
            controllerOnline: true,
            hasPermission: true
        ),
        Door(
            id: "door-005",
            name: "Executive Suite",
            building: "Office",
            floor: "Floor 5",
            gatewayOnline: true,
            controllerOnline: true,
            hasPermission: false
        ),
    ]

    // MARK: - Access Events

    static let events: [AccessEvent] = [
        AccessEvent(
            id: "evt-001",
            doorId: "door-001",
            doorName: "Main Entrance",
            timestamp: Date(),
            result: .granted,
            method: .ble,
            reason: nil
        ),
        AccessEvent(
            id: "evt-002",
            doorId: "door-003",
            doorName: "Parking Gate",
            timestamp: Date().addingTimeInterval(-3600),
            result: .granted,
            method: .qr,
            reason: nil
        ),
        AccessEvent(
            id: "evt-003",
            doorId: "door-002",
            doorName: "Server Room",
            timestamp: Date().addingTimeInterval(-7200),
            result: .denied,
            method: .ble,
            reason: "No permission"
        ),
        AccessEvent(
            id: "evt-004",
            doorId: "door-001",
            doorName: "Main Entrance",
            timestamp: Date().addingTimeInterval(-86400),
            result: .granted,
            method: .remote,
            reason: nil
        ),
        AccessEvent(
            id: "evt-005",
            doorId: "door-001",
            doorName: "Main Entrance",
            timestamp: Date().addingTimeInterval(-90000),
            result: .granted,
            method: .ble,
            reason: nil
        ),
    ]

    // MARK: - Credentials

    static let credentials: [Credential] = [
        Credential(
            id: "cred-001",
            deviceName: "iPhone 17 Pro",
            publicKeyFingerprint: "SHA256:a3b4c5d6e7f8...",
            createdAt: Date().addingTimeInterval(-2592000),
            expiresAt: Date().addingTimeInterval(5184000),
            isActive: true
        ),
    ]

    // MARK: - Visitors

    static let visitors: [Visitor] = [
        Visitor(
            id: "vis-001",
            name: "John Doe",
            phone: "+62812345678",
            hostName: "Ahmad",
            company: "Acme Corp",
            purpose: "Meeting",
            doorIds: ["door-001", "door-004"],
            doorNames: ["Main Entrance", "Meeting Room A"],
            accessToken: "eyJhbGciOiJFUzI1NiJ9.preview-token-001",
            createdAt: Date().addingTimeInterval(-3600),
            expiresAt: Date().addingTimeInterval(79200),
            isActive: true
        ),
        Visitor(
            id: "vis-002",
            name: "Jane Smith",
            phone: "+62898765432",
            hostName: "Budi",
            company: "Tech Inc",
            purpose: "Interview",
            doorIds: ["door-001"],
            doorNames: ["Main Entrance"],
            accessToken: "eyJhbGciOiJFUzI1NiJ9.preview-token-002",
            createdAt: Date().addingTimeInterval(-172800),
            expiresAt: Date().addingTimeInterval(-3600),
            isActive: false
        ),
    ]

    // MARK: - User Profile

    static let userProfile = UserProfile(
        id: "user-001",
        email: "ahmad@example.com",
        name: "Ahmad Wijaya",
        role: "Employee",
        building: "Jakarta HQ",
        tenantId: "tenant-001"
    )
}
#endif
