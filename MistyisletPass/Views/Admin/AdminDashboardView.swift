import SwiftUI

struct AdminDashboardView: View {
    let placeId: String
    let placeName: String

    var body: some View {
        List {
            Section("Access Management") {
                adminRow(title: "Users", icon: "person.2", color: .blue)
                adminRow(title: "Events", icon: "clock.arrow.circlepath", color: .green)
                adminRow(title: "Incidents", icon: "exclamationmark.shield", color: .red)
            }

            Section("Configuration") {
                adminRow(title: "Schedules", icon: "calendar.badge.clock", color: .purple)
                adminRow(title: "Zones", icon: "map", color: .teal)
                adminRow(title: "Teams", icon: "person.3", color: .indigo)
            }

            Section("Credentials") {
                adminRow(title: "Cards", icon: "creditcard", color: .orange)
                adminRow(title: "Digital Credentials", icon: "key.horizontal", color: .cyan)
            }
        }
        .navigationTitle("Admin")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func adminRow(title: String, icon: String, color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
    }
}
