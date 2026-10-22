import CoreLocation
import LimitCore

enum LocationAccess: Equatable {
    case notDetermined
    case denied
    /// Approximate location can't say which road you're on, so limits would show as unknown.
    case reduced
    case authorized

    var isUsable: Bool { self == .authorized }
}

/// Thin wrapper over CLLocationManager. "While Using the App" is enough: once a drive starts, background
/// location keeps the Lock Screen updating until it ends.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var onSample: ((LocationSample) -> Void)?
    var onAccessChange: ((LocationAccess) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
    }

    var access: LocationAccess { Self.access(for: manager) }

    func requestAuthorisation() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    nonisolated private static func access(for manager: CLLocationManager) -> LocationAccess {
        switch manager.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        case .authorizedAlways, .authorizedWhenInUse:
            return manager.accuracyAuthorization == .reducedAccuracy ? .reduced : .authorized
        @unknown default: return .denied
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let access = Self.access(for: manager)
        Task { @MainActor in self.onAccessChange?(access) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map {
            LocationSample(
                coordinate: Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude),
                speedMetresPerSecond: $0.speed,
                horizontalAccuracy: $0.horizontalAccuracy,
                timestamp: $0.timestamp
            )
        }
        Task { @MainActor in samples.forEach { self.onSample?($0) } }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // The engine ages out stale samples on its own, so a failed update just shows as "searching".
    }
}
