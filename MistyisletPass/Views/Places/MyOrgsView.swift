import SwiftUI

struct MyOrgsView: View {
    @State private var orgs: [Organization] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var settings = SettingsService.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if orgs.isEmpty {
                ContentUnavailableView(
                    settings.L("places.no_orgs"),
                    systemImage: "building.2",
                    description: Text(settings.L("places.no_orgs_desc"))
                )
            } else if orgs.count == 1, let org = orgs.first {
                Color.clear.onAppear {
                    settings.selectedOrgId = org.id
                    settings.selectedOrgName = org.name
                }
            } else {
                orgList
            }
        }
        .navigationTitle(settings.L("doors.title"))
        .refreshable { await fetchOrgs() }
        .task { await fetchOrgs() }
    }

    private var orgList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(orgs) { org in
                    Button {
                        settings.selectedOrgId = org.id
                        settings.selectedOrgName = org.name
                    } label: {
                        orgCard(org)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func orgCard(_ org: Organization) -> some View {
        HStack(spacing: 14) {
            Text(org.name.prefix(1).uppercased())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.brandPrimary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(org.name)
                    .font(.headline)
                    .lineLimit(1)
                if let domain = org.domain, !domain.isEmpty {
                    Text(domain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let role = org.role {
                    Text(role.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brandPrimary.opacity(0.12))
                        .foregroundStyle(.brandPrimary)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func fetchOrgs() async {
        isLoading = orgs.isEmpty
        do {
            orgs = try await APIService.shared.listOrgs()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
