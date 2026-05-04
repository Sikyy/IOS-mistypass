import SwiftUI

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.events.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Your access history will appear here.")
                    )
                } else {
                    eventList
                }
            }
            .navigationTitle("History")
            .refreshable {
                await viewModel.fetchEvents()
            }
            .task {
                await viewModel.fetchEvents()
            }
        }
    }

    private var eventList: some View {
        List {
            ForEach(viewModel.groupedEvents, id: \.0) { section in
                Section(section.0) {
                    ForEach(section.1) { event in
                        EventRowView(event: event)
                            .onAppear {
                                // Load more when reaching the last event
                                if event.id == viewModel.events.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                    }
                }
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct EventRowView: View {
    let event: AccessEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.result == .granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(event.result == .granted ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.doorName)
                    .font(.headline)
                if let reason = event.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.timestamp, style: .time)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(event.method.rawValue.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(event.result == .granted ? "Granted" : "Denied"), \(event.doorName), \(event.timestamp.formatted(date: .omitted, time: .shortened))"
        )
    }
}

#Preview {
    HistoryView()
}
