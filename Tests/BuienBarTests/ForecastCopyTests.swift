import XCTest
@testable import BuienBar

final class ForecastCopyTests: XCTestCase {
    func testHeaderCopyWhenLocationDenied() {
        let copy = ForecastCopy.headerCopy(
            locationAccess: .denied,
            loadState: .loaded,
            pattern: .dry
        )
        XCTAssertEqual(copy.title, "Location required")
        XCTAssertEqual(copy.subtitle, "Enable Location in System Settings")
    }

    func testHeaderCopyWhenNeedsLocation() {
        let copy = ForecastCopy.headerCopy(
            locationAccess: .authorized,
            loadState: .needsLocation,
            pattern: nil
        )
        XCTAssertEqual(copy.title, "Waiting for location…")
        XCTAssertEqual(copy.subtitle, "Allow Location to continue")
    }

    func testHeaderCopyWhenLoading() {
        let copy = ForecastCopy.headerCopy(
            locationAccess: .authorized,
            loadState: .loading,
            pattern: nil
        )
        XCTAssertEqual(copy.title, "Loading forecast…")
        XCTAssertEqual(copy.subtitle, "Fetching Buienradar data")
    }

    func testHeaderCopyWhenError() {
        let copy = ForecastCopy.headerCopy(
            locationAccess: .authorized,
            loadState: .error("boom"),
            pattern: nil
        )
        XCTAssertEqual(copy.title, "Update failed")
        XCTAssertEqual(copy.subtitle, "Check your connection")
    }

    func testHeaderCopyUsesRainPatternWhenLoaded() {
        let copy = ForecastCopy.headerCopy(
            locationAccess: .authorized,
            loadState: .loaded,
            pattern: .dry
        )
        XCTAssertEqual(copy.title, "Dry")
        XCTAssertEqual(copy.subtitle, "No rain expected")
    }
}
