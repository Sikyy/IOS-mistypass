import Foundation
import SwiftData

@MainActor @Observable
final class DoorsViewModel {
    var doors: [Door] = []
    var isLoading = false
    var isOffline = false
    var lastSyncedAt: Date?
    var unlockState: UnlockState = .idle
    var errorMessage: String?

    var biometricEnabled = true
    var sortOrder: DoorSortOrder = .status

    private let bleManager = BLEManager.shared
    private let hapticService = HapticService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let biometricService = BiometricService.shared

    var sortedDoors: [Door] {
        doors.sorted { lhs, rhs in
            switch sortOrder {
            case .name:
                return lhs.name < rhs.name
            case .status:
                if lhs.controllerOnline != rhs.controllerOnline {
                    return lhs.controllerOnline
                }
                return lhs.name < rhs.name
            case .building:
                if lhs.building != rhs.building {
                    return lhs.building < rhs.building
                }
                return lhs.name < rhs.name
            }
        }
    }

    // MARK: - Fetch Doors

    func fetchDoors(modelContext: ModelContext) async {
        isLoading = true
        isOffline = !networkMonitor.isConnected

        if networkMonitor.isConnected {
            do {
                let remoteDoors = try await APIService.shared.fetchDoors()
                doors = remoteDoors
                isOffline = false
                lastSyncedAt = Date()
                cacheDoors(remoteDoors, modelContext: modelContext)
            } catch {
                loadCachedDoors(modelContext: modelContext)
                isOffline = true
                errorMessage = error.localizedDescription
            }
        } else {
            loadCachedDoors(modelContext: modelContext)
        }

        isLoading = false
    }

    // MARK: - BLE Unlock

    func startHoldToUnlock(door: Door) {
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

    func completeUnlock(door: Door) async {
        // Biometric gate before unlock
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

        // Try BLE first, then remote
        if bleManager.bleReadyDoorIds.contains(door.id) {
            await bleUnlock(door: door)
        } else {
            await remoteUnlock(door: door)
        }
    }

    private func bleUnlock(door: Door) async {
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
            // Fallback to remote unlock
            await remoteUnlock(door: door)
        }

        // Auto-dismiss after delay
        try? await Task.sleep(for: .seconds(Constants.UI.unlockOverlayDismissDelay))
        unlockState = .idle
    }

    private func remoteUnlock(door: Door) async {
        do {
            let response = try await APIService.shared.remoteUnlock(doorId: door.id)
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

    // MARK: - Cache

    private func cacheDoors(_ doors: [Door], modelContext: ModelContext) {
        // Clear old cache
        try? modelContext.delete(model: CachedDoor.self)

        for door in doors {
            modelContext.insert(CachedDoor(from: door))
        }
        try? modelContext.save()
    }

    private func loadCachedDoors(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CachedDoor>()
        if let cached = try? modelContext.fetch(descriptor) {
            doors = cached.map { $0.toDoor() }
            lastSyncedAt = cached.first?.lastSyncedAt
        }
    }

    func isBLEReady(for door: Door) -> Bool {
        bleManager.bleReadyDoorIds.contains(door.id)
    }
}
