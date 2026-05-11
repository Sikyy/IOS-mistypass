import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int, String?)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Session expired. Please log in again."
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg ?? "Unknown")"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .decodingError(let err): return "Data error: \(err.localizedDescription)"
        }
    }
}

@Observable
final class APIService: @unchecked Sendable {
    nonisolated(unsafe) static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Coordinates concurrent token refreshes so two parallel 401s don't
    /// race and burn the refresh token twice. Access only via `refreshLock`.
    private let refreshLock = TokenRefreshLock()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let d = ISO8601DateFormatter.withFractionalSeconds.date(from: str) { return d }
            if let d = ISO8601DateFormatter.standard.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(str)")
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> LoginResponse {
        let body = LoginRequest(email: email, password: password)
        return try await post(path: Constants.API.loginPath, body: body, authenticated: false)
    }

    func refreshToken(refreshToken: String) async throws -> AuthTokens {
        let body = ["refresh_token": refreshToken]
        return try await post(path: Constants.API.refreshPath, body: body, authenticated: false)
    }

    // MARK: - Auth (multi-step)

    func requestMagicLink(email: String) async throws -> MagicLinkResponse {
        let body = MagicLinkRequest(email: email)
        return try await post(path: Constants.API.magicLinkPath, body: body, authenticated: false)
    }

    func lookupOrg(domain: String) async throws -> OrgAuthConfig {
        let encoded = domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? domain
        return try await get(path: "\(Constants.API.orgLookupPath)?domain=\(encoded)", authenticated: false)
    }

    func restorePassword(email: String) async throws {
        let body = RestorePasswordRequest(email: email)
        let _: Empty = try await post(path: Constants.API.restorePasswordPath, body: body, authenticated: false)
    }

    // MARK: - Organizations

    func listOrgs() async throws -> [Organization] {
        try await get(path: Constants.API.orgsPath)
    }

    func switchOrg(orgId: String) async throws -> LoginResponse {
        let response: LoginResponse = try await post(
            path: Constants.API.switchOrgPath(orgId),
            body: Optional<String>.none
        )
        try KeychainService.shared.save(response.accessToken, forKey: Constants.Keychain.accessTokenKey)
        try KeychainService.shared.save(response.refreshToken, forKey: Constants.Keychain.refreshTokenKey)
        return response
    }

    // MARK: - Places

    func listPlaces(orgId: String) async throws -> [Place] {
        try await get(path: Constants.API.placesPath(orgId))
    }

    func searchPlaces(orgId: String, query: String) async throws -> [Place] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await get(path: "\(Constants.API.placesSearchPath(orgId))?q=\(encoded)")
    }

    func updatePlace(placeId: String, name: String, address: String?, timezone: String?, capacity: Int?) async throws -> Place {
        struct Body: Encodable {
            let name: String
            let address: String?
            let timezone: String?
            let capacity: Int?
        }
        return try await put(
            path: Constants.API.placeSettingsPath(placeId),
            body: Body(name: name, address: address, timezone: timezone, capacity: capacity)
        )
    }

    // MARK: - Organization Settings

    func fetchOrgSettings(orgId: String) async throws -> OrganizationSettings {
        try await get(path: Constants.API.orgSettingsPath(orgId))
    }

    func updateOrgSettings(orgId: String, settings: OrganizationSettings) async throws -> OrganizationSettings {
        try await put(path: Constants.API.orgSettingsPath(orgId), body: settings)
    }

    // MARK: - Doors (legacy flat API)

    func fetchDoors() async throws -> [Door] {
        try await get(path: Constants.API.doorsPath)
    }

    /// Remote (server-side) unlock via legacy flat endpoint.
    func remoteUnlock(doorId: String) async throws -> RemoteUnlockResponse {
        let body = UnlockRequestBody(lockId: doorId, bleToken: nil)
        return try await post(path: Constants.API.unlockPath, body: body)
    }

    // MARK: - Doors (place-scoped API, matches Android)

    func fetchPlaceDoors(placeId: String) async throws -> [AccessibleDoor] {
        let response: PlaceDoorListResponse = try await get(
            path: Constants.API.placeDoorsPath(placeId)
        )
        return response.items
    }

    func searchPlaceDoors(placeId: String, query: String) async throws -> [AccessibleDoor] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: PlaceDoorListResponse = try await get(
            path: "\(Constants.API.placeDoorsSearchPath(placeId))?q=\(encoded)"
        )
        return response.items
    }

    func placeUnlockDoor(placeId: String, doorId: String) async throws -> RemoteUnlockResponse {
        let body = UnlockRequestBody(lockId: doorId, bleToken: nil)
        return try await post(path: Constants.API.placeUnlockPath(placeId, doorId), body: body)
    }

    func favoriteDoor(placeId: String, doorId: String) async throws {
        let _: Empty = try await put(path: Constants.API.placeFavoriteDoorPath(placeId, doorId))
    }

    func unfavoriteDoor(placeId: String, doorId: String) async throws {
        let _: Empty = try await delete(path: Constants.API.placeFavoriteDoorPath(placeId, doorId))
    }

    func enableLockdown(placeId: String) async throws {
        let _: Empty = try await post(
            path: Constants.API.placeLockdownPath(placeId),
            body: Optional<String>.none
        )
    }

    func disableLockdown(placeId: String) async throws {
        let _: Empty = try await delete(path: Constants.API.placeLockdownPath(placeId))
    }

    // MARK: - Door Lockdown

    func enableDoorLockdown(placeId: String, doorId: String) async throws {
        let _: Empty = try await post(
            path: Constants.API.doorLockdownPath(placeId, doorId),
            body: Optional<String>.none
        )
    }

    func disableDoorLockdown(placeId: String, doorId: String) async throws {
        let _: Empty = try await delete(path: Constants.API.doorLockdownPath(placeId, doorId))
    }

    // MARK: - Door Restrictions

    func fetchDoorRestrictions(placeId: String, doorId: String) async throws -> [DoorRestriction] {
        let response: AdminListResponse<DoorRestriction> = try await get(
            path: Constants.API.doorRestrictionsPath(placeId, doorId)
        )
        return response.items
    }

    // MARK: - Door Schedules

    func fetchDoorSchedules(placeId: String, doorId: String) async throws -> [UnlockSchedule] {
        let response: AdminListResponse<UnlockSchedule> = try await get(
            path: Constants.API.doorSchedulesPath(placeId, doorId)
        )
        return response.items
    }

    // MARK: - Schedule CRUD

    func createSchedule(placeId: String, name: String, description: String, scheduleType: String,
                         startTime: String, endTime: String, daysOfWeek: [Int]) async throws -> UnlockSchedule {
        struct Body: Encodable {
            let name: String
            let description: String
            let schedule_type: String
            let start_time: String
            let end_time: String
            let days_of_week: [Int]
        }
        return try await post(
            path: Constants.API.adminSchedulesPath(placeId),
            body: Body(name: name, description: description, schedule_type: scheduleType,
                       start_time: startTime, end_time: endTime, days_of_week: daysOfWeek)
        )
    }

    func updateSchedule(placeId: String, scheduleId: String, name: String, description: String,
                         startTime: String, endTime: String, daysOfWeek: [Int]) async throws -> UnlockSchedule {
        struct Body: Encodable {
            let name: String
            let description: String
            let start_time: String
            let end_time: String
            let days_of_week: [Int]
        }
        return try await put(
            path: Constants.API.adminSchedulePath(placeId, scheduleId),
            body: Body(name: name, description: description,
                       start_time: startTime, end_time: endTime, days_of_week: daysOfWeek)
        )
    }

    func deleteSchedule(placeId: String, scheduleId: String) async throws {
        let _: Empty = try await delete(path: Constants.API.adminSchedulePath(placeId, scheduleId))
    }

    // MARK: - Credentials

    /// Register a BLE mobile credential public key with the backend.
    /// Payload shape matches Android `RegisterMobileCredentialRequest`.
    func registerCredential(publicKey: String, deviceName: String) async throws -> Credential {
        let keystoreLevel: String = {
            #if targetEnvironment(simulator)
            return "software"
            #else
            return "strongbox"
            #endif
        }()
        let body = RegisterMobileCredentialBody(
            publicKeyPem: publicKey,
            platform: "ios",
            deviceId: deviceName,
            deviceModel: deviceName,
            keystoreLevel: keystoreLevel,
            attestationCertChain: []
        )
        let response: RegisterMobileCredentialResponse = try await post(
            path: Constants.API.mobileCredentialRegisterPath,
            body: body
        )
        return response.credential
    }

    func fetchCredentials() async throws -> [Credential] {
        let response: AdminListResponse<Credential> = try await get(path: Constants.API.mobileCredentialsPath)
        return response.items
    }

    func revokeCredential(id: String) async throws {
        let _: Empty = try await delete(path: "\(Constants.API.mobileCredentialsPath)/\(id)")
    }

    // MARK: - PIN Code

    func fetchPinCode() async throws -> PinCodeResponse {
        try await get(path: Constants.API.pinCodePath)
    }

    // MARK: - Events

    func fetchEvents(offset: Int = 0, limit: Int = 20) async throws -> [AccessEvent] {
        try await get(path: "\(Constants.API.logsPath)?offset=\(offset)&limit=\(limit)")
    }

    // MARK: - Visitors

    func fetchVisitors() async throws -> [Visitor] {
        let response: AdminListResponse<Visitor> = try await get(path: Constants.API.visitorPassesPath)
        return response.items
    }

    func createVisitor(_ request: CreateVisitorRequest) async throws -> Visitor {
        try await post(path: Constants.API.visitorPassesPath, body: request)
    }

    // MARK: - Visitor Groups

    func fetchVisitorGroups(placeId: String) async throws -> [VisitorGroup] {
        try await get(path: Constants.API.visitorGroupsPath(placeId))
    }

    func createVisitorGroup(placeId: String, name: String) async throws -> VisitorGroup {
        let body = ["name": name, "auto_remove_expired": "true"]
        return try await post(path: Constants.API.visitorGroupsPath(placeId), body: body)
    }

    func fetchVisitorGroupMembers(placeId: String, groupId: String) async throws -> [VisitorGroupMember] {
        try await get(path: Constants.API.visitorGroupMembersPath(placeId, groupId))
    }

    func cleanupExpiredVisitors(placeId: String, groupId: String) async throws -> [String: Int] {
        try await post(path: Constants.API.visitorGroupCleanupPath(placeId, groupId), body: Optional<String>.none)
    }

    // MARK: - Guests (admin)

    func fetchGuests() async throws -> [Guest] {
        let response: AdminListResponse<Guest> = try await get(path: Constants.API.guestsPath)
        return response.items
    }

    func createGuest(_ request: CreateGuestRequest) async throws -> Guest {
        try await post(path: Constants.API.guestsPath, body: request)
    }

    func updateGuestStatus(guestId: String, status: String) async throws -> Guest {
        try await patch(path: Constants.API.guestStatusPath(guestId), body: ["status": status])
    }

    func deleteGuest(guestId: String) async throws {
        let _: Empty = try await delete(path: Constants.API.guestPath(guestId))
    }

    // MARK: - Profile

    func fetchProfile() async throws -> UserProfile {
        try await get(path: Constants.API.mePath)
    }

    func updateProfile(name: String) async throws -> UserProfile {
        let body = UpdateProfileRequest(name: name)
        return try await patch(path: Constants.API.mePath, body: body)
    }

    func uploadAvatar(imageData: Data) async throws -> UserProfile {
        try await uploadMultipart(
            path: Constants.API.avatarPath,
            fileData: imageData,
            fileName: "avatar.jpg",
            mimeType: "image/jpeg"
        )
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        let body = ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        let _: Empty = try await post(path: Constants.API.changePasswordPath, body: body)
    }

    func setPrimaryDevice() async throws {
        let _: Empty = try await post(
            path: Constants.API.primaryDevicePath,
            body: Optional<String>.none
        )
    }

    func registerAPNSToken(_ tokenHex: String) async throws {
        let body = ["device_token": tokenHex, "platform": "ios"]
        let _: Empty = try await post(path: Constants.API.apnsDevicePath, body: body)
    }

    func bindNFCCard(cardUID: String, label: String) async throws -> Credential {
        let body = ["card_uid": cardUID, "card_type": "desfire_ev3", "label": label]
        return try await post(path: Constants.API.nfcCredentialPath, body: body)
    }

    func fetchNFCCards() async throws -> [Credential] {
        try await get(path: Constants.API.nfcCredentialPath)
    }

    func unbindNFCCard(id: String) async throws {
        let _: Empty = try await delete(path: "\(Constants.API.nfcCredentialPath)/\(id)")
    }

    func fetchQRToken(doorId: String?) async throws -> QRTokenResponse {
        if let doorId {
            return try await post(path: Constants.API.qrTokenPath, body: ["door_id": doorId])
        }
        return try await post(path: Constants.API.qrTokenPath, body: Optional<String>.none)
    }

    // MARK: - Admin (place-scoped)

    func fetchAdminUsers(placeId: String) async throws -> [PlaceUser] {
        let response: AdminListResponse<PlaceUser> = try await get(path: Constants.API.adminUsersPath(placeId))
        return response.items
    }

    func fetchAdminEvents(placeId: String) async throws -> [AdminEvent] {
        let response: AdminListResponse<AdminEvent> = try await get(path: Constants.API.adminEventsPath(placeId))
        return response.items
    }

    func fetchAdminIncidents(placeId: String) async throws -> [Incident] {
        let response: AdminListResponse<Incident> = try await get(path: Constants.API.adminIncidentsPath(placeId))
        return response.items
    }

    func fetchAdminTeams(placeId: String) async throws -> [Team] {
        let response: AdminListResponse<Team> = try await get(path: Constants.API.adminTeamsPath(placeId))
        return response.items
    }

    func fetchAdminSchedules(placeId: String) async throws -> [UnlockSchedule] {
        let response: AdminListResponse<UnlockSchedule> = try await get(path: Constants.API.adminSchedulesPath(placeId))
        return response.items
    }

    func fetchAdminZones(placeId: String) async throws -> [Zone] {
        let response: AdminListResponse<Zone> = try await get(path: Constants.API.adminZonesPath(placeId))
        return response.items
    }

    func fetchAdminCards(placeId: String) async throws -> [CardAssignment] {
        let response: AdminListResponse<CardAssignment> = try await get(path: Constants.API.adminCardsPath(placeId))
        return response.items
    }

    func fetchAdminCredentials(placeId: String) async throws -> [DigitalCredential] {
        let response: AdminListResponse<DigitalCredential> = try await get(path: Constants.API.adminCredentialsPath(placeId))
        return response.items
    }

    func unassignCard(placeId: String, cardUid: String) async throws {
        let _: Empty = try await delete(path: Constants.API.adminCardUnassignPath(placeId, cardUid))
    }

    func suspendWalletPass(passId: String) async throws {
        let _: Empty = try await patch(path: Constants.API.walletPassSuspendPath(passId), body: Optional<String>.none)
    }

    func activateWalletPass(passId: String) async throws {
        let _: Empty = try await patch(path: Constants.API.walletPassActivatePath(passId), body: Optional<String>.none)
    }

    func revokeWalletPass(passId: String) async throws {
        let _: Empty = try await patch(path: Constants.API.walletPassRevokePath(passId), body: Optional<String>.none)
    }

    // MARK: - User Management

    func inviteUser(placeId: String, email: String, role: String) async throws -> PlaceUser {
        let body = ["email": email, "role": role]
        return try await post(path: Constants.API.adminInviteUserPath(placeId), body: body)
    }

    func updateUserRole(placeId: String, userId: String, role: String) async throws -> PlaceUser {
        try await patch(path: Constants.API.adminUserRolePath(placeId, userId), body: ["role": role])
    }

    func removeUser(placeId: String, userId: String) async throws {
        let _: Empty = try await delete(path: Constants.API.adminUserPath(placeId, userId))
    }

    func signOutUser(placeId: String, userId: String) async throws {
        let _: Empty = try await post(path: Constants.API.adminUserSignOutPath(placeId, userId), body: Optional<String>.none)
    }

    // MARK: - Groups

    func fetchAdminGroups(placeId: String) async throws -> [AccessGroup] {
        let response: AdminListResponse<AccessGroup> = try await get(path: Constants.API.adminGroupsPath(placeId))
        return response.items
    }

    func createGroup(placeId: String, name: String, description: String) async throws -> AccessGroup {
        let body = ["name": name, "description": description]
        return try await post(path: Constants.API.adminGroupsPath(placeId), body: body)
    }

    func updateGroup(placeId: String, groupId: String, name: String, description: String) async throws -> AccessGroup {
        let body = ["name": name, "description": description]
        return try await patch(path: Constants.API.adminGroupPath(placeId, groupId), body: body)
    }

    func deleteGroup(placeId: String, groupId: String) async throws {
        let _: Empty = try await delete(path: Constants.API.adminGroupPath(placeId, groupId))
    }

    func fetchGroupMembers(placeId: String, groupId: String) async throws -> [GroupMember] {
        let response: AdminListResponse<GroupMember> = try await get(path: Constants.API.adminGroupMembersPath(placeId, groupId))
        return response.items
    }

    func addGroupMember(placeId: String, groupId: String, email: String) async throws -> GroupMember {
        try await post(path: Constants.API.adminGroupMembersPath(placeId, groupId), body: ["email": email])
    }

    func removeGroupMember(placeId: String, groupId: String, memberId: String) async throws {
        let _: Empty = try await delete(path: "\(Constants.API.adminGroupMembersPath(placeId, groupId))/\(memberId)")
    }

    func fetchGroupDoors(placeId: String, groupId: String) async throws -> [GroupDoor] {
        let response: AdminListResponse<GroupDoor> = try await get(path: Constants.API.adminGroupDoorsPath(placeId, groupId))
        return response.items
    }

    func addGroupDoor(placeId: String, groupId: String, doorId: String) async throws {
        let _: Empty = try await post(path: Constants.API.adminGroupDoorsPath(placeId, groupId), body: ["door_id": doorId])
    }

    func removeGroupDoor(placeId: String, groupId: String, doorId: String) async throws {
        let _: Empty = try await delete(path: "\(Constants.API.adminGroupDoorsPath(placeId, groupId))/\(doorId)")
    }

    // MARK: - Team Management

    func createTeam(placeId: String, name: String, description: String) async throws -> Team {
        let body = ["name": name, "description": description]
        return try await post(path: Constants.API.adminTeamsPath(placeId), body: body)
    }

    func deleteTeam(placeId: String, teamId: String) async throws {
        let _: Empty = try await delete(path: Constants.API.adminTeamPath(placeId, teamId))
    }

    func fetchTeamMembers(placeId: String, teamId: String) async throws -> [TeamMember] {
        let response: AdminListResponse<TeamMember> = try await get(path: Constants.API.adminTeamMembersPath(placeId, teamId))
        return response.items
    }

    func addTeamMember(placeId: String, teamId: String, email: String) async throws -> TeamMember {
        try await post(path: Constants.API.adminTeamMembersPath(placeId, teamId), body: ["email": email])
    }

    func removeTeamMember(placeId: String, teamId: String, memberId: String) async throws {
        let _: Empty = try await delete(path: "\(Constants.API.adminTeamMembersPath(placeId, teamId))/\(memberId)")
    }

    func fetchTeamAccessRights(placeId: String, teamId: String) async throws -> [AccessRightAssignment] {
        let response: AdminListResponse<AccessRightAssignment> = try await get(path: Constants.API.adminTeamAccessPath(placeId, teamId))
        return response.items
    }

    func assignTeamAccessRight(placeId: String, teamId: String, role: String, scope: String, scopeId: String?) async throws -> AccessRightAssignment {
        var body: [String: String] = ["role": role, "scope": scope]
        if let scopeId { body["scope_id"] = scopeId }
        return try await post(path: Constants.API.adminTeamAccessPath(placeId, teamId), body: body)
    }

    func removeTeamAccessRight(placeId: String, teamId: String, accessRightId: String) async throws {
        let _: Empty = try await delete(path: "\(Constants.API.adminTeamAccessPath(placeId, teamId))/\(accessRightId)")
    }

    // MARK: - Analytics & Reports

    func fetchAnalyticsSummary(placeId: String, days: Int = 30) async throws -> AnalyticsSummary {
        try await get(path: "\(Constants.API.analyticsSummaryPath(placeId))?days=\(days)")
    }

    func fetchUserPresence(placeId: String, days: Int = 30) async throws -> [UserPresenceRecord] {
        let response: AdminListResponse<UserPresenceRecord> = try await get(
            path: "\(Constants.API.userPresencePath(placeId))?days=\(days)"
        )
        return response.items
    }

    func exportReport(placeId: String, type: String, from: String, to: String, format: String = "csv") async throws -> ReportExportResponse {
        let body: [String: String] = [
            "type": type,
            "from": from,
            "to": to,
            "format": format
        ]
        return try await post(path: Constants.API.reportExportPath(placeId), body: body)
    }

    // MARK: - Alarms

    func fetchAlarms() async throws -> [Alarm] {
        let response: AdminListResponse<Alarm> = try await get(path: Constants.API.alarmsPath)
        return response.items
    }

    func updateAlarmStatus(alarmId: String, status: String) async throws -> Alarm {
        try await patch(path: Constants.API.alarmStatusPath(alarmId), body: ["status": status])
    }

    func fetchAlarmSchedules() async throws -> [AlarmSchedule] {
        let response: AdminListResponse<AlarmSchedule> = try await get(path: Constants.API.alarmSchedulesPath)
        return response.items
    }

    func streamAlarms() -> AsyncThrowingStream<AlarmStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = try buildRequest(path: Constants.API.alarmsStreamPath, method: "GET", authenticated: true)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let config = URLSessionConfiguration.default
                    config.timeoutIntervalForRequest = 300
                    config.timeoutIntervalForResource = 0
                    let streamSession = URLSession(configuration: config)

                    let (bytes, response) = try await streamSession.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        AppLogger.api.warning("SSE stream connection failed with status \(code)")
                        continuation.finish(throwing: APIError.serverError(code, "SSE connection failed"))
                        return
                    }

                    AppLogger.api.info("SSE alarm stream connected")
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard let data = json.data(using: .utf8) else { continue }
                        if let event = try? self.decoder.decode(AlarmStreamEvent.self, from: data) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        AppLogger.api.warning("SSE stream disconnected: \(error.localizedDescription)")
                        continuation.finish(throwing: error)
                    }
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    func fetchAlarmCalendar(timezone: String = "Asia/Jakarta") async throws -> [AlarmCalendarEntry] {
        let encoded = timezone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timezone
        let response: AdminListResponse<AlarmCalendarEntry> = try await get(
            path: "\(Constants.API.alarmCalendarPath)?timezone=\(encoded)"
        )
        return response.items
    }

    // MARK: - Activity

    func fetchUserActivity(placeId: String) async throws -> [UserActivity] {
        let response: AdminListResponse<UserActivity> = try await get(path: Constants.API.activityPath(placeId))
        return response.items
    }

    // MARK: - Bookings

    func fetchBookableSpaceStatus(spaceId: String) async throws -> BookableSpaceStatus {
        try await get(path: Constants.API.bookableSpaceStatusPath(spaceId))
    }

    func fetchBookableSpaces() async throws -> [BookableSpace] {
        let response: AdminListResponse<BookableSpace> = try await get(path: Constants.API.bookableSpacesPath)
        return response.items
    }

    func fetchBookings(spaceId: String? = nil) async throws -> [Booking] {
        var path = Constants.API.bookingsPath
        if let spaceId {
            let encoded = spaceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? spaceId
            path += "?space_id=\(encoded)"
        }
        let response: AdminListResponse<Booking> = try await get(path: path)
        return response.items
    }

    func createBooking(_ request: CreateBookingRequest) async throws -> Booking {
        try await post(path: Constants.API.bookingsPath, body: request)
    }

    func cancelBooking(bookingId: String) async throws -> Booking {
        try await post(path: Constants.API.cancelBookingPath(bookingId), body: Optional<String>.none)
    }

    func checkInBooking(bookingId: String) async throws -> Booking {
        try await post(path: Constants.API.checkInBookingPath(bookingId), body: Optional<String>.none)
    }

    func checkOutBooking(bookingId: String) async throws -> Booking {
        try await post(path: Constants.API.checkOutBookingPath(bookingId), body: Optional<String>.none)
    }

    // MARK: - Cameras / Monitoring

    func fetchCameras() async throws -> [Camera] {
        let response: AdminListResponse<Camera> = try await get(path: Constants.API.camerasPath)
        return response.items
    }

    func fetchCameraVideoLink(cameraId: String) async throws -> CameraVideoLink {
        try await get(path: Constants.API.cameraVideoLinkPath(cameraId))
    }

    func captureSnapshot(cameraId: String) async throws -> CameraSnapshot {
        try await post(path: Constants.API.cameraSnapshotPath(cameraId), body: Empty())
    }

    func fetchEventMedia(placeId: String, eventId: String) async throws -> [EventMedia] {
        try await get(path: Constants.API.eventMediaPath(placeId, eventId))
    }

    // MARK: - Hardware Rename

    func renameDoor(placeId: String, doorId: String, name: String) async throws -> AccessibleDoor {
        try await patch(path: Constants.API.doorRenamePath(placeId, doorId), body: ["name": name])
    }

    func renameGateway(gatewayId: String, name: String) async throws -> [String: String] {
        try await patch(path: Constants.API.gatewayRenamePath(gatewayId), body: ["name": name])
    }

    func renameCamera(cameraId: String, name: String) async throws -> Camera {
        try await patch(path: Constants.API.cameraRenamePath(cameraId), body: ["name": name])
    }

    // MARK: - Active Logins

    func fetchMyLogins() async throws -> [UserLogin] {
        let response: UserLoginListResponse = try await get(path: Constants.API.myLoginsPath)
        return response.items
    }

    func remoteLogout(loginId: String) async throws {
        let _: Empty = try await delete(path: "\(Constants.API.myLoginsPath)/\(loginId)")
    }

    // MARK: - Generic Request Methods

    private func get<T: Decodable>(path: String, authenticated: Bool = true) async throws -> T {
        let request = try buildRequest(path: path, method: "GET", authenticated: authenticated)
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(
        path: String,
        body: B?,
        authenticated: Bool = true
    ) async throws -> T {
        var request = try buildRequest(path: path, method: "POST", authenticated: authenticated)
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await execute(request)
    }

    private func put<T: Decodable>(path: String, authenticated: Bool = true) async throws -> T {
        let request = try buildRequest(path: path, method: "PUT", authenticated: authenticated)
        return try await execute(request)
    }

    private func put<T: Decodable, B: Encodable>(
        path: String,
        body: B,
        authenticated: Bool = true
    ) async throws -> T {
        var request = try buildRequest(path: path, method: "PUT", authenticated: authenticated)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    private func patch<T: Decodable, B: Encodable>(
        path: String,
        body: B,
        authenticated: Bool = true
    ) async throws -> T {
        var request = try buildRequest(path: path, method: "PATCH", authenticated: authenticated)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    private func delete<T: Decodable>(path: String, authenticated: Bool = true) async throws -> T {
        let request = try buildRequest(path: path, method: "DELETE", authenticated: authenticated)
        return try await execute(request)
    }

    private func uploadMultipart<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file",
        authenticated: Bool = true
    ) async throws -> T {
        let boundary = UUID().uuidString
        var request = try buildRequest(path: path, method: "POST", authenticated: authenticated)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return try await execute(request)
    }

    private func buildRequest(path: String, method: String, authenticated: Bool) throws -> URLRequest {
        guard let url = URL(string: Constants.API.baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if authenticated {
            if let token = KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest, retryOnUnauthorized: Bool = true) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            AppLogger.api.error("Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(0, "Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            AppLogger.api.warning("401 received, attempting token refresh")
            if retryOnUnauthorized {
                let refreshed = await refreshLock.refresh { [weak self] in
                    await self?.performTokenRefresh() ?? false
                }
                if refreshed {
                    var retryRequest = request
                    if let newToken = KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) {
                        retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    }
                    return try await execute(retryRequest, retryOnUnauthorized: false)
                }
            }
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8)
            AppLogger.api.error("Server error \(httpResponse.statusCode): \(message ?? "")")
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }

    /// Performs the actual token refresh. Called at most once per concurrent
    /// burst of 401s — see `TokenRefreshLock`.
    private func performTokenRefresh() async -> Bool {
        guard let storedRefresh = KeychainService.shared.readString(forKey: Constants.Keychain.refreshTokenKey) else {
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            return false
        }

        do {
            let tokens = try await refreshToken(refreshToken: storedRefresh)
            try KeychainService.shared.save(tokens.accessToken, forKey: Constants.Keychain.accessTokenKey)
            try KeychainService.shared.save(tokens.refreshToken, forKey: Constants.Keychain.refreshTokenKey)
            return true
        } catch {
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            return false
        }
    }
}

/// Coalesces concurrent token refresh attempts into a single in-flight Task.
/// Without this, two parallel 401 responses would each fire a refresh call
/// and the second one would invalidate the first's refresh token mid-flight.
private actor TokenRefreshLock {
    private var inFlight: Task<Bool, Never>?

    func refresh(_ work: @Sendable @escaping () async -> Bool) async -> Bool {
        if let existing = inFlight {
            return await existing.value
        }
        let task = Task { await work() }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }
}

// Helper for endpoints that return no meaningful body
private struct Empty: Codable {}

extension ISO8601DateFormatter {
    nonisolated(unsafe) static let withFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) static let standard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
