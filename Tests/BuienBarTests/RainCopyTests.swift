import XCTest
@testable import BuienBar

final class RainCopyTests: XCTestCase {
    func testDryCopy() {
        let pattern: RainPattern = .dry
        XCTAssertEqual(RainCopy.menuBarText(for: pattern), "Dry")
        XCTAssertEqual(RainCopy.headerText(for: pattern), "Dry")
        XCTAssertEqual(RainCopy.subtitleText(for: pattern), "No rain expected")
    }

    func testRainingStopsDryCopy() {
        let pattern: RainPattern = .rainingStopsDry(dryInMinutes: 12, intensity: .light)
        XCTAssertEqual(RainCopy.menuBarText(for: pattern), "Dry in 12m")
        XCTAssertEqual(RainCopy.headerText(for: pattern), "Dry in ~12m")
        XCTAssertEqual(RainCopy.subtitleText(for: pattern), "Light rain")
    }

    func testRainingOnAndOffCopy() {
        let pattern: RainPattern = .rainingOnAndOff(dryBreakInMinutes: 12, intensity: .moderate)
        XCTAssertEqual(RainCopy.menuBarText(for: pattern), "On/off · dry in 12m")
        XCTAssertEqual(RainCopy.headerText(for: pattern), "Rain on and off")
        XCTAssertEqual(RainCopy.subtitleText(for: pattern), "Moderate · dry break in ~12m")
    }

    func testRainingContinuesCopy() {
        let pattern: RainPattern = .rainingContinues(intensity: .heavy)
        XCTAssertEqual(RainCopy.menuBarText(for: pattern), "Raining")
        XCTAssertEqual(RainCopy.headerText(for: pattern), "Raining")
        XCTAssertEqual(RainCopy.subtitleText(for: pattern), "Heavy rain continues")
    }

    func testDryRainComingCopy() {
        let pattern: RainPattern = .dryRainComing(startsInMinutes: 20, lastsMinutes: 10, intensity: .light)
        XCTAssertEqual(RainCopy.menuBarText(for: pattern), "Shower in 20m")
        XCTAssertEqual(RainCopy.headerText(for: pattern), "Rain in 20m")
        XCTAssertEqual(RainCopy.subtitleText(for: pattern), "Light rain for ~10m")
    }

    func testDryIntermittentComingCopy() {
        let pattern: RainPattern = .dryIntermittentComing(startsInMinutes: 15, intensity: .trace)
        XCTAssertEqual(RainCopy.menuBarText(for: pattern), "Showers in 15m")
        XCTAssertEqual(RainCopy.headerText(for: pattern), "Showers from 15m")
        XCTAssertEqual(RainCopy.subtitleText(for: pattern), "Drizzle showers on and off")
    }
}
