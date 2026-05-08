import SwiftUI
import UIKit

struct GeofenceSettingsView: View {
    @State private var geofenceService = GeofenceService.shared
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            Section {
                Toggle(settings.L("geofence.toggle"), isOn: Bindable(settings).geofenceEnabled)
                    .tint(.brandPrimary)
                    .onChange(of: settings.geofenceEnabled) { _, enabled in
                        if enabled {
                            geofenceService.requestAuthorization()
                        } else {
                            geofenceService.stopAllMonitoring()
                        }
                    }
            } footer: {
                Text(settings.L("geofence.description"))
            }

            Section {
                HStack {
                    Text(settings.L("geofence.location_permission"))
                    Spacer()
                    Text(permissionText)
                        .foregroundStyle(permissionColor)
                }

                HStack {
                    Text(settings.L("geofence.monitored_doors"))
                    Spacer()
                    Text("\(geofenceService.monitoredDoors.count)")
                        .foregroundStyle(.secondary)
                }
            }

            if !geofenceService.isAuthorized && settings.geofenceEnabled {
                Section {
                    Button(settings.L("geofence.open_settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } footer: {
                    Text(settings.L("geofence.permission_required"))
                }
            }

            Section(settings.L("geofence.how_it_works")) {
                Label(settings.L("geofence.step_1"), systemImage: "mappin.circle")
                Label(settings.L("geofence.step_2"), systemImage: "bell")
                Label(settings.L("geofence.step_3"), systemImage: "lock.open")
                Label(settings.L("geofence.step_4"), systemImage: "hand.raised")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .navigationTitle(settings.L("geofence.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var permissionText: String {
        switch geofenceService.authorizationStatus {
        case .authorizedAlways: return settings.L("geofence.perm_always")
        case .authorizedWhenInUse: return settings.L("geofence.perm_while_using")
        case .denied: return settings.L("geofence.perm_denied")
        case .restricted: return settings.L("geofence.perm_restricted")
        case .notDetermined: return settings.L("geofence.perm_not_set")
        @unknown default: return "—"
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
