import XCTest
@testable import BuienBar

final class RainSummaryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func makePoints(_ values: [Double], precipitation: Double = 2) -> [RainPoint] {
        values.enumerated().map { index, value in
            let date = now.addingTimeInterval(Double(index * 5) * 60)
            let precip = value > 0 ? precipitation : nil
            return RainPoint(date: date, value: value, precipitation: precip)
        }
    }

    func testDryPattern() {
        let points = makePoints([0, 0, 0, 0])
        let pattern = RainSummary.classify(points: points, now: now)
        XCTAssertEqual(pattern, .dry)
    }

    func testRainingStopsDryPattern() {
        let points = makePoints([10, 10, 10, 0, 0])
        let pattern = RainSummary.classify(points: points, now: now)
        XCTAssertEqual(pattern, .rainingStopsDry(dryInMinutes: 15, intensity: .moderate))
    }

    func testRainingOnAndOffPattern() {
        let points = makePoints([10, 10, 0, 0, 10, 10])
        let pattern = RainSummary.classify(points: points, now: now)
        XCTAssertEqual(pattern, .rainingOnAndOff(dryBreakInMinutes: 10, intensity: .moderate))
    }

    func testRainingContinuesPattern() {
        let points = makePoints([10, 10, 10, 10])
        let pattern = RainSummary.classify(points: points, now: now)
        XCTAssertEqual(pattern, .rainingContinues(intensity: .moderate))
    }

    func testDryRainComingPattern() {
        let points = makePoints([0, 0, 10, 10, 0, 0])
        let pattern = RainSummary.classify(points: points, now: now)
        XCTAssertEqual(pattern, .dryRainComing(startsInMinutes: 10, lastsMinutes: 10, intensity: .moderate))
    }

    func testDryIntermittentPattern() {
        let points = makePoints([0, 0, 10, 10, 0, 0, 10, 10])
        let pattern = RainSummary.classify(points: points, now: now)
        XCTAssertEqual(pattern, .dryIntermittentComing(startsInMinutes: 10, intensity: .moderate))
    }
}
