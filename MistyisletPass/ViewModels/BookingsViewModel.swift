import Foundation

@MainActor @Observable
final class BookingsViewModel {
    var spaces: [BookableSpace] = []
    var bookings: [Booking] = []
    var spaceStatuses: [String: BookableSpaceStatus] = [:]
    var isLoading = false
    var errorMessage: String?
    var showCreateSheet = false
    var selectedSpace: BookableSpace?

    var activeBookings: [Booking] {
        bookings.filter { $0.isActive }
    }

    var pastBookings: [Booking] {
        bookings.filter { !$0.isActive }
    }

    func fetchSpaces() async {
        guard !Constants.AppEnvironment.isPreview else { return }
        isLoading = true
        errorMessage = nil
        do {
            spaces = try await APIService.shared.fetchBookableSpaces()
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if spaces.isEmpty {
            spaces = [
                BookableSpace(id: "space-1", tenantId: "t1", name: "Meeting Room A",
                              description: "8-person conference room with projector",
                              spaceType: "meeting_room", capacityMode: "limited_capacity",
                              maxCapacity: 8, currentOccupancy: 2, lockId: nil,
                              requiresBooking: true, enabled: true,
                              createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"),
                BookableSpace(id: "space-2", tenantId: "t1", name: "Phone Booth 1",
                              description: "Single-person quiet call space",
                              spaceType: "phone_booth", capacityMode: "single_occupancy",
                              maxCapacity: 1, currentOccupancy: 0, lockId: nil,
                              requiresBooking: true, enabled: true,
                              createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"),
                BookableSpace(id: "space-3", tenantId: "t1", name: "Prayer Room",
                              description: "Multi-faith prayer space",
                              spaceType: "prayer_room", capacityMode: "unlimited",
                              maxCapacity: 0, currentOccupancy: 0, lockId: nil,
                              requiresBooking: false, enabled: true,
                              createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"),
            ]
        }
        #endif
        isLoading = false
    }

    func fetchBookings(spaceId: String? = nil) async {
        guard !Constants.AppEnvironment.isPreview else { return }
        isLoading = true
        errorMessage = nil
        do {
            bookings = try await APIService.shared.fetchBookings(spaceId: spaceId)
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if bookings.isEmpty {
            let now = ISO8601DateFormatter().string(from: Date())
            let later = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
            bookings = [
                Booking(id: "bk-1", tenantId: "t1", spaceId: "space-1", userId: "u1",
                        userName: "Siky", title: "Team Standup",
                        startTime: now, endTime: later, status: "confirmed",
                        checkedInAt: nil, checkedOutAt: nil,
                        createdAt: now, updatedAt: now),
            ]
        }
        #endif
        isLoading = false
    }

    func fetchSpaceStatuses() async {
        await withTaskGroup(of: (String, BookableSpaceStatus?).self) { group in
            for space in spaces {
                group.addTask {
                    let status = try? await APIService.shared.fetchBookableSpaceStatus(spaceId: space.id)
                    return (space.id, status)
                }
            }
            for await (spaceId, status) in group {
                if let status {
                    spaceStatuses[spaceId] = status
                }
            }
        }
    }

    func createBooking(spaceId: String, title: String, startTime: Date, endTime: Date) async {
        isLoading = true
        errorMessage = nil
        let fmt = ISO8601DateFormatter()
        do {
            let booking = try await APIService.shared.createBooking(
                CreateBookingRequest(
                    spaceId: spaceId,
                    title: title,
                    startTime: fmt.string(from: startTime),
                    endTime: fmt.string(from: endTime)
                )
            )
            bookings.insert(booking, at: 0)
            showCreateSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func cancelBooking(_ booking: Booking) async {
        do {
            let updated = try await APIService.shared.cancelBooking(bookingId: booking.id)
            if let idx = bookings.firstIndex(where: { $0.id == booking.id }) {
                bookings[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkIn(_ booking: Booking) async {
        do {
            let updated = try await APIService.shared.checkInBooking(bookingId: booking.id)
            if let idx = bookings.firstIndex(where: { $0.id == booking.id }) {
                bookings[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkOut(_ booking: Booking) async {
        do {
            let updated = try await APIService.shared.checkOutBooking(bookingId: booking.id)
            if let idx = bookings.firstIndex(where: { $0.id == booking.id }) {
                bookings[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
