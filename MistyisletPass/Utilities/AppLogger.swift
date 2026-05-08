import Foundation
import os

enum AppLogger {
    static let auth = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mistyislet.pass", category: "auth")
    static let ble = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mistyislet.pass", category: "ble")
    static let api = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mistyislet.pass", category: "api")
    static let nfc = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mistyislet.pass", category: "nfc")
    static let push = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mistyislet.pass", category: "push")
    static let geofence = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mistyislet.pass", category: "geofence")
}
