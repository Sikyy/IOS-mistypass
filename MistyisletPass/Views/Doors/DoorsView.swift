import SwiftUI
import SwiftData

struct DoorsView: View {
    @State private var viewModel = DoorsViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                doorList

                // Unlock overlay (only for states that render content, not .idle/.holding)
                switch viewModel.unlockState {
                case .connecting, .granted, .denied, .failed:
                    UnlockOverlayView(state: viewModel.unlockState)
                        .transition(.opacity)
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Doors")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { viewModel.sortOrder = .name } label: {
                            Label("Name", systemImage: viewModel.sortOrder == .name ? "checkmark" : "")
                        }
                        Button { viewModel.sortOrder = .status } label: {
                            Label("Status", systemImage: viewModel.sortOrder == .status ? "checkmark" : "")
                        }
                        Button { viewModel.sortOrder = .building } label: {
                            Label("Building", systemImage: viewModel.sortOrder == .building ? "checkmark" : "")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .refreshable {
                await viewModel.fetchDoors(modelContext: modelContext)
            }
            .task {
                await viewModel.fetchDoors(modelContext: modelContext)
            }
            .animation(.easeInOut, value: viewModel.unlockState)
        }
    }

    private var doorList: some View {
        ScrollView {
            if viewModel.isOffline {
                offlineBanner
            }

            LazyVStack(spacing: 12) {
                ForEach(viewModel.sortedDoors) { door in
                    DoorCardView(
                        door: door,
                        isBLEReady: viewModel.isBLEReady(for: door),
                        onHoldStart: { viewModel.startHoldToUnlock(door: door) },
                        onHoldProgress: { viewModel.updateHoldProgress($0) },
                        onHoldComplete: { Task { await viewModel.completeUnlock(door: door) } },
                        onHoldCancel: { viewModel.cancelHold() }
                    )
                }
            }
            .padding()
        }
    }

    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("Offline")
            if let lastSync = viewModel.lastSyncedAt {
                Text("- Last synced \(lastSync, style: .relative) ago")
                    .font(.caption)
            }
        }
        .font(.callout)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal)
        .glassEffect(.regular.tint(.orange), in: .capsule)
    }
}

#Preview {
    DoorsView()
        .modelContainer(for: CachedDoor.self, inMemory: true)
}
