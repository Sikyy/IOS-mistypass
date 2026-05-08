import SwiftUI

struct AlarmsView: View {
    @State private var viewModel = AlarmsViewModel()
    @State private var settings = SettingsService.shared
    @State private var selectedTab = 0

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.alarms.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else {
                alarmSummary

                Picker("", selection: $selectedTab) {
                    Text(settings.L("alarms.open")).tag(0)
                    Text(settings.L("alarms.all")).tag(1)
                    Text(settings.L("alarms.schedules")).tag(2)
                    Text(settings.L("alarms.calendar")).tag(3)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                switch selectedTab {
                case 0:
                    openAlarmsSection
                case 2:
                    schedulesSection
                case 3:
                    calendarSection
                default:
                    allAlarmsSection
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("alarms.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isStreaming {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text(settings.L("alarms.live"))
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .refreshable {
            await viewModel.fetchAlarms()
            await viewModel.fetchSchedules()
            await viewModel.fetchCalendar()
        }
        .task {
            await viewModel.fetchAlarms()
            await viewModel.fetchSchedules()
            await viewModel.fetchCalendar()
            viewModel.startStreaming()
        }
        .onDisappear {
            viewModel.stopStreaming()
        }
    }

    // MARK: - Summary

    private var alarmSummary: some View {
        Section {
            HStack(spacing: 20) {
                Spacer()
                alarmKPI(value: "\(viewModel.openAlarms.count)", label: settings.L("alarms.open"), color: .red)
                alarmKPI(value: "\(viewModel.criticalCount)", label: settings.L("alarms.critical"), color: .purple)
                alarmKPI(value: "\(viewModel.highCount)", label: settings.L("alarms.high"), color: .orange)
                alarmKPI(value: "\(viewModel.alarms.count)", label: settings.L("dashboard.total"), color: .primary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private func alarmKPI(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Open Alarms

    private var openAlarmsSection: some View {
        Group {
            if viewModel.openAlarms.isEmpty {
                Section {
                    ContentUnavailableView(
                        settings.L("alarms.no_open"),
                        systemImage: "checkmark.shield",
                        description: Text(settings.L("alarms.all_clear"))
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section(settings.L("alarms.open")) {
                    ForEach(viewModel.openAlarms) { alarm in
                        alarmRow(alarm)
                    }
                }
            }
        }
    }

    // MARK: - All Alarms

    private var allAlarmsSection: some View {
        Section {
            ForEach(viewModel.alarms) { alarm in
                alarmRow(alarm)
            }
        }
    }

    // MARK: - Alarm Row

    private func alarmRow(_ alarm: Alarm) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(severityColor(alarm.severity))
                    .frame(width: 10, height: 10)
                Text(alarm.typeLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                statusBadge(alarm.status)
            }

            HStack(spacing: 12) {
                Label(alarm.location, systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(alarm.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if alarm.isOpen {
                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.updateStatus(alarm, status: "acknowledged") }
                    } label: {
                        Label(settings.L("alarms.acknowledge"), systemImage: "hand.raised")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.blue)

                    Button {
                        Task { await viewModel.updateStatus(alarm, status: "resolved") }
                    } label: {
                        Label(settings.L("alarms.resolve"), systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.green)

                    Button {
                        Task { await viewModel.updateStatus(alarm, status: "false_positive") }
                    } label: {
                        Text(settings.L("alarms.false_positive"))
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .blue
        default: return .gray
        }
    }

    private func statusBadge(_ status: String) -> some View {
        let color: Color = switch status.lowercased() {
        case "open": .red
        case "acknowledged": .blue
        case "investigating": .orange
        case "resolved": .green
        case "false_positive": .gray
        default: .secondary
        }
        return Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Schedules

    private var schedulesSection: some View {
        Group {
            if viewModel.schedules.isEmpty {
                Section {
                    Text(settings.L("alarms.no_schedules"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            } else {
                Section(settings.L("alarms.schedules")) {
                    ForEach(viewModel.schedules) { schedule in
                        scheduleRow(schedule)
                    }
                }
            }
        }
    }

    private func scheduleRow(_ schedule: AlarmSchedule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(schedule.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(schedule.enabled ? settings.L("alarms.enabled") : settings.L("alarms.disabled"))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((schedule.enabled ? Color.green : Color.gray).opacity(0.15))
                    .foregroundStyle(schedule.enabled ? .green : .gray)
                    .clipShape(Capsule())
            }

            Text("\(schedule.startTime) – \(schedule.endTime)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(schedule.daysOfWeek, id: \.self) { day in
                    Text(dayLabel(day))
                        .font(.system(size: 10))
                        .fontWeight(.medium)
                        .frame(width: 24, height: 20)
                        .background(Color.brandPrimary.opacity(0.1))
                        .foregroundStyle(.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            if !schedule.alarmTypes.isEmpty {
                Text(schedule.alarmTypes.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func dayLabel(_ day: Int) -> String {
        switch day {
        case 0: return "Mo"
        case 1: return "Tu"
        case 2: return "We"
        case 3: return "Th"
        case 4: return "Fr"
        case 5: return "Sa"
        case 6: return "Su"
        default: return "?"
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        Group {
            if viewModel.calendarEntries.isEmpty {
                Section {
                    Text(settings.L("alarms.no_calendar"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            } else {
                ForEach(0..<7, id: \.self) { day in
                    let dayEntries = viewModel.calendarEntries.filter { $0.dayOfWeek == day }
                    if !dayEntries.isEmpty {
                        Section(dayLabel(day)) {
                            ForEach(dayEntries) { entry in
                                calendarEntryRow(entry)
                            }
                        }
                    }
                }
            }
        }
    }

    private func calendarEntryRow(_ entry: AlarmCalendarEntry) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.red.opacity(0.7))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(entry.startTime) – \(entry.endTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !entry.alarmTypes.isEmpty {
                    Text(entry.alarmTypes.map { $0.replacingOccurrences(of: "_", with: " ").capitalized }.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
