import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    private let router = DeepLinkRouter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "tab.doors"), systemImage: "house.fill", value: 0) {
                DoorsView()
            }

            Tab(String(localized: "tab.pass"), systemImage: "qrcode", value: 1) {
                QRPassView()
            }

            Tab(String(localized: "tab.history"), systemImage: "clock.arrow.circlepath", value: 2) {
                HistoryView()
            }

            Tab(String(localized: "tab.visitors"), systemImage: "person.badge.plus", value: 3) {
                VisitorsView()
            }

            Tab(String(localized: "tab.profile"), systemImage: "person.crop.circle", value: 4) {
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

#Preview {
    MainTabView()
        .modelContainer(for: [CachedDoor.self, CachedAccessEvent.self], inMemory: true)
        .environment(AuthViewModel())
}
