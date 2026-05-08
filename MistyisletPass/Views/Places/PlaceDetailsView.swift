import SwiftUI

struct PlaceDetailsView: View {
    let placeId: String
    let placeName: String

    @State private var viewModel: PlaceDoorsViewModel
    @State private var settings = SettingsService.shared
    @State private var selectedTab = 0

    init(placeId: String, placeName: String) {
        self.placeId = placeId
        self.placeName = placeName
        self._viewModel = State(initialValue: PlaceDoorsViewModel(placeId: placeId))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                tabPicker
                doorsList
                if viewModel.isLockdown {
                    lockdownBanner
                }
            }

            switch viewModel.unlockState {
            case .connecting, .granted, .denied, .failed:
                UnlockOverlayView(state: viewModel.unlockState)
                    .transition(.opacity)
            default:
                EmptyView()
            }
        }
        .navigationTitle(placeName)
        .searchable(text: $viewModel.searchQuery, prompt: settings.L("doors.search"))
        .refreshable { await viewModel.fetchDoors() }
        .task { await viewModel.fetchDoors() }
        .animation(.easeInOut, value: viewModel.unlockState)
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text(settings.L("doors.all")).tag(0)
            Text(settings.L("doors.favorites")).tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var doorsList: some View {
        let doors = selectedTab == 0 ? viewModel.allDoors : viewModel.favoriteDoors

        return ScrollView {
            if viewModel.isLoading && doors.isEmpty {
                ProgressView()
                    .padding(.top, 40)
            } else if doors.isEmpty {
                ContentUnavailableView(
                    selectedTab == 0 ? settings.L("doors.no_doors") : settings.L("doors.no_favorites"),
                    systemImage: selectedTab == 0 ? "door.left.hand.closed" : "star.slash",
                    description: Text(
                        selectedTab == 0
                            ? settings.L("doors.no_doors_desc")
                            : settings.L("doors.no_favorites_desc")
                    )
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(doors) { door in
                        AccessibleDoorCardView(
                            door: door,
                            placeId: placeId,
                            isBLEReady: viewModel.isBLEReady(for: door),
                            onHoldStart: { viewModel.startHoldToUnlock(door: door) },
                            onHoldProgress: { viewModel.updateHoldProgress($0) },
                            onHoldComplete: { Task { await viewModel.completeUnlock(door: door) } },
                            onHoldCancel: { viewModel.cancelHold() },
                            onToggleFavorite: { Task { await viewModel.toggleFavorite(door: door) } }
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var lockdownBanner: some View {
        HStack {
            Image(systemName: "lock.shield.fill")
            Text(settings.L("doors.lockdown_banner"))
                .fontWeight(.bold)
            Spacer()
            Button(settings.L("doors.disable_lockdown")) {
                Task { await viewModel.toggleLockdown() }
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .font(.callout)
        .foregroundStyle(.white)
        .padding()
        .background(.red.gradient)
    }
}

enum AdminDestination: Hashable {
    case dashboard
}
