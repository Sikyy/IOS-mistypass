import XCTest
@testable import MistyisletPass

final class AdminModelDecodingTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - AdminEvent

    func testDecodeAdminEvent() throws {
        let json = """
        {
            "id": "evt-001",
            "place_id": "place-001",
            "timestamp": "2026-05-03T10:23:00Z",
            "actor": "user@example.com",
            "action": "unlock",
            "result": "granted",
            "object_name": "Main Entrance",
            "object_type": "door",
            "object_id": "door-001",
            "door_id": "door-001"
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(AdminEvent.self, from: json)
        XCTAssertEqual(event.id, "evt-001")
        XCTAssertEqual(event.actor, "user@example.com")
        XCTAssertEqual(event.resultIcon, "checkmark.circle.fill")
        XCTAssertEqual(event.resultColor, "green")
    }

    func testAdminEventDeniedColors() throws {
        let json = """
        {
            "id": "evt-002",
            "place_id": "place-001",
            "timestamp": "2026-05-03T10:23:00Z",
            "actor": "user@example.com",
            "action": "unlock",
            "result": "denied",
            "object_name": "Server Room",
            "object_type": "door"
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(AdminEvent.self, from: json)
        XCTAssertEqual(event.resultIcon, "xmark.circle.fill")
        XCTAssertEqual(event.resultColor, "red")
    }

    func testDecodeAdminEventDetailFields() throws {
        let json = """
        {
            "id": "evt-003",
            "place_id": "place-001",
            "timestamp": "2026-05-03T10:23:00Z",
            "actor": "user@example.com",
            "action": "unlock",
            "result": "denied",
            "object_name": "Server Room",
            "object_type": "door",
            "object_id": "door-002",
            "door_id": "door-002",
            "area_id": "area-001",
            "gateway_id": "gateway-001",
            "detail": "Denied by policy",
            "relation": "same_actor_same_door"
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(AdminEvent.self, from: json)
        XCTAssertEqual(event.areaId, "area-001")
        XCTAssertEqual(event.gatewayId, "gateway-001")
        XCTAssertEqual(event.detail, "Denied by policy")
        XCTAssertEqual(event.relation, "same_actor_same_door")
    }

    func testDecodeRelatedEventsResponse() throws {
        let json = """
        {
            "event_id": "evt-source",
            "items": [
                {
                    "id": "evt-related",
                    "place_id": "place-001",
                    "timestamp": "2026-05-03T10:25:00Z",
                    "actor": "user@example.com",
                    "action": "unlock",
                    "result": "denied",
                    "object_name": "Server Room",
                    "object_type": "door",
                    "relation": "same_actor"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RelatedEventsResponse.self, from: json)
        XCTAssertEqual(response.eventId, "evt-source")
        XCTAssertEqual(response.items.first?.id, "evt-related")
        XCTAssertEqual(response.items.first?.relation, "same_actor")
    }

    // MARK: - Incident

    func testDecodeIncident() throws {
        let json = """
        {
            "id": "inc-001",
            "place_id": "place-001",
            "type": "forced_entry",
            "state": "active",
            "status": "open",
            "severity": "critical",
            "description": "Door forced open",
            "created_at": "2026-05-03T08:00:00Z",
            "subject_type": "door",
            "subject_id": "door-001",
            "count": 2
        }
        """.data(using: .utf8)!

        let incident = try decoder.decode(Incident.self, from: json)
        XCTAssertEqual(incident.id, "inc-001")
        XCTAssertEqual(incident.severityColor, "red")
        XCTAssertEqual(incident.subjectType, "door")
        XCTAssertEqual(incident.subjectId, "door-001")
        XCTAssertEqual(incident.count, 2)
    }

    func testIncidentSeverityColors() throws {
        let cases: [(String, String)] = [
            ("critical", "red"),
            ("high", "orange"),
            ("medium", "yellow"),
            ("low", "blue"),
            ("unknown", "gray"),
        ]

        for (severity, expectedColor) in cases {
            let json = """
            {
                "id": "inc-\(severity)",
                "place_id": "p1",
                "type": "test",
                "state": "active",
                "status": "open",
                "severity": "\(severity)",
                "description": "Test",
                "created_at": "2026-05-03T08:00:00Z"
            }
            """.data(using: .utf8)!

            let incident = try decoder.decode(Incident.self, from: json)
            XCTAssertEqual(incident.severityColor, expectedColor, "Severity \(severity) should be \(expectedColor)")
        }
    }

    func testDecodeIncidentDetailEvents() throws {
        let json = """
        {
            "id": "inc_deny_door-001",
            "place_id": "place-001",
            "type": "access_denied",
            "state": "open",
            "status": "active",
            "severity": "medium",
            "subject_type": "door",
            "subject_id": "door-001",
            "description": "Access denied at door-001",
            "created_at": "2026-05-03T08:00:00Z",
            "count": 2,
            "events": [
                {
                    "event_id": "evt-001",
                    "actor": "user@example.com",
                    "timestamp": "2026-05-03T08:00:00Z"
                }
            ]
        }
        """.data(using: .utf8)!

        let incident = try decoder.decode(Incident.self, from: json)
        XCTAssertEqual(incident.events?.first?.eventId, "evt-001")
        XCTAssertEqual(incident.events?.first?.id, "evt-001")
    }

    func testDecodeIncidentOccurrencesResponse() throws {
        let json = """
        {
            "incident_id": "inc_deny_door-001",
            "items": [
                {
                    "event_id": "evt-001",
                    "actor": "user@example.com",
                    "door_id": "door-001",
                    "gateway_id": "gateway-001",
                    "result": "denied",
                    "occurred_at": "2026-05-03T08:00:00Z"
                }
            ],
            "pagination": {
                "offset": 0,
                "limit": 1,
                "total": 1
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(IncidentOccurrencesResponse.self, from: json)
        XCTAssertEqual(response.incidentId, "inc_deny_door-001")
        XCTAssertEqual(response.items.first?.doorId, "door-001")
        XCTAssertEqual(response.items.first?.id, "evt-001")
        XCTAssertEqual(response.pagination?.total, 1)
    }

    // MARK: - AnalyticsSummary

    func testDecodeAnalyticsSummary() throws {
        let json = """
        {
            "total_unlocks": 1500,
            "unique_users": 42,
            "failed_attempts": 15,
            "avg_daily_unlocks": 50.0,
            "period_days": 30,
            "top_doors": [
                {"id": "d1", "name": "Main", "count": 500}
            ],
            "unlocks_by_method": [
                {"method": "mobile", "count": 800},
                {"method": "card", "count": 700}
            ],
            "daily_trend": [
                {"date": "2026-05-01", "unlocks": 55, "unique_users": 20, "failed": 1}
            ],
            "heatmap": [
                {"day_of_week": 0, "hour": 9, "value": 15}
            ],
            "weekly_users": [
                {"week_start": "2026-04-28", "unique_users": 35}
            ]
        }
        """.data(using: .utf8)!

        let summary = try decoder.decode(AnalyticsSummary.self, from: json)
        XCTAssertEqual(summary.totalUnlocks, 1500)
        XCTAssertEqual(summary.uniqueUsers, 42)
        XCTAssertEqual(summary.failedAttempts, 15)
        XCTAssertEqual(summary.topDoors.count, 1)
        XCTAssertEqual(summary.unlocksByMethod.count, 2)
        XCTAssertEqual(summary.dailyTrend.count, 1)
        XCTAssertEqual(summary.heatmap?.count, 1)
        XCTAssertEqual(summary.weeklyUsers?.count, 1)
    }

    func testDecodeAnalyticsSummaryWithoutOptionals() throws {
        let json = """
        {
            "total_unlocks": 100,
            "unique_users": 10,
            "failed_attempts": 2,
            "avg_daily_unlocks": 3.3,
            "period_days": 30,
            "top_doors": [],
            "unlocks_by_method": [],
            "daily_trend": []
        }
        """.data(using: .utf8)!

        let summary = try decoder.decode(AnalyticsSummary.self, from: json)
        XCTAssertNil(summary.heatmap)
        XCTAssertNil(summary.weeklyUsers)
    }

    // MARK: - HeatmapCell

    func testHeatmapCellId() throws {
        let json = """
        {"day_of_week": 2, "hour": 14, "value": 8}
        """.data(using: .utf8)!

        let cell = try decoder.decode(HeatmapCell.self, from: json)
        XCTAssertEqual(cell.id, "2-14")
        XCTAssertEqual(cell.dayOfWeek, 2)
        XCTAssertEqual(cell.hour, 14)
        XCTAssertEqual(cell.value, 8)
    }

    // MARK: - AdminListResponse

    func testDecodeAdminListResponse() throws {
        let json = """
        {
            "items": [
                {"id": "d1", "name": "Door 1", "count": 10},
                {"id": "d2", "name": "Door 2", "count": 20}
            ],
            "total": 2
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(AdminListResponse<DoorUsage>.self, from: json)
        XCTAssertEqual(response.items.count, 2)
        XCTAssertEqual(response.total, 2)
    }

    func testDecodeAdminListResponseWithoutTotal() throws {
        let json = """
        {
            "items": []
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(AdminListResponse<DoorUsage>.self, from: json)
        XCTAssertTrue(response.items.isEmpty)
        XCTAssertNil(response.total)
    }

    // MARK: - UnlockSchedule

    func testDecodeUnlockSchedule() throws {
        let json = """
        {
            "id": "sched-001",
            "name": "Business Hours",
            "description": "Weekday access",
            "schedule_type": "unlock",
            "start_time": "09:00",
            "end_time": "18:00",
            "days_of_week": [1, 2, 3, 4, 5]
        }
        """.data(using: .utf8)!

        let schedule = try decoder.decode(UnlockSchedule.self, from: json)
        XCTAssertEqual(schedule.daysDisplay, "Mon, Tue, Wed, Thu, Fri")
        XCTAssertEqual(schedule.typeIcon, "lock.open")
    }

    // MARK: - ReportExportResponse

    func testDecodeReportExport() throws {
        let json = """
        {
            "url": "https://cdn.mistyislet.com/reports/123.csv",
            "expires_at": "2026-05-04T00:00:00Z",
            "format": "csv"
        }
        """.data(using: .utf8)!

        let export = try decoder.decode(ReportExportResponse.self, from: json)
        XCTAssertEqual(export.format, "csv")
        XCTAssertNotNil(export.expiresAt)
    }
}
