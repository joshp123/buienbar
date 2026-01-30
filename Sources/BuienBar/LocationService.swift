import AppKit
import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var access: LocationAccess
    @Published var location: CLLocation?
    @Published var servicesEnabled: Bool
    @Published var rawAuthorizationStatus: CLAuthorizationStatus
    @Published var lastError: String?
    @Published var isOverride: Bool = false

    private let manager = CLLocationManager()
    private let lastLatKey = "BuienBar.LastLat"
    private let lastLonKey = "BuienBar.LastLon"
    private let useOverrideLocation = false
    private let overrideLocation = CLLocation(latitude: 53.2194, longitude: 6.5665)

    override init() {
        let status = manager.authorizationStatus
        access = LocationAccess(status: status)
        rawAuthorizationStatus = status
        servicesEnabled = CLLocationManager.locationServicesEnabled()
        super.init()
    }

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 1000
        servicesEnabled = CLLocationManager.locationServicesEnabled()
        if applyOverrideLocationIfNeeded() {
            return
        }
        refreshAuthorizationStatus(cachedLocation: manager.location)
        if access == .authorized, location == nil, let stored = loadStoredLocation() {
            if isLikelyOverride(stored) {
                clearStoredLocation()
            } else {
                applyLocation(stored)
            }
        }
        if access == .authorized {
            manager.startUpdatingLocation()
            manager.requestLocation()
        }
    }

    func requestLocation() {
        guard access == .authorized else { return }
        manager.startUpdatingLocation()
        manager.requestLocation()
    }

    func scheduleRetry() {
        guard access == .authorized, location == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.manager.requestLocation()
        }
    }

    func requestAuthorization() {
        if applyOverrideLocationIfNeeded() {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.refreshAuthorizationStatus(cachedLocation: self.manager.location)
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func applyOverrideLocationIfNeeded() -> Bool {
        guard useOverrideLocation else { return false }
        guard !isOverride else { return true }
        isOverride = true
        access = .authorized
        rawAuthorizationStatus = .authorizedAlways
        servicesEnabled = true
        applyLocation(overrideLocation)
        return true
    }

    private func refreshAuthorizationStatus(cachedLocation: CLLocation?) {
        let status = manager.authorizationStatus
        applyAccess(status, cachedLocation: cachedLocation)
    }

    private func handleAuthorizationChange(status: CLAuthorizationStatus, cachedLocation: CLLocation?) {
        applyAccess(status, cachedLocation: cachedLocation)
        switch LocationAccess(status: status) {
        case .authorized:
            manager.requestLocation()
            manager.startUpdatingLocation()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
        case .notDetermined:
            break
        }
    }

    private func applyAccess(_ status: CLAuthorizationStatus, cachedLocation: CLLocation?) {
        rawAuthorizationStatus = status
        servicesEnabled = CLLocationManager.locationServicesEnabled()
        let newAccess = LocationAccess(status: status)
        access = newAccess
        switch newAccess {
        case .authorized:
            if let cachedLocation {
                applyLocation(cachedLocation)
            }
        case .denied, .restricted:
            location = nil
        case .notDetermined:
            break
        }
    }

    private func applyLocation(_ newLocation: CLLocation) {
        location = newLocation
        lastError = nil
        storeLocation(newLocation)
    }

    private func storeLocation(_ location: CLLocation) {
        UserDefaults.standard.set(location.coordinate.latitude, forKey: lastLatKey)
        UserDefaults.standard.set(location.coordinate.longitude, forKey: lastLonKey)
    }

    private func clearStoredLocation() {
        UserDefaults.standard.removeObject(forKey: lastLatKey)
        UserDefaults.standard.removeObject(forKey: lastLonKey)
    }

    private func loadStoredLocation() -> CLLocation? {
        let lat = UserDefaults.standard.double(forKey: lastLatKey)
        let lon = UserDefaults.standard.double(forKey: lastLonKey)
        guard lat != 0 || lon != 0 else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    private func isLikelyOverride(_ location: CLLocation) -> Bool {
        guard !useOverrideLocation else { return false }
        let latDelta = abs(location.coordinate.latitude - overrideLocation.coordinate.latitude)
        let lonDelta = abs(location.coordinate.longitude - overrideLocation.coordinate.longitude)
        return latDelta < 0.001 && lonDelta < 0.001
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let cachedLocation = manager.location
        Task { @MainActor [weak self] in
            self?.handleAuthorizationChange(status: status, cachedLocation: cachedLocation)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let cachedLocation = manager.location
        Task { @MainActor [weak self] in
            self?.handleAuthorizationChange(status: status, cachedLocation: cachedLocation)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.applyLocation(latest)
            self?.manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        Task { @MainActor [weak self] in
            guard let self else { return }
            let description = clError.map { "\($0.code.rawValue) \($0.localizedDescription)" } ?? error.localizedDescription
            self.lastError = description
            if clError?.code == .denied {
                self.rawAuthorizationStatus = .denied
                self.access = .denied
                self.location = nil
                self.manager.stopUpdatingLocation()
                return
            }
            if clError?.code == .locationUnknown {
                self.scheduleRetry()
                return
            }
            self.manager.stopUpdatingLocation()
            self.scheduleRetry()
        }
    }
}
