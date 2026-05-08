import SwiftUI

// MARK: - ViewModel

@MainActor @Observable
final class GuestManagementViewModel {
    var guests: [Guest] = []
    var isLoading = false
    var errorMessage: String?
    var showCreateSheet = false
    var selectedTab = 0

    var pendingGuests: [Guest] { guests.filter { $0.status == "expected" } }
    var checkedInGuests: [Guest] { guests.filter { $0.status == "checked_in" } }
    var completedGuests: [Guest] { guests.filter { $0.status == "checked_out" || $0.status == "cancelled" } }

    func fetchGuests() async {
        isLoading = true
        errorMessage = nil
        do {
            guests = try await APIService.shared.fetchGuests()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func checkIn(_ guest: Guest) async {
        do {
            let updated = try await APIService.shared.updateGuestStatus(guestId: guest.id, status: "checked_in")
            if let idx = guests.firstIndex(where: { $0.id == guest.id }) {
                guests[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkOut(_ guest: Guest) async {
        do {
            let updated = try await APIService.shared.updateGuestStatus(guestId: guest.id, status: "checked_out")
            if let idx = guests.firstIndex(where: { $0.id == guest.id }) {
                guests[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel(_ guest: Guest) async {
        do {
            let updated = try await APIService.shared.updateGuestStatus(guestId: guest.id, status: "cancelled")
            if let idx = guests.firstIndex(where: { $0.id == guest.id }) {
                guests[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGuest(_ guest: Guest) async {
        do {
            try await APIService.shared.deleteGuest(guestId: guest.id)
            guests.removeAll { $0.id == guest.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - List View

struct AdminGuestManagementView: View {
    @State private var viewModel = GuestManagementViewModel()
    @State private var settings = SettingsService.shared

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.guests.isEmpty {
                ProgressView()
            } else if viewModel.guests.isEmpty {
                ContentUnavailableView(
                    settings.L("guests.empty"),
                    systemImage: "person.badge.plus",
                    description: Text(settings.L("guests.empty_description"))
                )
            } else {
                guestList
            }
        }
        .navigationTitle(settings.L("guests.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { await viewModel.fetchGuests() }
        .task { await viewModel.fetchGuests() }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateGuestView(viewModel: viewModel)
        }
    }

    private var guestList: some View {
        List {
            summarySection

            Picker("", selection: $viewModel.selectedTab) {
                Text(settings.L("guests.expected")).tag(0)
                Text(settings.L("guests.on_site")).tag(1)
                Text(settings.L("guests.completed")).tag(2)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

            let filtered = switch viewModel.selectedTab {
            case 0: viewModel.pendingGuests
            case 1: viewModel.checkedInGuests
            default: viewModel.completedGuests
            }

            if filtered.isEmpty {
                Text(settings.L("guests.none_in_tab"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(filtered) { guest in
                    GuestRowView(guest: guest, viewModel: viewModel, settings: settings)
                }
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var summarySection: some View {
        HStack(spacing: 0) {
            kpiChip(value: viewModel.pendingGuests.count, label: settings.L("guests.expected"), color: .orange)
            kpiChip(value: viewModel.checkedInGuests.count, label: settings.L("guests.on_site"), color: .green)
            kpiChip(value: viewModel.guests.count, label: settings.L("dashboard.total"), color: .primary)
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private func kpiChip(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Guest Row

private struct GuestRowView: View {
    let guest: Guest
    let viewModel: GuestManagementViewModel
    let settings: SettingsService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(guest.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let company = guest.company, !company.isEmpty {
                        Text(company)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                statusBadge(guest.status)
            }

            HStack(spacing: 12) {
                Label(guest.hostName, systemImage: "person")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let expected = guest.expectedAtDisplay {
                    Label(expected, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let idType = guest.idDocumentType, !idType.isEmpty {
                Label("\(idType.uppercased()): \(guest.idDocumentNumber ?? "—")", systemImage: "creditcard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if guest.canCheckIn || guest.canCheckOut || guest.canCancel {
                HStack(spacing: 8) {
                    if guest.canCheckIn {
                        Button {
                            Task { await viewModel.checkIn(guest) }
                        } label: {
                            Label(settings.L("guests.check_in"), systemImage: "arrow.right.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.green)
                    }

                    if guest.canCheckOut {
                        Button {
                            Task { await viewModel.checkOut(guest) }
                        } label: {
                            Label(settings.L("guests.check_out"), systemImage: "arrow.left.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.blue)
                    }

                    if guest.canCancel {
                        Button(role: .destructive) {
                            Task { await viewModel.cancel(guest) }
                        } label: {
                            Label(settings.L("guests.cancel_visit"), systemImage: "xmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.deleteGuest(guest) }
            } label: {
                Label(settings.L("common.delete"), systemImage: "trash")
            }
        }
    }

    private func statusBadge(_ status: String) -> some View {
        let color: Color = switch status {
        case "expected": .orange
        case "checked_in": .green
        case "checked_out": .gray
        case "cancelled": .red
        default: .gray
        }
        let label = status.replacingOccurrences(of: "_", with: " ").capitalized
        return Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Create Guest

struct CreateGuestView: View {
    let viewModel: GuestManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsService.shared

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var company = ""
    @State private var purpose = ""
    @State private var hostName = ""
    @State private var hostEmail = ""
    @State private var hostPhone = ""
    @State private var idDocType = ""
    @State private var idDocNumber = ""
    @State private var expectedAt = Date().addingTimeInterval(3600)
    @State private var hasExpectedTime = false
    @State private var notifyHost = true
    @State private var selectedTTL = 24
    @State private var isSubmitting = false

    private let ttlOptions = [4, 8, 24, 48, 72]
    private var isValid: Bool { !name.isEmpty && !phone.isEmpty && !hostName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.L("guests.visitor_info")) {
                    TextField(settings.L("guests.name"), text: $name)
                        .textContentType(.name)
                    TextField(settings.L("guests.email_optional"), text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    TextField(settings.L("guests.phone"), text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField(settings.L("guests.company_optional"), text: $company)
                    TextField(settings.L("guests.purpose_optional"), text: $purpose)
                }

                Section(settings.L("guests.host_info")) {
                    TextField(settings.L("guests.host_name"), text: $hostName)
                        .textContentType(.name)
                    TextField(settings.L("guests.host_email_optional"), text: $hostEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    TextField(settings.L("guests.host_phone_optional"), text: $hostPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    Toggle(settings.L("guests.notify_host"), isOn: $notifyHost)
                        .tint(.brandPrimary)
                }

                Section(settings.L("guests.id_verification")) {
                    Picker(settings.L("guests.id_type"), selection: $idDocType) {
                        Text(settings.L("guests.none")).tag("")
                        Text(settings.L("guests.ktp")).tag("ktp")
                        Text(settings.L("guests.sim")).tag("sim")
                        Text(settings.L("guests.passport")).tag("passport")
                        Text(settings.L("guests.other")).tag("other")
                    }
                    if !idDocType.isEmpty {
                        TextField(settings.L("guests.id_number"), text: $idDocNumber)
                    }
                }

                Section(settings.L("guests.schedule")) {
                    Toggle(settings.L("guests.set_expected_time"), isOn: $hasExpectedTime)
                    if hasExpectedTime {
                        DatePicker(settings.L("guests.expected_at"), selection: $expectedAt)
                    }

                    Picker(settings.L("guests.access_duration"), selection: $selectedTTL) {
                        ForEach(ttlOptions, id: \.self) { hours in
                            Text(String(format: settings.L("visitors.hours"), hours)).tag(hours)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(settings.L("guests.new_guest"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.L("guests.register")) {
                        Task { await submit() }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        let fmt = ISO8601DateFormatter()
        let request = CreateGuestRequest(
            name: name,
            email: email.isEmpty ? nil : email,
            phone: phone,
            company: company.isEmpty ? nil : company,
            purpose: purpose.isEmpty ? nil : purpose,
            hostName: hostName,
            hostEmail: hostEmail.isEmpty ? nil : hostEmail,
            hostPhone: hostPhone.isEmpty ? nil : hostPhone,
            idDocumentType: idDocType.isEmpty ? nil : idDocType,
            idDocumentNumber: idDocNumber.isEmpty ? nil : idDocNumber,
            expectedAt: hasExpectedTime ? fmt.string(from: expectedAt) : nil,
            notifyHost: notifyHost,
            doorIds: [],
            accessTtlHours: selectedTTL
        )
        do {
            let guest = try await APIService.shared.createGuest(request)
            viewModel.guests.insert(guest, at: 0)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
