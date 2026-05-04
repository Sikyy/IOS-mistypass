import XCTest
@testable import MistyisletPass

final class ModelDecodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Door

    func testDecodeDoor() throws {
        let json = """
        {
            "id": "door-001",
            "name": "Main Entrance",
            "building": "Lobby",
            "floor": "Floor 1",
            "gateway_online": true,
            "controller_online": true,
            "has_permission": true
        }
        """.data(using: .utf8)!

        let door = try decoder.decode(Door.self, from: json)
        XCTAssertEqual(door.id, "door-001")
        XCTAssertEqual(door.name, "Main Entrance")
        XCTAssertTrue(door.gatewayOnline)
        XCTAssertTrue(door.controllerOnline)
        XCTAssertTrue(door.hasPermission)
        XCTAssertTrue(door.canUnlock)
        XCTAssertEqual(door.statusDescription, "Online")
    }

    func testDoorOfflineStatus() throws {
        let json = """
        {
            "id": "door-002",
            "name": "Server Room",
            "building": "DC",
            "floor": "B2",
            "gateway_online": true,
            "controller_online": false,
            "has_permission": true
        }
        """.data(using: .utf8)!

        let door = try decoder.decode(Door.self, from: json)
        XCTAssertFalse(door.canUnlock)
        XCTAssertEqual(door.statusDescription, "Controller offline")
    }

    // MARK: - AccessEvent

    func testDecodeAccessEvent() throws {
        let json = """
        {
            "id": "evt-001",
            "door_id": "door-001",
            "door_name": "Main Entrance",
            "timestamp": "2026-05-03T10:23:00Z",
            "result": "granted",
            "method": "ble",
            "reason": null
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(AccessEvent.self, from: json)
        XCTAssertEqual(event.id, "evt-001")
        XCTAssertEqual(event.result, .granted)
        XCTAssertEqual(event.method, .ble)
        XCTAssertNil(event.reason)
    }

    func testDecodeAccessEventDenied() throws {
        let json = """
        {
            "id": "evt-002",
            "door_id": "door-002",
            "door_name": "Server Room",
            "timestamp": "2026-05-03T08:14:00Z",
            "result": "denied",
            "method": "ble",
            "reason": "No permission"
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(AccessEvent.self, from: json)
        XCTAssertEqual(event.result, .denied)
        XCTAssertEqual(event.reason, "No permission")
    }

    // MARK: - Credential

    func testDecodeCredential() throws {
        let json = """
        {
            "id": "cred-001",
            "device_name": "iPhone 17 Pro",
            "public_key_fingerprint": "SHA256:abc123",
            "created_at": "2026-04-01T00:00:00Z",
            "expires_at": "2026-07-01T00:00:00Z",
            "is_active": true
        }
        """.data(using: .utf8)!

        let credential = try decoder.decode(Credential.self, from: json)
        XCTAssertEqual(credential.deviceName, "iPhone 17 Pro")
        XCTAssertTrue(credential.isActive)
        XCTAssertFalse(credential.isExpired)
    }

    // MARK: - Visitor

    func testDecodeVisitor() throws {
        let json = """
        {
            "id": "vis-001",
            "name": "John Doe",
            "phone": "+62812345678",
            "host_name": "Ahmad",
            "company": "Acme Corp",
            "purpose": "Meeting",
            "door_ids": ["door-001"],
            "door_names": ["Main Entrance"],
            "access_token": "token-abc",
            "created_at": "2026-05-03T00:00:00Z",
            "expires_at": "2026-05-04T00:00:00Z",
            "is_active": true
        }
        """.data(using: .utf8)!

        let visitor = try decoder.decode(Visitor.self, from: json)
        XCTAssertEqual(visitor.name, "John Doe")
        XCTAssertEqual(visitor.hostName, "Ahmad")
        XCTAssertEqual(visitor.doorIds.count, 1)
        XCTAssertTrue(visitor.isActive)
    }

    // MARK: - LoginResponse

    func testDecodeLoginResponse() throws {
        let json = """
        {
            "tokens": {
                "access_token": "eyJ...",
                "refresh_token": "eyR...",
                "expires_in": 3600
            },
            "user": {
                "id": "user-001",
                "email": "test@example.com",
                "name": "Test User",
                "role": "Employee",
                "building": "Jakarta HQ",
                "tenant_id": "tenant-001"
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(LoginResponse.self, from: json)
        XCTAssertEqual(response.tokens.accessToken, "eyJ...")
        XCTAssertEqual(response.tokens.expiresIn, 3600)
        XCTAssertEqual(response.user.email, "test@example.com")
    }

    // MARK: - Site

    func testDecodeSite() throws {
        let json = """
        {
            "id": "site-001",
            "name": "Jakarta HQ",
            "address": "Jl. Sudirman No. 1",
            "building_count": 3
        }
        """.data(using: .utf8)!

        let site = try decoder.decode(Site.self, from: json)
        XCTAssertEqual(site.name, "Jakarta HQ")
        XCTAssertEqual(site.buildingCount, 3)
    }
}
