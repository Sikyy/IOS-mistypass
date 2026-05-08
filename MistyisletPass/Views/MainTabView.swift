import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var settings = SettingsService.shared
    private let router = DeepLinkRouter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(settings.L("tab.doors"), systemImage: "door.left.hand.closed", value: 0) {
                NavigationStack {
                    DoorsRootView()
                }
            }

            Tab(settings.L("tab.pass"), systemImage: "wallet.pass", value: 1) {
                WalletView()
            }

            Tab(settings.L("tab.dashboard"), systemImage: "square.grid.2x2", value: 2) {
                NavigationStack {
                    DashboardTabView()
                }
            }

            Tab(settings.L("tab.profile"), systemImage: "person.crop.circle", value: 3) {
                ProfileView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color.brandPrimary)
        .onChange(of: router.pendingTab) { _, tab in
            if let tab {
                selectedTab = tab
                router.pendingTab = nil
            }
        }
    }
}

/// Root view for the Doors tab. Shows the org→place→doors hierarchy,
/// skipping levels when only one option exists.
struct DoorsRootView: View {
    @State private var settings = SettingsService.shared

    var body: some View {
        if let placeId = settings.selectedPlaceId,
           let placeName = settings.selectedPlaceName {
            PlaceDetailsView(placeId: placeId, placeName: placeName)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            settings.selectedPlaceId = nil
                            settings.selectedPlaceName = nil
                        } label: {
                            Label("Places", systemImage: "chevron.left")
                        }
                    }
                }
        } else if let orgId = settings.selectedOrgId,
                  let orgName = settings.selectedOrgName {
            MyPlacesView(orgId: orgId, orgName: orgName)
        } else {
            MyOrgsView()
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [CachedDoor.self, CachedAccessEvent.self], inMemory: true)
        .environment(AuthViewModel())
}
