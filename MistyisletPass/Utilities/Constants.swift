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
    /// Endpoint paths are sourced from generated mobile OpenAPI routes where
    /// coverage exists. Routes are mounted at `/api/v1` on the backend.
    enum API {
        static var baseURL: String { AppEnvironment.current.baseURL }

        // Auth (mobile routes under /app/auth)
        static let loginPath = MobileAPIRoutes.createAppLoginSession.path
        static let refreshPath = MobileAPIRoutes.refreshAppLoginSession.path
        static let magicLinkPath = MobileAPIRoutes.postAppAuthMagicLink.path
        static let magicLinkVerifyPath = MobileAPIRoutes.postAppAuthMagicLinkVerify.path
        static let orgLookupPath = MobileAPIRoutes.getAppAuthOrgLookup.path
        static let restorePasswordPath = MobileAPIRoutes.postAppAuthRestorePassword.path

        // User
        static let mePath = MobileAPIRoutes.fetchAppCurrentUser.path

        // Legacy flat endpoints (still supported by backend)
        static let doorsPath = MobileAPIRoutes.fetchAppAccessMyDoors.path
        static let unlockPath = MobileAPIRoutes.appUnlockDoor.path
        static let qrUnlockPath = MobileAPIRoutes.appQRUnlockDoor.path
        static let bleTokenPath = MobileAPIRoutes.fetchAppAccessBLEToken.path
        static let logsPath = MobileAPIRoutes.fetchAppAccessLogs.path
        static let pinCodePath = MobileAPIRoutes.getAppAccessPinCode.path

        // Org / Place hierarchy (matches Android navigation)
        static let orgsPath = MobileAPIRoutes.getAppOrgs.path
        static func switchOrgPath(_ orgId: String) -> String {
            MobileAPIRoutes.postAppOrgsOrgIdSwitch(orgId: orgId).path
        }
        static func placesPath(_ orgId: String) -> String {
            MobileAPIRoutes.getAppOrgsOrgIdPlaces(orgId: orgId).path
        }
        static func placesSearchPath(_ orgId: String) -> String {
            MobileAPIRoutes.getAppOrgsOrgIdPlacesSearch(orgId: orgId).path
        }
        static func placeDoorsPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdDoors(placeId: placeId).path
        }
        static func placeDoorsSearchPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdDoorsSearch(placeId: placeId).path
        }
        static func placeUnlockPath(_ placeId: String, _ doorId: String) -> String {
            MobileAPIRoutes.postAppPlacesPlaceIdDoorsDoorIdUnlock(placeId: placeId, doorId: doorId).path
        }
        static func placeFavoriteDoorPath(_ placeId: String, _ doorId: String) -> String {
            MobileAPIRoutes.putAppPlacesPlaceIdDoorsDoorIdFavorite(placeId: placeId, doorId: doorId).path
        }
        static func placeLockdownPath(_ placeId: String) -> String {
            MobileAPIRoutes.postAppPlacesPlaceIdLockdown(placeId: placeId).path
        }
        static func doorLockdownPath(_ placeId: String, _ doorId: String) -> String {
            MobileAPIRoutes.postAppPlacesPlaceIdDoorsDoorIdLockdown(placeId: placeId, doorId: doorId).path
        }
        static func doorRestrictionsPath(_ placeId: String, _ doorId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdDoorsDoorIdRestrictions(placeId: placeId, doorId: doorId).path
        }
        static func doorSchedulesPath(_ placeId: String, _ doorId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdDoorsDoorIdSchedules(placeId: placeId, doorId: doorId).path
        }

        // Schedule CRUD
        static func adminSchedulePath(_ placeId: String, _ scheduleId: String) -> String {
            MobileAPIRoutes.putAppPlacesPlaceIdSchedulesScheduleId(placeId: placeId, scheduleId: scheduleId).path
        }

        // Admin (place-scoped)
        static func adminUsersPath(_ placeId: String) -> String { "/app/places/\(placeId)/users" }
        static func adminEventsPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdEvents(placeId: placeId).path
        }
        static func adminEventPath(_ placeId: String, _ eventId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdEventsEventId(placeId: placeId, eventId: eventId).path
        }
        static func adminEventRelatedPath(_ placeId: String, _ eventId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdEventsEventIdRelated(placeId: placeId, eventId: eventId).path
        }
        static func adminIncidentsPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdIncidents(placeId: placeId).path
        }
        static func adminIncidentPath(_ placeId: String, _ incidentId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdIncidentsIncidentId(placeId: placeId, incidentId: incidentId).path
        }
        static func adminIncidentOccurrencesPath(_ placeId: String, _ incidentId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdIncidentsIncidentIdOccurrences(placeId: placeId, incidentId: incidentId).path
        }
        static func adminActivityPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdActivity(placeId: placeId).path
        }
        static func adminSchedulesPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdSchedules(placeId: placeId).path
        }
        static func adminZonesPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdZones(placeId: placeId).path
        }
        static func adminCardsPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdCards(placeId: placeId).path
        }
        static func adminCardUnassignPath(_ placeId: String, _ cardUid: String) -> String {
            MobileAPIRoutes.deleteAppPlacesPlaceIdCardsCardUid(placeId: placeId, cardUid: cardUid).path
        }
        static func adminCredentialsPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdCredentials(placeId: placeId).path
        }
        static func adminCredentialSearchPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdCredentialsSearch(placeId: placeId).path
        }
        static func adminCredentialPath(_ placeId: String, _ credId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdCredentialsCredentialId(placeId: placeId, credentialId: credId).path
        }
        private static func queryValue(_ value: String) -> String {
            value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        }

        static func walletPassSuspendPath(_ passId: String, tenantId: String) -> String {
            "/wallet/passes/\(passId)/suspend?tenant_id=\(queryValue(tenantId))"
        }
        static func walletPassActivatePath(_ passId: String, tenantId: String) -> String {
            "/wallet/passes/\(passId)/activate?tenant_id=\(queryValue(tenantId))"
        }
        static func walletPassRevokePath(_ passId: String, tenantId: String) -> String {
            "/wallet/passes/\(passId)/revoke?tenant_id=\(queryValue(tenantId))"
        }
        static func adminTeamsPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdTeams(placeId: placeId).path
        }

        // User management
        static func adminUserPath(_ placeId: String, _ userId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdUsersUserId(placeId: placeId, userId: userId).path
        }
        static func adminUserRolePath(_ placeId: String, _ userId: String) -> String {
            MobileAPIRoutes.patchAppPlacesPlaceIdUsersUserIdRole(placeId: placeId, userId: userId).path
        }
        static func adminUserSignOutPath(_ placeId: String, _ userId: String) -> String {
            MobileAPIRoutes.postAppPlacesPlaceIdUsersUserIdSignOut(placeId: placeId, userId: userId).path
        }
        static func adminInviteUserPath(_ placeId: String) -> String {
            MobileAPIRoutes.postAppPlacesPlaceIdUsersInvite(placeId: placeId).path
        }
        static func adminUserLoginsPath(_ placeId: String, _ userId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdUsersUserIdLogins(placeId: placeId, userId: userId).path
        }
        static func adminUserAccessRightsPath(_ placeId: String, _ userId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdUsersUserIdAccessRights(placeId: placeId, userId: userId).path
        }
        static func adminUserShareAccessPath(_ placeId: String, _ userId: String) -> String {
            MobileAPIRoutes.postAppPlacesPlaceIdUsersUserIdShareAccess(placeId: placeId, userId: userId).path
        }

        // Groups
        static func adminGroupsPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdGroups(placeId: placeId).path
        }
        static func adminGroupPath(_ placeId: String, _ groupId: String) -> String {
            MobileAPIRoutes.patchAppPlacesPlaceIdGroupsGroupId(placeId: placeId, groupId: groupId).path
        }
        static func adminGroupMembersPath(_ placeId: String, _ groupId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdGroupsGroupIdMembers(placeId: placeId, groupId: groupId).path
        }
        static func adminGroupDoorsPath(_ placeId: String, _ groupId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdGroupsGroupIdDoors(placeId: placeId, groupId: groupId).path
        }

        // Team management
        static func adminTeamPath(_ placeId: String, _ teamId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdTeamsTeamId(placeId: placeId, teamId: teamId).path
        }
        static func adminTeamMembersPath(_ placeId: String, _ teamId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdTeamsTeamIdMembers(placeId: placeId, teamId: teamId).path
        }
        static func adminTeamAccessPath(_ placeId: String, _ teamId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdTeamsTeamIdAccessRights(placeId: placeId, teamId: teamId).path
        }

        // Organization settings
        static func orgSettingsPath(_ orgId: String) -> String {
            MobileAPIRoutes.getAppOrgsOrgIdSettings(orgId: orgId).path
        }

        // Zones
        static func adminZonePath(_ placeId: String, _ zoneId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdZonesZoneId(placeId: placeId, zoneId: zoneId).path
        }
        static func adminZoneHolidayRegionsPath(_ placeId: String, _: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdHolidayRegions(placeId: placeId).path
        }

        // Place management
        static func placeSettingsPath(_ placeId: String) -> String {
            MobileAPIRoutes.putAppPlacesPlaceIdSettings(placeId: placeId).path
        }

        // Analytics & Reports (place-scoped)
        static func analyticsSummaryPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdAnalyticsSummary(placeId: placeId).path
        }
        static func userPresencePath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdAnalyticsPresence(placeId: placeId).path
        }
        static func reportExportPath(_ placeId: String) -> String {
            MobileAPIRoutes.postAppPlacesPlaceIdReportsExport(placeId: placeId).path
        }

        // Profile
        static let avatarPath = MobileAPIRoutes.postAppMeAvatar.path
        static let changePasswordPath = MobileAPIRoutes.postAppMeChangePassword.path
        static let myLoginsPath = MobileAPIRoutes.getAppMeLogins.path

        // Visitor passes
        static let visitorPassesPath = MobileAPIRoutes.getAppVisitorPasses.path
        static func visitorGroupsPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdVisitorGroups(placeId: placeId).path
        }
        static func visitorGroupMembersPath(_ placeId: String, _ groupId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdVisitorGroupsGroupIdMembers(placeId: placeId, groupId: groupId).path
        }
        static func visitorGroupCleanupPath(_ placeId: String, _ groupId: String) -> String {
            MobileAPIRoutes.postAppPlacesPlaceIdVisitorGroupsGroupIdCleanupExpired(placeId: placeId, groupId: groupId).path
        }

        // Guests (place-scoped)
        static func guestsPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdGuests(placeId: placeId).path
        }
        static func guestPath(_ placeId: String, _ guestId: String) -> String {
            MobileAPIRoutes.patchAppPlacesPlaceIdGuestsGuestId(placeId: placeId, guestId: guestId).path
        }

        // Mobile credentials
        static let credentialsPath = MobileAPIRoutes.fetchAppCredentials.path
        static let mobileCredentialRegisterPath = MobileAPIRoutes.registerMobileCredential.path
        static let mobileCredentialsPath = MobileAPIRoutes.listMobileCredentials.path
        static let primaryDevicePath = MobileAPIRoutes.postAppMePrimaryDevice.path
        static let apnsDevicePath = MobileAPIRoutes.postAppDevicesApns.path
        static let nfcCredentialPath = MobileAPIRoutes.getAppCredentialsNfc.path
        static let qrTokenPath = MobileAPIRoutes.postAppQrToken.path

        // Hardware rename
        static func doorRenamePath(_ placeId: String, _ doorId: String) -> String {
            MobileAPIRoutes.patchAppPlacesPlaceIdDoorsDoorId(placeId: placeId, doorId: doorId).path
        }
        static func gatewayRenamePath(_ gatewayId: String) -> String {
            MobileAPIRoutes.patchAppGatewaysGatewayId(gatewayId: gatewayId).path
        }
        static func cameraRenamePath(_ cameraId: String) -> String {
            MobileAPIRoutes.patchAppCamerasCameraId(cameraId: cameraId).path
        }

        // Alarms
        static let alarmsPath = MobileAPIRoutes.getAppAlarms.path
        static let alarmsStreamPath = MobileAPIRoutes.getAppAlarmsStream.path
        static func alarmStatusPath(_ alarmId: String) -> String {
            MobileAPIRoutes.patchAppAlarmsAlarmIDStatus(alarmID: alarmId).path
        }
        static let alarmSchedulesPath = MobileAPIRoutes.getAppAlarmSchedules.path
        static let alarmCalendarPath = MobileAPIRoutes.getAppAlarmSchedulesCalendar.path

        // Activity
        static func activityPath(_ placeId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdActivity(placeId: placeId).path
        }

        // Bookings
        static let bookableSpacesPath = MobileAPIRoutes.getAppBookableSpaces.path
        static func bookableSpaceStatusPath(_ spaceId: String) -> String {
            MobileAPIRoutes.getAppBookableSpacesSpaceIDStatus(spaceID: spaceId).path
        }
        static let bookingsPath = MobileAPIRoutes.getAppBookings.path
        static func cancelBookingPath(_ bookingId: String) -> String {
            MobileAPIRoutes.postAppBookingsBookingIDCancel(bookingID: bookingId).path
        }
        static func checkInBookingPath(_ bookingId: String) -> String {
            MobileAPIRoutes.postAppBookingsBookingIDCheckIn(bookingID: bookingId).path
        }
        static func checkOutBookingPath(_ bookingId: String) -> String {
            MobileAPIRoutes.postAppBookingsBookingIDCheckOut(bookingID: bookingId).path
        }

        // Cameras / Monitoring
        static let camerasPath = MobileAPIRoutes.getAppCameras.path
        static func cameraVideoLinkPath(_ cameraId: String) -> String {
            MobileAPIRoutes.getAppCamerasCameraIDVideoLink(cameraID: cameraId).path
        }
        static func cameraSnapshotPath(_ cameraId: String) -> String {
            MobileAPIRoutes.postAppCamerasCameraIDSnapshot(cameraID: cameraId).path
        }
        static func cameraCloudTokenPath(_ cameraId: String) -> String {
            MobileAPIRoutes.getAppCamerasCameraIDCloudToken(cameraID: cameraId).path
        }
        static func cameraRecordingsPath(_ cameraId: String) -> String {
            MobileAPIRoutes.getAppCamerasCameraIDCloudRecordings(cameraID: cameraId).path
        }
        static func eventMediaPath(_ placeId: String, _ eventId: String) -> String {
            MobileAPIRoutes.getAppPlacesPlaceIdEventsEventIdMedia(placeId: placeId, eventId: eventId).path
        }
    }

    // MARK: - Security
    enum Security {
        static let apiPinnedHost = "api.mistyislet.com"

        /// Comma or newline separated SHA-256 hashes of allowed API certificate
        /// SubjectPublicKeyInfo values, encoded with base64.
        static var apiPinnedSPKIHashes: Set<String> {
            let raw = (Bundle.main.object(forInfoDictionaryKey: "API_PINNED_SPKI_HASHES") as? String)
                ?? ProcessInfo.processInfo.environment["API_PINNED_SPKI_HASHES"]
                ?? ""
            let separators = CharacterSet(charactersIn: ",\n")
            return Set(
                raw.components(separatedBy: separators)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }

        static var requiresProductionPinning: Bool {
            AppEnvironment.current == .production
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
