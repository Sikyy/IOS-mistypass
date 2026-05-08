import SwiftUI
import Charts
import AVKit

struct DashboardTabView: View {
    @State private var settings = SettingsService.shared

    var body: some View {
        Group {
            if let placeId = settings.selectedPlaceId,
               let placeName = settings.selectedPlaceName {
                DashboardContent(placeId: placeId, placeName: placeName, settings: settings)
            } else {
                ContentUnavailableView(
                    settings.L("dashboard.no_place"),
                    systemImage: "square.grid.2x2",
                    description: Text(settings.L("dashboard.no_place_description"))
                )
            }
        }
        .navigationTitle(settings.L("tab.dashboard"))
    }
}

private struct DashboardContent: View {
    let placeId: String
    let placeName: String
    let settings: SettingsService

    var body: some View {
        List {
            Section(settings.L("dashboard.activity")) {
                NavigationLink {
                    HistoryView()
                } label: {
                    dashboardRow(title: settings.L("history.title"), icon: "clock.arrow.circlepath", color: .green)
                }

                NavigationLink {
                    AdminEventsListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.events"), icon: "list.bullet.clipboard", color: .blue)
                }

                NavigationLink {
                    AdminIncidentsListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.incidents"), icon: "exclamationmark.shield", color: .red)
                }
            }

            Section(settings.L("dashboard.management")) {
                NavigationLink {
                    AdminUsersListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.users"), icon: "person.2", color: .blue)
                }

                NavigationLink {
                    AdminGroupsListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.groups"), icon: "person.2.circle", color: .mint)
                }

                NavigationLink {
                    AdminTeamsListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.teams"), icon: "person.3", color: .indigo)
                }

                NavigationLink {
                    AdminSchedulesListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.schedules"), icon: "calendar.badge.clock", color: .purple)
                }

                NavigationLink {
                    AdminZonesListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.zones"), icon: "map", color: .teal)
                }
            }

            Section(settings.L("dashboard.security")) {
                NavigationLink {
                    AlarmsView()
                } label: {
                    dashboardRow(title: settings.L("dashboard.alarms"), icon: "bell.badge", color: .red)
                }

                NavigationLink {
                    LiveActivityView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("activity.title"), icon: "person.wave.2", color: .green)
                }
            }

            Section(settings.L("dashboard.visitors_section")) {
                NavigationLink {
                    AdminGuestManagementView()
                } label: {
                    dashboardRow(title: settings.L("dashboard.guest_management"), icon: "person.badge.clock", color: .orange)
                }
            }

            Section(settings.L("dashboard.bookings_section")) {
                NavigationLink {
                    BookingsView()
                } label: {
                    dashboardRow(title: settings.L("dashboard.bookings"), icon: "calendar.badge.clock", color: .cyan)
                }
            }

            Section(settings.L("dashboard.credentials_section")) {
                NavigationLink {
                    AdminCardsListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.cards"), icon: "creditcard", color: .orange)
                }

                NavigationLink {
                    AdminDigitalCredentialsListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.digital_credentials"), icon: "key.horizontal", color: .cyan)
                }
            }

            Section(settings.L("dashboard.reports")) {
                NavigationLink {
                    AnalyticsSummaryView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.analytics"), icon: "chart.bar.xaxis", color: .purple)
                }

                NavigationLink {
                    UserPresenceView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.user_presence"), icon: "person.badge.clock", color: .indigo)
                }

                NavigationLink {
                    EventExportView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.export_events"), icon: "square.and.arrow.up", color: .orange)
                }
            }

            Section(settings.L("dashboard.access_control")) {
                NavigationLink {
                    AccessRightsOverviewView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.access_rights"), icon: "person.badge.shield.checkmark", color: .red)
                }
            }

            Section(settings.L("dashboard.my_device")) {
                NavigationLink {
                    DeviceHardwareListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.door_controllers"), icon: "door.left.hand.closed", color: .brandPrimary)
                }

                NavigationLink {
                    GatewayStatusListView(placeId: placeId)
                } label: {
                    dashboardRow(title: settings.L("dashboard.gateways"), icon: "antenna.radiowaves.left.and.right", color: .teal)
                }

                NavigationLink {
                    CameraListView()
                } label: {
                    dashboardRow(title: settings.L("dashboard.cameras"), icon: "video.fill", color: .blue)
                }
            }

            if let orgId = settings.selectedOrgId {
                Section(settings.L("dashboard.org_settings_section")) {
                    NavigationLink {
                        OrgSettingsView(orgId: orgId)
                    } label: {
                        dashboardRow(title: settings.L("dashboard.org_settings"), icon: "gearshape.2", color: .gray)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func dashboardRow(title: String, icon: String, color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
    }
}

// MARK: - My Credentials (moved from Profile Devices tab)

struct MyCredentialsView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.credentials.isEmpty {
                ContentUnavailableView(
                    settings.L("dashboard.no_credentials"),
                    systemImage: "iphone",
                    description: Text(settings.L("dashboard.no_credentials_description"))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.credentials) { credential in
                    CredentialCardView(
                        credential: credential,
                        onRevoke: {
                            Task { await viewModel.revokeCredential(credential) }
                        }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.my_credentials"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchProfile()
        }
    }
}

// MARK: - Credential Card

struct CredentialCardView: View {
    let credential: Credential
    let onRevoke: () -> Void
    private let settings = SettingsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "iphone")
                    .foregroundStyle(.brandPrimary)
                Text(credential.deviceName)
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 8) {
                Text(credential.isActive
                     ? settings.L("profile.active")
                     : settings.L("profile.revoked"))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(credential.isActive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .foregroundStyle(credential.isActive ? .green : .red)
                    .clipShape(Capsule())

                Text(settings.L("profile.secure_enclave"))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }

            HStack {
                Text(String(format: settings.L("profile.expires"), credential.expiresAt?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "—"))
                    .font(.caption)
                    .foregroundStyle(credential.isExpiringSoon ? .orange : .secondary)

                Spacer()

                if credential.isActive {
                    Button(settings.L("profile.revoke"), role: .destructive) {
                        onRevoke()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Active Sessions (moved from Profile Logins tab)

struct ActiveSessionsView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            if viewModel.isLoadingLogins {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.logins.isEmpty {
                ContentUnavailableView(
                    settings.L("profile.no_sessions"),
                    systemImage: "iphone.and.arrow.forward",
                    description: Text(settings.L("profile.no_sessions_description"))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.logins) { login in
                    LoginSessionRow(login: login) {
                        Task { await viewModel.remoteLogout(login) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.active_sessions"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchLogins()
        }
    }
}

struct LoginSessionRow: View {
    let login: UserLogin
    let onLogout: () -> Void
    private let settings = SettingsService.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: platformIcon)
                .font(.title2)
                .foregroundStyle(.brandPrimary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(login.deviceName)
                        .font(.headline)
                    if login.isCurrent {
                        Text(settings.L("dashboard.current"))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                Text(platformLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: settings.L("dashboard.last_active"), login.lastActive))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !login.isCurrent {
                Button(role: .destructive) {
                    onLogout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private var platformIcon: String {
        switch login.platform.lowercased() {
        case "ios": return "iphone"
        case "ipados": return "ipad"
        case "android": return "apps.iphone"
        case "macos", "mac": return "macbook"
        case "windows": return "pc"
        case "web": return "globe"
        default: return "desktopcomputer"
        }
    }

    private var platformLabel: String {
        switch login.platform.lowercased() {
        case "ios": return "iOS"
        case "ipados": return "iPadOS"
        case "android": return "Android"
        case "macos", "mac": return "macOS"
        case "windows": return "Windows"
        case "web": return "Web"
        default: return login.platform
        }
    }
}

// MARK: - Device Hardware List (Door Controllers)

struct DeviceHardwareListView: View {
    let placeId: String
    @State private var doors: [AccessibleDoor] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var settings = SettingsService.shared
    @State private var renameDoorId: String?
    @State private var renameText = ""

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if doors.isEmpty {
                ContentUnavailableView(
                    settings.L("dashboard.no_controllers"),
                    systemImage: "door.left.hand.closed",
                    description: Text(settings.L("dashboard.no_controllers_description"))
                )
                .listRowBackground(Color.clear)
            } else {
                statusSummary

                Section(settings.L("dashboard.all_controllers")) {
                    ForEach(doors) { door in
                        doorHardwareRow(door)
                            .contextMenu {
                                Button {
                                    renameText = door.name
                                    renameDoorId = door.id
                                } label: {
                                    Label(settings.L("dashboard.rename"), systemImage: "pencil")
                                }
                            }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.door_controllers"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadData() }
        .task { await loadData() }
        .alert(settings.L("dashboard.rename"), isPresented: Binding(
            get: { renameDoorId != nil },
            set: { if !$0 { renameDoorId = nil } }
        )) {
            TextField(settings.L("dashboard.enter_new_name"), text: $renameText)
            Button(settings.L("common.cancel"), role: .cancel) { renameDoorId = nil }
            Button(settings.L("common.save")) {
                guard let doorId = renameDoorId, !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task {
                    do {
                        let updated = try await APIService.shared.renameDoor(placeId: placeId, doorId: doorId, name: renameText)
                        if let idx = doors.firstIndex(where: { $0.id == doorId }) {
                            doors[idx] = updated
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    renameDoorId = nil
                }
            }
        }
    }

    private var statusSummary: some View {
        Section {
            let onlineCount = doors.filter { $0.status != "offline" && $0.gatewayStatus == "online" }.count
            let offlineCount = doors.count - onlineCount

            HStack(spacing: 24) {
                Spacer()
                VStack(spacing: 4) {
                    Text("\(onlineCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text(settings.L("doors.online"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(offlineCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(offlineCount > 0 ? .red : .secondary)
                    Text(settings.L("doors.offline_banner"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(doors.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text(settings.L("dashboard.total"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private func doorHardwareRow(_ door: AccessibleDoor) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(door))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(door.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    if let group = door.groupName, !group.isEmpty {
                        Text(group)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let gwName = door.gatewayName {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(gwName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(door.statusDescription)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor(door).opacity(0.15))
                .foregroundStyle(statusColor(door))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ door: AccessibleDoor) -> Color {
        switch door.displayStatus {
        case .onlineUnlockable: return .green
        case .lockedDown: return .orange
        case .offline: return .red
        case .disconnected: return .gray
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.fetchPlaceDoors(placeId: placeId)
            doors = response
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if doors.isEmpty { doors = PreviewData.accessibleDoors }
        #endif
        isLoading = false
    }
}

// MARK: - Gateway Status List

struct GatewayStatusListView: View {
    let placeId: String
    @State private var doors: [AccessibleDoor] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var settings = SettingsService.shared
    @State private var renameGatewayId: String?
    @State private var renameText = ""

    struct GatewayGroup: Identifiable {
        let id: String
        var name: String
        let status: String
        let doors: [AccessibleDoor]
    }

    private var gatewayGroups: [GatewayGroup] {
        let grouped = Dictionary(grouping: doors) { $0.gatewayId ?? $0.gatewayStatus }
        return grouped.map { key, groupDoors in
            let firstDoor = groupDoors.first
            return GatewayGroup(
                id: key,
                name: firstDoor?.gatewayName ?? (settings.L("dashboard.gateway_label") + " " + key),
                status: firstDoor?.gatewayStatus ?? "offline",
                doors: groupDoors
            )
        }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if doors.isEmpty {
                ContentUnavailableView(
                    settings.L("dashboard.no_gateways"),
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text(settings.L("dashboard.no_gateways_description"))
                )
                .listRowBackground(Color.clear)
            } else {
                gatewaySummary

                Section {
                    ForEach(gatewayGroups) { gw in
                        NavigationLink {
                            GatewayDetailView(gateway: gw, placeId: placeId)
                        } label: {
                            gatewayRow(gw)
                        }
                        .contextMenu {
                            Button {
                                renameText = gw.name
                                renameGatewayId = gw.id
                            } label: {
                                Label(settings.L("dashboard.rename"), systemImage: "pencil")
                            }
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.gateways"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadData() }
        .task { await loadData() }
        .alert(settings.L("dashboard.rename"), isPresented: Binding(
            get: { renameGatewayId != nil },
            set: { if !$0 { renameGatewayId = nil } }
        )) {
            TextField(settings.L("dashboard.enter_new_name"), text: $renameText)
            Button(settings.L("common.cancel"), role: .cancel) { renameGatewayId = nil }
            Button(settings.L("common.save")) {
                guard let gwId = renameGatewayId, !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task {
                    do {
                        _ = try await APIService.shared.renameGateway(gatewayId: gwId, name: renameText)
                        await loadData()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    renameGatewayId = nil
                }
            }
        }
    }

    private func gatewayRow(_ gw: GatewayGroup) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(gw.status == "online" ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(gw.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(String(format: settings.L("admin.doors_count"), gw.doors.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(gw.status.capitalized)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((gw.status == "online" ? Color.green : Color.red).opacity(0.15))
                .foregroundStyle(gw.status == "online" ? .green : .red)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private var gatewaySummary: some View {
        Section {
            let onlineGateways = gatewayGroups.filter { $0.status == "online" }.count
            let offlineGateways = gatewayGroups.filter { $0.status != "online" }.count

            HStack(spacing: 24) {
                Spacer()
                VStack(spacing: 4) {
                    Text("\(onlineGateways)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text(settings.L("doors.online"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(offlineGateways)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(offlineGateways > 0 ? .red : .secondary)
                    Text(settings.L("doors.offline_banner"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(gatewayGroups.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text(settings.L("dashboard.total"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.fetchPlaceDoors(placeId: placeId)
            doors = response
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        let hasGatewayInfo = doors.contains { $0.gatewayId != nil }
        if doors.isEmpty || !hasGatewayInfo { doors = PreviewData.accessibleDoors }
        #endif
        isLoading = false
    }
}

// MARK: - Gateway Detail (doors belonging to a gateway)

struct GatewayDetailView: View {
    let gateway: GatewayStatusListView.GatewayGroup
    let placeId: String
    @State private var settings = SettingsService.shared
    @State private var renameDoorId: String?
    @State private var renameText = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundStyle(gateway.status == "online" ? .green : .red)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(gateway.name)
                            .font(.headline)
                        Text(gateway.status.capitalized)
                            .font(.caption)
                            .foregroundStyle(gateway.status == "online" ? .green : .red)
                    }

                    Spacer()

                    Text(String(format: settings.L("admin.doors_count"), gateway.doors.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(settings.L("dashboard.door_controllers")) {
                ForEach(gateway.doors) { door in
                    doorRow(door)
                        .contextMenu {
                            Button {
                                renameText = door.name
                                renameDoorId = door.id
                            } label: {
                                Label(settings.L("dashboard.rename"), systemImage: "pencil")
                            }
                        }
                }
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(gateway.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(settings.L("dashboard.rename"), isPresented: Binding(
            get: { renameDoorId != nil },
            set: { if !$0 { renameDoorId = nil } }
        )) {
            TextField(settings.L("dashboard.enter_new_name"), text: $renameText)
            Button(settings.L("common.cancel"), role: .cancel) { renameDoorId = nil }
            Button(settings.L("common.save")) {
                guard let doorId = renameDoorId, !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task {
                    do {
                        _ = try await APIService.shared.renameDoor(placeId: placeId, doorId: doorId, name: renameText)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    renameDoorId = nil
                }
            }
        }
    }

    private func doorRow(_ door: AccessibleDoor) -> some View {
        HStack(spacing: 12) {
            Image(systemName: door.kind == "turnstile" ? "figure.walk" : "door.left.hand.closed")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(door.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let group = door.groupName, !group.isEmpty {
                    Text(group)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(door.statusDescription)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(doorStatusColor(door).opacity(0.15))
                .foregroundStyle(doorStatusColor(door))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private func doorStatusColor(_ door: AccessibleDoor) -> Color {
        switch door.displayStatus {
        case .onlineUnlockable: return .green
        case .lockedDown: return .orange
        case .offline: return .red
        case .disconnected: return .gray
        }
    }
}

// MARK: - Camera List

struct CameraListView: View {
    @State private var cameras: [Camera] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var settings = SettingsService.shared
    @State private var renameCameraId: String?
    @State private var renameText = ""

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if cameras.isEmpty {
                ContentUnavailableView(
                    settings.L("dashboard.no_cameras"),
                    systemImage: "video.slash",
                    description: Text(settings.L("dashboard.no_cameras_description"))
                )
                .listRowBackground(Color.clear)
            } else {
                cameraSummary

                Section(settings.L("dashboard.all_cameras")) {
                    ForEach(cameras) { camera in
                        NavigationLink {
                            CameraDetailView(camera: camera)
                        } label: {
                            cameraRow(camera)
                        }
                        .contextMenu {
                            Button {
                                renameText = camera.name
                                renameCameraId = camera.id
                            } label: {
                                Label(settings.L("dashboard.rename"), systemImage: "pencil")
                            }
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.cameras"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadCameras() }
        .task { await loadCameras() }
        .alert(settings.L("dashboard.rename"), isPresented: Binding(
            get: { renameCameraId != nil },
            set: { if !$0 { renameCameraId = nil } }
        )) {
            TextField(settings.L("dashboard.enter_new_name"), text: $renameText)
            Button(settings.L("common.cancel"), role: .cancel) { renameCameraId = nil }
            Button(settings.L("common.save")) {
                guard let camId = renameCameraId, !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task {
                    do {
                        let updated = try await APIService.shared.renameCamera(cameraId: camId, name: renameText)
                        if let idx = cameras.firstIndex(where: { $0.id == camId }) {
                            cameras[idx] = updated
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    renameCameraId = nil
                }
            }
        }
    }

    private var cameraSummary: some View {
        Section {
            let onlineCount = cameras.filter { $0.status == "online" }.count
            let offlineCount = cameras.filter { $0.status == "offline" }.count
            let errorCount = cameras.filter { $0.status == "error" }.count

            HStack(spacing: 20) {
                Spacer()
                VStack(spacing: 4) {
                    Text("\(onlineCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text(settings.L("doors.online"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(offlineCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(offlineCount > 0 ? .red : .secondary)
                    Text(settings.L("doors.offline_banner"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if errorCount > 0 {
                    VStack(spacing: 4) {
                        Text("\(errorCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        Text(settings.L("common.error"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 4) {
                    Text("\(cameras.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text(settings.L("dashboard.total"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private func cameraRow(_ camera: Camera) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(cameraStatusColor(camera.status))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(camera.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(camera.vendor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let doorName = camera.doorName {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(doorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(camera.status.capitalized)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(cameraStatusColor(camera.status).opacity(0.15))
                .foregroundStyle(cameraStatusColor(camera.status))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private func cameraStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "online": return .green
        case "offline": return .red
        case "error": return .orange
        default: return .gray
        }
    }

    private func loadCameras() async {
        isLoading = true
        errorMessage = nil
        do {
            cameras = try await APIService.shared.fetchCameras()
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if cameras.isEmpty { cameras = PreviewData.cameras }
        #endif
        isLoading = false
    }
}

// MARK: - Camera Detail

struct CameraDetailView: View {
    let camera: Camera
    @State private var videoLink: CameraVideoLink?
    @State private var isLoadingStream = false
    @State private var isPlaying = false
    @State private var streamError: String?
    @State private var isCapturingSnapshot = false
    @State private var snapshotMessage: String?
    @State private var settings = SettingsService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Video player area
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)

                    if isLoadingStream {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    } else if let link = videoLink, let url = URL(string: link.videoUrl) {
                        CameraPlayerView(url: url, isPlaying: $isPlaying)
                    } else if camera.status == "online" {
                        VStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(settings.L("dashboard.tap_to_stream"))
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .onTapGesture { Task { await loadVideoLink() } }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(settings.L("dashboard.camera_offline"))
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if let error = streamError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                // Controls bar
                if videoLink != nil {
                    HStack(spacing: 20) {
                        Button {
                            isPlaying.toggle()
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                        }

                        Button {
                            Task { await loadVideoLink() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                        }

                        Spacer()

                        Button {
                            Task { await captureSnapshot() }
                        } label: {
                            if isCapturingSnapshot {
                                ProgressView()
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                            }
                        }
                        .disabled(isCapturingSnapshot)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }

                if let msg = snapshotMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 20)
                }

                // Camera info
                VStack(spacing: 0) {
                    cameraInfoSection
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle(camera.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if camera.status == "online" {
                await loadVideoLink()
            }
        }
    }

    private var cameraInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(settings.L("dashboard.camera_info"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            VStack(spacing: 0) {
                infoRow(label: settings.L("dashboard.status"), value: camera.status.capitalized, color: cameraStatusColor(camera.status))
                Divider().padding(.leading, 20)
                infoRow(label: settings.L("dashboard.camera_vendor"), value: camera.vendor)
                if let model = camera.model {
                    Divider().padding(.leading, 20)
                    infoRow(label: settings.L("dashboard.camera_model"), value: model)
                }
                if let ip = camera.ipAddress {
                    Divider().padding(.leading, 20)
                    infoRow(label: settings.L("dashboard.camera_ip"), value: ip)
                }
                if let doorName = camera.doorName {
                    Divider().padding(.leading, 20)
                    infoRow(label: settings.L("dashboard.camera_door"), value: doorName)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
        }
    }

    private func infoRow(label: String, value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            if let color {
                Text(value)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            } else {
                Text(value)
                    .foregroundStyle(.primary)
            }
        }
        .font(.callout)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func cameraStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "online": return .green
        case "offline": return .red
        case "error": return .orange
        default: return .gray
        }
    }

    private func loadVideoLink() async {
        isLoadingStream = true
        streamError = nil
        do {
            videoLink = try await APIService.shared.fetchCameraVideoLink(cameraId: camera.id)
            isPlaying = true
        } catch {
            streamError = error.localizedDescription
        }
        isLoadingStream = false
    }

    private func captureSnapshot() async {
        isCapturingSnapshot = true
        snapshotMessage = nil
        do {
            _ = try await APIService.shared.captureSnapshot(cameraId: camera.id)
            snapshotMessage = settings.L("dashboard.snapshot_captured")
        } catch {
            snapshotMessage = error.localizedDescription
        }
        isCapturingSnapshot = false
    }
}

// MARK: - HLS Video Player

struct CameraPlayerView: UIViewControllerRepresentable {
    let url: URL
    @Binding var isPlaying: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        player.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if isPlaying {
            if controller.player?.timeControlStatus != .playing {
                controller.player?.play()
            }
        } else {
            controller.player?.pause()
        }
    }
}

// MARK: - Analytics Summary

struct AnalyticsSummaryView: View {
    let placeId: String
    @State private var summary: AnalyticsSummary?
    @State private var recentFailed: [AdminEvent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDays = 30
    @State private var settings = SettingsService.shared

    private let dayOptions = [7, 14, 30]

    private var dateRangeText: String {
        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -selectedDays, to: to) ?? to
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return "\(fmt.string(from: from)) – \(fmt.string(from: to))"
    }

    var body: some View {
        List {
            // Report header
            Section {
                VStack(spacing: 4) {
                    Text(settings.selectedPlaceName ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(dateRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            }

            // Period picker
            Section {
                Picker(settings.L("reports.period"), selection: $selectedDays) {
                    ForEach(dayOptions, id: \.self) { days in
                        Text(String(format: settings.L("reports.last_n_days"), days)).tag(days)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if let data = summary {
                kpiSection(data)
                dailyUsageChartSection(data)
                heatmapSection(data)
                weeklyUsersChartSection(data)
                unlockMethodsChartSection(data)
                topDoorsSection(data)
                failedAttemptsSection
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.analytics"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedDays) { _, _ in
            Task { await loadData() }
        }
        .task { await loadData() }
    }

    // MARK: - KPI Cards

    private func kpiSection(_ data: AnalyticsSummary) -> some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                kpiCard(
                    value: "\(data.totalUnlocks)",
                    label: settings.L("reports.total_unlocks"),
                    icon: "lock.open.fill",
                    color: .brandPrimary
                )
                kpiCard(
                    value: "\(data.uniqueUsers)",
                    label: settings.L("reports.unique_users"),
                    icon: "person.2.fill",
                    color: .blue
                )
                kpiCard(
                    value: "\(data.failedAttempts)",
                    label: settings.L("reports.failed_attempts"),
                    icon: "xmark.shield.fill",
                    color: .red
                )
                kpiCard(
                    value: String(format: "%.1f", data.avgDailyUnlocks),
                    label: settings.L("reports.daily_avg"),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func kpiCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title)
                .fontWeight(.heavy)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Daily Usage Chart (bar chart like Kisi)

    private func dailyUsageChartSection(_ data: AnalyticsSummary) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(settings.L("reports.daily_trend"))

                if data.dailyTrend.isEmpty {
                    Text(settings.L("reports.no_data"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    Chart {
                        ForEach(data.dailyTrend) { day in
                            BarMark(
                                x: .value("Date", shortDate(day.date)),
                                y: .value("Unlocks", day.unlocks)
                            )
                            .foregroundStyle(Color.brandPrimary.gradient)
                            .cornerRadius(3)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisValueLabel()
                                .font(.system(size: 8))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            AxisValueLabel()
                                .font(.system(size: 9))
                        }
                    }
                    .frame(height: 160)
                    .padding(.top, 4)

                    // Daily usage table (compact, like Kisi PDF)
                    dailyUsageTable(data)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func dailyUsageTable(_ data: AnalyticsSummary) -> some View {
        VStack(spacing: 0) {
            // Table header
            HStack {
                Text(settings.L("reports.date_col"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(settings.L("reports.unlocks_col"))
                    .frame(width: 60, alignment: .trailing)
                Text(settings.L("reports.users_col"))
                    .frame(width: 50, alignment: .trailing)
                Text(settings.L("reports.failed_col"))
                    .frame(width: 50, alignment: .trailing)
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)

            Divider()

            ForEach(data.dailyTrend.suffix(7)) { day in
                HStack {
                    Text(shortDate(day.date))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(day.unlocks)")
                        .frame(width: 60, alignment: .trailing)
                        .fontWeight(.medium)
                    Text("\(day.uniqueUsers)")
                        .frame(width: 50, alignment: .trailing)
                    Text("\(day.failed)")
                        .frame(width: 50, alignment: .trailing)
                        .foregroundStyle(day.failed > 0 ? .red : .secondary)
                }
                .font(.caption)
                .padding(.vertical, 4)

                Divider()
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Heatmap (unique users × day/hour)

    private func heatmapSection(_ data: AnalyticsSummary) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(settings.L("reports.unlock_heatmap"))

                if let cells = data.heatmap, !cells.isEmpty {
                    let maxVal = cells.map(\.value).max() ?? 1
                    let dayLabels = [
                        settings.L("reports.day_mon"),
                        settings.L("reports.day_tue"),
                        settings.L("reports.day_wed"),
                        settings.L("reports.day_thu"),
                        settings.L("reports.day_fri"),
                        settings.L("reports.day_sat"),
                        settings.L("reports.day_sun")
                    ]

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            // Hour labels
                            HStack(spacing: 2) {
                                Text("")
                                    .frame(width: 28)
                                ForEach(0..<24, id: \.self) { h in
                                    Text("\(h)")
                                        .font(.system(size: 7))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 14)
                                }
                            }

                            // Day rows
                            ForEach(0..<7, id: \.self) { day in
                                HStack(spacing: 2) {
                                    Text(dayLabels[day])
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28, alignment: .trailing)

                                    ForEach(0..<24, id: \.self) { hour in
                                        let val = cells.first { $0.dayOfWeek == day && $0.hour == hour }?.value ?? 0
                                        let intensity = maxVal > 0 ? Double(val) / Double(maxVal) : 0
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(heatmapColor(intensity))
                                            .frame(width: 14, height: 14)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Legend
                    HStack(spacing: 4) {
                        Spacer()
                        Text(settings.L("reports.less"))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatmapColor(level))
                                .frame(width: 12, height: 12)
                        }
                        Text(settings.L("reports.more"))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(settings.L("reports.no_data"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func heatmapColor(_ intensity: Double) -> Color {
        if intensity <= 0 {
            return Color(.systemGray5)
        }
        return Color.brandPrimary.opacity(0.15 + intensity * 0.85)
    }

    // MARK: - Weekly Unique Users (bar chart)

    private func weeklyUsersChartSection(_ data: AnalyticsSummary) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(settings.L("reports.weekly_users"))

                if let weeks = data.weeklyUsers, !weeks.isEmpty {
                    Chart(weeks) { week in
                        BarMark(
                            x: .value("Week", shortWeekLabel(week.weekStart)),
                            y: .value("Users", week.uniqueUsers)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(4)

                        if weeks.count <= 8 {
                            PointMark(
                                x: .value("Week", shortWeekLabel(week.weekStart)),
                                y: .value("Users", week.uniqueUsers)
                            )
                            .annotation(position: .top, spacing: 4) {
                                Text("\(week.uniqueUsers)")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.clear)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.system(size: 8))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            AxisValueLabel()
                                .font(.system(size: 9))
                        }
                    }
                    .frame(height: 140)
                } else {
                    Text(settings.L("reports.no_data"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func shortWeekLabel(_ isoDate: String) -> String {
        if isoDate.count >= 10 {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            if let d = fmt.date(from: String(isoDate.prefix(10))) {
                fmt.dateFormat = "MM/dd"
                return fmt.string(from: d)
            }
        }
        return String(isoDate.suffix(5))
    }

    // MARK: - Unlock Methods (donut chart)

    private func unlockMethodsChartSection(_ data: AnalyticsSummary) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(settings.L("reports.unlock_methods"))

                if data.unlocksByMethod.isEmpty {
                    Text(settings.L("reports.no_data"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    let total = data.unlocksByMethod.reduce(0) { $0 + $1.count }

                    HStack(spacing: 16) {
                        // Donut chart
                        Chart(data.unlocksByMethod, id: \.method) { item in
                            SectorMark(
                                angle: .value("Count", item.count),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(methodColor(item.method))
                            .cornerRadius(4)
                        }
                        .chartBackground { _ in
                            VStack(spacing: 2) {
                                Text("\(total)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text(settings.L("dashboard.total"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 120, height: 120)

                        // Legend
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(data.unlocksByMethod, id: \.method) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(methodColor(item.method))
                                        .frame(width: 8, height: 8)
                                    Text(methodLabel(item.method))
                                        .font(.caption)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Top 5 Most Used Doors

    private func topDoorsSection(_ data: AnalyticsSummary) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(settings.L("reports.top_doors"))

                if data.topDoors.isEmpty {
                    Text(settings.L("reports.no_data"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    let maxCount = data.topDoors.first?.count ?? 1

                    VStack(spacing: 0) {
                        // Table header
                        HStack {
                            Text("")
                                .frame(width: 20)
                            Text(settings.L("reports.door_col"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(settings.L("reports.unlocks_col"))
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)

                        Divider()

                        ForEach(Array(data.topDoors.prefix(5).enumerated()), id: \.element.id) { index, door in
                            VStack(spacing: 4) {
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.brandPrimary)
                                        .frame(width: 20)
                                    Text(door.name)
                                        .font(.caption)
                                    Spacer()
                                    Text("\(door.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 4)

                                // Progress bar
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.brandPrimary.opacity(0.15))
                                        .frame(height: 4)
                                        .overlay(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.brandPrimary)
                                                .frame(
                                                    width: geo.size.width * CGFloat(door.count) / CGFloat(maxCount),
                                                    height: 4
                                                )
                                        }
                                }
                                .frame(height: 4)
                                .padding(.leading, 20)
                            }

                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Recent Failed Attempts

    private var failedAttemptsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                    Text(settings.L("reports.recent_failed"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                if recentFailed.isEmpty {
                    Text(settings.L("reports.no_failed"))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 0) {
                        // Table header
                        HStack {
                            Text(settings.L("reports.time_col"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(settings.L("reports.user_col"))
                                .frame(width: 80, alignment: .leading)
                            Text(settings.L("reports.door_col"))
                                .frame(width: 80, alignment: .trailing)
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)

                        Divider()

                        ForEach(recentFailed.prefix(10)) { event in
                            HStack {
                                Text(event.displayTime)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(event.actor)
                                    .frame(width: 80, alignment: .leading)
                                    .lineLimit(1)
                                Text(event.objectName)
                                    .frame(width: 80, alignment: .trailing)
                                    .lineLimit(1)
                            }
                            .font(.caption)
                            .padding(.vertical, 3)

                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.brandPrimary)
                .frame(width: 3, height: 14)
            Text(text)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func shortDate(_ isoDate: String) -> String {
        // "2025-06-01" → "Jun 01"
        if isoDate.count >= 10 {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            if let d = fmt.date(from: String(isoDate.prefix(10))) {
                fmt.dateFormat = "MM/dd"
                return fmt.string(from: d)
            }
        }
        return String(isoDate.suffix(5))
    }

    private func methodColor(_ method: String) -> Color {
        switch method.lowercased() {
        case "mobile": return .blue
        case "ble": return .cyan
        case "card": return .orange
        case "pin": return .purple
        case "qr": return .green
        case "visitor": return .mint
        case "remote": return .indigo
        default: return .gray
        }
    }

    private func methodLabel(_ method: String) -> String {
        method.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let summaryResult = APIService.shared.fetchAnalyticsSummary(placeId: placeId, days: selectedDays)
            async let eventsResult = APIService.shared.fetchAdminEvents(placeId: placeId)

            summary = try await summaryResult
            let allEvents = try await eventsResult
            recentFailed = allEvents.filter {
                $0.result.lowercased() == "denied" || $0.result.lowercased() == "failed"
            }
        } catch {
            #if DEBUG
            summary = PreviewData.analyticsSummary
            recentFailed = PreviewData.failedEvents
            #else
            errorMessage = error.localizedDescription
            #endif
        }
        isLoading = false
    }
}

// MARK: - User Presence

struct UserPresenceView: View {
    let placeId: String
    @State private var records: [UserPresenceRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDays = 30
    @State private var searchText = ""
    @State private var sortOrder: PresenceSortOrder = .daysDesc
    @State private var settings = SettingsService.shared

    private let dayOptions = [7, 14, 30]

    private enum PresenceSortOrder {
        case daysDesc, daysAsc, unlocksDesc, nameAsc
    }

    private var filteredRecords: [UserPresenceRecord] {
        var result = records
        if !searchText.isEmpty {
            result = result.filter {
                $0.userName.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .daysDesc: result.sort { $0.daysPresent > $1.daysPresent }
        case .daysAsc: result.sort { $0.daysPresent < $1.daysPresent }
        case .unlocksDesc: result.sort { $0.totalUnlocks > $1.totalUnlocks }
        case .nameAsc: result.sort { $0.userName.localizedCompare($1.userName) == .orderedAscending }
        }
        return result
    }

    // Aggregate weekday stats across all users
    private var weekdayTotals: [Int] {
        var totals = [0, 0, 0, 0, 0, 0, 0]
        for record in records {
            if let breakdown = record.weekdayBreakdown, breakdown.count == 7 {
                for i in 0..<7 { totals[i] += breakdown[i] }
            }
        }
        return totals
    }

    var body: some View {
        List {
            // Period picker
            Section {
                Picker(settings.L("reports.period"), selection: $selectedDays) {
                    ForEach(dayOptions, id: \.self) { days in
                        Text(String(format: settings.L("reports.last_n_days"), days)).tag(days)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if records.isEmpty {
                ContentUnavailableView(
                    settings.L("reports.no_presence_data"),
                    systemImage: "person.badge.clock",
                    description: Text(settings.L("reports.no_presence_description"))
                )
                .listRowBackground(Color.clear)
            } else {
                presenceKPISection
                weekdayChartSection
                presenceHeatmapSection
                presenceTableSection
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.user_presence"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: settings.L("admin.search_users"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { sortOrder = .daysDesc } label: {
                        Label(settings.L("reports.sort_days_desc"), systemImage: sortOrder == .daysDesc ? "checkmark" : "")
                    }
                    Button { sortOrder = .unlocksDesc } label: {
                        Label(settings.L("reports.sort_unlocks_desc"), systemImage: sortOrder == .unlocksDesc ? "checkmark" : "")
                    }
                    Button { sortOrder = .nameAsc } label: {
                        Label(settings.L("reports.sort_name"), systemImage: sortOrder == .nameAsc ? "checkmark" : "")
                    }
                    Button { sortOrder = .daysAsc } label: {
                        Label(settings.L("reports.sort_days_asc"), systemImage: sortOrder == .daysAsc ? "checkmark" : "")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
        .onChange(of: selectedDays) { _, _ in
            Task { await loadData() }
        }
        .task { await loadData() }
    }

    // MARK: - KPI Summary

    private var presenceKPISection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                presenceKPI(
                    value: "\(records.count)",
                    label: settings.L("reports.total_users"),
                    color: .blue
                )
                presenceKPI(
                    value: String(format: "%.0f", records.isEmpty ? 0 : Double(records.map(\.daysPresent).reduce(0, +)) / Double(records.count)),
                    label: settings.L("reports.avg_days"),
                    color: .green
                )
                presenceKPI(
                    value: "\(records.map(\.totalUnlocks).reduce(0, +))",
                    label: settings.L("reports.total_unlocks"),
                    color: .brandPrimary
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func presenceKPI(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Weekday Attendance Chart

    private var weekdayChartSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                presenceSectionLabel(settings.L("reports.weekday_activity"))

                let dayLabels = [
                    settings.L("reports.day_mon"),
                    settings.L("reports.day_tue"),
                    settings.L("reports.day_wed"),
                    settings.L("reports.day_thu"),
                    settings.L("reports.day_fri"),
                    settings.L("reports.day_sat"),
                    settings.L("reports.day_sun")
                ]
                let totals = weekdayTotals

                if totals.reduce(0, +) > 0 {
                    Chart {
                        ForEach(0..<7, id: \.self) { i in
                            BarMark(
                                x: .value("Day", dayLabels[i]),
                                y: .value("Unlocks", totals[i])
                            )
                            .foregroundStyle(i < 5 ? Color.brandPrimary.gradient : Color.orange.gradient)
                            .cornerRadius(4)

                            PointMark(
                                x: .value("Day", dayLabels[i]),
                                y: .value("Unlocks", totals[i])
                            )
                            .annotation(position: .top, spacing: 4) {
                                Text("\(totals[i])")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.clear)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.system(size: 9))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            AxisValueLabel()
                                .font(.system(size: 9))
                        }
                    }
                    .frame(height: 140)

                    Text(settings.L("reports.weekday_note"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(settings.L("reports.no_data"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Per-User Weekday Heatmap

    private var presenceHeatmapSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                presenceSectionLabel(settings.L("reports.attendance_heatmap"))

                let displayRecords = Array(filteredRecords.prefix(15))
                let dayLabels = [
                    settings.L("reports.day_mon"),
                    settings.L("reports.day_tue"),
                    settings.L("reports.day_wed"),
                    settings.L("reports.day_thu"),
                    settings.L("reports.day_fri"),
                    settings.L("reports.day_sat"),
                    settings.L("reports.day_sun")
                ]

                if displayRecords.contains(where: { $0.weekdayBreakdown != nil }) {
                    let allValues = displayRecords.compactMap(\.weekdayBreakdown).flatMap { $0 }
                    let maxVal = allValues.max() ?? 1

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            // Column headers (weekday labels)
                            HStack(spacing: 2) {
                                Text("")
                                    .frame(width: 70)
                                ForEach(0..<7, id: \.self) { d in
                                    Text(dayLabels[d])
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28)
                                }
                            }

                            // User rows
                            ForEach(displayRecords) { record in
                                HStack(spacing: 2) {
                                    Text(record.userName)
                                        .font(.system(size: 8))
                                        .lineLimit(1)
                                        .frame(width: 70, alignment: .trailing)

                                    if let breakdown = record.weekdayBreakdown, breakdown.count == 7 {
                                        ForEach(0..<7, id: \.self) { d in
                                            let val = breakdown[d]
                                            let intensity = maxVal > 0 ? Double(val) / Double(maxVal) : 0
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(presenceHeatColor(intensity))
                                                    .frame(width: 28, height: 18)
                                                if val > 0 {
                                                    Text("\(val)")
                                                        .font(.system(size: 7))
                                                        .foregroundStyle(intensity > 0.5 ? .white : .primary)
                                                }
                                            }
                                        }
                                    } else {
                                        ForEach(0..<7, id: \.self) { _ in
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(.systemGray5))
                                                .frame(width: 28, height: 18)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Legend
                    HStack(spacing: 4) {
                        Spacer()
                        Text(settings.L("reports.less"))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(presenceHeatColor(level))
                                .frame(width: 12, height: 12)
                        }
                        Text(settings.L("reports.more"))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(settings.L("reports.no_data"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func presenceHeatColor(_ intensity: Double) -> Color {
        if intensity <= 0 { return Color(.systemGray5) }
        return Color.green.opacity(0.15 + intensity * 0.85)
    }

    // MARK: - User Detail Table

    private var presenceTableSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                presenceSectionLabel(settings.L("reports.user_details"))

                // Table header
                VStack(spacing: 0) {
                    HStack {
                        Text(settings.L("reports.user_col"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(settings.L("reports.days_col"))
                            .frame(width: 40, alignment: .trailing)
                        Text(settings.L("reports.unlocks_col"))
                            .frame(width: 55, alignment: .trailing)
                        Text(settings.L("reports.first_seen"))
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)

                    Divider()

                    ForEach(filteredRecords) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(record.userName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(record.email)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(record.daysPresent)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(attendanceColor(record))
                                .frame(width: 40, alignment: .trailing)

                            Text("\(record.totalUnlocks)")
                                .font(.caption)
                                .frame(width: 55, alignment: .trailing)

                            Text(shortDateOnly(record.firstUnlock))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .padding(.vertical, 4)

                        Divider()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func attendanceColor(_ record: UserPresenceRecord) -> Color {
        let ratio = Double(record.daysPresent) / Double(max(selectedDays, 1))
        if ratio >= 0.8 { return .green }
        if ratio >= 0.5 { return .orange }
        return .red
    }

    private func shortDateOnly(_ isoDate: String?) -> String {
        guard let date = isoDate, date.count >= 10 else { return "—" }
        return String(date.prefix(10).suffix(5))  // "MM-DD"
    }

    private func presenceSectionLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.brandPrimary)
                .frame(width: 3, height: 14)
            Text(text)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            records = try await APIService.shared.fetchUserPresence(placeId: placeId, days: selectedDays)
        } catch {
            #if DEBUG
            records = PreviewData.userPresenceRecords
            #else
            errorMessage = error.localizedDescription
            #endif
        }
        isLoading = false
    }
}

// MARK: - Event Export

struct EventExportView: View {
    let placeId: String
    @State private var fromDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    @State private var toDate = Date()
    @State private var selectedFormat = "csv"
    @State private var selectedType: ReportType = .weeklyAnalytics
    @State private var isExporting = false
    @State private var exportResult: ReportExportResponse?
    @State private var errorMessage: String?
    @State private var settings = SettingsService.shared

    enum ReportType: String, CaseIterable {
        case weeklyAnalytics = "weekly_analytics"
        case events = "events"
        case unlockStats = "unlock_stats"
        case userPresence = "user_presence"
        case incidents = "incidents"
        case hardwareSummary = "hardware_summary"

        @MainActor func label(_ s: SettingsService) -> String {
            switch self {
            case .weeklyAnalytics: return s.L("reports.type_weekly")
            case .events: return s.L("dashboard.events")
            case .unlockStats: return s.L("reports.type_unlock_stats")
            case .userPresence: return s.L("dashboard.user_presence")
            case .incidents: return s.L("dashboard.incidents")
            case .hardwareSummary: return s.L("reports.type_hardware")
            }
        }

        func icon() -> String {
            switch self {
            case .weeklyAnalytics: return "chart.bar.doc.horizontal"
            case .events: return "list.bullet.clipboard"
            case .unlockStats: return "chart.bar.xaxis"
            case .userPresence: return "person.badge.clock"
            case .incidents: return "exclamationmark.shield"
            case .hardwareSummary: return "cpu"
            }
        }

        @MainActor func description(_ s: SettingsService) -> String {
            switch self {
            case .weeklyAnalytics: return s.L("reports.desc_weekly")
            case .events: return s.L("reports.desc_events")
            case .unlockStats: return s.L("reports.desc_unlock_stats")
            case .userPresence: return s.L("reports.desc_user_presence")
            case .incidents: return s.L("reports.desc_incidents")
            case .hardwareSummary: return s.L("reports.desc_hardware")
            }
        }
    }

    private var dateRangeText: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return "\(fmt.string(from: fromDate)) – \(fmt.string(from: toDate))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Report type dropdown — Liquid Glass style
                reportTypeCard

                // Date range card
                dateRangeCard

                // Format selection card
                formatCard

                // Export button
                exportButton

                // Result
                if let result = exportResult {
                    exportResultCard(result)
                }

                if let error = errorMessage {
                    errorCard(error)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.L("dashboard.export_events"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Report Type (Liquid Glass dropdown)

    private var reportTypeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.L("reports.report_type"))
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Menu dropdown — Liquid Glass
            Menu {
                ForEach(ReportType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedType = type
                        }
                    } label: {
                        Label(type.label(settings), systemImage: type.icon())
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedType.icon())
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.brandPrimary.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedType.label(settings))
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text(selectedType.description(settings))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Date Range Card

    private var dateRangeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.L("reports.date_range"))
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                DatePicker(
                    settings.L("reports.from"),
                    selection: $fromDate,
                    in: ...toDate,
                    displayedComponents: .date
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider()
                    .padding(.leading, 14)

                DatePicker(
                    settings.L("reports.to"),
                    selection: $toDate,
                    in: fromDate...Date(),
                    displayedComponents: .date
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )

            // Quick presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetChip(settings.L("reports.preset_7d"), days: 7)
                    presetChip(settings.L("reports.preset_14d"), days: 14)
                    presetChip(settings.L("reports.preset_30d"), days: 30)
                    presetChip(settings.L("reports.preset_90d"), days: 90)
                }
            }
        }
    }

    private func presetChip(_ label: String, days: Int) -> some View {
        let isSelected = Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day == days
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                toDate = Date()
                fromDate = Calendar.current.date(byAdding: .day, value: -days, to: toDate)!
            }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? AnyShapeStyle(Color.brandPrimary)
                        : AnyShapeStyle(.regularMaterial)
                    , in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .strokeBorder(.quaternary, lineWidth: isSelected ? 0 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Format Card

    private var formatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.L("reports.format"))
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 10) {
                Picker(settings.L("reports.format"), selection: $selectedFormat) {
                    Label("CSV", systemImage: "tablecells").tag("csv")
                    Label("PDF", systemImage: "doc.richtext").tag("pdf")
                }
                .pickerStyle(.segmented)

                Text(selectedFormat == "pdf"
                     ? settings.L("reports.format_pdf_note")
                     : settings.L("reports.format_csv_note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            Task { await exportReport() }
        } label: {
            HStack(spacing: 8) {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                }
                Label(settings.L("reports.export"), systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.brandPrimary.gradient, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .opacity(isExporting ? 0.7 : 1)
    }

    // MARK: - Result & Error Cards

    private func exportResultCard(_ result: ReportExportResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(settings.L("reports.export_ready"), systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.green)

            if let url = URL(string: result.url) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.L("reports.download_report"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(result.url)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.brandPrimary)
                }
            }

            if let expires = result.expiresAt {
                Text(String(format: settings.L("reports.link_expires"), expires))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private func errorCard(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Export

    private func exportReport() async {
        isExporting = true
        errorMessage = nil
        exportResult = nil

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        do {
            exportResult = try await APIService.shared.exportReport(
                placeId: placeId,
                type: selectedType.rawValue,
                from: formatter.string(from: fromDate),
                to: formatter.string(from: toDate),
                format: selectedFormat
            )
        } catch {
            #if DEBUG
            exportResult = ReportExportResponse(
                url: "https://api.mistyislet.com/reports/demo-\(selectedType.rawValue).\(selectedFormat)",
                expiresAt: "2026-05-08T10:00:00Z",
                format: selectedFormat
            )
            #else
            errorMessage = error.localizedDescription
            #endif
        }
        isExporting = false
    }
}
