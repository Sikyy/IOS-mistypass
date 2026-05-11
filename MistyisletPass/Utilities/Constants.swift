import Foundation
import CoreBluetooth

enum Constants {
    // MARK: - Environment
    /// App environment. Resolves base URL from `APP_ENV` Info.plist key (set per
    /// scheme) or falls back to production. Mirrors Android build variants.
    enum AppEnvironment: String {
        case mock, dev, staging, production

        var baseURL: String {
            switch self {
            case .mock: return "http://localhost:4010/api/v1"
            case .dev: return "http://localhost:8080/api/v1"
            case .staging: return "https://staging-api.mistyislet.com/api/v1"
            case .production: return "https://api.mistyislet.com/api/v1"
            }
        }

        static let current: AppEnvironment = {
            let raw = (Bundle.main.object(forInfoDictionaryKey: "APP_ENV") as? String)
                ?? ProcessInfo.processInfo.environment["APP_ENV"]
                ?? ""
            return AppEnvironment(rawValue: raw.lowercased()) ?? .production
        }()

        static let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // MARK: - API
    /// Endpoint paths must match `api/internal/http/router.go` (mobile routes
    /// nested under `/app`, mounted at `/api/v1` on the backend).
    enum API {
        static var baseURL: String { AppEnvironment.current.baseURL }

        // Auth (mobile routes under /app/auth)
        static let loginPath = "/app/auth/login"
        static let refreshPath = "/app/auth/refresh"
        static let magicLinkPath = "/app/auth/magic-link"
        static let magicLinkVerifyPath = "/app/auth/magic-link/verify"
        static let orgLookupPath = "/app/auth/org-lookup"
        static let restorePasswordPath = "/app/auth/restore-password"

        // User
        static let mePath = "/app/me"

        // Legacy flat endpoints (still supported by backend)
        static let doorsPath = "/app/access/my-doors"
        static let unlockPath = "/app/access/unlock"
        static let qrUnlockPath = "/app/access/qr-unlock"
        static let bleTokenPath = "/app/access/ble-token"
        static let logsPath = "/app/access/logs"
        static let pinCodePath = "/app/access/pin-code"

        // Org / Place hierarchy (matches Android navigation)
        static let orgsPath = "/app/orgs"
        static func switchOrgPath(_ orgId: String) -> String { "/app/orgs/\(orgId)/switch" }
        static func placesPath(_ orgId: String) -> String { "/app/orgs/\(orgId)/places" }
        static func placesSearchPath(_ orgId: String) -> String { "/app/orgs/\(orgId)/places/search" }
        static func placeDoorsPath(_ placeId: String) -> String { "/app/places/\(placeId)/doors" }
        static func placeDoorsSearchPath(_ placeId: String) -> String { "/app/places/\(placeId)/doors/search" }
        static func placeUnlockPath(_ placeId: String, _ doorId: String) -> String {
            "/app/places/\(placeId)/doors/\(doorId)/unlock"
        }
        static func placeFavoriteDoorPath(_ placeId: String, _ doorId: String) -> String {
            "/app/places/\(placeId)/doors/\(doorId)/favorite"
        }
        static func placeLockdownPath(_ placeId: String) -> String { "/app/places/\(placeId)/lockdown" }
        static func doorLockdownPath(_ placeId: String, _ doorId: String) -> String {
            "/app/places/\(placeId)/doors/\(doorId)/lockdown"
        }
        static func doorRestrictionsPath(_ placeId: String, _ doorId: String) -> String {
            "/app/places/\(placeId)/doors/\(doorId)/restrictions"
        }
        static func doorSchedulesPath(_ placeId: String, _ doorId: String) -> String {
            "/app/places/\(placeId)/doors/\(doorId)/schedules"
        }

        // Schedule CRUD
        static func adminSchedulePath(_ placeId: String, _ scheduleId: String) -> String {
            "/app/places/\(placeId)/schedules/\(scheduleId)"
        }

        // Admin (place-scoped)
        static func adminUsersPath(_ placeId: String) -> String { "/app/places/\(placeId)/users" }
        static func adminEventsPath(_ placeId: String) -> String { "/app/places/\(placeId)/events" }
        static func adminIncidentsPath(_ placeId: String) -> String { "/app/places/\(placeId)/incidents" }
        static func adminActivityPath(_ placeId: String) -> String { "/app/places/\(placeId)/activity" }
        static func adminSchedulesPath(_ placeId: String) -> String { "/app/places/\(placeId)/schedules" }
        static func adminZonesPath(_ placeId: String) -> String { "/app/places/\(placeId)/zones" }
        static func adminCardsPath(_ placeId: String) -> String { "/app/places/\(placeId)/cards" }
        static func adminCardUnassignPath(_ placeId: String, _ cardUid: String) -> String { "/app/places/\(placeId)/cards/\(cardUid)" }
        static func adminCredentialsPath(_ placeId: String) -> String { "/app/places/\(placeId)/credentials" }
        static func adminCredentialSearchPath(_ placeId: String) -> String { "/app/places/\(placeId)/credentials/search" }
        static func adminCredentialPath(_ placeId: String, _ credId: String) -> String { "/app/places/\(placeId)/credentials/\(credId)" }
        static func walletPassSuspendPath(_ passId: String) -> String { "/wallet/passes/\(passId)/suspend" }
        static func walletPassActivatePath(_ passId: String) -> String { "/wallet/passes/\(passId)/activate" }
        static func walletPassRevokePath(_ passId: String) -> String { "/wallet/passes/\(passId)/revoke" }
        static func adminTeamsPath(_ placeId: String) -> String { "/app/places/\(placeId)/teams" }

        // User management
        static func adminUserPath(_ placeId: String, _ userId: String) -> String { "/app/places/\(placeId)/users/\(userId)" }
        static func adminUserRolePath(_ placeId: String, _ userId: String) -> String { "/app/places/\(placeId)/users/\(userId)/role" }
        static func adminUserSignOutPath(_ placeId: String, _ userId: String) -> String { "/app/places/\(placeId)/users/\(userId)/sign-out" }
        static func adminInviteUserPath(_ placeId: String) -> String { "/app/places/\(placeId)/users/invite" }

        // Groups
        static func adminGroupsPath(_ placeId: String) -> String { "/app/places/\(placeId)/groups" }
        static func adminGroupPath(_ placeId: String, _ groupId: String) -> String { "/app/places/\(placeId)/groups/\(groupId)" }
        static func adminGroupMembersPath(_ placeId: String, _ groupId: String) -> String { "/app/places/\(placeId)/groups/\(groupId)/members" }
        static func adminGroupDoorsPath(_ placeId: String, _ groupId: String) -> String { "/app/places/\(placeId)/groups/\(groupId)/doors" }

        // Team management
        static func adminTeamPath(_ placeId: String, _ teamId: String) -> String { "/app/places/\(placeId)/teams/\(teamId)" }
        static func adminTeamMembersPath(_ placeId: String, _ teamId: String) -> String { "/app/places/\(placeId)/teams/\(teamId)/members" }
        static func adminTeamAccessPath(_ placeId: String, _ teamId: String) -> String { "/app/places/\(placeId)/teams/\(teamId)/access-rights" }

        // Organization settings
        static func orgSettingsPath(_ orgId: String) -> String { "/app/orgs/\(orgId)/settings" }

        // Place management
        static func placeSettingsPath(_ placeId: String) -> String { "/app/places/\(placeId)/settings" }

        // Analytics & Reports (place-scoped)
        static func analyticsSummaryPath(_ placeId: String) -> String { "/app/places/\(placeId)/analytics/summary" }
        static func userPresencePath(_ placeId: String) -> String { "/app/places/\(placeId)/analytics/presence" }
        static func reportExportPath(_ placeId: String) -> String { "/app/places/\(placeId)/reports/export" }

        // Profile
        static let avatarPath = "/app/me/avatar"
        static let changePasswordPath = "/app/me/change-password"
        static let myLoginsPath = "/app/me/logins"

        // Visitor passes
        static let visitorPassesPath = "/app/visitor-passes"
        static func visitorGroupsPath(_ placeId: String) -> String { "/app/places/\(placeId)/visitor-groups" }
        static func visitorGroupPath(_ placeId: String, _ groupId: String) -> String { "/app/places/\(placeId)/visitor-groups/\(groupId)" }
        static func visitorGroupMembersPath(_ placeId: String, _ groupId: String) -> String { "/app/places/\(placeId)/visitor-groups/\(groupId)/members" }
        static func visitorGroupCleanupPath(_ placeId: String, _ groupId: String) -> String { "/app/places/\(placeId)/visitor-groups/\(groupId)/cleanup-expired" }

        // Guests (admin-scoped)
        static let guestsPath = "/guests"
        static func guestPath(_ guestId: String) -> String { "/guests/\(guestId)" }
        static func guestStatusPath(_ guestId: String) -> String { "/guests/\(guestId)/status" }

        // Mobile credentials
        static let credentialsPath = "/app/credentials"
        static let mobileCredentialRegisterPath = "/app/credentials/register"
        static let mobileCredentialsPath = "/app/credentials/mobile"
        static let primaryDevicePath = "/app/me/primary-device"
        static let apnsDevicePath = "/app/devices/apns"
        static let nfcCredentialPath = "/app/credentials/nfc"
        static let qrTokenPath = "/app/qr-token"

        // Hardware rename
        static func doorRenamePath(_ placeId: String, _ doorId: String) -> String {
            "/app/places/\(placeId)/doors/\(doorId)"
        }
        static func gatewayRenamePath(_ gatewayId: String) -> String { "/app/gateways/\(gatewayId)" }
        static func cameraRenamePath(_ cameraId: String) -> String { "/app/cameras/\(cameraId)" }

        // Alarms
        static let alarmsPath = "/app/alarms"
        static let alarmsStreamPath = "/app/alarms/stream"
        static func alarmStatusPath(_ alarmId: String) -> String { "/app/alarms/\(alarmId)/status" }
        static let alarmSchedulesPath = "/app/alarm-schedules"
        static let alarmCalendarPath = "/app/alarm-schedules/calendar"

        // Activity
        static func activityPath(_ placeId: String) -> String { "/app/places/\(placeId)/activity" }

        // Bookings
        static let bookableSpacesPath = "/app/bookable-spaces"
        static func bookableSpaceStatusPath(_ spaceId: String) -> String { "/app/bookable-spaces/\(spaceId)/status" }
        static let bookingsPath = "/app/bookings"
        static func cancelBookingPath(_ bookingId: String) -> String { "/app/bookings/\(bookingId)/cancel" }
        static func checkInBookingPath(_ bookingId: String) -> String { "/app/bookings/\(bookingId)/check-in" }
        static func checkOutBookingPath(_ bookingId: String) -> String { "/app/bookings/\(bookingId)/check-out" }

        // Cameras / Monitoring
        static let camerasPath = "/app/cameras"
        static func cameraVideoLinkPath(_ cameraId: String) -> String { "/app/cameras/\(cameraId)/video-link" }
        static func cameraSnapshotPath(_ cameraId: String) -> String { "/app/cameras/\(cameraId)/snapshot" }
        static func eventMediaPath(_ placeId: String, _ eventId: String) -> String {
            "/app/places/\(placeId)/events/\(eventId)/media"
        }
    }

    // MARK: - BLE
    /// GATT UUIDs are derived from ASCII strings to keep the protocol identifiable
    /// across platforms. Each segment encodes 6 ASCII chars (12 hex digits).
    /// Canonical source: `api/cmd/gateway-agent/ble_protocol.go`.
    enum BLE {
        /// Service UUID: "MISTYPASS-BLEAUT"
        nonisolated(unsafe) static let serviceUUID = CBUUID(string: "4D495354-5950-4153-532D-424C45415554")

        // GATT Characteristics — must match Go backend and Android exactly.
        /// "MISTYPASS-CHALLN"
        nonisolated(unsafe) static let challengeUUID = CBUUID(string: "4D495354-5950-4153-532D-4348414C4C4E")
        /// "MISTYPASS-AUTHRE"
        nonisolated(unsafe) static let authResponseUUID = CBUUID(string: "4D495354-5950-4153-532D-415554485245")
        /// "MISTYPASS-READER"
        nonisolated(unsafe) static let readerIdentityUUID = CBUUID(string: "4D495354-5950-4153-532D-524541444552")
        /// "MISTYPASS-RESULT"
        nonisolated(unsafe) static let authResultUUID = CBUUID(string: "4D495354-5950-4153-532D-524553554C54")

        static let connectionTimeout: TimeInterval = 8.0
        static let scanDebounceDuration: TimeInterval = 3.0

        /// BLE auth result codes (must match `BLEResult*` in ble_protocol.go)
        static let resultGranted: UInt8 = 0x01
        static let resultDenied: UInt8 = 0x02
    }

    // MARK: - Keychain
    enum Keychain {
        static let accessTokenKey = "com.mistyislet.accessToken"
        static let refreshTokenKey = "com.mistyislet.refreshToken"
        static let credentialTag = "com.mistyislet.credential"
    }

    // MARK: - UI
    enum UI {
        static let unlockHoldDuration: TimeInterval = 0.5
        static let unlockOverlayDismissDelay: TimeInterval = 2.0
        static let qrScanDebounce: TimeInterval = 3.0
        static let minimumTouchTarget: CGFloat = 44.0
    }

    // MARK: - Cache
    enum Cache {
        static let offlineMaxAge: TimeInterval = 72 * 3600 // 72 hours
    }
}
