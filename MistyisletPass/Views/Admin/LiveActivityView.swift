import SwiftUI

struct LiveActivityView: View {
    let placeId: String
    @State private var activities: [UserActivity] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if activities.isEmpty {
                ContentUnavailableView(
                    settings.L("activity.no_one"),
                    systemImage: "person.slash",
                    description: Text(settings.L("activity.no_one_desc"))
                )
                .listRowBackground(Color.clear)
            } else {
                activitySummary

                Section(settings.L("activity.people_in_building")) {
                    ForEach(activities) { entry in
                        activityRow(entry)
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
        .navigationTitle(settings.L("activity.title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private var activitySummary: some View {
        Section {
            HStack(spacing: 24) {
                Spacer()
                VStack(spacing: 4) {
                    Text("\(activities.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text(settings.L("activity.active_now"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private func activityRow(_ entry: UserActivity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.brandPrimary)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.userId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Label(entry.lastDoor, systemImage: "door.left.hand.closed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.lastSeenAgo)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            activities = try await APIService.shared.fetchUserActivity(placeId: placeId)
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if activities.isEmpty {
            let now = ISO8601DateFormatter().string(from: Date())
            let recent = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-180))
            activities = [
                UserActivity(userId: "user1@example.com", placeId: placeId,
                             lastSeen: now, lastDoor: "Main Entrance", eventId: "e1"),
                UserActivity(userId: "admin@example.com", placeId: placeId,
                             lastSeen: recent, lastDoor: "Server Room", eventId: "e2"),
                UserActivity(userId: "guard@example.com", placeId: placeId,
                             lastSeen: recent, lastDoor: "Lobby", eventId: "e3"),
            ]
        }
        #endif
        isLoading = false
    }
}
