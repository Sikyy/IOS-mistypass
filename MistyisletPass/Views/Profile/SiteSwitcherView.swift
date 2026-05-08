import SwiftUI

struct SiteSwitcherView: View {
    @Environment(ProfileViewModel.self) private var viewModel

    @State private var orgs: [Organization] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var settings = SettingsService.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Button {
                    settings.selectedOrgId = nil
                    settings.selectedOrgName = nil
                    dismiss()
                } label: {
                    HStack {
                        Label("All Organizations", systemImage: "building.2")
                            .foregroundStyle(.primary)
                        Spacer()
                        if settings.selectedOrgId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.brandPrimary)
                        }
                    }
                }
            }

            Section("Your Organizations") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if orgs.isEmpty {
                    Text(settings.L("places.no_orgs"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(orgs) { org in
                        Button {
                            settings.selectedOrgId = org.id
                            settings.selectedOrgName = org.name
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(org.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if let role = org.role {
                                        Text(role.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if settings.selectedOrgId == org.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.brandPrimary)
                                }
                            }
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Select Organization")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchOrgs()
        }
    }

    private func fetchOrgs() async {
        isLoading = true
        do {
            orgs = try await APIService.shared.listOrgs()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SiteSwitcherView()
            .environment(ProfileViewModel())
    }
}
