import Foundation

@MainActor @Observable
final class HistoryViewModel {
    var events: [AccessEvent] = []
    var isLoading = false
    var errorMessage: String?
    private var currentPage = 1
    private var hasMorePages = true

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var groupedEvents: [(String, [AccessEvent])] {
        let calendar = Calendar.current
        let settings = SettingsService.shared
        let grouped = Dictionary(grouping: events) { event -> String in
            if calendar.isDateInToday(event.timestamp) {
                return settings.L("history.today")
            } else if calendar.isDateInYesterday(event.timestamp) {
                return settings.L("history.yesterday")
            } else {
                return Self.dateFormatter.string(from: event.timestamp)
            }
        }

        return grouped.sorted { lhs, rhs in
            let lhsDate = lhs.value.first?.timestamp ?? .distantPast
            let rhsDate = rhs.value.first?.timestamp ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    func fetchEvents() async {
        guard !Constants.AppEnvironment.isPreview else { return }
        isLoading = true
        currentPage = 1
        errorMessage = nil

        do {
            events = try await APIService.shared.fetchEvents(offset: 0, limit: 20)
            hasMorePages = events.count >= 20
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMorePages, !isLoading else { return }

        currentPage += 1
        do {
            let offset = (currentPage - 1) * 20
            let newEvents = try await APIService.shared.fetchEvents(offset: offset, limit: 20)
            events.append(contentsOf: newEvents)
            hasMorePages = newEvents.count >= 20
        } catch {
            currentPage -= 1
            errorMessage = error.localizedDescription
        }
    }
}
