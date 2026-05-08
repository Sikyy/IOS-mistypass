import Foundation

@MainActor @Observable
final class PlaceDoorsViewModel {
    var doors: [AccessibleDoor] = []
    var isLoading = true
    var errorMessage: String?
    var unlockState: UnlockState = .idle
    var isLockdown = false
    var searchQuery = ""

    let placeId: String

    private let bleManager = BLEManager.shared
    private let hapticService = HapticService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let biometricService = BiometricService.shared
    private let biometricEnabled: Bool

    init(placeId: String) {
        self.placeId = placeId
        self.biometricEnabled = SettingsService.shared.biometricEnabled
    }

    var allDoors: [AccessibleDoor] {
        if searchQuery.isEmpty { return doors }
        return doors.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    var favoriteDoors: [AccessibleDoor] {
        let filtered = doors.filter(\.isFavorite)
        if searchQuery.isEmpty { return filtered }
        return filtered.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    // MARK: - Fetch

    func fetchDoors() async {
        guard !Constants.AppEnvironment.isPreview else { return }
        isLoading = true
        errorMessage = nil

        do {
            doors = try await APIService.shared.fetchPlaceDoors(placeId: placeId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func searchDoors() async {
        guard !searchQuery.isEmpty else {
            await fetchDoors()
            return
        }
        isLoading = true
        do {
            doors = try await APIService.shared.searchPlaceDoors(placeId: placeId, query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Favorites

    func toggleFavorite(door: AccessibleDoor) async {
        do {
            if door.isFavorite {
                try await APIService.shared.unfavoriteDoor(placeId: placeId, doorId: door.id)
            } else {
                try await APIService.shared.favoriteDoor(placeId: placeId, doorId: door.id)
            }
            await fetchDoors()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Lockdown

    func toggleLockdown() async {
        do {
            if isLockdown {
                try await APIService.shared.disableLockdown(placeId: placeId)
            } else {
                try await APIService.shared.enableLockdown(placeId: placeId)
            }
            isLockdown.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Unlock

    func startHoldToUnlock(door: AccessibleDoor) {
        guard door.canUnlock else { return }
        hapticService.holdStart()
        unlockState = .holding(progress: 0)
    }

    func updateHoldProgress(_ progress: Double) {
        if case .holding = unlockState {
            unlockState = .holding(progress: min(progress, 1.0))
        }
    }

    func cancelHold() {
        unlockState = .idle
    }

    func completeUnlock(door: AccessibleDoor) async {
        if biometricEnabled && biometricService.isAvailable {
            do {
                try await biometricService.authenticate(reason: "Authenticate to unlock \(door.name)")
            } catch BiometricError.cancelled {
                unlockState = .idle
                return
            } catch {
                unlockState = .denied(doorName: door.name, reason: "Biometric authentication failed")
                hapticService.unlockDenied()
                try? await Task.sleep(for: .seconds(Constants.UI.unlockOverlayDismissDelay))
                unlockState = .idle
                return
            }
        }

        unlockState = .connecting
        hapticService.buttonTap()

        if bleManager.bleReadyDoorIds.contains(door.id) {
            await bleUnlock(door: door)
        } else {
            await remoteUnlock(door: door)
        }
    }

    private func bleUnlock(door: AccessibleDoor) async {
        do {
            let result = try await bleManager.unlock(doorId: door.id)
            if result == Constants.BLE.resultGranted {
                hapticService.unlockGranted()
                unlockState = .granted(doorName: door.name)
            } else {
                hapticService.unlockDenied()
                unlockState = .denied(doorName: door.name, reason: "Access denied by controller")
            }
        } catch {
            await remoteUnlock(door: door)
        }

        try? await Task.sleep(for: .seconds(Constants.UI.unlockOverlayDismissDelay))
        unlockState = .idle
    }

    private func remoteUnlock(door: AccessibleDoor) async {
        do {
            let response = try await APIService.shared.placeUnlockDoor(placeId: placeId, doorId: door.id)
            if response.isGranted {
                hapticService.unlockGranted()
                unlockState = .granted(doorName: door.name)
            } else {
                hapticService.unlockDenied()
                unlockState = .denied(doorName: door.name, reason: response.reason ?? "Access denied")
            }
        } catch {
            hapticService.unlockDenied()
            unlockState = .failed(doorName: door.name, reason: error.localizedDescription)
        }

        try? await Task.sleep(for: .seconds(Constants.UI.unlockOverlayDismissDelay))
        unlockState = .idle
    }

    func isBLEReady(for door: AccessibleDoor) -> Bool {
        bleManager.bleReadyDoorIds.contains(door.id)
    }
}
