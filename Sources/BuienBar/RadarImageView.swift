import CoreLocation
import SwiftUI

struct RadarImageView: View {
    let url: URL?
    let coordinate: CLLocationCoordinate2D?

    private let aspectRatio: CGFloat = 550.0 / 512.0

    var body: some View {
        GeometryReader { proxy in
            let rect = aspectFitRect(aspect: aspectRatio, in: proxy.size)
            ZStack {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Color.black.opacity(0.05)
                                ProgressView()
                            }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(aspectRatio, contentMode: .fit)
                        case .failure:
                            Text("Radar unavailable")
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    ZStack {
                        Color.black.opacity(0.05)
                        Text("Radar loading…")
                            .foregroundStyle(.secondary)
                    }
                }

                if let coordinate,
                   let point = RadarProjection.point(for: coordinate, in: rect.size) {
                    LocationMarker()
                        .position(x: rect.minX + point.x, y: rect.minY + point.y)
                }
            }
        }
    }

    private func aspectFitRect(aspect: CGFloat, in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let containerAspect = size.width / size.height
        if containerAspect > aspect {
            let height = size.height
            let width = height * aspect
            let x = (size.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        }
        let width = size.width
        let height = width / aspect
        let y = (size.height - height) / 2
        return CGRect(x: 0, y: y, width: width, height: height)
    }
}

private struct LocationMarker: View {
    var body: some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 2))
            .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
            .accessibilityLabel("Current location")
            .allowsHitTesting(false)
    }
}

enum RadarProjection {
    static let north: Double = 54.8
    static let south: Double = 49.5
    static let west: Double = 0.0
    static let east: Double = 10.0

    static func point(for coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint? {
        guard size.width > 0, size.height > 0 else { return nil }
        let lat = min(max(coordinate.latitude, south), north)
        let lon = min(max(coordinate.longitude, west), east)
        let xRatio = (lon - west) / (east - west)

        let northY = mercatorY(north)
        let southY = mercatorY(south)
        let y = mercatorY(lat)
        let yRatio = (northY - y) / (northY - southY)

        let x = CGFloat(xRatio) * size.width
        let yPoint = CGFloat(yRatio) * size.height
        return CGPoint(x: x, y: yPoint)
    }

    private static func mercatorY(_ latitude: Double) -> Double {
        let radians = latitude * .pi / 180.0
        return log(tan(.pi / 4.0 + radians / 2.0))
    }
}
