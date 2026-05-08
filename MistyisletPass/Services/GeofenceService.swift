import Foundation
import CoreLocation
import UserNotifications

/// Monitors circular geofence regions around door controllers.
/// When user enters a region, triggers a notification or auto-prepares BLE unlock.
@MainActor @Observable
final class GeofenceService: NSObject {
    static let shared = GeofenceService()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var monitoredDoors: [String: CLCircularRegion] = [:]  // doorId -> region
    var enteredRegionDoorId: String?

    private let locationManager = CLLocationManager()
    private let maxMonitoredRegions = 20  // iOS limit

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Authorization

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    // MARK: - Region Monitoring

    /// Start monitoring a geofence around a door's location.
    /// - Parameters:
    ///   - doorId: Unique door identifier
    ///   - latitude: Door controller latitude
    ///   - longitude: Door controller longitude
    ///   - radius: Geofence radius in meters (default 50m)
    func startMonitoring(doorId: String, latitude: Double, longitude: Double, radius: Double = 50) {
        guard isAuthorized else { return }
        guard monitoredDoors.count < maxMonitoredRegions else { return }

        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let clampedRadius = min(radius, locationManager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(center: center, radius: clampedRadius, identifier: doorId)
        region.notifyOnEntry = true
        region.notifyOnExit = true

        locationManager.startMonitoring(for: region)
        monitoredDoors[doorId] = region
        AppLogger.geofence.info("Started monitoring region for door \(doorId)")
    }

    /// Stop monitoring a specific door geofence
    func stopMonitoring(doorId: String) {
        guard let region = monitoredDoors[doorId] else { return }
        locationManager.stopMonitoring(for: region)
        monitoredDoors.removeValue(forKey: doorId)
        AppLogger.geofence.info("Stopped monitoring region for door \(doorId)")
    }

    /// Stop all geofence monitoring
    func stopAllMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredDoors.removeAll()
    }

    /// Sync door geofences from door list (call after door list refresh)
    func syncGeofences(doors: [DoorWithLocation]) {
        // Remove stale regions
        let activeDoorIds = Set(doors.map(\.doorId))
        for (doorId, _) in monitoredDoors where !activeDoorIds.contains(doorId) {
            stopMonitoring(doorId: doorId)
        }

        // Add new regions (up to remaining iOS limit slots)
        let newDoors = doors.filter { monitoredDoors[$0.doorId] == nil }
        let availableSlots = maxMonitoredRegions - monitoredDoors.count
        for door in newDoors.prefix(max(0, availableSlots)) {
            startMonitoring(
                doorId: door.doorId,
                latitude: door.latitude,
                longitude: door.longitude,
                radius: door.geofenceRadius
            )
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        let doorId = circularRegion.identifier
        AppLogger.geofence.info("Entered geofence region for door \(doorId)")

        enteredRegionDoorId = doorId

        // Post notification for the app to prepare BLE connection
        NotificationCenter.default.post(
            name: .didEnterDoorGeofence,
            object: nil,
            userInfo: ["doorId": doorId]
        )

        // Send local notification if app is in background
        sendLocalNotification(
            title: SettingsService.shared.L("geofence.nearby_title"),
            body: SettingsService.shared.L("geofence.nearby_body"),
            doorId: doorId
        )
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        let doorId = circularRegion.identifier
        AppLogger.geofence.info("Exited geofence region for door \(doorId)")

        if enteredRegionDoorId == doorId {
            enteredRegionDoorId = nil
        }

        NotificationCenter.default.post(
            name: .didExitDoorGeofence,
            object: nil,
            userInfo: ["doorId": doorId]
        )
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Region monitoring failed — degrade gracefully, BLE still works
        if let region {
            monitoredDoors.removeValue(forKey: region.identifier)
        }
    }

    private func sendLocalNotification(title: String, body: String, doorId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["type": "geofence", "doorId": doorId]

        let request = UNNotificationRequest(
            identifier: "geofence-\(doorId)",
            content: content,
            trigger: nil  // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didEnterDoorGeofence = Notification.Name("didEnterDoorGeofence")
    static let didExitDoorGeofence = Notification.Name("didExitDoorGeofence")
}

// MARK: - Door Location Model

struct DoorWithLocation {
    let doorId: String
    let latitude: Double
    let longitude: Double
    let geofenceRadius: Double

    init(doorId: String, latitude: Double, longitude: Double, geofenceRadius: Double = 50) {
        self.doorId = doorId
        self.latitude = latitude
        self.longitude = longitude
        self.geofenceRadius = geofenceRadius
    }
}
