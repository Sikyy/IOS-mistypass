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
        static let selectedSiteId = "settings.selectedSiteId"
        static let selectedSiteName = "settings.selectedSiteName"
        static let hapticEnabled = "settings.hapticEnabled"
        static let autoScreenBrightness = "settings.autoScreenBrightness"
    }

    // MARK: - Stored Properties (Observable-tracked)

    var biometricEnabled: Bool {
        didSet { defaults.set(biometricEnabled, forKey: Keys.biometricEnabled) }
    }

    var selectedLanguage: AppLanguage {
        didSet {
            defaults.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage)
            applyLanguage(selectedLanguage)
        }
    }

    var selectedSiteId: String? {
        didSet { defaults.set(selectedSiteId, forKey: Keys.selectedSiteId) }
    }

    var selectedSiteName: String? {
        didSet { defaults.set(selectedSiteName, forKey: Keys.selectedSiteName) }
    }

    var hapticEnabled: Bool {
        didSet { defaults.set(hapticEnabled, forKey: Keys.hapticEnabled) }
    }

    var autoScreenBrightness: Bool {
        didSet { defaults.set(autoScreenBrightness, forKey: Keys.autoScreenBrightness) }
    }

    // MARK: - Init (load from UserDefaults)

    private init() {
        let defaults = UserDefaults.standard
        self.biometricEnabled = defaults.object(forKey: Keys.biometricEnabled) as? Bool ?? true
        self.hapticEnabled = defaults.object(forKey: Keys.hapticEnabled) as? Bool ?? true
        self.autoScreenBrightness = defaults.object(forKey: Keys.autoScreenBrightness) as? Bool ?? true
        self.selectedSiteId = defaults.string(forKey: Keys.selectedSiteId)
        self.selectedSiteName = defaults.string(forKey: Keys.selectedSiteName)

        if let raw = defaults.string(forKey: Keys.selectedLanguage),
           let lang = AppLanguage(rawValue: raw) {
            self.selectedLanguage = lang
        } else {
            self.selectedLanguage = .system
        }
    }

    // MARK: - Language Helper

    private func applyLanguage(_ language: AppLanguage) {
        switch language {
        case .system:
            defaults.removeObject(forKey: "AppleLanguages")
        case .english:
            defaults.set(["en"], forKey: "AppleLanguages")
        case .indonesian:
            defaults.set(["id"], forKey: "AppleLanguages")
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case indonesian = "id"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .indonesian: return "Bahasa Indonesia"
        }
    }
}
