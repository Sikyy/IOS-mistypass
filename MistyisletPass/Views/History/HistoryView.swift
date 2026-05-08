import SwiftUI

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()
    @State private var settings = SettingsService.shared

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.events.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        settings.L("history.empty"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(settings.L("history.empty_description"))
                    )
                } else {
                    eventList
                }
            }
            .navigationTitle(settings.L("history.title"))
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
                        NavigationLink {
                            EventDetailView(event: event)
                        } label: {
                            EventRowView(event: event)
                        }
                        .onAppear {
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
            "\(event.doorName), \(event.timestamp.formatted(date: .omitted, time: .shortened))"
        )
    }
}

// MARK: - Event Detail with Media

struct EventDetailView: View {
    let event: AccessEvent
    @State private var media: [EventMedia] = []
    @State private var isLoadingMedia = false
    private let settings = SettingsService.shared

    var body: some View {
        List {
            Section {
                detailRow(label: settings.L("history.door"), value: event.doorName)
                detailRow(label: settings.L("history.time"), value: event.timestamp.formatted(date: .abbreviated, time: .shortened))
                detailRow(label: settings.L("history.result"), value: event.result == .granted ? settings.L("history.granted") : settings.L("history.denied"))
                detailRow(label: settings.L("history.method"), value: event.method.rawValue.uppercased())
                if let reason = event.reason {
                    detailRow(label: "", value: reason)
                }
            }

            Section(settings.L("history.media")) {
                if isLoadingMedia {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if media.isEmpty {
                    Text(settings.L("history.no_media"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(media) { item in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: item.snapshotUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                case .failure:
                                    Image(systemName: "photo")
                                        .frame(width: 80, height: 60)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                default:
                                    ProgressView()
                                        .frame(width: 80, height: 60)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.cameraName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(item.datetime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settings.L("history.event_detail"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMedia() }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            if !label.isEmpty {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .fontWeight(label.isEmpty ? .regular : .medium)
        }
    }

    private func loadMedia() async {
        guard let placeId = SettingsService.shared.selectedPlaceId else { return }
        isLoadingMedia = true
        do {
            media = try await APIService.shared.fetchEventMedia(placeId: placeId, eventId: event.id)
        } catch {
            // Non-critical — media is supplementary
        }
        isLoadingMedia = false
    }
}

#Preview {
    HistoryView()
}
