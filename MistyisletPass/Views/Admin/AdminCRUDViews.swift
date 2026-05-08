import SwiftUI

// MARK: - User Detail View

struct UserDetailView: View {
    let placeId: String
    @State var user: PlaceUser
    @State private var settings = SettingsService.shared
    @State private var selectedRole: String
    @State private var showRoleConfirm = false
    @State private var showRemoveConfirm = false
    @State private var showSignOutConfirm = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @Environment(\.dismiss) private var dismiss
    var onUpdate: ((PlaceUser) -> Void)?
    var onRemove: (() -> Void)?

    init(placeId: String, user: PlaceUser, onUpdate: ((PlaceUser) -> Void)? = nil, onRemove: (() -> Void)? = nil) {
        self.placeId = placeId
        self._user = State(initialValue: user)
        self._selectedRole = State(initialValue: user.role)
        self.onUpdate = onUpdate
        self.onRemove = onRemove
    }

    private let availableRoles = [
        "door_access", "group_manager",
        "place_door_access", "place_access_manager", "place_administrator",
        "observer", "user_manager", "organization_access_manager", "organization_administrator"
    ]

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.brandPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.headline)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(settings.L("admin.user_info")) {
                LabeledContent(settings.L("admin.role"), value: user.role.replacingOccurrences(of: "_", with: " ").capitalized)
                LabeledContent(settings.L("admin.status"), value: user.status.capitalized)
                if let lastActivity = user.lastActivity {
                    LabeledContent(settings.L("admin.last_activity"), value: lastActivity)
                }
                if let createdAt = user.createdAt {
                    LabeledContent(settings.L("admin.joined"), value: createdAt)
                }
            }

            Section(settings.L("admin.change_role")) {
                Picker(settings.L("admin.role"), selection: $selectedRole) {
                    ForEach(availableRoles, id: \.self) { role in
                        Text(role.replacingOccurrences(of: "_", with: " ").capitalized)
                            .tag(role)
                    }
                }
                .pickerStyle(.menu)

                if selectedRole != user.role {
                    Button(settings.L("admin.apply_role")) {
                        showRoleConfirm = true
                    }
                    .foregroundStyle(.brandPrimary)
                }
            }

            if let successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                Button(settings.L("admin.force_sign_out")) {
                    showSignOutConfirm = true
                }
                .foregroundStyle(.orange)

                Button(settings.L("admin.remove_user"), role: .destructive) {
                    showRemoveConfirm = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(settings.L("admin.confirm_role_change"), isPresented: $showRoleConfirm) {
            Button(settings.L("admin.apply_role")) {
                Task { await changeRole() }
            }
        }
        .confirmationDialog(settings.L("admin.confirm_sign_out"), isPresented: $showSignOutConfirm) {
            Button(settings.L("admin.force_sign_out"), role: .destructive) {
                Task { await signOut() }
            }
        }
        .confirmationDialog(settings.L("admin.confirm_remove"), isPresented: $showRemoveConfirm) {
            Button(settings.L("admin.remove_user"), role: .destructive) {
                Task { await remove() }
            }
        }
    }

    private func changeRole() async {
        do {
            let updated = try await APIService.shared.updateUserRole(placeId: placeId, userId: user.id, role: selectedRole)
            user = updated
            successMessage = settings.L("admin.role_updated")
            onUpdate?(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signOut() async {
        do {
            try await APIService.shared.signOutUser(placeId: placeId, userId: user.id)
            successMessage = settings.L("admin.user_signed_out")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove() async {
        do {
            try await APIService.shared.removeUser(placeId: placeId, userId: user.id)
            onRemove?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Invite User Sheet

struct InviteUserSheet: View {
    let placeId: String
    @State private var settings = SettingsService.shared
    @State private var email = ""
    @State private var selectedRole = "door_access"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    var onInvited: ((PlaceUser) -> Void)?

    private let roles = [
        "door_access", "group_manager",
        "place_door_access", "place_access_manager", "place_administrator"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(settings.L("admin.email"), text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section(settings.L("admin.role")) {
                    Picker(settings.L("admin.role"), selection: $selectedRole) {
                        ForEach(roles, id: \.self) { role in
                            Text(role.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle(settings.L("admin.invite_user"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.L("admin.invite")) {
                        Task { await invite() }
                    }
                    .disabled(email.isEmpty || isLoading)
                }
            }
        }
    }

    private func invite() async {
        isLoading = true
        errorMessage = nil
        do {
            let user = try await APIService.shared.inviteUser(placeId: placeId, email: email, role: selectedRole)
            onInvited?(user)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Groups List View

struct AdminGroupsListView: View {
    let placeId: String
    @State private var vm = AdminListViewModel<AccessGroup>()
    @State private var settings = SettingsService.shared
    @State private var showCreateSheet = false

    var body: some View {
        List {
            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if vm.items.isEmpty {
                ContentUnavailableView(settings.L("admin.no_groups"), systemImage: "person.2.circle")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(vm.items) { group in
                    NavigationLink {
                        GroupDetailView(placeId: placeId, group: group) {
                            Task { await loadData() }
                        }
                    } label: {
                        groupRow(group)
                    }
                }
                .onDelete { offsets in
                    Task { await deleteGroups(at: offsets) }
                }
            }

            if let error = vm.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("dashboard.groups"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateGroupSheet(placeId: placeId) { group in
                vm.items.insert(group, at: 0)
            }
        }
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func loadData() async {
        await vm.load { try await APIService.shared.fetchAdminGroups(placeId: placeId) }
        #if DEBUG
        if vm.items.isEmpty { vm.items = PreviewData.groups }
        #endif
    }

    private func deleteGroups(at offsets: IndexSet) async {
        let groups = offsets.map { vm.items[$0] }
        for group in groups {
            do {
                try await APIService.shared.deleteGroup(placeId: placeId, groupId: group.id)
                vm.items.removeAll { $0.id == group.id }
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        }
    }

    private func groupRow(_ group: AccessGroup) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.circle.fill")
                .foregroundStyle(.mint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !group.description.isEmpty {
                    Text(group.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill").font(.caption2)
                    Text("\(group.memberCount)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "door.left.hand.closed").font(.caption2)
                    Text("\(group.doorCount)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Create Group Sheet

struct CreateGroupSheet: View {
    let placeId: String
    @State private var settings = SettingsService.shared
    @State private var name = ""
    @State private var description = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    var onCreated: ((AccessGroup) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(settings.L("admin.group_name"), text: $name)
                    TextField(settings.L("admin.group_description"), text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle(settings.L("admin.create_group"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.L("common.save")) {
                        Task { await create() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    private func create() async {
        isLoading = true
        do {
            let group = try await APIService.shared.createGroup(placeId: placeId, name: name, description: description)
            onCreated?(group)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Group Detail View

struct GroupDetailView: View {
    let placeId: String
    let group: AccessGroup
    var onChanged: (() -> Void)?
    @State private var settings = SettingsService.shared
    @State private var selectedTab: GroupTab = .members
    @State private var members: [GroupMember] = []
    @State private var doors: [GroupDoor] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddMember = false
    @State private var showAddDoor = false
    @State private var addEmail = ""
    @State private var addDoorId = ""
    @State private var availableDoors: [AccessibleDoor] = []
    @State private var pendingRemoveMember: GroupMember?
    @State private var pendingRemoveDoor: GroupDoor?

    private enum GroupTab: CaseIterable {
        case members, doors
        @MainActor func label(_ s: SettingsService) -> String {
            switch self {
            case .members: return s.L("admin.members")
            case .doors: return s.L("admin.doors")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(GroupTab.allCases, id: \.self) { tab in
                    Text(tab.label(settings)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedTab {
            case .members:
                membersList
            case .doors:
                doorsList
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAll() }
    }

    private var membersList: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if members.isEmpty {
                ContentUnavailableView(settings.L("admin.no_members"), systemImage: "person.slash")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.brandPrimary.opacity(0.15)).frame(width: 32, height: 32)
                            Text(String(member.name.prefix(1)).uppercased())
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.brandPrimary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name).font(.subheadline).fontWeight(.medium)
                            Text(member.email).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(member.role.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingRemoveMember = member
                        } label: {
                            Label(settings.L("admin.remove"), systemImage: "trash")
                        }
                    }
                }
            }

            errorRow
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddMember = true } label: { Image(systemName: "plus") }
            }
        }
        .alert(settings.L("admin.add_member"), isPresented: $showAddMember) {
            TextField(settings.L("admin.email"), text: $addEmail)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            Button(settings.L("common.cancel"), role: .cancel) { addEmail = "" }
            Button(settings.L("admin.add")) {
                let email = addEmail
                addEmail = ""
                Task { await addMember(email: email) }
            }
        }
        .confirmationDialog(
            settings.L("admin.confirm_remove_member"),
            isPresented: Binding(get: { pendingRemoveMember != nil }, set: { if !$0 { pendingRemoveMember = nil } }),
            titleVisibility: .visible
        ) {
            if let member = pendingRemoveMember {
                Button(settings.L("admin.remove"), role: .destructive) {
                    Task { await removeMember(member) }
                }
            }
        } message: {
            if let member = pendingRemoveMember {
                Text(String(format: settings.L("admin.confirm_remove_member_msg"), member.name))
            }
        }
    }

    private var doorsList: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if doors.isEmpty {
                ContentUnavailableView(settings.L("admin.no_group_doors"), systemImage: "door.left.hand.closed")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(doors) { door in
                    HStack(spacing: 12) {
                        Image(systemName: "door.left.hand.closed")
                            .foregroundStyle(door.status == "online" ? .green : .red)
                            .frame(width: 28)
                        Text(door.name)
                            .font(.subheadline)
                        Spacer()
                        Text(door.status.capitalized)
                            .font(.caption2)
                            .foregroundStyle(door.status == "online" ? .green : .red)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingRemoveDoor = door
                        } label: {
                            Label(settings.L("admin.remove"), systemImage: "trash")
                        }
                    }
                }
            }

            errorRow
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddDoor = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddDoor) {
            AddDoorToGroupSheet(placeId: placeId, groupId: group.id) { newDoor in
                doors.append(newDoor)
            }
        }
        .confirmationDialog(
            settings.L("admin.confirm_remove_door"),
            isPresented: Binding(get: { pendingRemoveDoor != nil }, set: { if !$0 { pendingRemoveDoor = nil } }),
            titleVisibility: .visible
        ) {
            if let door = pendingRemoveDoor {
                Button(settings.L("admin.remove"), role: .destructive) {
                    Task { await removeDoor(door) }
                }
            }
        } message: {
            if let door = pendingRemoveDoor {
                Text(String(format: settings.L("admin.confirm_remove_door_msg"), door.name))
            }
        }
    }

    @ViewBuilder
    private var errorRow: some View {
        if let errorMessage {
            Section {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).font(.caption)
            }
        }
    }

    private func loadAll() async {
        isLoading = true
        do {
            async let m = APIService.shared.fetchGroupMembers(placeId: placeId, groupId: group.id)
            async let d = APIService.shared.fetchGroupDoors(placeId: placeId, groupId: group.id)
            members = try await m
            doors = try await d
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if members.isEmpty { members = PreviewData.groupMembers }
        if doors.isEmpty { doors = PreviewData.groupDoors }
        #endif
        isLoading = false
    }

    private func addMember(email: String) async {
        do {
            let member = try await APIService.shared.addGroupMember(placeId: placeId, groupId: group.id, email: email)
            members.append(member)
            onChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeMember(_ member: GroupMember) async {
        do {
            try await APIService.shared.removeGroupMember(placeId: placeId, groupId: group.id, memberId: member.id)
            members.removeAll { $0.id == member.id }
            pendingRemoveMember = nil
            onChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeDoor(_ door: GroupDoor) async {
        do {
            try await APIService.shared.removeGroupDoor(placeId: placeId, groupId: group.id, doorId: door.id)
            doors.removeAll { $0.id == door.id }
            pendingRemoveDoor = nil
            onChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Add Door to Group Sheet

struct AddDoorToGroupSheet: View {
    let placeId: String
    let groupId: String
    @State private var settings = SettingsService.shared
    @State private var doors: [AccessibleDoor] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    var onAdded: ((GroupDoor) -> Void)?

    var filteredDoors: [AccessibleDoor] {
        if searchText.isEmpty { return doors }
        return doors.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else {
                    ForEach(filteredDoors) { door in
                        Button {
                            Task { await addDoor(door) }
                        } label: {
                            HStack {
                                Image(systemName: "door.left.hand.closed")
                                    .foregroundStyle(door.status == "online" ? .green : .gray)
                                Text(door.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.brandPrimary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: settings.L("admin.search_doors"))
            .navigationTitle(settings.L("admin.add_door"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.L("common.cancel")) { dismiss() }
                }
            }
            .task { await loadDoors() }
        }
    }

    private func loadDoors() async {
        do {
            doors = try await APIService.shared.fetchPlaceDoors(placeId: placeId)
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if doors.isEmpty { doors = PreviewData.accessibleDoors }
        #endif
        isLoading = false
    }

    private func addDoor(_ door: AccessibleDoor) async {
        do {
            try await APIService.shared.addGroupDoor(placeId: placeId, groupId: groupId, doorId: door.id)
            onAdded?(GroupDoor(id: door.id, name: door.name, status: door.status))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Team Detail View

struct TeamDetailView: View {
    let placeId: String
    let team: Team
    var onChanged: (() -> Void)?
    @State private var settings = SettingsService.shared
    @State private var selectedTab: TeamTab = .members
    @State private var members: [TeamMember] = []
    @State private var accessRights: [AccessRightAssignment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddMember = false
    @State private var showAddRight = false
    @State private var addEmail = ""
    @State private var pendingRemoveMember: TeamMember?
    @State private var pendingRemoveRight: AccessRightAssignment?

    private enum TeamTab: CaseIterable {
        case members, accessRights
        @MainActor func label(_ s: SettingsService) -> String {
            switch self {
            case .members: return s.L("admin.members")
            case .accessRights: return s.L("admin.access_rights")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(TeamTab.allCases, id: \.self) { tab in
                    Text(tab.label(settings)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedTab {
            case .members:
                teamMembersList
            case .accessRights:
                accessRightsList
            }
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAll() }
    }

    private var teamMembersList: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if members.isEmpty {
                ContentUnavailableView(settings.L("admin.no_members"), systemImage: "person.slash")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.indigo.opacity(0.15)).frame(width: 32, height: 32)
                            Text(String(member.name.prefix(1)).uppercased())
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.indigo)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name).font(.subheadline).fontWeight(.medium)
                            Text(member.email).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingRemoveMember = member
                        } label: {
                            Label(settings.L("admin.remove"), systemImage: "trash")
                        }
                    }
                }
            }

            errorSection
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddMember = true } label: { Image(systemName: "plus") }
            }
        }
        .alert(settings.L("admin.add_member"), isPresented: $showAddMember) {
            TextField(settings.L("admin.email"), text: $addEmail)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            Button(settings.L("common.cancel"), role: .cancel) { addEmail = "" }
            Button(settings.L("admin.add")) {
                let email = addEmail
                addEmail = ""
                Task { await addMember(email: email) }
            }
        }
        .confirmationDialog(
            settings.L("admin.confirm_remove_member"),
            isPresented: Binding(get: { pendingRemoveMember != nil }, set: { if !$0 { pendingRemoveMember = nil } }),
            titleVisibility: .visible
        ) {
            if let member = pendingRemoveMember {
                Button(settings.L("admin.remove"), role: .destructive) {
                    Task { await removeMember(member) }
                }
            }
        } message: {
            if let member = pendingRemoveMember {
                Text(String(format: settings.L("admin.confirm_remove_member_msg"), member.name))
            }
        }
    }

    private var accessRightsList: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if accessRights.isEmpty {
                ContentUnavailableView(settings.L("admin.no_access_rights"), systemImage: "lock.shield")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(accessRights) { right in
                    HStack(spacing: 12) {
                        Image(systemName: "shield.checkered")
                            .foregroundStyle(.purple)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(right.role.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack(spacing: 4) {
                                Text(right.scope.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let scopeName = right.scopeName {
                                    Text("·")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(scopeName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingRemoveRight = right
                        } label: {
                            Label(settings.L("admin.remove"), systemImage: "trash")
                        }
                    }
                }
            }

            errorSection
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddRight = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddRight) {
            AssignAccessRightSheet(placeId: placeId, teamId: team.id) { right in
                accessRights.append(right)
            }
        }
        .confirmationDialog(
            settings.L("admin.confirm_remove_member"),
            isPresented: Binding(get: { pendingRemoveRight != nil }, set: { if !$0 { pendingRemoveRight = nil } }),
            titleVisibility: .visible
        ) {
            if let right = pendingRemoveRight {
                Button(settings.L("admin.remove"), role: .destructive) {
                    Task { await removeAccessRight(right) }
                }
            }
        } message: {
            if let right = pendingRemoveRight {
                Text(String(format: settings.L("admin.confirm_remove_member_msg"), right.role.replacingOccurrences(of: "_", with: " ").capitalized))
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage {
            Section {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).font(.caption)
            }
        }
    }

    private func loadAll() async {
        isLoading = true
        do {
            async let m = APIService.shared.fetchTeamMembers(placeId: placeId, teamId: team.id)
            async let r = APIService.shared.fetchTeamAccessRights(placeId: placeId, teamId: team.id)
            members = try await m
            accessRights = try await r
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if members.isEmpty { members = PreviewData.teamMembers }
        if accessRights.isEmpty { accessRights = PreviewData.accessRights }
        #endif
        isLoading = false
    }

    private func addMember(email: String) async {
        do {
            let member = try await APIService.shared.addTeamMember(placeId: placeId, teamId: team.id, email: email)
            members.append(member)
            onChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeMember(_ member: TeamMember) async {
        do {
            try await APIService.shared.removeTeamMember(placeId: placeId, teamId: team.id, memberId: member.id)
            members.removeAll { $0.id == member.id }
            onChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeAccessRight(_ right: AccessRightAssignment) async {
        do {
            try await APIService.shared.removeTeamAccessRight(placeId: placeId, teamId: team.id, accessRightId: right.id)
            accessRights.removeAll { $0.id == right.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Assign Access Right Sheet

struct AssignAccessRightSheet: View {
    let placeId: String
    let teamId: String
    @State private var settings = SettingsService.shared
    @State private var selectedRole = "door_access"
    @State private var selectedScope = "group"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    var onAssigned: ((AccessRightAssignment) -> Void)?

    private let roles = [
        "door_access", "group_manager",
        "place_door_access", "place_access_manager", "place_administrator",
        "observer", "user_manager", "organization_access_manager", "organization_administrator"
    ]

    private let scopes = ["group", "place", "organization"]

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.L("admin.role")) {
                    Picker(settings.L("admin.role"), selection: $selectedRole) {
                        ForEach(roles, id: \.self) { role in
                            Text(role.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(settings.L("admin.scope")) {
                    Picker(settings.L("admin.scope"), selection: $selectedScope) {
                        ForEach(scopes, id: \.self) { scope in
                            Text(scope.capitalized).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle(settings.L("admin.assign_access"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.L("common.save")) {
                        Task { await assign() }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func assign() async {
        isLoading = true
        do {
            let right = try await APIService.shared.assignTeamAccessRight(
                placeId: placeId, teamId: teamId,
                role: selectedRole, scope: selectedScope, scopeId: nil
            )
            onAssigned?(right)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Create Team Sheet

struct CreateTeamSheet: View {
    let placeId: String
    @State private var settings = SettingsService.shared
    @State private var name = ""
    @State private var description = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    var onCreated: ((Team) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(settings.L("admin.team_name"), text: $name)
                    TextField(settings.L("admin.team_description"), text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle(settings.L("admin.create_team"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.L("common.save")) {
                        Task { await create() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    private func create() async {
        isLoading = true
        do {
            let team = try await APIService.shared.createTeam(placeId: placeId, name: name, description: description)
            onCreated?(team)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Organization Settings

struct OrgSettingsView: View {
    let orgId: String
    @State private var settings = SettingsService.shared
    @State private var orgSettings: OrganizationSettings?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        Form {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if var s = orgSettings {
                generalSection(s: &s)
                emailSection(s: &s)
                whatsappSection(s: &s)
                securitySection(s: &s)

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red).font(.caption)
                    }
                }
                if let success = successMessage {
                    Section {
                        Label(success, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.caption)
                    }
                }
            }
        }
        .navigationTitle(settings.L("org_settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button(settings.L("common.save")) {
                        Task { await saveSettings() }
                    }
                    .disabled(orgSettings == nil)
                }
            }
        }
        .task { await loadSettings() }
    }

    private func generalSection(s: inout OrganizationSettings) -> some View {
        Section(settings.L("org_settings.general")) {
            HStack {
                Text(settings.L("org_settings.name"))
                Spacer()
                TextField("", text: binding(for: \.name))
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text(settings.L("org_settings.domain"))
                Spacer()
                TextField("", text: optionalBinding(for: \.domain))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(settings.L("org_settings.timezone"))
                Spacer()
                Text(orgSettings?.timezone ?? "—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func emailSection(s: inout OrganizationSettings) -> some View {
        Section(settings.L("org_settings.email")) {
            Toggle(settings.L("org_settings.send_emails"), isOn: binding(for: \.sendEmails))
            if orgSettings?.sendEmails == true {
                Toggle(settings.L("org_settings.email_access"), isOn: binding(for: \.emailAccessAssignment))
                Toggle(settings.L("org_settings.email_credentials"), isOn: binding(for: \.emailCredentialAssignment))
                Toggle(settings.L("org_settings.email_incidents"), isOn: binding(for: \.emailIncidentAlerts))
                Toggle(settings.L("org_settings.email_reports"), isOn: binding(for: \.emailReports))
            }
        }
    }

    private func whatsappSection(s: inout OrganizationSettings) -> some View {
        Section(settings.L("org_settings.whatsapp")) {
            Toggle(settings.L("org_settings.whatsapp_enabled"), isOn: binding(for: \.whatsappEnabled))
            if orgSettings?.whatsappEnabled == true {
                Toggle(settings.L("org_settings.whatsapp_access"), isOn: binding(for: \.whatsappAccessAssignment))
                Toggle(settings.L("org_settings.whatsapp_credentials"), isOn: binding(for: \.whatsappCredentialAssignment))
                Toggle(settings.L("org_settings.whatsapp_incidents"), isOn: binding(for: \.whatsappIncidentAlerts))
            }
        }
    }

    private func securitySection(s: inout OrganizationSettings) -> some View {
        Section(settings.L("org_settings.security")) {
            HStack {
                Text(settings.L("org_settings.session_timeout"))
                Spacer()
                Text(orgSettings.map { "\($0.sessionTimeoutMinutes ?? 30) min" } ?? "—")
                    .foregroundStyle(.secondary)
            }
            Toggle(settings.L("org_settings.webauthn"), isOn: binding(for: \.webauthnEnabled))
        }
    }

    private func binding<T>(for keyPath: WritableKeyPath<OrganizationSettings, T>) -> Binding<T> {
        Binding(
            get: { orgSettings![keyPath: keyPath] },
            set: { orgSettings?[keyPath: keyPath] = $0 }
        )
    }

    private func optionalBinding(for keyPath: WritableKeyPath<OrganizationSettings, String?>) -> Binding<String> {
        Binding(
            get: { orgSettings?[keyPath: keyPath] ?? "" },
            set: { orgSettings?[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func loadSettings() async {
        isLoading = true
        do {
            orgSettings = try await APIService.shared.fetchOrgSettings(orgId: orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if orgSettings == nil {
            orgSettings = OrganizationSettings(
                name: settings.selectedOrgName ?? "Demo Org", address: "123 Main St",
                timezone: "America/Los_Angeles", domain: "demo.mistyislet.com",
                logoUrl: nil, sessionTimeoutMinutes: 30,
                sendEmails: true, emailAccessAssignment: true,
                emailCredentialAssignment: true, emailIncidentAlerts: true,
                emailReports: false,
                whatsappEnabled: true, whatsappAccessAssignment: true,
                whatsappCredentialAssignment: true, whatsappIncidentAlerts: false,
                webauthnEnabled: false
            )
        }
        #endif
        isLoading = false
    }

    private func saveSettings() async {
        guard let s = orgSettings else { return }
        isSaving = true
        errorMessage = nil
        successMessage = nil
        do {
            orgSettings = try await APIService.shared.updateOrgSettings(orgId: orgId, settings: s)
            successMessage = settings.L("org_settings.saved")
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Access Rights Overview

struct AccessRightsOverviewView: View {
    let placeId: String
    @State private var settings = SettingsService.shared
    @State private var users: [PlaceUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedScope = "all"

    private let scopes = ["all", "organization", "place", "group"]

    private var filteredUsers: [PlaceUser] {
        var result = users
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
        if selectedScope != "all" {
            result = result.filter { $0.role.localizedCaseInsensitiveContains(selectedScope) }
        }
        return result
    }

    var body: some View {
        List {
            Section {
                Picker(settings.L("access_rights.scope_filter"), selection: $selectedScope) {
                    ForEach(scopes, id: \.self) { scope in
                        Text(scope.capitalized).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if filteredUsers.isEmpty {
                ContentUnavailableView(settings.L("access_rights.no_users"), systemImage: "person.badge.shield.checkmark")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredUsers) { user in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.indigo.opacity(0.15)).frame(width: 36, height: 36)
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.indigo)
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(roleColor(user.role).opacity(0.15))
                            .foregroundStyle(roleColor(user.role))
                            .clipShape(Capsule())
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("access_rights.title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: settings.L("admin.search_users"))
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func roleColor(_ role: String) -> Color {
        let r = role.lowercased()
        if r.contains("owner") || r.contains("administrator") { return .red }
        if r.contains("manager") { return .orange }
        if r.contains("observer") { return .blue }
        return .green
    }

    private func loadData() async {
        isLoading = true
        do {
            users = try await APIService.shared.fetchAdminUsers(placeId: placeId)
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if users.isEmpty { users = PreviewData.placeUsers }
        #endif
        isLoading = false
    }
}
