import Foundation

enum BuienradarError: LocalizedError {
    case invalidURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Buienradar URL."
        case .invalidResponse:
            return "Buienradar returned an unexpected response."
        }
    }
}

struct RainResponse: Decodable {
    let forecasts: [RainForecast]
}

struct RainForecast: Decodable {
    let datetime: String
    let value: Double
    let precipitation: Double?

    private enum CodingKeys: String, CodingKey {
        case datetime
        case value
        case precipitation
        case precipation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        datetime = try container.decode(String.self, forKey: .datetime)
        value = try container.decodeIfPresent(Double.self, forKey: .value) ?? 0
        precipitation = try container.decodeIfPresent(Double.self, forKey: .precipitation)
            ?? container.decodeIfPresent(Double.self, forKey: .precipation)
    }
}

struct ImageFrame: Decodable {
    let timestamp: String
    let url: String
}

struct ImageMetadata: Decodable {
    let imagetype: String?
    let still: String
    let times: [ImageFrame]
}

enum RadarMapType: String, CaseIterable {
    case rain5mNL = "radarMapRain5mNL"
    case rain15mNL = "radarMapRain15mNL"
    case rain1hNL = "radarMapRain1hNL"
}

struct BuienradarClient {
    private let decoder = JSONDecoder()
    private let session: URLSession
    private let imageApiKey = "3c4a3037-85e6-4d1e-ad6c-f3f6e4b75f2f"

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.urlCache = .shared
        session = URLSession(configuration: configuration)
    }

    func fetchRain3Hour(lat: Double, lon: Double) async throws -> RainResponse {
        let urlString = "https://graphdata.buienradar.nl/2.0/forecast/geo/Rain3Hour?lat=\(lat)&lon=\(lon)"
        return try await fetch(urlString)
    }

    func fetchRain24Hour(lat: Double, lon: Double) async throws -> RainResponse {
        let urlString = "https://graphdata.buienradar.nl/2.0/forecast/geo/Rain24Hour?lat=\(lat)&lon=\(lon)"
        return try await fetch(urlString)
    }

    func fetchRainRadarMetadata(type: RadarMapType = .rain5mNL, history: Int = 12, forecast: Int = 0) async throws -> ImageMetadata {
        let urlString = "https://image-lite.buienradar.nl/3.0/metadata/\(type.rawValue)?history=\(history)&forecast=\(forecast)&ak=\(imageApiKey)"
        return try await fetch(urlString)
    }

    func rainRadarSingleURL(width: Int = 700, height: Int = 765, cacheBuster: Int? = nil) -> URL? {
        var urlString = "https://image.buienradar.nl/2.0/image/single/RadarMapRainNL?height=\(height)&width=\(width)&extension=png&renderBackground=True&renderBranding=False&renderText=False"
        if let cacheBuster {
            urlString += "&_t=\(cacheBuster)"
        }
        return URL(string: urlString)
    }

    private func fetch<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw BuienradarError.invalidURL
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BuienradarError.invalidResponse
        }
        return try decoder.decode(T.self, from: data)
    }
}
