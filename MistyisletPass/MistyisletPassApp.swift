import SwiftUI
import SwiftData

@main
struct MistyisletPassApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    MainTabView()
                        .environment(authViewModel)
                } else {
                    LoginView()
                        .environment(authViewModel)
                }
            }
            .animation(.easeInOut, value: authViewModel.isAuthenticated)
            .onOpenURL { url in
                DeepLinkRouter.shared.handle(url: url)
            }
            .task {
                if authViewModel.isAuthenticated {
                    _ = await NotificationService.shared.requestAuthorization()
                    await authViewModel.renewCredentialIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await authViewModel.renewCredentialIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
                authViewModel.logout()
            }
        }
        .modelContainer(for: [CachedDoor.self, CachedAccessEvent.self])
    }
}

// MARK: - AppDelegate for APNs

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await NotificationService.shared.registerDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // APNs registration failed — BLE still works, so this is non-fatal
    }
}
