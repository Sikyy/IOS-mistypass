import SwiftUI

// MARK: - Generic Admin List ViewModel

@MainActor @Observable
final class AdminListViewModel<T: Identifiable & Sendable> {
    var items: [T] = []
    var isLoading = false
    var errorMessage: String?

    func load(_ fetch: @Sendable () async throws -> [T]) async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Events List

struct AdminEventsListView: View {
    let placeId: String
    @State private var vm = AdminListViewModel<AdminEvent>()
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            if vm.isLoading {
                loadingRow
            } else if vm.items.isEmpty {
                emptyView(title: settings.L("admin.no_events"), icon: "list.bullet.clipboard")
            } else {
                ForEach(vm.items) { event in
                    eventRow(event)
                }
            }

            errorSection(vm.errorMessage)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.events"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func loadData() async {
        await vm.load { try await APIService.shared.fetchAdminEvents(placeId: placeId) }
    }

    private func eventRow(_ event: AdminEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.resultIcon)
                .foregroundStyle(colorForResult(event.resultColor))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(event.actor) · \(event.action)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(event.objectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(event.displayTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Incidents List

struct AdminIncidentsListView: View {
    let placeId: String
    @State private var vm = AdminListViewModel<Incident>()
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            if vm.isLoading {
                loadingRow
            } else if vm.items.isEmpty {
                emptyView(title: settings.L("admin.no_incidents"), icon: "exclamationmark.shield")
            } else {
                ForEach(vm.items) { incident in
                    incidentRow(incident)
                }
            }

            errorSection(vm.errorMessage)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.incidents"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func loadData() async {
        await vm.load { try await APIService.shared.fetchAdminIncidents(placeId: placeId) }
    }

    private func incidentRow(_ incident: Incident) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorForResult(incident.severityColor))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(incident.type.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(incident.severity.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colorForResult(incident.severityColor).opacity(0.15))
                        .foregroundStyle(colorForResult(incident.severityColor))
                        .clipShape(Capsule())
                }
                Text(incident.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(incident.state.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Users List

struct AdminUsersListView: View {
    let placeId: String
    @State private var vm = AdminListViewModel<PlaceUser>()
    @State private var settings = SettingsService.shared
    @State private var searchText = ""
    @State private var showInvite = false

    var filteredUsers: [PlaceUser] {
        if searchText.isEmpty { return vm.items }
        return vm.items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if vm.isLoading {
                loadingRow
            } else if filteredUsers.isEmpty {
                emptyView(title: settings.L("admin.no_users"), icon: "person.2")
            } else {
                ForEach(filteredUsers) { user in
                    NavigationLink {
                        UserDetailView(
                            placeId: placeId,
                            user: user,
                            onUpdate: { updated in
                                if let idx = vm.items.firstIndex(where: { $0.id == updated.id }) {
                                    vm.items[idx] = updated
                                }
                            },
                            onRemove: {
                                vm.items.removeAll { $0.id == user.id }
                            }
                        )
                    } label: {
                        userRow(user)
                    }
                }
            }

            errorSection(vm.errorMessage)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.users"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: settings.L("admin.search_users"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showInvite = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showInvite) {
            InviteUserSheet(placeId: placeId) { user in
                vm.items.insert(user, at: 0)
            }
        }
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func loadData() async {
        await vm.load { try await APIService.shared.fetchAdminUsers(placeId: placeId) }
    }

    private func userRow(_ user: PlaceUser) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(String(user.name.prefix(1)).uppercased())
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(user.role.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Teams List

struct AdminTeamsListView: View {
    let placeId: String
    @State private var vm = AdminListViewModel<Team>()
    @State private var settings = SettingsService.shared
    @State private var showCreateSheet = false

    var body: some View {
        List {
            if vm.isLoading {
                loadingRow
            } else if vm.items.isEmpty {
                emptyView(title: settings.L("admin.no_teams"), icon: "person.3")
            } else {
                ForEach(vm.items) { team in
                    NavigationLink {
                        TeamDetailView(placeId: placeId, team: team) {
                            Task { await loadData() }
                        }
                    } label: {
                        teamRow(team)
                    }
                }
                .onDelete { offsets in
                    Task { await deleteTeams(at: offsets) }
                }
            }

            errorSection(vm.errorMessage)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.teams"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTeamSheet(placeId: placeId) { team in
                vm.items.insert(team, at: 0)
            }
        }
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func loadData() async {
        await vm.load { try await APIService.shared.fetchAdminTeams(placeId: placeId) }
    }

    private func deleteTeams(at offsets: IndexSet) async {
        let teams = offsets.map { vm.items[$0] }
        for team in teams {
            do {
                try await APIService.shared.deleteTeam(placeId: placeId, teamId: team.id)
                vm.items.removeAll { $0.id == team.id }
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        }
    }

    private func teamRow(_ team: Team) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .foregroundStyle(.indigo)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !team.description.isEmpty {
                    Text(team.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(team.memberCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "person.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Schedules List

struct AdminSchedulesListView: View {
    let placeId: String
    @State private var vm = AdminListViewModel<UnlockSchedule>()
    @State private var settings = SettingsService.shared
    @State private var showCreate = false
    @State private var editingSchedule: UnlockSchedule?
    @State private var pendingDelete: UnlockSchedule?

    var body: some View {
        List {
            if vm.isLoading {
                loadingRow
            } else if vm.items.isEmpty {
                emptyView(title: settings.L("admin.no_schedules"), icon: "calendar.badge.clock")
            } else {
                ForEach(vm.items) { schedule in
                    scheduleRow(schedule)
                        .contentShape(Rectangle())
                        .onTapGesture { editingSchedule = schedule }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDelete = schedule
                            } label: {
                                Label(settings.L("admin.remove"), systemImage: "trash")
                            }
                        }
                }
            }

            errorSection(vm.errorMessage)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.schedules"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .refreshable { await loadData() }
        .task { await loadData() }
        .sheet(isPresented: $showCreate) {
            ScheduleFormSheet(placeId: placeId) { _ in await loadData() }
        }
        .sheet(item: $editingSchedule) { schedule in
            ScheduleFormSheet(placeId: placeId, editing: schedule) { _ in await loadData() }
        }
        .confirmationDialog(
            settings.L("schedules.confirm_delete"),
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let schedule = pendingDelete {
                Button(settings.L("common.delete"), role: .destructive) {
                    Task { await deleteSchedule(schedule) }
                }
            }
        } message: {
            if let schedule = pendingDelete {
                Text(String(format: settings.L("schedules.confirm_delete_msg"), schedule.name))
            }
        }
    }

    private func loadData() async {
        await vm.load { try await APIService.shared.fetchAdminSchedules(placeId: placeId) }
    }

    private func deleteSchedule(_ schedule: UnlockSchedule) async {
        do {
            try await APIService.shared.deleteSchedule(placeId: placeId, scheduleId: schedule.id)
            vm.items.removeAll { $0.id == schedule.id }
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }

    private func scheduleRow(_ schedule: UnlockSchedule) -> some View {
        HStack(spacing: 12) {
            Image(systemName: schedule.typeIcon)
                .foregroundStyle(schedule.typeColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(schedule.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(schedule.scheduleType.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(schedule.typeColor.opacity(0.15))
                        .foregroundStyle(schedule.typeColor)
                        .clipShape(Capsule())
                }
                Text("\(schedule.startTime) – \(schedule.endTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(schedule.daysDisplay)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Schedule Create/Edit Form

struct ScheduleFormSheet: View {
    let placeId: String
    var editing: UnlockSchedule?
    var onSaved: ((UnlockSchedule) async -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsService.shared
    @State private var name = ""
    @State private var description = ""
    @State private var scheduleType = "unlock"
    @State private var startTime = "08:00"
    @State private var endTime = "18:00"
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5]
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let scheduleTypes = ["unlock", "access_denial", "first_to_arrive", "holiday"]
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.L("schedules.details")) {
                    TextField(settings.L("schedules.name"), text: $name)
                    TextField(settings.L("schedules.description"), text: $description)

                    if editing == nil {
                        Picker(settings.L("schedules.type"), selection: $scheduleType) {
                            ForEach(scheduleTypes, id: \.self) { type in
                                Text(type.replacingOccurrences(of: "_", with: " ").capitalized).tag(type)
                            }
                        }
                    }
                }

                Section(settings.L("schedules.time_range")) {
                    HStack {
                        Text(settings.L("schedules.start"))
                        Spacer()
                        TextField("08:00", text: $startTime)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    HStack {
                        Text(settings.L("schedules.end"))
                        Spacer()
                        TextField("18:00", text: $endTime)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }

                Section(settings.L("schedules.days")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(0..<7, id: \.self) { day in
                            Button {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            } label: {
                                Text(dayLabels[day])
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedDays.contains(day) ? Color.brandPrimary : Color(.tertiarySystemBackground))
                                    .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        Button(settings.L("schedules.weekdays")) {
                            selectedDays = [1, 2, 3, 4, 5]
                        }
                        .font(.caption)
                        Button(settings.L("schedules.weekends")) {
                            selectedDays = [0, 6]
                        }
                        .font(.caption)
                        Button(settings.L("schedules.every_day")) {
                            selectedDays = Set(0..<7)
                        }
                        .font(.caption)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(editing != nil ? settings.L("schedules.edit") : settings.L("schedules.create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.L("common.save")) {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onAppear {
                if let s = editing {
                    name = s.name
                    description = s.description
                    scheduleType = s.scheduleType
                    startTime = s.startTime
                    endTime = s.endTime
                    selectedDays = Set(s.daysOfWeek)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let days = selectedDays.sorted()
        do {
            let result: UnlockSchedule
            if let s = editing {
                result = try await APIService.shared.updateSchedule(
                    placeId: placeId, scheduleId: s.id,
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    startTime: startTime, endTime: endTime, daysOfWeek: days
                )
            } else {
                result = try await APIService.shared.createSchedule(
                    placeId: placeId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    scheduleType: scheduleType,
                    startTime: startTime, endTime: endTime, daysOfWeek: days
                )
            }
            await onSaved?(result)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Zones List

struct AdminZonesListView: View {
    let placeId: String
    @State private var vm = AdminListViewModel<Zone>()
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            if vm.isLoading {
                loadingRow
            } else if vm.items.isEmpty {
                emptyView(title: settings.L("admin.no_zones"), icon: "map")
            } else {
                ForEach(vm.items) { zone in
                    zoneRow(zone)
                }
            }

            errorSection(vm.errorMessage)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.zones"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func loadData() async {
        await vm.load { try await APIService.shared.fetchAdminZones(placeId: placeId) }
    }

    private func zoneRow(_ zone: Zone) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "map.fill")
                .foregroundStyle(.teal)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(zone.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !zone.description.isEmpty {
                    Text(zone.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(String(format: settings.L("admin.doors_count"), zone.doorCount))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Cards List

// MARK: - Cards List (User-centric)

struct AdminCardsListView: View {
    let placeId: String
    @State private var vm = AdminListViewModel<CardAssignment>()
    @State private var settings = SettingsService.shared
    @State private var searchText = ""

    private var userGroups: [(name: String, email: String, userId: String, cards: [CardAssignment])] {
        var grouped: [String: (name: String, email: String, cards: [CardAssignment])] = [:]
        for card in vm.items {
            let key = card.userId ?? "unassigned"
            let name = (card.userName ?? "").isEmpty ? settings.L("admin.unassigned") : card.userName!
            let email = card.userEmail ?? ""
            grouped[key, default: (name: name, email: email, cards: [])].cards.append(card)
        }
        var result = grouped.map { (name: $0.value.name, email: $0.value.email, userId: $0.key, cards: $0.value.cards) }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { group in
                group.name.lowercased().contains(q) ||
                group.email.lowercased().contains(q) ||
                group.cards.contains { $0.cardUid.lowercased().contains(q) }
            }
        }
        return result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            if vm.isLoading {
                loadingRow
            } else if userGroups.isEmpty {
                emptyView(title: settings.L("admin.no_cards"), icon: "creditcard")
            } else {
                ForEach(userGroups, id: \.userId) { group in
                    NavigationLink {
                        UserCardsDetailView(placeId: placeId, userName: group.name, cards: group.cards, onRefresh: { await loadData() })
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(String(group.name.prefix(1)).uppercased())
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !group.email.isEmpty {
                                    Text(group.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(String(format: settings.L("admin.cards_count"), group.cards.count))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            errorSection(vm.errorMessage)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.cards"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: settings.L("admin.search_users"))
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func loadData() async {
        await vm.load { try await APIService.shared.fetchAdminCards(placeId: placeId) }
    }
}

// MARK: - User Cards Detail

private struct UserCardsDetailView: View {
    let placeId: String
    let userName: String
    @State var cards: [CardAssignment]
    let onRefresh: () async -> Void
    @State private var settings = SettingsService.shared
    @State private var cardToUnbind: CardAssignment?
    @State private var actionError: String?

    var body: some View {
        List {
            ForEach(cards) { card in
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.deviceName ?? settings.L("nfc.card_label"))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(card.cardUid)
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            statusBadge(card.status)
                        }

                        Divider()

                        if let num = card.cardNumber, !num.isEmpty {
                            LabeledContent(settings.L("nfc.card_number"), value: num)
                                .font(.caption)
                        }
                        if let issued = card.issuedAt {
                            LabeledContent(settings.L("history.time"), value: String(issued.prefix(10)))
                                .font(.caption)
                        }
                        if let exp = card.expiresAt {
                            LabeledContent(settings.L("reports.to"), value: String(exp.prefix(10)))
                                .font(.caption)
                        }

                        if card.status == "active" {
                            Divider()
                            Button(role: .destructive) {
                                cardToUnbind = card
                            } label: {
                                Label(settings.L("nfc.unbind"), systemImage: "minus.circle")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let err = actionError {
                Section { Text(err).foregroundStyle(.red).font(.caption) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(userName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(settings.L("nfc.unbind_confirm"), isPresented: Binding(
            get: { cardToUnbind != nil },
            set: { if !$0 { cardToUnbind = nil } }
        ), presenting: cardToUnbind) { card in
            Button(settings.L("nfc.unbind"), role: .destructive) {
                Task {
                    do {
                        try await APIService.shared.unassignCard(placeId: placeId, cardUid: card.cardUid)
                        cards.removeAll { $0.id == card.id }
                        await onRefresh()
                    } catch {
                        actionError = error.localizedDescription
                    }
                }
            }
        } message: { _ in
            Text(settings.L("nfc.unbind_message"))
        }
    }

    private func statusBadge(_ status: String) -> some View {
        let color: Color = switch status {
        case "active": .green
        case "suspended": .orange
        case "revoked": .red
        default: .secondary
        }
        return Text(status.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Digital Credentials List (User-centric)

struct AdminDigitalCredentialsListView: View {
    let placeId: String
    @State private var vm = AdminListViewModel<DigitalCredential>()
    @State private var settings = SettingsService.shared
    @State private var searchText = ""

    private var userGroups: [(name: String, email: String, creds: [DigitalCredential])] {
        var grouped: [String: (name: String, creds: [DigitalCredential])] = [:]
        for cred in vm.items {
            let key = cred.recipientEmail ?? cred.userEmail ?? "unknown"
            let name = (cred.userName ?? "").isEmpty ? key : cred.userName!
            grouped[key, default: (name: name, creds: [])].creds.append(cred)
        }
        var result = grouped.map { (name: $0.value.name, email: $0.key, creds: $0.value.creds) }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { group in
                group.name.lowercased().contains(q) ||
                group.email.lowercased().contains(q) ||
                group.creds.contains { ($0.deviceModel ?? "").lowercased().contains(q) }
            }
        }
        return result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            if vm.isLoading {
                loadingRow
            } else if userGroups.isEmpty {
                emptyView(title: settings.L("admin.no_digital_credentials"), icon: "key.horizontal")
            } else {
                ForEach(userGroups, id: \.email) { group in
                    NavigationLink {
                        UserCredentialsDetailView(placeId: placeId, userEmail: group.email, credentials: group.creds, onRefresh: { await loadData() })
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(String(group.name.prefix(1)).uppercased())
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.cyan)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if group.name != group.email {
                                    Text(group.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    ForEach(group.creds, id: \.id) { cred in
                                        HStack(spacing: 2) {
                                            Image(systemName: credPlatformIcon(cred.platform))
                                                .font(.caption2)
                                            Text(credPlatformLabel(cred.platform))
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(credPlatformColor(cred.platform))
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
            errorSection(vm.errorMessage)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.digital_credentials"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: settings.L("admin.search_users"))
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func loadData() async {
        await vm.load { try await APIService.shared.fetchAdminCredentials(placeId: placeId) }
    }
}

// MARK: - User Credentials Detail

private struct UserCredentialsDetailView: View {
    let placeId: String
    let userEmail: String
    @State var credentials: [DigitalCredential]
    let onRefresh: () async -> Void
    @State private var settings = SettingsService.shared
    @State private var credToRevoke: DigitalCredential?
    @State private var actionError: String?
    @State private var actionSuccess: String?

    var body: some View {
        List {
            ForEach(credentials) { cred in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: credPlatformIcon(cred.platform))
                            .foregroundStyle(credPlatformColor(cred.platform))
                        Text(credPlatformLabel(cred.platform))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        if let status = cred.status {
                            Text(status.capitalized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(status == "active" ? Color.green.opacity(0.15) : Color(.tertiarySystemBackground))
                                .foregroundStyle(status == "active" ? .green : .secondary)
                                .clipShape(Capsule())
                        }
                    }

                    if let model = cred.deviceModel {
                        LabeledContent(settings.L("dashboard.my_device"), value: model)
                            .font(.caption)
                    }
                    LabeledContent(settings.L("admin.usage_label"), value: "\(cred.usageCount)")
                        .font(.caption)
                    if let issued = cred.issuedAt {
                        LabeledContent(settings.L("history.time"), value: String(issued.prefix(10)))
                            .font(.caption)
                    }
                    if let exp = cred.expiresAt {
                        LabeledContent(settings.L("reports.to"), value: String(exp.prefix(10)))
                            .font(.caption)
                    }

                    if cred.status == "active" {
                        HStack(spacing: 12) {
                            Button(role: .destructive) {
                                credToRevoke = cred
                            } label: {
                                Label(settings.L("profile.revoke"), systemImage: "xmark.circle")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }

            if let err = actionError {
                Section { Text(err).foregroundStyle(.red).font(.caption) }
            }
            if let msg = actionSuccess {
                Section { Text(msg).foregroundStyle(.green).font(.caption) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(userEmail)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(settings.L("profile.revoke"), isPresented: Binding(
            get: { credToRevoke != nil },
            set: { if !$0 { credToRevoke = nil } }
        ), presenting: credToRevoke) { cred in
            Button(settings.L("profile.revoke"), role: .destructive) {
                Task {
                    do {
                        try await APIService.shared.revokeWalletPass(passId: cred.id)
                        if let idx = credentials.firstIndex(where: { $0.id == cred.id }) {
                            credentials.remove(at: idx)
                        }
                        actionSuccess = settings.L("profile.revoked")
                        await onRefresh()
                    } catch {
                        actionError = error.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - Platform Helpers

private func credPlatformIcon(_ platform: String?) -> String {
    switch platform?.lowercased() {
    case "ios": return "apple.logo"
    case "android": return "g.circle.fill"
    case "qr", "qrcode": return "qrcode"
    default: return "key.horizontal.fill"
    }
}

private func credPlatformColor(_ platform: String?) -> Color {
    switch platform?.lowercased() {
    case "ios": return .blue
    case "android": return .green
    case "qr", "qrcode": return .purple
    default: return .cyan
    }
}

private func credPlatformLabel(_ platform: String?) -> String {
    switch platform?.lowercased() {
    case "ios": return "Apple Wallet"
    case "android": return "Google Wallet"
    case "qr", "qrcode": return "QR Code"
    default: return platform?.capitalized ?? "Unknown"
    }
}

// MARK: - Shared Helpers

private var loadingRow: some View {
    HStack {
        Spacer()
        ProgressView()
        Spacer()
    }
    .listRowBackground(Color.clear)
}

private func emptyView(title: String, icon: String) -> some View {
    ContentUnavailableView(title, systemImage: icon)
        .listRowBackground(Color.clear)
}

private func errorSection(_ message: String?) -> some View {
    Group {
        if let message {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
}

private func colorForResult(_ name: String) -> Color {
    switch name {
    case "green": return .green
    case "red": return .red
    case "orange": return .orange
    case "yellow": return .yellow
    case "blue": return .blue
    default: return .gray
    }
}
