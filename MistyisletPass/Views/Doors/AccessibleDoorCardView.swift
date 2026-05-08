import SwiftUI

struct AccessibleDoorCardView: View {
    let door: AccessibleDoor
    var placeId: String?
    let isBLEReady: Bool
    let onHoldStart: () -> Void
    let onHoldProgress: (Double) -> Void
    let onHoldComplete: () -> Void
    let onHoldCancel: () -> Void
    let onToggleFavorite: () -> Void

    @State private var holdProgress: Double = 0
    @State private var isHolding = false
    @State private var holdTimer: Timer?
    @State private var showDetails = false
    @Namespace private var glassNS
    private let settings = SettingsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: status icon + name + BLE + favorite
            HStack(spacing: 8) {
                statusIcon
                Text(door.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if isBLEReady {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.brandPrimary)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
                Button {
                    onToggleFavorite()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: door.isFavorite ? "star.fill" : "star")
                        Text(door.isFavorite ? settings.L("doors.saved") : settings.L("doors.save"))
                            .font(.caption2)
                    }
                    .foregroundStyle(door.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Status tags
            HStack(spacing: 6) {
                ForEach(statusTags, id: \.label) { tag in
                    Text(tag.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tag.color.opacity(0.15))
                        .foregroundStyle(tag.color)
                        .clipShape(Capsule())
                }
            }

            // Location info
            if let group = door.groupName {
                Text(group)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Unlock button or status
            if door.canUnlock {
                holdToUnlockButton
            } else {
                Text(door.statusDescription)
                    .font(.callout)
                    .foregroundStyle(Color.orange)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .glassEffectUnion(id: "card", namespace: glassNS)
        .contentShape(Rectangle())
        .onTapGesture { showDetails = true }
        .sheet(isPresented: $showDetails) {
            DoorDetailsSheet(door: door, placeId: placeId)
                .presentationDetents([.medium, .large])
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(door.name), \(door.statusDescription)")
        .accessibilityHint(door.canUnlock ? "Long press to unlock, tap for details" : "Tap for details")
    }

    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.title3)
            .foregroundStyle(statusColor)
    }

    private var statusIconName: String {
        switch door.displayStatus {
        case .onlineUnlockable: return kindIcon(open: true)
        case .lockedDown: return "lock.fill"
        case .offline: return "wifi.slash"
        case .disconnected: return "bolt.slash"
        }
    }

    private func kindIcon(open: Bool) -> String {
        switch door.kind?.lowercased() {
        case "elevator": return "arrow.up.arrow.down"
        case "gate": return open ? "car.side.front.open" : "car.side.lock"
        case "turnstile": return "figure.walk.arrival"
        case "printer": return "printer"
        default: return open ? "door.left.hand.open" : "door.left.hand.closed"
        }
    }

    private var statusColor: Color {
        switch door.displayStatus {
        case .onlineUnlockable: return .blue
        case .lockedDown: return .red
        case .offline: return .gray
        case .disconnected: return .orange
        }
    }

    private struct StatusTag {
        let label: String
        let color: Color
    }

    private var statusTags: [StatusTag] {
        var tags: [StatusTag] = []
        switch door.displayStatus {
        case .onlineUnlockable:
            tags.append(StatusTag(label: settings.L("doors.online"), color: .blue))
            if door.canUnlock { tags.append(StatusTag(label: settings.L("doors.unlockable"), color: .green)) }
        case .lockedDown:
            tags.append(StatusTag(label: settings.L("doors.lockdown"), color: .red))
        case .offline:
            tags.append(StatusTag(label: settings.L("doors.offline"), color: .yellow))
        case .disconnected:
            tags.append(StatusTag(label: settings.L("doors.disconnected"), color: .gray))
        }
        return tags
    }

    private var holdToUnlockButton: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.brandPrimary.opacity(0.3))
                    .frame(width: geo.size.width * holdProgress, height: 44)
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                Image(systemName: holdProgress >= 1.0 ? "lock.open.fill" : "lock.fill")
                Text(holdProgress >= 1.0 ? settings.L("doors.release_to_unlock") : settings.L("doors.hold_to_unlock"))
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(holdProgress > 0 ? .brandPrimary : .primary)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
        .glassEffectUnion(id: "card", namespace: glassNS)
        .gesture(
            LongPressGesture(minimumDuration: 0.01)
                .onChanged { _ in startHold() }
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onEnded { _ in endHold() }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in if isHolding { endHold() } }
        )
        .accessibilityAction {
            onHoldStart()
            onHoldComplete()
        }
        .onDisappear {
            holdTimer?.invalidate()
            holdTimer = nil
        }
    }

    private func startHold() {
        guard !isHolding else { return }
        isHolding = true
        holdProgress = 0
        onHoldStart()

        let interval: TimeInterval = 0.02
        let steps = Constants.UI.unlockHoldDuration / interval
        var currentStep = 0.0

        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            let progress = currentStep / steps
            holdProgress = min(progress, 1.0)
            onHoldProgress(holdProgress)
            if progress >= 1.0 { timer.invalidate() }
        }
    }

    private func endHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        if holdProgress >= 1.0 {
            onHoldComplete()
        } else {
            onHoldCancel()
        }
        withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
        isHolding = false
    }
}

// MARK: - Door Details Sheet

struct DoorDetailsSheet: View {
    let door: AccessibleDoor
    var placeId: String?
    var onLockdownChanged: ((Bool) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsService.shared
    @State private var isLockedDown: Bool
    @State private var isTogglingLockdown = false
    @State private var showLockdownConfirm = false
    @State private var restrictions: [DoorRestriction] = []
    @State private var schedules: [UnlockSchedule] = []
    @State private var isLoadingExtra = false
    @State private var errorMessage: String?

    init(door: AccessibleDoor, placeId: String? = nil, onLockdownChanged: ((Bool) -> Void)? = nil) {
        self.door = door
        self.placeId = placeId
        self.onLockdownChanged = onLockdownChanged
        self._isLockedDown = State(initialValue: door.status == "locked_down")
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                infoSection
                if placeId != nil { lockdownSection }
                if !restrictions.isEmpty { restrictionsSection }
                if !schedules.isEmpty { schedulesSection }
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(settings.L("doors.details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.L("common.done")) { dismiss() }
                }
            }
            .task { await loadExtras() }
            .confirmationDialog(
                settings.L("doors.confirm_lockdown"),
                isPresented: $showLockdownConfirm,
                titleVisibility: .visible
            ) {
                Button(isLockedDown ? settings.L("doors.disable_lockdown") : settings.L("doors.enable_lockdown"),
                       role: isLockedDown ? nil : .destructive) {
                    Task { await toggleLockdown() }
                }
            } message: {
                Text(isLockedDown
                     ? settings.L("doors.confirm_disable_lockdown_msg")
                     : settings.L("doors.confirm_enable_lockdown_msg"))
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(door.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 8, height: 8)
                    Text(isLockedDown ? settings.L("doors.lockdown") : door.statusDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var infoSection: some View {
        Section(settings.L("doors.info")) {
            if let group = door.groupName {
                detailRow(icon: "mappin.circle", label: settings.L("doors.location"), value: group)
            }
            detailRow(icon: "antenna.radiowaves.left.and.right",
                      label: settings.L("doors.gateway"), value: door.gatewayStatus.capitalized)
            if let lastUnlock = door.lastUnlockAt {
                detailRow(icon: "clock", label: settings.L("doors.last_unlocked"), value: lastUnlock)
            }
            if let kind = door.kind {
                detailRow(icon: "door.left.hand.closed", label: settings.L("doors.type"), value: kind.capitalized)
            }
            detailRow(icon: door.canUnlock ? "lock.open" : "lock",
                      label: settings.L("doors.access"), value: door.canUnlock ? settings.L("doors.unlockable") : settings.L("doors.no_access"))
        }
    }

    private var lockdownSection: some View {
        Section {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(isLockedDown ? .red : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.L("doors.lockdown"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(isLockedDown ? settings.L("doors.lockdown_active") : settings.L("doors.lockdown_inactive"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isTogglingLockdown {
                    ProgressView()
                } else {
                    Toggle("", isOn: Binding(
                        get: { isLockedDown },
                        set: { _ in showLockdownConfirm = true }
                    ))
                    .labelsHidden()
                    .tint(.red)
                }
            }
        } header: {
            Text(settings.L("doors.security"))
        }
    }

    private var restrictionsSection: some View {
        Section(settings.L("doors.restrictions")) {
            ForEach(restrictions) { restriction in
                HStack(spacing: 12) {
                    Image(systemName: restriction.typeIcon)
                        .foregroundStyle(restriction.isEnabled ? .orange : .secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(restriction.typeLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if restriction.type == "geofence", let radius = restriction.radiusMeters {
                            Text(String(format: settings.L("doors.geofence_radius"), radius))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(restriction.isEnabled ? settings.L("common.enabled") : settings.L("common.disabled"))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((restriction.isEnabled ? Color.green : Color.gray).opacity(0.15))
                        .foregroundStyle(restriction.isEnabled ? .green : .gray)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var schedulesSection: some View {
        Section(settings.L("doors.schedules")) {
            ForEach(schedules) { schedule in
                HStack(spacing: 12) {
                    Image(systemName: schedule.typeIcon)
                        .foregroundStyle(schedule.typeColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(schedule.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(schedule.startTime) – \(schedule.endTime)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(schedule.daysDisplay)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusDotColor: Color {
        if isLockedDown { return .red }
        switch door.displayStatus {
        case .onlineUnlockable: return .green
        case .lockedDown: return .red
        case .offline, .disconnected: return .gray
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
            }
            Spacer()
        }
    }

    private func toggleLockdown() async {
        guard let placeId else { return }
        isTogglingLockdown = true
        do {
            if isLockedDown {
                try await APIService.shared.disableDoorLockdown(placeId: placeId, doorId: door.id)
            } else {
                try await APIService.shared.enableDoorLockdown(placeId: placeId, doorId: door.id)
            }
            isLockedDown.toggle()
            onLockdownChanged?(isLockedDown)
        } catch {
            errorMessage = error.localizedDescription
        }
        isTogglingLockdown = false
    }

    private func loadExtras() async {
        guard let placeId else { return }
        isLoadingExtra = true
        do {
            async let r = APIService.shared.fetchDoorRestrictions(placeId: placeId, doorId: door.id)
            async let s = APIService.shared.fetchDoorSchedules(placeId: placeId, doorId: door.id)
            restrictions = try await r
            schedules = try await s
        } catch {
            // Non-critical — just don't show these sections
        }
        #if DEBUG
        if restrictions.isEmpty {
            restrictions = [
                DoorRestriction(id: "r1", type: "geofence", latitude: 37.7749, longitude: -122.4194, radiusMeters: 200, isEnabled: true),
                DoorRestriction(id: "r2", type: "reader_proximity", latitude: nil, longitude: nil, radiusMeters: nil, isEnabled: false)
            ]
        }
        if schedules.isEmpty {
            schedules = [
                UnlockSchedule(id: "ds1", name: "Business Hours", description: "Mon–Fri unlock", scheduleType: "unlock",
                               startTime: "08:00", endTime: "18:00", daysOfWeek: [1, 2, 3, 4, 5], isEnabled: true, doorId: door.id, doorName: door.name),
                UnlockSchedule(id: "ds2", name: "Weekend Deny", description: "No weekend access", scheduleType: "access_denial",
                               startTime: "00:00", endTime: "23:59", daysOfWeek: [0, 6], isEnabled: true, doorId: door.id, doorName: door.name)
            ]
        }
        #endif
        isLoadingExtra = false
    }
}
