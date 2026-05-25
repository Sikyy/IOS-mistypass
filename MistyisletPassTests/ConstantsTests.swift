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
        XCTAssertEqual(Constants.BLE.connectionTimeout, 8.0)
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

    func testAppEnvironmentPrefersSchemeEnvironment() {
        XCTAssertEqual(
            Constants.AppEnvironment.resolve(environmentValue: "staging", infoValue: "dev"),
            .staging
        )
    }

    func testAppEnvironmentFallsBackToInfoPlist() {
        XCTAssertEqual(
            Constants.AppEnvironment.resolve(environmentValue: nil, infoValue: "dev"),
            .dev
        )
    }

    func testStagingBaseURL() {
        XCTAssertEqual(Constants.AppEnvironment.staging.baseURL, "https://staging-api.mistyislet.com/api/v1")
    }

    func testAdminDeepRoutePaths() {
        XCTAssertEqual(Constants.API.adminEventPath("place-001", "evt-001"), "/app/places/place-001/events/evt-001")
        XCTAssertEqual(Constants.API.adminEventRelatedPath("place-001", "evt-001"), "/app/places/place-001/events/evt-001/related")
        XCTAssertEqual(Constants.API.adminIncidentPath("place-001", "inc-001"), "/app/places/place-001/incidents/inc-001")
        XCTAssertEqual(Constants.API.adminIncidentOccurrencesPath("place-001", "inc-001"), "/app/places/place-001/incidents/inc-001/occurrences")
    }

    func testAdminUserDetailRoutePaths() {
        XCTAssertEqual(Constants.API.adminUsersPath("place-001"), "/app/places/place-001/users")
        XCTAssertEqual(Constants.API.adminUserPath("place-001", "user-001"), "/app/places/place-001/users/user-001")
        XCTAssertEqual(Constants.API.adminUserLoginsPath("place-001", "user-001"), "/app/places/place-001/users/user-001/logins")
        XCTAssertEqual(Constants.API.adminUserAccessRightsPath("place-001", "user-001"), "/app/places/place-001/users/user-001/access-rights")
        XCTAssertEqual(Constants.API.adminUserShareAccessPath("place-001", "user-001"), "/app/places/place-001/users/user-001/share-access")
    }

    func testAdminZoneRoutePaths() {
        XCTAssertEqual(Constants.API.adminZonePath("place-001", "zone-001"), "/app/places/place-001/zones/zone-001")
        XCTAssertEqual(Constants.API.adminZoneHolidayRegionsPath("place-001", "zone-001"), "/app/places/place-001/holiday-regions")
    }

    func testCameraCloudRoutePaths() {
        XCTAssertEqual(Constants.API.cameraCloudTokenPath("cam-001"), "/app/cameras/cam-001/cloud-token")
        XCTAssertEqual(Constants.API.cameraRecordingsPath("cam-001"), "/app/cameras/cam-001/cloud-recordings")
    }
}
