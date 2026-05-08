import Foundation

#if DEBUG
enum PreviewData {

    // MARK: - Doors

    static let doors: [Door] = [
        Door(
            id: "door-001",
            name: "Main Entrance",
            building: "Lobby",
            floor: "Floor 1",
            gatewayOnline: true,
            controllerOnline: true,
            hasPermission: true
        ),
        Door(
            id: "door-002",
            name: "Server Room",
            building: "Data Center",
            floor: "B2",
            gatewayOnline: true,
            controllerOnline: false,
            hasPermission: true
        ),
        Door(
            id: "door-003",
            name: "Parking Gate",
            building: "Parking",
            floor: "G",
            gatewayOnline: false,
            controllerOnline: true,
            hasPermission: true
        ),
        Door(
            id: "door-004",
            name: "Meeting Room A",
            building: "Office",
            floor: "Floor 3",
            gatewayOnline: true,
            controllerOnline: true,
            hasPermission: true
        ),
        Door(
            id: "door-005",
            name: "Executive Suite",
            building: "Office",
            floor: "Floor 5",
            gatewayOnline: true,
            controllerOnline: true,
            hasPermission: false
        ),
    ]

    // MARK: - Access Events

    static let events: [AccessEvent] = [
        AccessEvent(
            id: "evt-001",
            doorId: "door-001",
            doorName: "Main Entrance",
            timestamp: Date(),
            result: .granted,
            method: .ble,
            reason: nil
        ),
        AccessEvent(
            id: "evt-002",
            doorId: "door-003",
            doorName: "Parking Gate",
            timestamp: Date().addingTimeInterval(-3600),
            result: .granted,
            method: .qr,
            reason: nil
        ),
        AccessEvent(
            id: "evt-003",
            doorId: "door-002",
            doorName: "Server Room",
            timestamp: Date().addingTimeInterval(-7200),
            result: .denied,
            method: .ble,
            reason: "No permission"
        ),
        AccessEvent(
            id: "evt-004",
            doorId: "door-001",
            doorName: "Main Entrance",
            timestamp: Date().addingTimeInterval(-86400),
            result: .granted,
            method: .remote,
            reason: nil
        ),
        AccessEvent(
            id: "evt-005",
            doorId: "door-001",
            doorName: "Main Entrance",
            timestamp: Date().addingTimeInterval(-90000),
            result: .granted,
            method: .ble,
            reason: nil
        ),
    ]

    // MARK: - Accessible Doors (place-scoped, used by Hardware & Gateway views)

    static let accessibleDoors: [AccessibleDoor] = [
        AccessibleDoor(
            id: "door-001", name: "Main Entrance",
            buildingId: "b1", areaId: nil,
            status: "online", gatewayStatus: "online",
            gatewayId: "gw-001", gatewayName: "Gateway Lobby",
            groupName: "Lobby", canUnlock: true, isFavorite: true,
            lastUnlockAt: "2026-05-07T08:12:00Z", kind: "door"
        ),
        AccessibleDoor(
            id: "door-002", name: "Server Room",
            buildingId: "b2", areaId: nil,
            status: "online", gatewayStatus: "online",
            gatewayId: "gw-002", gatewayName: "Gateway DC",
            groupName: "Data Center", canUnlock: true, isFavorite: false,
            lastUnlockAt: "2026-05-07T07:45:00Z", kind: "door"
        ),
        AccessibleDoor(
            id: "door-003", name: "Parking Gate",
            buildingId: "b1", areaId: nil,
            status: "online", gatewayStatus: "offline",
            gatewayId: "gw-003", gatewayName: "Gateway Parking",
            groupName: "Parking", canUnlock: false, isFavorite: false,
            lastUnlockAt: "2026-05-06T18:30:00Z", kind: "turnstile"
        ),
        AccessibleDoor(
            id: "door-004", name: "Meeting Room A",
            buildingId: "b1", areaId: nil,
            status: "online", gatewayStatus: "online",
            gatewayId: "gw-001", gatewayName: "Gateway Lobby",
            groupName: "Lobby", canUnlock: true, isFavorite: false,
            lastUnlockAt: "2026-05-07T09:02:00Z", kind: "door"
        ),
        AccessibleDoor(
            id: "door-005", name: "Executive Suite",
            buildingId: "b1", areaId: nil,
            status: "locked_down", gatewayStatus: "online",
            gatewayId: "gw-001", gatewayName: "Gateway Lobby",
            groupName: "Office", canUnlock: false, isFavorite: false,
            lastUnlockAt: nil, kind: "door"
        ),
    ]

    // MARK: - Cameras

    static let cameras: [Camera] = [
        Camera(
            id: "cam-001", name: "Lobby Camera 1",
            vendor: "Hikvision", model: "DS-2CD2143G2-I",
            ipAddress: "192.168.1.101", status: "online",
            doorId: "door-001", doorName: "Main Entrance",
            streamUrl: "rtsp://192.168.1.101/stream1", createdAt: "2026-01-15T10:00:00Z"
        ),
        Camera(
            id: "cam-002", name: "Server Room Camera",
            vendor: "Dahua", model: "IPC-HDW3849H",
            ipAddress: "192.168.1.102", status: "online",
            doorId: "door-002", doorName: "Server Room",
            streamUrl: "rtsp://192.168.1.102/stream1", createdAt: "2026-01-15T10:00:00Z"
        ),
        Camera(
            id: "cam-003", name: "Parking Entrance",
            vendor: "Hikvision", model: "DS-2CD2T47G2-L",
            ipAddress: "192.168.1.103", status: "offline",
            doorId: "door-003", doorName: "Parking Gate",
            streamUrl: nil, createdAt: "2026-02-20T14:00:00Z"
        ),
        Camera(
            id: "cam-004", name: "Executive Floor",
            vendor: "Axis", model: "P3265-V",
            ipAddress: "192.168.1.104", status: "online",
            doorId: "door-005", doorName: "Executive Suite",
            streamUrl: "rtsp://192.168.1.104/stream1", createdAt: "2026-03-10T09:00:00Z"
        ),
    ]

    // MARK: - Credentials

    static let credentials: [Credential] = [
        Credential(
            id: "cred-001",
            userEmail: "siky@mistyislet.com",
            deviceId: "iPhone17Pro",
            platform: "ios",
            deviceModel: "iPhone 17 Pro",
            keystoreLevel: "strongbox",
            status: "active",
            issuedAt: Date().addingTimeInterval(-2592000),
            expiresAt: Date().addingTimeInterval(5184000),
            revokedAt: nil,
            lastUsedAt: Date()
        ),
    ]

    // MARK: - Visitors

    static let visitors: [Visitor] = [
        Visitor(
            id: "vis-001",
            visitor: "John Doe",
            host: "Ahmad",
            deliveryMethod: "whatsapp",
            expiresAt: ISO8601DateFormatter.standard.string(from: Date().addingTimeInterval(79200)),
            createdAt: Date().addingTimeInterval(-3600),
            validFrom: ISO8601DateFormatter.standard.string(from: Date().addingTimeInterval(-3600)),
            validUntil: ISO8601DateFormatter.standard.string(from: Date().addingTimeInterval(79200)),
            displayLabel: "VP-001"
        ),
        Visitor(
            id: "vis-002",
            visitor: "Jane Smith",
            host: "Budi",
            deliveryMethod: "email",
            expiresAt: ISO8601DateFormatter.standard.string(from: Date().addingTimeInterval(-3600)),
            createdAt: Date().addingTimeInterval(-172800),
            validFrom: ISO8601DateFormatter.standard.string(from: Date().addingTimeInterval(-172800)),
            validUntil: ISO8601DateFormatter.standard.string(from: Date().addingTimeInterval(-3600)),
            displayLabel: "VP-002"
        ),
    ]

    // MARK: - Analytics Demo

    static let analyticsSummary: AnalyticsSummary = {
        let calendar = Calendar.current
        let today = Date()

        // Daily trend: 30 days of data
        let dailyTrend: [DailyUnlockStat] = (0..<30).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            let base = isWeekend ? 15 : 65
            let unlocks = base + Int.random(in: -12...20)
            let users = max(3, unlocks / 3 + Int.random(in: -2...3))
            let failed = Int.random(in: 0...4)
            return DailyUnlockStat(
                date: fmt.string(from: date),
                unlocks: unlocks,
                uniqueUsers: users,
                failed: failed
            )
        }

        // Heatmap: 7 days × 24 hours
        let heatmap: [HeatmapCell] = (0..<7).flatMap { day in
            (0..<24).map { hour in
                let isWorkday = day < 5
                let isWorkHour = hour >= 8 && hour <= 18
                let val: Int
                if isWorkday && isWorkHour {
                    val = Int.random(in: 3...18)
                } else if isWorkday {
                    val = Int.random(in: 0...3)
                } else {
                    val = Int.random(in: 0...5)
                }
                return HeatmapCell(dayOfWeek: day, hour: hour, value: val)
            }
        }

        // Weekly users: ~6 weeks
        let weeklyUsers: [WeeklyUserCount] = (0..<6).reversed().map { weeksAgo in
            let date = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: today)!
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return WeeklyUserCount(
                weekStart: fmt.string(from: date),
                uniqueUsers: Int.random(in: 12...24)
            )
        }

        return AnalyticsSummary(
            totalUnlocks: dailyTrend.map(\.unlocks).reduce(0, +),
            uniqueUsers: 23,
            failedAttempts: dailyTrend.map(\.failed).reduce(0, +),
            avgDailyUnlocks: Double(dailyTrend.map(\.unlocks).reduce(0, +)) / 30.0,
            periodDays: 30,
            topDoors: [
                DoorUsage(id: "d1", name: "Main Entrance", count: 458),
                DoorUsage(id: "d2", name: "Staff Room", count: 231),
                DoorUsage(id: "d3", name: "Parking Gate", count: 189),
                DoorUsage(id: "d4", name: "Server Room", count: 76),
                DoorUsage(id: "d5", name: "Meeting Room A", count: 52),
            ],
            unlocksByMethod: [
                MethodBreakdown(method: "mobile", count: 412),
                MethodBreakdown(method: "card", count: 298),
                MethodBreakdown(method: "ble", count: 187),
                MethodBreakdown(method: "pin", count: 63),
                MethodBreakdown(method: "qr", count: 34),
                MethodBreakdown(method: "visitor", count: 12),
            ],
            dailyTrend: dailyTrend,
            heatmap: heatmap,
            weeklyUsers: weeklyUsers
        )
    }()

    static let userPresenceRecords: [UserPresenceRecord] = [
        UserPresenceRecord(id: "u1", userName: "Ahmad Wijaya", email: "ahmad@mistyislet.com",
                           firstUnlock: "2026-04-08", lastUnlock: "2026-05-07", daysPresent: 26, totalUnlocks: 187,
                           weekdayBreakdown: [32, 28, 30, 27, 31, 8, 5]),
        UserPresenceRecord(id: "u2", userName: "Siti Rahayu", email: "siti@mistyislet.com",
                           firstUnlock: "2026-04-08", lastUnlock: "2026-05-07", daysPresent: 24, totalUnlocks: 156,
                           weekdayBreakdown: [28, 25, 22, 30, 26, 4, 2]),
        UserPresenceRecord(id: "u3", userName: "Budi Santoso", email: "budi@mistyislet.com",
                           firstUnlock: "2026-04-10", lastUnlock: "2026-05-06", daysPresent: 22, totalUnlocks: 134,
                           weekdayBreakdown: [24, 22, 20, 25, 23, 6, 3]),
        UserPresenceRecord(id: "u4", userName: "Dewi Lestari", email: "dewi@mistyislet.com",
                           firstUnlock: "2026-04-08", lastUnlock: "2026-05-07", daysPresent: 20, totalUnlocks: 98,
                           weekdayBreakdown: [18, 16, 20, 15, 19, 2, 0]),
        UserPresenceRecord(id: "u5", userName: "Eko Prasetyo", email: "eko@mistyislet.com",
                           firstUnlock: "2026-04-12", lastUnlock: "2026-05-05", daysPresent: 18, totalUnlocks: 112,
                           weekdayBreakdown: [20, 18, 22, 17, 21, 10, 8]),
        UserPresenceRecord(id: "u6", userName: "Fitri Handayani", email: "fitri@mistyislet.com",
                           firstUnlock: "2026-04-15", lastUnlock: "2026-05-07", daysPresent: 16, totalUnlocks: 78,
                           weekdayBreakdown: [14, 12, 16, 13, 15, 0, 0]),
        UserPresenceRecord(id: "u7", userName: "Gunawan Tan", email: "gunawan@mistyislet.com",
                           firstUnlock: "2026-04-20", lastUnlock: "2026-05-04", daysPresent: 12, totalUnlocks: 45,
                           weekdayBreakdown: [8, 10, 6, 9, 7, 3, 1]),
        UserPresenceRecord(id: "u8", userName: "Hesti Wulandari", email: "hesti@mistyislet.com",
                           firstUnlock: "2026-04-22", lastUnlock: "2026-05-02", daysPresent: 8, totalUnlocks: 32,
                           weekdayBreakdown: [6, 5, 7, 4, 6, 0, 0]),
        UserPresenceRecord(id: "u9", userName: "Irfan Maulana", email: "irfan@mistyislet.com",
                           firstUnlock: "2026-04-28", lastUnlock: "2026-05-07", daysPresent: 6, totalUnlocks: 21,
                           weekdayBreakdown: [4, 3, 5, 3, 4, 1, 0]),
        UserPresenceRecord(id: "u10", userName: "Joko Widodo", email: "joko@mistyislet.com",
                           firstUnlock: "2026-05-01", lastUnlock: "2026-05-06", daysPresent: 4, totalUnlocks: 14,
                           weekdayBreakdown: [3, 2, 3, 2, 3, 0, 0]),
    ]

    static let failedEvents: [AdminEvent] = [
        AdminEvent(id: "fe1", placeId: "p1", timestamp: "2026-05-07T09:14:00Z", actor: "Gunawan Tan",
                   action: "unlock", result: "denied", objectName: "Server Room", objectType: "door", objectId: "d4", doorId: "d4"),
        AdminEvent(id: "fe2", placeId: "p1", timestamp: "2026-05-07T08:32:00Z", actor: "Hesti Wulandari",
                   action: "unlock", result: "denied", objectName: "Executive Suite", objectType: "door", objectId: "d5", doorId: "d5"),
        AdminEvent(id: "fe3", placeId: "p1", timestamp: "2026-05-06T17:45:00Z", actor: "Irfan Maulana",
                   action: "unlock", result: "failed", objectName: "Main Entrance", objectType: "door", objectId: "d1", doorId: "d1"),
        AdminEvent(id: "fe4", placeId: "p1", timestamp: "2026-05-06T14:22:00Z", actor: "Joko Widodo",
                   action: "unlock", result: "denied", objectName: "Server Room", objectType: "door", objectId: "d4", doorId: "d4"),
        AdminEvent(id: "fe5", placeId: "p1", timestamp: "2026-05-05T11:08:00Z", actor: "Fitri Handayani",
                   action: "unlock", result: "denied", objectName: "Parking Gate", objectType: "door", objectId: "d3", doorId: "d3"),
        AdminEvent(id: "fe6", placeId: "p1", timestamp: "2026-05-05T09:55:00Z", actor: "Dewi Lestari",
                   action: "unlock", result: "failed", objectName: "Meeting Room A", objectType: "door", objectId: "d5", doorId: "d5"),
        AdminEvent(id: "fe7", placeId: "p1", timestamp: "2026-05-04T16:30:00Z", actor: "Eko Prasetyo",
                   action: "unlock", result: "denied", objectName: "Executive Suite", objectType: "door", objectId: "d5", doorId: "d5"),
    ]

    // MARK: - Login Sessions

    static let logins: [UserLogin] = [
        UserLogin(id: "login-001", deviceName: "iPhone 17 Pro", platform: "ios",
                  lastActive: "2026-05-07T12:30:00Z", isCurrent: true),
        UserLogin(id: "login-002", deviceName: "MacBook Pro", platform: "web",
                  lastActive: "2026-05-07T10:15:00Z", isCurrent: false),
        UserLogin(id: "login-003", deviceName: "Samsung Galaxy S25", platform: "android",
                  lastActive: "2026-05-06T18:42:00Z", isCurrent: false),
        UserLogin(id: "login-004", deviceName: "iPad Air", platform: "ipados",
                  lastActive: "2026-05-05T09:20:00Z", isCurrent: false),
        UserLogin(id: "login-005", deviceName: "Windows Desktop", platform: "windows",
                  lastActive: "2026-05-04T14:08:00Z", isCurrent: false),
    ]

    // MARK: - Groups

    static let groups: [AccessGroup] = [
        AccessGroup(id: "grp-001", name: "Lobby Access", description: "Access to lobby and main entrance doors",
              scope: "place", placeId: "p1", memberCount: 12, doorCount: 3, createdAt: "2026-01-15T10:00:00Z"),
        AccessGroup(id: "grp-002", name: "Server Room", description: "Restricted server room access",
              scope: "place", placeId: "p1", memberCount: 4, doorCount: 1, createdAt: "2026-02-01T08:00:00Z"),
        AccessGroup(id: "grp-003", name: "Executive Floor", description: "Executive suite and meeting rooms",
              scope: "organization", placeId: nil, memberCount: 6, doorCount: 2, createdAt: "2026-02-15T09:00:00Z"),
        AccessGroup(id: "grp-004", name: "Parking", description: "Parking gate access",
              scope: "place", placeId: "p1", memberCount: 18, doorCount: 1, createdAt: "2026-03-01T07:00:00Z"),
    ]

    static let groupMembers: [GroupMember] = [
        GroupMember(id: "gm-001", userId: "u1", name: "Ahmad Wijaya", email: "ahmad@mistyislet.com", role: "door_access", addedAt: "2026-01-15T10:00:00Z"),
        GroupMember(id: "gm-002", userId: "u2", name: "Siti Rahayu", email: "siti@mistyislet.com", role: "door_access", addedAt: "2026-01-16T08:00:00Z"),
        GroupMember(id: "gm-003", userId: "u3", name: "Budi Santoso", email: "budi@mistyislet.com", role: "group_manager", addedAt: "2026-01-15T10:00:00Z"),
    ]

    static let groupDoors: [GroupDoor] = [
        GroupDoor(id: "door-001", name: "Main Entrance", status: "online"),
        GroupDoor(id: "door-004", name: "Meeting Room A", status: "online"),
        GroupDoor(id: "door-005", name: "Executive Suite", status: "locked_down"),
    ]

    // MARK: - Team Members & Access Rights

    static let teamMembers: [TeamMember] = [
        TeamMember(id: "tm-001", userId: "u1", name: "Ahmad Wijaya", email: "ahmad@mistyislet.com", addedAt: "2026-01-15T10:00:00Z"),
        TeamMember(id: "tm-002", userId: "u4", name: "Dewi Lestari", email: "dewi@mistyislet.com", addedAt: "2026-02-01T08:00:00Z"),
        TeamMember(id: "tm-003", userId: "u5", name: "Eko Prasetyo", email: "eko@mistyislet.com", addedAt: "2026-02-10T09:00:00Z"),
    ]

    static let accessRights: [AccessRightAssignment] = [
        AccessRightAssignment(id: "ar-001", role: "door_access", scope: "group", scopeName: "Lobby Access", scopeId: "grp-001"),
        AccessRightAssignment(id: "ar-002", role: "place_door_access", scope: "place", scopeName: "Sudirman Hub", scopeId: "p1"),
    ]

    // MARK: - Place Users (for Access Rights overview)

    static let placeUsers: [PlaceUser] = [
        PlaceUser(id: "u1", name: "Ahmad Wijaya", email: "ahmad@example.com", avatar: nil, role: "place_administrator", status: "active", lastActivity: "2026-05-07T10:00:00Z", createdAt: "2025-01-01"),
        PlaceUser(id: "u2", name: "Siti Rahayu", email: "siti@example.com", avatar: nil, role: "group_manager", status: "active", lastActivity: "2026-05-06T15:00:00Z", createdAt: "2025-02-01"),
        PlaceUser(id: "u3", name: "John Chen", email: "john@example.com", avatar: nil, role: "door_access", status: "active", lastActivity: "2026-05-05T09:00:00Z", createdAt: "2025-03-01"),
        PlaceUser(id: "u4", name: "Maria Santos", email: "maria@example.com", avatar: nil, role: "observer", status: "active", lastActivity: nil, createdAt: "2025-04-01"),
    ]

    // MARK: - User Profile

    static let userProfile = UserProfile(
        id: "user-001",
        email: "ahmad@example.com",
        name: "Ahmad Wijaya",
        role: "employee",
        tenantId: "tenant-001",
        organizationName: "Jakarta HQ",
        roleDisplayLabel: "Employee",
        language: "en",
        avatar: nil,
        buildingIds: nil,
        passwordAuthEnabled: true
    )
}
#endif
