import XCTest
@testable import MistyisletPass

@MainActor
final class SettingsServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        let settings = SettingsService.shared
        settings.biometricEnabled = true
        settings.hapticEnabled = true
        settings.autoScreenBrightness = true
        settings.geofenceEnabled = false
        settings.selectedLanguage = .english
        settings.selectedOrgId = nil
        settings.selectedOrgName = nil
        settings.selectedPlaceId = nil
        settings.selectedPlaceName = nil
    }

    func testBiometricDefault() {
        // Default is true on first launch
        let settings = SettingsService.shared
        XCTAssertTrue(settings.biometricEnabled)
    }

    func testHapticDefault() {
        let settings = SettingsService.shared
        XCTAssertTrue(settings.hapticEnabled)
    }

    func testAutoScreenBrightnessDefault() {
        let settings = SettingsService.shared
        XCTAssertTrue(settings.autoScreenBrightness)
    }

    func testLanguageDefault() {
        let settings = SettingsService.shared
        XCTAssertEqual(settings.selectedLanguage, .english)
    }

    func testPlaceDefaultNil() {
        let settings = SettingsService.shared
        XCTAssertNil(settings.selectedPlaceId)
        XCTAssertNil(settings.selectedPlaceName)
    }
}
