import SwiftUI

struct SiteSwitcherView: View {
    let viewModel: ProfileViewModel

    @State private var sites: [Site] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var settings = SettingsService.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // "All Sites" option
            Section {
                Button {
                    settings.selectedSiteId = nil
                    settings.selectedSiteName = nil
                    dismiss()
                } label: {
                    HStack {
                        Label("All Sites", systemImage: "building.2")
                            .foregroundStyle(.primary)
                        Spacer()
                        if settings.selectedSiteId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.brandPrimary)
                        }
                    }
                }
            }

            // Sites list
            Section("Your Sites") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if sites.isEmpty {
                    Text("No sites available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sites) { site in
                        Button {
                            settings.selectedSiteId = site.id
                            settings.selectedSiteName = site.name
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(site.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(site.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(site.buildingCount) buildings")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.selectedSiteId == site.id {
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
        .navigationTitle("Select Site")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchSites()
        }
    }

    private func fetchSites() async {
        isLoading = true
        do {
            guard let url = URL(string: Constants.API.baseURL + "/app/sites") else { return }
            var request = URLRequest(url: url)
            if let token = KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            sites = try decoder.decode([Site].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SiteSwitcherView(viewModel: ProfileViewModel())
    }
}
