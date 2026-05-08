import Foundation
import SwiftUI

/// Centralized app settings backed by UserDefaults.
/// Uses stored properties with didSet for @Observable tracking.
@MainActor @Observable
final class SettingsService {
    static let shared = SettingsService()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let biometricEnabled = "settings.biometricEnabled"
        static let selectedLanguage = "settings.language"
        static let selectedOrgId = "settings.selectedOrgId"
        static let selectedOrgName = "settings.selectedOrgName"
        static let selectedPlaceId = "settings.selectedPlaceId"
        static let selectedPlaceName = "settings.selectedPlaceName"
        static let hapticEnabled = "settings.hapticEnabled"
        static let autoScreenBrightness = "settings.autoScreenBrightness"
        static let geofenceEnabled = "settings.geofenceEnabled"
    }

    // MARK: - Stored Properties (Observable-tracked)

    var biometricEnabled: Bool {
        didSet { defaults.set(biometricEnabled, forKey: Keys.biometricEnabled) }
    }

    var selectedLanguage: AppLanguage {
        didSet {
            defaults.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage)
            _localizedBundle = selectedLanguage.bundle
        }
    }

    var selectedOrgId: String? {
        didSet { defaults.set(selectedOrgId, forKey: Keys.selectedOrgId) }
    }

    var selectedOrgName: String? {
        didSet { defaults.set(selectedOrgName, forKey: Keys.selectedOrgName) }
    }

    var selectedPlaceId: String? {
        didSet { defaults.set(selectedPlaceId, forKey: Keys.selectedPlaceId) }
    }

    var selectedPlaceName: String? {
        didSet { defaults.set(selectedPlaceName, forKey: Keys.selectedPlaceName) }
    }

    var hapticEnabled: Bool {
        didSet { defaults.set(hapticEnabled, forKey: Keys.hapticEnabled) }
    }

    var autoScreenBrightness: Bool {
        didSet { defaults.set(autoScreenBrightness, forKey: Keys.autoScreenBrightness) }
    }

    var geofenceEnabled: Bool {
        didSet { defaults.set(geofenceEnabled, forKey: Keys.geofenceEnabled) }
    }

    // MARK: - Runtime Localization

    /// Cached bundle for the current language. Updated whenever
    /// `selectedLanguage` changes, triggering Observable re-renders.
    private(set) var _localizedBundle: Bundle = .main

    /// Resolve a localization key using the currently selected language.
    /// Because this reads `_localizedBundle` (an Observable property),
    /// any SwiftUI view calling `settings.L(...)` in its body
    /// automatically re-renders when the language changes.
    func L(_ key: String) -> String {
        _localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    // MARK: - Init (load from UserDefaults)

    private init() {
        let defaults = UserDefaults.standard
        self.biometricEnabled = defaults.object(forKey: Keys.biometricEnabled) as? Bool ?? true
        self.hapticEnabled = defaults.object(forKey: Keys.hapticEnabled) as? Bool ?? true
        self.autoScreenBrightness = defaults.object(forKey: Keys.autoScreenBrightness) as? Bool ?? true
        self.geofenceEnabled = defaults.object(forKey: Keys.geofenceEnabled) as? Bool ?? false
        self.selectedOrgId = defaults.string(forKey: Keys.selectedOrgId)
        self.selectedOrgName = defaults.string(forKey: Keys.selectedOrgName)
        self.selectedPlaceId = defaults.string(forKey: Keys.selectedPlaceId)
        self.selectedPlaceName = defaults.string(forKey: Keys.selectedPlaceName)

        if let raw = defaults.string(forKey: Keys.selectedLanguage),
           let lang = AppLanguage(rawValue: raw) {
            self.selectedLanguage = lang
            self._localizedBundle = lang.bundle
        } else {
            self.selectedLanguage = .english
            self._localizedBundle = AppLanguage.english.bundle
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"
    case indonesian = "id"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        case .indonesian: return "Bahasa Indonesia"
        }
    }

    /// Returns the .lproj Bundle for this language, falling back to main.
    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
