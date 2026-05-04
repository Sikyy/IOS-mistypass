import Foundation
import CoreBluetooth

@Observable
final class BLEManager: NSObject {
    static let shared = BLEManager()

    // MARK: - Published State

    var isScanning = false
    var discoveredControllers: [String: CBPeripheral] = [:]  // doorId -> peripheral
    var bleReadyDoorIds: Set<String> = []

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private let bleQueue = DispatchQueue(label: "com.mistyislet.ble", qos: .userInitiated)
    private var connectedPeripheral: CBPeripheral?
    private var authResultContinuation: CheckedContinuation<UInt8, Error>?
    private var challengeCharacteristic: CBCharacteristic?
    private var authResponseCharacteristic: CBCharacteristic?
    private var authResultCharacteristic: CBCharacteristic?
    private var readerIdentityCharacteristic: CBCharacteristic?
    private var verifiedReaderId: String?

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
    }

    /// Perform BLE unlock: connect → read challenge → sign → write auth → await result
    func unlock(doorId: String) async throws -> UInt8 {
        guard let peripheral = discoveredControllers[doorId] else {
            throw BLEUnlockError.controllerNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Install continuation and start connection on bleQueue so the
            // continuation, the timeout fire, and CoreBluetooth delegate callbacks
            // are all serialized — preventing a double-resume race.
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

    /// Resume the pending unlock continuation exactly once. No-op if already resumed.
    /// Must be called on bleQueue (where all delegate callbacks land).
    fileprivate func finishUnlock(_ result: Result<UInt8, Error>) {
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

    private func signAndRespond(challengeData: Data, peripheral: CBPeripheral) {
        guard let authResponseChar = authResponseCharacteristic else { return }

        do {
            // Extract nonce from challenge: [32B nonce][8B issued_at][8B expires_at]
            let nonce = challengeData.prefix(32)
            let userId = KeychainService.shared.readString(forKey: "com.mistyislet.userId") ?? ""
            let userIdData = userId.data(using: .utf8) ?? Data()

            // Sign: SHA256(nonce || userID) — matches Android signChallenge() and Go VerifyBLESignature.
            var signPayload = Data()
            signPayload.append(nonce)
            signPayload.append(userIdData)

            let signature = try SecureEnclaveService.shared.sign(data: signPayload)

            // Build response: [1B userID_len][userID][signature]
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
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            DispatchQueue.main.async { self.isScanning = false }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // Map peripheral to door ID from advertisement data
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let doorIdData = serviceData[Constants.BLE.serviceUUID],
           let doorId = String(data: doorIdData, encoding: .utf8) {
            DispatchQueue.main.async {
                self.discoveredControllers[doorId] = peripheral
                self.bleReadyDoorIds.insert(doorId)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([Constants.BLE.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finishUnlock(.failure(BLEUnlockError.connectionFailed))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            finishUnlock(.failure(BLEUnlockError.connectionFailed))
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        // State restoration for background BLE
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                peripheral.delegate = self
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
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

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
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

        // Read reader identity first; challenge is read after identity is verified.
        if let readerIdChar = readerIdentityCharacteristic {
            peripheral.readValue(for: readerIdChar)
        } else if let challengeChar = challengeCharacteristic {
            peripheral.readValue(for: challengeChar)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case Constants.BLE.readerIdentityUUID:
            if let data = characteristic.value, let readerId = String(data: data, encoding: .utf8), !readerId.isEmpty {
                verifiedReaderId = readerId
            }
            // Chain: now read the challenge
            if let challengeChar = challengeCharacteristic {
                peripheral.readValue(for: challengeChar)
            }

        case Constants.BLE.challengeUUID:
            guard let data = characteristic.value, data.count >= 48 else {
                finishUnlock(.failure(BLEUnlockError.invalidChallenge))
                return
            }
            signAndRespond(challengeData: data, peripheral: peripheral)

        case Constants.BLE.authResultUUID:
            guard let data = characteristic.value, let resultCode = data.first else {
                finishUnlock(.failure(BLEUnlockError.invalidResponse))
                return
            }
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
