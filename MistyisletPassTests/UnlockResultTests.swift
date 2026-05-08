import XCTest
@testable import MistyisletPass

final class UnlockResultTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - UnlockState Equatable

    func testIdleEquals() {
        XCTAssertEqual(UnlockState.idle, UnlockState.idle)
    }

    func testHoldingEqualsWithSameProgress() {
        XCTAssertEqual(UnlockState.holding(progress: 0.5), UnlockState.holding(progress: 0.5))
    }

    func testHoldingNotEqualsDifferentProgress() {
        XCTAssertNotEqual(UnlockState.holding(progress: 0.3), UnlockState.holding(progress: 0.7))
    }

    func testConnectingEquals() {
        XCTAssertEqual(UnlockState.connecting, UnlockState.connecting)
    }

    func testGrantedEquals() {
        XCTAssertEqual(
            UnlockState.granted(doorName: "Main"),
            UnlockState.granted(doorName: "Main")
        )
    }

    func testGrantedNotEqualsDifferentDoor() {
        XCTAssertNotEqual(
            UnlockState.granted(doorName: "Main"),
            UnlockState.granted(doorName: "Back")
        )
    }

    func testDifferentStatesNotEqual() {
        XCTAssertNotEqual(UnlockState.idle, UnlockState.connecting)
        XCTAssertNotEqual(UnlockState.idle, UnlockState.holding(progress: 0))
    }

    // MARK: - RemoteUnlockResponse

    func testDecodeGrantResponse() throws {
        let json = """
        {
            "decision": "grant",
            "reason": null,
            "lock_id": "lock-001",
            "lock_name": "Main Entrance",
            "request_id": "req-abc",
            "dispatched": true
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RemoteUnlockResponse.self, from: json)
        XCTAssertTrue(response.isGranted)
        XCTAssertEqual(response.lockId, "lock-001")
        XCTAssertEqual(response.lockName, "Main Entrance")
        XCTAssertTrue(response.dispatched ?? false)
    }

    func testDecodeAllowResponse() throws {
        let json = """
        {
            "decision": "allow",
            "lock_id": "lock-002"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RemoteUnlockResponse.self, from: json)
        XCTAssertTrue(response.isGranted)
    }

    func testDecodeDenyResponse() throws {
        let json = """
        {
            "decision": "deny",
            "reason": "No permission",
            "lock_id": "lock-003"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RemoteUnlockResponse.self, from: json)
        XCTAssertFalse(response.isGranted)
        XCTAssertEqual(response.reason, "No permission")
    }

    // MARK: - DoorSortOrder

    func testSortOrderCases() {
        let orders: [DoorSortOrder] = [.name, .status, .building]
        XCTAssertEqual(orders.count, 3)
    }
}
