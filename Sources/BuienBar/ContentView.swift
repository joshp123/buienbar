import CoreLocation
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ForecastStore

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerSection
            statusSection
            sparklineSection
            radarSection
            settingsSection
            footerSection
        }
        .padding(18)
        .frame(minWidth: 640, alignment: .topLeading)
    }

    private var headerSection: some View {
        let header = headerCopy
        return VStack(alignment: .leading, spacing: 4) {
            Text(header.title)
                .font(.headline)
            if let subtitle = header.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(store.locationLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch store.locationAccess {
            case .denied, .restricted:
                Text("Location access is disabled.")
                    .font(.subheadline)
                Button("Enable Location…") {
                    store.openLocationSettings()
                }
            case .notDetermined:
                Text("Waiting for location permission…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Allow Location") {
                    store.requestLocationAuthorization()
                }
            case .authorized:
                EmptyView()
            }

            switch store.loadState {
            case .loading:
                ProgressView()
            case .error(let message):
                Text("Update failed")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            default:
                EmptyView()
            }
        }
    }

    private var sparklineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SparklineView(title: "1h", points: store.rain1h, rangeMinutes: 60)
            SparklineView(title: "3h", points: store.rain3h, rangeMinutes: 180)
            SparklineView(title: "24h", points: store.rain24h, rangeMinutes: 24 * 60)
        }
        .padding(18)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }

    private var radarSection: some View {
        RadarImageView(url: store.radarStillURL, coordinate: store.locationCoordinate)
            .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 480)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu bar style")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Menu bar style", selection: $store.menuBarStyle) {
                ForEach(MenuBarStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if store.loadState != .loaded {
                Text(store.debugStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Updated \(updatedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Buienradar.nl")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var headerCopy: ForecastHeaderCopy {
        ForecastCopy.headerCopy(
            locationAccess: store.locationAccess,
            loadState: store.loadState,
            pattern: store.rainPattern
        )
    }

    private var updatedText: String {
        guard let lastUpdated = store.lastUpdated else {
            return "—"
        }
        return Self.timeFormatter.string(from: lastUpdated)
    }
}
