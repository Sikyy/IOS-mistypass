import Foundation
import CoreBluetooth
import CryptoKit

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

    /// Authenticate against a Gateway TCP simulator (for dev/testing without BLE hardware).
    ///
    /// Same v2 challenge-response protocol as BLE GATT, but over a plain TCP socket.
    /// Run gateway-agent on Mac, then call this from a real iOS device on the same network.
    ///
    /// - Parameters:
    ///   - host: IP address of the Mac running gateway-agent (e.g. "192.168.1.100")
    ///   - port: TCP port (default 9900, matching gateway-agent's BLE TCP simulator)
    ///   - expectedGatewayId: Optional gateway ID for challenge validation
    /// - Returns: Auth result code (0x01 = granted, 0x02 = denied)
    func unlockViaTCP(host: String, port: UInt16 = 9900, expectedGatewayId: String? = nil) async throws -> UInt8 {
        return try await TCPAuthClient.shared.authenticate(host: host, port: port, expectedGatewayId: expectedGatewayId)
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
            // Validate v2 challenge structure (52 bytes: nonce[32] + issued_at[8] + expires_at[8] + gateway_id[4])
            guard challengeData.count >= 52 else {
                throw BLEUnlockError.invalidChallenge
            }

            // Check challenge hasn't expired (bytes [40:48] = expires_at as BigEndian uint64 unix timestamp)
            let expiresAtRaw = challengeData[challengeData.startIndex + 40 ..< challengeData.startIndex + 48]
            let expiresAtUnix = expiresAtRaw.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
            let expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtUnix))
            guard expiresAt > Date() else {
                AppLogger.ble.warning("BLE challenge expired, rejecting")
                throw BLEUnlockError.invalidChallenge
            }

            // Validate gateway_id matches the reader identity we read earlier (bytes [48:52])
            if let expectedReaderId = verifiedReaderId,
               let readerIdData = expectedReaderId.data(using: .utf8) {
                let challengeGatewayIdBytes = challengeData[challengeData.startIndex + 48 ..< challengeData.startIndex + 52]
                let challengeGatewayId = challengeGatewayIdBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                let digest = SHA256.hash(data: readerIdData)
                let expectedGatewayId = digest.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                if challengeGatewayId != expectedGatewayId {
                    AppLogger.ble.warning("BLE challenge gateway_id mismatch: got \(challengeGatewayId), expected \(expectedGatewayId)")
                    throw BLEUnlockError.invalidChallenge
                }
            }

            let nonce = challengeData.prefix(32)
            let userId = KeychainService.shared.readString(forKey: "com.mistyislet.userId") ?? ""
            let userIdData = userId.data(using: .utf8) ?? Data()

            var signPayload = Data()
            signPayload.append(nonce)
            signPayload.append(userIdData)
            signPayload.append("BLE".data(using: .utf8)!) // v2 transport binding

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
            guard let data = characteristic.value, data.count >= 52 else {
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
