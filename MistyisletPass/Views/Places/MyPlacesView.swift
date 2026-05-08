import SwiftUI

struct MyPlacesView: View {
    let orgId: String
    let orgName: String

    @State private var places: [Place] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var settings = SettingsService.shared
    @State private var searchText = ""

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if places.isEmpty {
                ContentUnavailableView(
                    settings.L("places.no_places"),
                    systemImage: "mappin.slash",
                    description: Text(settings.L("places.no_places_desc"))
                )
            } else if places.count == 1, let place = places.first {
                Color.clear.onAppear {
                    settings.selectedPlaceId = place.id
                    settings.selectedPlaceName = place.name
                }
            } else {
                placeList
            }
        }
        .navigationTitle(orgName)
        .searchable(text: $searchText, prompt: settings.L("doors.search"))
        .refreshable { await fetchPlaces() }
        .task { await fetchPlaces() }
    }

    private var filteredPlaces: [Place] {
        if searchText.isEmpty { return places }
        return places.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var placeList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredPlaces) { place in
                    Button {
                        settings.selectedPlaceId = place.id
                        settings.selectedPlaceName = place.name
                    } label: {
                        placeCard(place)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func placeCard(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: gradientColors(for: place.id),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)
                .overlay(alignment: .center) {
                    Text(place.name.prefix(1).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }

                if place.isLockdown {
                    Label(settings.L("doors.lockdown"), systemImage: "lock.shield.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                    .lineLimit(1)

                if let address = place.address, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "door.left.hand.closed")
                            .font(.caption2)
                        Text("\(place.doorCount)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)

                    if let capacity = place.capacity, capacity > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.caption2)
                            Text("\(place.currentOccupancy ?? 0)/\(capacity)")
                                .font(.caption2)
                        }
                        .foregroundStyle(occupancyColor(place))
                    }
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func gradientColors(for id: String) -> [Color] {
        let hash = abs(id.hashValue)
        let palettes: [[Color]] = [
            [.blue, .purple],
            [.teal, .blue],
            [.indigo, .pink],
            [.green, .teal],
            [.orange, .red],
            [.purple, .indigo],
        ]
        return palettes[hash % palettes.count]
    }

    private func occupancyColor(_ place: Place) -> Color {
        guard let capacity = place.capacity, capacity > 0 else { return .secondary }
        let ratio = Double(place.currentOccupancy ?? 0) / Double(capacity)
        if ratio >= 0.9 { return .red }
        if ratio >= 0.7 { return .orange }
        return .green
    }

    private func fetchPlaces() async {
        isLoading = places.isEmpty
        do {
            places = try await APIService.shared.listPlaces(orgId: orgId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
