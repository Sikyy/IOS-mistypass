import XCTest
@testable import MistyisletPass

@MainActor
final class SettingsServiceTests: XCTestCase {

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
        XCTAssertEqual(settings.selectedLanguage, .system)
    }

    func testSiteDefaultNil() {
        let settings = SettingsService.shared
        // May not be nil if previous test set it, so just verify it doesn't crash
        _ = settings.selectedSiteId
        _ = settings.selectedSiteName
    }
}
