import Combine
import CoreLocation
import Foundation
import OSLog

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case minutes
    case sparkline

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minutes:
            return "Minutes"
        case .sparkline:
            return "Sparkline"
        }
    }
}

enum LocationAccess: Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized

    init(status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .restricted
        }
    }
}

enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case needsLocation
    case error(String)
}

struct MenuBarDisplay: Equatable {
    let title: String
    let symbolName: String?
    let sparklineValues: [Double]?
}

struct RainPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    let precipitation: Double?
}

struct RadarFrame: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let url: URL
}

@MainActor
final class ForecastStore: ObservableObject {
    @Published var rain1h: [RainPoint] = []
    @Published var rain3h: [RainPoint] = []
    @Published var rain24h: [RainPoint] = []
    @Published var radarStillURL: URL? {
        didSet {
            guard let url = radarStillURL, oldValue != url else { return }
            prefetchImage(url)
        }
    }
    @Published var radarFrames: [RadarFrame] = []
    @Published var lastUpdated: Date?
    @Published var rainPattern: RainPattern?
    @Published var locationAccess: LocationAccess = .notDetermined
    @Published var locationLabel: String = "Location: —"
    @Published var locationCoordinate: CLLocationCoordinate2D?
    @Published var loadState: LoadState = .idle
    @Published var menuBarStyle: MenuBarStyle {
        didSet {
            UserDefaults.standard.set(menuBarStyle.rawValue, forKey: menuBarStyleKey)
            DispatchQueue.main.async { [weak self] in
                self?.updateMenuBarDisplay()
            }
        }
    }
    @Published var menuBarDisplay: MenuBarDisplay = .init(title: "", symbolName: "cloud.sun.fill", sparklineValues: nil)
    @Published var debugStatus: String = ""

    private let menuBarStyleKey = "BuienBar.MenuBarStyle"
    private let client = BuienradarClient()
    private let locationService = LocationService()
    private let logger = Logger(subsystem: "BuienBar", category: "Forecast")
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: DispatchSourceTimer?
    private var minuteTimer: DispatchSourceTimer?
    private var refreshTask: Task<Void, Never>?

    init() {
        if let raw = UserDefaults.standard.string(forKey: menuBarStyleKey),
           let saved = MenuBarStyle(rawValue: raw) {
            menuBarStyle = saved
        } else {
            menuBarStyle = .minutes
        }
    }

    func start() {
        locationService.start()

        locationService.$access
            .receive(on: RunLoop.main)
            .sink { [weak self] access in
                self?.locationAccess = access
                self?.updateLocationInfo()
                self?.updateDebugStatus()
                self?.updateMenuBarDisplay()
                if access == .authorized {
                    self?.refresh()
                }
            }
            .store(in: &cancellables)

        locationService.$location
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                self?.updateLocationInfo()
                self?.updateDebugStatus()
                guard location != nil else {
                    self?.locationService.scheduleRetry()
                    return
                }
                self?.refresh()
            }
            .store(in: &cancellables)

        locationService.$servicesEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateDebugStatus()
            }
            .store(in: &cancellables)

        locationService.$rawAuthorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateDebugStatus()
            }
            .store(in: &cancellables)

        locationService.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateDebugStatus()
            }
            .store(in: &cancellables)

        locationService.$isOverride
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateLocationInfo()
            }
            .store(in: &cancellables)

        scheduleRefreshTimer()
        scheduleMinuteTimer()
        refresh()
    }

    func stop() {
        refreshTask?.cancel()
        refreshTimer?.cancel()
        minuteTimer?.cancel()
        refreshTimer = nil
        minuteTimer = nil
    }

    func openLocationSettings() {
        locationService.openSystemSettings()
    }

    func requestLocationAuthorization() {
        locationService.requestAuthorization()
    }

    func refresh() {
        guard locationAccess == .authorized else {
            loadState = .needsLocation
            rainPattern = nil
            updateMenuBarDisplay()
            return
        }
        guard let location = locationService.location else {
            loadState = .loading
            rainPattern = nil
            updateMenuBarDisplay()
            locationService.requestLocation()
            return
        }

        logger.info("Starting refresh")
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.fetchAndUpdate(location: location)
        }
    }

    private func scheduleRefreshTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 5, repeating: 300)
        timer.setEventHandler { [weak self] in
            self?.refresh()
        }
        timer.resume()
        refreshTimer = timer
    }

    private func scheduleMinuteTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in
            self?.updateDerivedValues()
        }
        timer.resume()
        minuteTimer = timer
    }

    private func fetchAndUpdate(location: CLLocation) async {
        loadState = .loading
        logger.info("Refreshing forecast")
        do {
            async let rain3hResponse = client.fetchRain3Hour(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            async let rain24hResponse = client.fetchRain24Hour(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            async let radarMetadata = client.fetchRainRadarMetadata()

            let (rain3hData, rain24hData, radarMetadataResponse) = try await (rain3hResponse, rain24hResponse, radarMetadata)
            let points3h = parseRainPoints(from: rain3hData)
            let points24h = parseRainPoints(from: rain24hData)

            rain3h = points3h
            rain1h = Array(points3h.prefix(12))
            rain24h = points24h
            let cacheBuster = Int(Date().timeIntervalSince1970)
            radarStillURL = client.rainRadarSingleURL(cacheBuster: cacheBuster) ?? URL(string: radarMetadataResponse.still)
            radarFrames = parseRadarFrames(from: radarMetadataResponse.times)
            rainPattern = RainSummary.classify(points: points3h, now: Date())
            lastUpdated = Date()
            loadState = .loaded
            logger.info("Forecast updated")
        } catch {
            loadState = .error(error.localizedDescription)
            rainPattern = nil
            logger.error("Forecast update failed: \(error.localizedDescription, privacy: .public)")
        }

        updateMenuBarDisplay()
    }

    private func updateDerivedValues() {
        guard loadState == .loaded else { return }
        rainPattern = RainSummary.classify(points: rain3h, now: Date())
        updateMenuBarDisplay()
    }

    private func parseRainPoints(from response: RainResponse) -> [RainPoint] {
        response.forecasts.compactMap { forecast in
            guard let date = DateParser.parse(forecast.datetime) else { return nil }
            return RainPoint(date: date, value: forecast.value, precipitation: forecast.precipitation)
        }.sorted { $0.date < $1.date }
    }

    private func parseRadarFrames(from frames: [ImageFrame]) -> [RadarFrame] {
        frames.compactMap { frame in
            guard let date = DateParser.parse(frame.timestamp),
                  let url = URL(string: frame.url) else {
                return nil
            }
            return RadarFrame(timestamp: date, url: url)
        }.sorted { $0.timestamp < $1.timestamp }
    }

    private func sampleMenuBarValues(from points: [RainPoint], maxCount: Int) -> [Double] {
        let values = points.map { $0.value }
        guard values.count > maxCount, maxCount > 1 else { return values }
        let stride = Double(values.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { index in
            let rawIndex = Int(round(Double(index) * stride))
            return values[min(rawIndex, values.count - 1)]
        }
    }

    private func prefetchImage(_ url: URL) {
        Task.detached(priority: .utility) { [logger] in
            do {
                _ = try await URLSession.shared.data(from: url)
                logger.info("Prefetched radar image")
            } catch {
                logger.info("Radar prefetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func updateLocationInfo() {
        guard let location = locationService.location else {
            locationLabel = "Location: —"
            locationCoordinate = nil
            return
        }
        locationCoordinate = location.coordinate
        let coords = String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
        if locationService.isOverride {
            locationLabel = "Location: Groningen (test) • \(coords)"
        } else {
            locationLabel = "Location: \(coords)"
        }
    }

    private func updateDebugStatus() {
        let enabled = locationService.servicesEnabled ? "on" : "off"
        let status = authorizationLabel(locationService.rawAuthorizationStatus)
        let coords: String
        if let location = locationService.location {
            coords = String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
        } else {
            coords = "--"
        }
        let errorText = locationService.lastError ?? ""
        debugStatus = "Location: \(enabled) • Auth: \(status) • Coord: \(coords)\(errorText.isEmpty ? "" : " • \(errorText)")"
    }

    private func authorizationLabel(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "always"
        case .authorizedWhenInUse:
            return "whenInUse"
        @unknown default:
            return "unknown"
        }
    }

    private func updateMenuBarDisplay() {
        if case .error = loadState {
            menuBarDisplay = MenuBarDisplay(title: "", symbolName: "exclamationmark.triangle", sparklineValues: nil)
            return
        }

        if locationAccess == .denied || locationAccess == .restricted {
            menuBarDisplay = MenuBarDisplay(title: "", symbolName: "location.slash", sparklineValues: nil)
            return
        }

        guard loadState == .loaded, let pattern = rainPattern else {
            menuBarDisplay = MenuBarDisplay(title: "…", symbolName: "cloud.sun.fill", sparklineValues: nil)
            return
        }

        let title = RainCopy.menuBarText(for: pattern)
        let symbolName = RainCopy.symbolName(for: pattern)

        switch menuBarStyle {
        case .minutes:
            menuBarDisplay = MenuBarDisplay(title: title, symbolName: symbolName, sparklineValues: nil)
        case .sparkline:
            let values = sampleMenuBarValues(from: rain1h, maxCount: 12)
            let hasRain = values.contains { $0 > 0 }
            if hasRain {
                menuBarDisplay = MenuBarDisplay(title: title, symbolName: nil, sparklineValues: values)
            } else {
                menuBarDisplay = MenuBarDisplay(title: title, symbolName: symbolName, sparklineValues: nil)
            }
        }
    }
}

enum DateParser {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }
}
