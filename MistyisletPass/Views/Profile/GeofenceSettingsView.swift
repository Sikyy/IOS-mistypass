import SwiftUI
import UIKit

struct GeofenceSettingsView: View {
    @State private var geofenceService = GeofenceService.shared
    @State private var isEnabled = false

    var body: some View {
        List {
            Section {
                Toggle("Auto-Unlock Geofence", isOn: $isEnabled)
                    .tint(.brandPrimary)
                    .onChange(of: isEnabled) { _, enabled in
                        if enabled {
                            geofenceService.requestAuthorization()
                        } else {
                            geofenceService.stopAllMonitoring()
                        }
                        UserDefaults.standard.set(enabled, forKey: "settings.geofenceEnabled")
                    }
            } footer: {
                Text("When enabled, you'll receive a notification when you're near a door, making it faster to unlock.")
            }

            Section {
                HStack {
                    Text("Location Permission")
                    Spacer()
                    Text(permissionText)
                        .foregroundStyle(permissionColor)
                }

                HStack {
                    Text("Monitored Doors")
                    Spacer()
                    Text("\(geofenceService.monitoredDoors.count)")
                        .foregroundStyle(.secondary)
                }
            }

            if !geofenceService.isAuthorized && isEnabled {
                Section {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } footer: {
                    Text("Location permission is required for geofence monitoring. Please enable \"While Using\" in Settings.")
                }
            }

            Section("How It Works") {
                Label("A small geofence (50m) is set around each door", systemImage: "mappin.circle")
                Label("When you enter the zone, you get a notification", systemImage: "bell")
                Label("Tap the notification to quickly unlock", systemImage: "lock.open")
                Label("No GPS tracking — only region entry/exit", systemImage: "hand.raised")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Auto-Unlock")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isEnabled = UserDefaults.standard.bool(forKey: "settings.geofenceEnabled")
        }
    }

    private var permissionText: String {
        switch geofenceService.authorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While Using"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default: return "Unknown"
        }
    }

    private var permissionColor: Color {
        switch geofenceService.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return .green
        case .denied, .restricted: return .red
        default: return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        GeofenceSettingsView()
    }
}
