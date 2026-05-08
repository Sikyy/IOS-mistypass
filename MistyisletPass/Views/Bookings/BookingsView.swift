import SwiftUI

struct BookingsView: View {
    @State private var viewModel = BookingsViewModel()
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.spaces.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else {
                spacesSection
                activeBookingsSection
                pastBookingsSection
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
        .navigationTitle(settings.L("bookings.title"))
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
        .refreshable {
            await viewModel.fetchSpaces()
            await viewModel.fetchBookings()
            await viewModel.fetchSpaceStatuses()
        }
        .task {
            await viewModel.fetchSpaces()
            await viewModel.fetchBookings()
            await viewModel.fetchSpaceStatuses()
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateBookingView(viewModel: viewModel)
        }
    }

    // MARK: - Spaces

    private var spacesSection: some View {
        Section(settings.L("bookings.spaces")) {
            if viewModel.spaces.isEmpty {
                Text(settings.L("bookings.no_spaces"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(viewModel.spaces) { space in
                    spaceRow(space)
                }
            }
        }
    }

    private func spaceRow(_ space: BookableSpace) -> some View {
        HStack(spacing: 12) {
            Image(systemName: space.spaceTypeIcon)
                .font(.title3)
                .foregroundStyle(.brandPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(space.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(space.spaceTypeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if space.capacityMode != "unlimited" {
                        Text("\u{00B7}")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: settings.L("bookings.capacity_fmt"), space.currentOccupancy, space.maxCapacity))
                            .font(.caption)
                            .foregroundStyle(space.isFull ? .red : .secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let status = viewModel.spaceStatuses[space.id] {
                    if status.isAvailable {
                        Text(settings.L("bookings.available"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    } else {
                        Text(settings.L("bookings.full"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    if status.activeBookings > 0 {
                        Text(String(format: settings.L("bookings.active_count"), status.activeBookings))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    if let next = status.nextSlotFormatted, !status.isAvailable {
                        Text(String(format: settings.L("bookings.next_at"), next))
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                } else {
                    if space.isFull {
                        Text(settings.L("bookings.full"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    } else {
                        Text(settings.L("bookings.available"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Active Bookings

    private var activeBookingsSection: some View {
        Section(settings.L("bookings.active")) {
            if viewModel.activeBookings.isEmpty {
                Text(settings.L("bookings.no_active"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(viewModel.activeBookings) { booking in
                    bookingRow(booking)
                }
            }
        }
    }

    // MARK: - Past Bookings

    private var pastBookingsSection: some View {
        Group {
            if !viewModel.pastBookings.isEmpty {
                Section(settings.L("bookings.past")) {
                    ForEach(viewModel.pastBookings) { booking in
                        bookingRow(booking)
                    }
                }
            }
        }
    }

    // MARK: - Booking Row

    private func bookingRow(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(booking.title ?? settings.L("bookings.untitled"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                statusBadge(booking.status)
            }

            Text(booking.displayTime)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let spaceName = viewModel.spaces.first(where: { $0.id == booking.spaceId })?.name {
                Text(spaceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if booking.isActive {
                HStack(spacing: 8) {
                    if booking.canCheckIn {
                        Button {
                            Task { await viewModel.checkIn(booking) }
                        } label: {
                            Label(settings.L("bookings.check_in"), systemImage: "arrow.right.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.green)
                    }

                    if booking.canCheckOut {
                        Button {
                            Task { await viewModel.checkOut(booking) }
                        } label: {
                            Label(settings.L("bookings.check_out"), systemImage: "arrow.left.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.blue)
                    }

                    if booking.canCancel {
                        Button(role: .destructive) {
                            Task { await viewModel.cancelBooking(booking) }
                        } label: {
                            Label(settings.L("bookings.cancel"), systemImage: "xmark.circle")
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
    }

    private func statusBadge(_ status: String) -> some View {
        let color: Color = switch status {
        case "confirmed": .blue
        case "checked_in": .green
        case "completed": .gray
        case "cancelled": .red
        case "no_show": .orange
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

// MARK: - Create Booking

struct CreateBookingView: View {
    let viewModel: BookingsViewModel
    @State private var settings = SettingsService.shared
    @State private var selectedSpaceId = ""
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.L("bookings.space")) {
                    Picker(settings.L("bookings.space"), selection: $selectedSpaceId) {
                        Text(settings.L("bookings.select_space")).tag("")
                        ForEach(viewModel.spaces.filter { $0.enabled && !$0.isFull }) { space in
                            Text(space.name).tag(space.id)
                        }
                    }
                }

                Section(settings.L("bookings.details")) {
                    TextField(settings.L("bookings.title_placeholder"), text: $title)
                    DatePicker(settings.L("bookings.start"), selection: $startTime)
                    DatePicker(settings.L("bookings.end"), selection: $endTime)
                }
            }
            .navigationTitle(settings.L("bookings.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.L("bookings.book")) {
                        Task {
                            await viewModel.createBooking(
                                spaceId: selectedSpaceId,
                                title: title,
                                startTime: startTime,
                                endTime: endTime
                            )
                        }
                    }
                    .disabled(selectedSpaceId.isEmpty)
                }
            }
        }
    }
}
