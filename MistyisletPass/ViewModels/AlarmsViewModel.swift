import Foundation

@MainActor @Observable
final class AlarmsViewModel {
    var alarms: [Alarm] = []
    var schedules: [AlarmSchedule] = []
    var calendarEntries: [AlarmCalendarEntry] = []
    var isLoading = false
    var isStreaming = false
    var errorMessage: String?
    private var streamTask: Task<Void, Never>?

    var openAlarms: [Alarm] {
        alarms.filter { $0.isOpen }
    }

    var resolvedAlarms: [Alarm] {
        alarms.filter { !$0.isOpen }
    }

    var criticalCount: Int {
        openAlarms.filter { $0.severity.lowercased() == "critical" }.count
    }

    var highCount: Int {
        openAlarms.filter { $0.severity.lowercased() == "high" }.count
    }

    func fetchAlarms() async {
        guard !Constants.AppEnvironment.isPreview else { return }
        isLoading = true
        errorMessage = nil
        do {
            alarms = try await APIService.shared.fetchAlarms()
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if alarms.isEmpty {
            let now = ISO8601DateFormatter().string(from: Date())
            let earlier = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300))
            alarms = [
                Alarm(id: "alm-1", tenantId: "t1", buildingId: "b1", areaId: "a1",
                      doorId: "d1", type: "forced_entry", severity: "critical",
                      location: "Main Entrance", status: "open", createdAt: now),
                Alarm(id: "alm-2", tenantId: "t1", buildingId: "b1", areaId: "a2",
                      doorId: "d2", type: "door_held_open", severity: "high",
                      location: "Fire Exit B", status: "open", createdAt: earlier),
                Alarm(id: "alm-3", tenantId: "t1", buildingId: "b1", areaId: "a3",
                      doorId: "d3", type: "access_denied", severity: "medium",
                      location: "Server Room", status: "acknowledged", createdAt: earlier),
                Alarm(id: "alm-4", tenantId: "t1", buildingId: "b1", areaId: "a1",
                      doorId: "d1", type: "tamper_detected", severity: "low",
                      location: "Parking Gate", status: "resolved", createdAt: earlier),
            ]
        }
        #endif
        isLoading = false
    }

    func fetchSchedules() async {
        guard !Constants.AppEnvironment.isPreview else { return }
        do {
            schedules = try await APIService.shared.fetchAlarmSchedules()
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if schedules.isEmpty {
            schedules = [
                AlarmSchedule(id: "as-1", tenantId: "t1", name: "After Hours",
                              description: "Weekday nights", daysOfWeek: [0,1,2,3,4],
                              startTime: "20:00", endTime: "07:00", timezone: "Asia/Jakarta",
                              alarmTypes: ["forced_entry", "tamper_detected"], enabled: true,
                              createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"),
                AlarmSchedule(id: "as-2", tenantId: "t1", name: "Weekend Full",
                              description: "All day weekends", daysOfWeek: [5,6],
                              startTime: "00:00", endTime: "23:59", timezone: "Asia/Jakarta",
                              alarmTypes: ["forced_entry", "door_held_open", "tamper_detected"],
                              enabled: true,
                              createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"),
            ]
        }
        #endif
    }

    func fetchCalendar() async {
        do {
            calendarEntries = try await APIService.shared.fetchAlarmCalendar()
        } catch {
            // Calendar is supplementary — don't show error for it
        }
    }

    func startStreaming() {
        guard streamTask == nil else { return }
        streamTask = Task {
            var retryDelay: TimeInterval = 2
            let maxDelay: TimeInterval = 60
            let maxRetries = 10
            var retryCount = 0

            while !Task.isCancelled && retryCount < maxRetries {
                isStreaming = true
                retryDelay = 2
                do {
                    for try await event in APIService.shared.streamAlarms() {
                        if Task.isCancelled { break }
                        handleStreamEvent(event)
                        retryCount = 0
                    }
                } catch {
                    isStreaming = false
                }
                if Task.isCancelled { break }
                retryCount += 1
                try? await Task.sleep(for: .seconds(retryDelay))
                retryDelay = min(retryDelay * 2, maxDelay)
            }
            isStreaming = false
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    private func handleStreamEvent(_ event: AlarmStreamEvent) {
        switch event.type {
        case "new_alarm":
            if !alarms.contains(where: { $0.id == event.alarm.id }) {
                alarms.insert(event.alarm, at: 0)
            }
        case "status_changed", "resolved":
            if let idx = alarms.firstIndex(where: { $0.id == event.alarm.id }) {
                alarms[idx] = event.alarm
            }
        default:
            if let idx = alarms.firstIndex(where: { $0.id == event.alarm.id }) {
                alarms[idx] = event.alarm
            }
        }
    }

    func updateStatus(_ alarm: Alarm, status: String) async {
        do {
            let updated = try await APIService.shared.updateAlarmStatus(alarmId: alarm.id, status: status)
            if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
                alarms[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
