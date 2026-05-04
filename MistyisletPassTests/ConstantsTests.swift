import XCTest
import CoreBluetooth
@testable import MistyisletPass

final class ConstantsTests: XCTestCase {

    func testBLEServiceUUID() {
        let uuid = Constants.BLE.serviceUUID
        XCTAssertEqual(uuid.uuidString, "4D495354-5950-4153-532D-424C45415554")
    }

    func testBLEResultCodes() {
        XCTAssertEqual(Constants.BLE.resultGranted, 0x01)
        XCTAssertEqual(Constants.BLE.resultDenied, 0x02)
    }

    func testConnectionTimeout() {
        XCTAssertEqual(Constants.BLE.connectionTimeout, 5.0)
    }

    func testHoldDuration() {
        XCTAssertEqual(Constants.UI.unlockHoldDuration, 0.5)
    }

    func testOfflineMaxAge() {
        XCTAssertEqual(Constants.Cache.offlineMaxAge, 72 * 3600)
    }

    func testMinimumTouchTarget() {
        XCTAssertGreaterThanOrEqual(Constants.UI.minimumTouchTarget, 44.0)
    }
}
