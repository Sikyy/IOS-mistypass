import XCTest
@testable import MistyisletPass

@MainActor
final class DoorsViewModelTests: XCTestCase {

    private var viewModel: DoorsViewModel!

    override func setUp() {
        super.setUp()
        viewModel = DoorsViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertTrue(viewModel.doors.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isOffline)
        XCTAssertEqual(viewModel.unlockState, .idle)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.lastSyncedAt)
    }

    // MARK: - Hold-to-Unlock State Machine

    func testStartHoldOnUnlockableDoor() {
        let door = makeDoor(controllerOnline: true, gatewayOnline: true, hasPermission: true)
        viewModel.startHoldToUnlock(door: door)
        XCTAssertEqual(viewModel.unlockState, .holding(progress: 0))
    }

    func testStartHoldOnLockedDoorDoesNothing() {
        let door = makeDoor(controllerOnline: false, gatewayOnline: true, hasPermission: true)
        viewModel.startHoldToUnlock(door: door)
        XCTAssertEqual(viewModel.unlockState, .idle)
    }

    func testStartHoldOnNoPermissionDoesNothing() {
        let door = makeDoor(controllerOnline: true, gatewayOnline: true, hasPermission: false)
        viewModel.startHoldToUnlock(door: door)
        XCTAssertEqual(viewModel.unlockState, .idle)
    }

    func testUpdateHoldProgress() {
        let door = makeDoor(controllerOnline: true, gatewayOnline: true, hasPermission: true)
        viewModel.startHoldToUnlock(door: door)
        viewModel.updateHoldProgress(0.5)
        XCTAssertEqual(viewModel.unlockState, .holding(progress: 0.5))
    }

    func testUpdateHoldProgressClamps() {
        let door = makeDoor(controllerOnline: true, gatewayOnline: true, hasPermission: true)
        viewModel.startHoldToUnlock(door: door)
        viewModel.updateHoldProgress(1.5)
        XCTAssertEqual(viewModel.unlockState, .holding(progress: 1.0))
    }

    func testUpdateProgressIgnoredWhenIdle() {
        viewModel.updateHoldProgress(0.5)
        XCTAssertEqual(viewModel.unlockState, .idle)
    }

    func testCancelHold() {
        let door = makeDoor(controllerOnline: true, gatewayOnline: true, hasPermission: true)
        viewModel.startHoldToUnlock(door: door)
        viewModel.cancelHold()
        XCTAssertEqual(viewModel.unlockState, .idle)
    }

    // MARK: - Sorting

    func testSortByName() {
        viewModel.doors = [
            makeDoor(id: "d1", name: "Zebra Room"),
            makeDoor(id: "d2", name: "Alpha Room"),
            makeDoor(id: "d3", name: "Middle Room"),
        ]
        viewModel.sortOrder = .name
        let names = viewModel.sortedDoors.map(\.name)
        XCTAssertEqual(names, ["Alpha Room", "Middle Room", "Zebra Room"])
    }

    func testSortByStatusPutsOnlineFirst() {
        viewModel.doors = [
            makeDoor(id: "d1", name: "Offline A", controllerOnline: false),
            makeDoor(id: "d2", name: "Online B", controllerOnline: true),
            makeDoor(id: "d3", name: "Online A", controllerOnline: true),
        ]
        viewModel.sortOrder = .status
        let names = viewModel.sortedDoors.map(\.name)
        XCTAssertEqual(names, ["Online A", "Online B", "Offline A"])
    }

    func testSortByBuilding() {
        viewModel.doors = [
            makeDoor(id: "d1", name: "Room 1", building: "Tower B"),
            makeDoor(id: "d2", name: "Room 2", building: "Tower A"),
            makeDoor(id: "d3", name: "Room 3", building: "Tower A"),
        ]
        viewModel.sortOrder = .building
        let buildings = viewModel.sortedDoors.map(\.building)
        XCTAssertEqual(buildings, ["Tower A", "Tower A", "Tower B"])
    }

    // MARK: - BLE Ready

    func testIsBLEReadyReturnsFalseByDefault() {
        let door = makeDoor(id: "d1")
        XCTAssertFalse(viewModel.isBLEReady(for: door))
    }

    // MARK: - Helpers

    private func makeDoor(
        id: String = "door-test",
        name: String = "Test Door",
        building: String = "Main",
        floor: String = "1F",
        controllerOnline: Bool = true,
        gatewayOnline: Bool = true,
        hasPermission: Bool = true
    ) -> Door {
        let json = """
        {
            "id": "\(id)",
            "name": "\(name)",
            "building": "\(building)",
            "floor": "\(floor)",
            "gateway_online": \(gatewayOnline),
            "controller_online": \(controllerOnline),
            "has_permission": \(hasPermission)
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(Door.self, from: json)
    }
}
