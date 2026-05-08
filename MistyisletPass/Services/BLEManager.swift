import Foundation
import CoreBluetooth

extension CBPeripheral: @unchecked @retroactive Sendable {}

@MainActor @Observable
final class BLEManager: NSObject, @unchecked Sendable {
    static let shared = BLEManager()

    // MARK: - Observable State (MainActor)

    var isScanning = false
    var discoveredControllers: [String: CBPeripheral] = [:]
    var bleReadyDoorIds: Set<String> = []

    // MARK: - BLE-Internal State (serialized on bleQueue)

    nonisolated(unsafe) private var centralManager: CBCentralManager!
    private let bleQueue = DispatchQueue(label: "com.mistyislet.ble", qos: .userInitiated)
    nonisolated(unsafe) private var connectedPeripheral: CBPeripheral?
    nonisolated(unsafe) private var authResultContinuation: CheckedContinuation<UInt8, Error>?
    nonisolated(unsafe) private var challengeCharacteristic: CBCharacteristic?
    nonisolated(unsafe) private var authResponseCharacteristic: CBCharacteristic?
    nonisolated(unsafe) private var authResultCharacteristic: CBCharacteristic?
    nonisolated(unsafe) private var readerIdentityCharacteristic: CBCharacteristic?
    nonisolated(unsafe) private var verifiedReaderId: String?

    override private init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: bleQueue,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: "mistyislet-ble",
            ]
        )
    }

    // MARK: - Public API

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: [Constants.BLE.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        discoveredControllers.removeAll()
        bleReadyDoorIds.removeAll()
    }

    func unlock(doorId: String) async throws -> UInt8 {
        guard let peripheral = discoveredControllers[doorId] else {
            throw BLEUnlockError.controllerNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            bleQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: BLEUnlockError.connectionFailed)
                    return
                }
                guard self.authResultContinuation == nil else {
                    continuation.resume(throwing: BLEUnlockError.connectionFailed)
                    return
                }
                self.authResultContinuation = continuation
                self.connectedPeripheral = peripheral
                self.centralManager.connect(peripheral, options: nil)

                self.bleQueue.asyncAfter(deadline: .now() + Constants.BLE.connectionTimeout) { [weak self] in
                    self?.finishUnlock(.failure(BLEUnlockError.timeout))
                }
            }
        }
    }

    /// Resume the pending unlock continuation exactly once.
    /// Must be called on bleQueue (where all delegate callbacks land).
    nonisolated fileprivate func finishUnlock(_ result: Result<UInt8, Error>) {
        dispatchPrecondition(condition: .onQueue(bleQueue))
        guard let continuation = authResultContinuation else { return }
        authResultContinuation = nil
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
        }
        challengeCharacteristic = nil
        authResponseCharacteristic = nil
        authResultCharacteristic = nil
        readerIdentityCharacteristic = nil
        verifiedReaderId = nil
        switch result {
        case .success(let code): continuation.resume(returning: code)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }

    nonisolated private func signAndRespond(challengeData: Data, peripheral: CBPeripheral) {
        guard let authResponseChar = authResponseCharacteristic else { return }

        do {
            let nonce = challengeData.prefix(32)
            let userId = KeychainService.shared.readString(forKey: "com.mistyislet.userId") ?? ""
            let userIdData = userId.data(using: .utf8) ?? Data()

            var signPayload = Data()
            signPayload.append(nonce)
            signPayload.append(userIdData)

            let signature = try SecureEnclaveService.shared.sign(data: signPayload)

            var response = Data()
            response.append(UInt8(userIdData.count))
            response.append(userIdData)
            response.append(signature)

            peripheral.writeValue(response, for: authResponseChar, type: .withResponse)
        } catch {
            finishUnlock(.failure(error))
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        AppLogger.ble.info("Central manager state changed: \(String(describing: central.state.rawValue))")
        if central.state == .poweredOn {
            Task { @MainActor in startScanning() }
        } else {
            Task { @MainActor in isScanning = false }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let doorIdData = serviceData[Constants.BLE.serviceUUID],
           let doorId = String(data: doorIdData, encoding: .utf8) {
            AppLogger.ble.info("Discovered peripheral for door \(doorId)")
            Task { @MainActor in
                self.discoveredControllers[doorId] = peripheral
                self.bleReadyDoorIds.insert(doorId)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        AppLogger.ble.info("Connected to peripheral \(peripheral.identifier.uuidString)")
        peripheral.delegate = self
        peripheral.discoverServices([Constants.BLE.serviceUUID])
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        AppLogger.ble.error("Failed to connect to peripheral: \(error?.localizedDescription ?? "unknown")")
        finishUnlock(.failure(BLEUnlockError.connectionFailed))
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error {
            AppLogger.ble.error("Peripheral disconnected with error: \(error.localizedDescription)")
            finishUnlock(.failure(BLEUnlockError.connectionFailed))
        } else {
            AppLogger.ble.info("Peripheral disconnected")
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else { return }
        AppLogger.ble.info("Restoring \(peripherals.count) peripheral(s) from background")
        for peripheral in peripherals {
            peripheral.delegate = self
        }
        if central.state == .poweredOn {
            Task { @MainActor in self.startScanning() }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Constants.BLE.serviceUUID }) else {
            return
        }
        peripheral.discoverCharacteristics([
            Constants.BLE.challengeUUID,
            Constants.BLE.authResponseUUID,
            Constants.BLE.authResultUUID,
            Constants.BLE.readerIdentityUUID,
        ], for: service)
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            finishUnlock(.failure(BLEUnlockError.invalidResponse))
            return
        }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case Constants.BLE.challengeUUID:
                challengeCharacteristic = characteristic
            case Constants.BLE.authResponseUUID:
                authResponseCharacteristic = characteristic
            case Constants.BLE.authResultUUID:
                authResultCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case Constants.BLE.readerIdentityUUID:
                readerIdentityCharacteristic = characteristic
            default:
                break
            }
        }

        if let readerIdChar = readerIdentityCharacteristic {
            peripheral.readValue(for: readerIdChar)
        } else if let challengeChar = challengeCharacteristic {
            peripheral.readValue(for: challengeChar)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case Constants.BLE.readerIdentityUUID:
            if let data = characteristic.value, let readerId = String(data: data, encoding: .utf8), !readerId.isEmpty {
                verifiedReaderId = readerId
            }
            if let challengeChar = challengeCharacteristic {
                peripheral.readValue(for: challengeChar)
            }

        case Constants.BLE.challengeUUID:
            guard let data = characteristic.value, data.count >= 48 else {
                AppLogger.ble.error("Invalid BLE challenge data")
                finishUnlock(.failure(BLEUnlockError.invalidChallenge))
                return
            }
            AppLogger.ble.info("Received auth challenge, signing response")
            signAndRespond(challengeData: data, peripheral: peripheral)

        case Constants.BLE.authResultUUID:
            guard let data = characteristic.value, let resultCode = data.first else {
                AppLogger.ble.error("Invalid auth result from controller")
                finishUnlock(.failure(BLEUnlockError.invalidResponse))
                return
            }
            AppLogger.ble.info("Auth result received: \(resultCode)")
            finishUnlock(.success(resultCode))

        default:
            break
        }
    }
}

// MARK: - Errors

enum BLEUnlockError: Error, LocalizedError {
    case controllerNotFound
    case connectionFailed
    case timeout
    case invalidChallenge
    case invalidResponse
    case bluetoothOff

    var errorDescription: String? {
        switch self {
        case .controllerNotFound: return "Door controller not found nearby"
        case .connectionFailed: return "Failed to connect to controller"
        case .timeout: return "Connection timed out"
        case .invalidChallenge: return "Invalid challenge from controller"
        case .invalidResponse: return "Invalid response from controller"
        case .bluetoothOff: return "Bluetooth is turned off"
        }
    }
}
