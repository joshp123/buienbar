import Foundation

struct ForecastHeaderCopy: Equatable {
    let title: String
    let subtitle: String?
}

enum ForecastCopy {
    static func headerCopy(
        locationAccess: LocationAccess,
        loadState: LoadState,
        pattern: RainPattern?
    ) -> ForecastHeaderCopy {
        if locationAccess == .denied || locationAccess == .restricted {
            return ForecastHeaderCopy(
                title: "Location required",
                subtitle: "Enable Location in System Settings"
            )
        }

        switch loadState {
        case .needsLocation:
            return ForecastHeaderCopy(
                title: "Waiting for location…",
                subtitle: "Allow Location to continue"
            )
        case .loading:
            return ForecastHeaderCopy(
                title: "Loading forecast…",
                subtitle: "Fetching Buienradar data"
            )
        case .error:
            return ForecastHeaderCopy(
                title: "Update failed",
                subtitle: "Check your connection"
            )
        case .idle:
            return ForecastHeaderCopy(
                title: "Loading forecast…",
                subtitle: nil
            )
        case .loaded:
            break
        }

        guard let pattern else {
            return ForecastHeaderCopy(title: "—", subtitle: nil)
        }

        return ForecastHeaderCopy(
            title: RainCopy.headerText(for: pattern),
            subtitle: RainCopy.subtitleText(for: pattern)
        )
    }
}
