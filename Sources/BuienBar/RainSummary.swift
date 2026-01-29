import Foundation

struct RainSegment: Equatable {
    let isRain: Bool
    let startMinutes: Int
    let endMinutes: Int

    var duration: Int { max(0, endMinutes - startMinutes) }
}

enum RainIntensity: String, Equatable {
    case trace = "Trace"
    case light = "Light"
    case moderate = "Moderate"
    case heavy = "Heavy"

    init(mmPerHour: Double) {
        if mmPerHour >= 4 {
            self = .heavy
        } else if mmPerHour >= 1 {
            self = .moderate
        } else if mmPerHour >= 0.1 {
            self = .light
        } else {
            self = .trace
        }
    }
}

enum RainPattern: Equatable {
    case dry
    case rainingStopsDry(dryInMinutes: Int, intensity: RainIntensity)
    case rainingOnAndOff(dryBreakInMinutes: Int, intensity: RainIntensity)
    case rainingContinues(intensity: RainIntensity)
    case dryRainComing(startsInMinutes: Int, lastsMinutes: Int, intensity: RainIntensity)
    case dryIntermittentComing(startsInMinutes: Int, intensity: RainIntensity)
}

enum RainSummary {
    private struct RainBucket {
        let startMinutes: Int
        let endMinutes: Int
        let isRain: Bool
    }

    static func classify(
        points: [RainPoint],
        now: Date = Date(),
        horizonMinutes: Int = 90,
        bucketMinutes: Int = 5,
        threshold: Double = 0
    ) -> RainPattern {
        let segments = self.segments(
            from: points,
            now: now,
            horizonMinutes: horizonMinutes,
            bucketMinutes: bucketMinutes,
            threshold: threshold
        )

        guard !segments.isEmpty else { return .dry }
        guard segments.contains(where: { $0.isRain }) else { return .dry }

        if let current = segments.first(where: { $0.startMinutes <= 0 && $0.endMinutes > 0 }) {
            if current.isRain {
                let intensity = peakIntensity(from: points, now: now, startMinutes: current.startMinutes, endMinutes: current.endMinutes)
                let dryIn = max(0, current.endMinutes)
                let nextDry = segments.first(where: { !$0.isRain && $0.startMinutes >= current.endMinutes })
                if nextDry == nil {
                    return .rainingContinues(intensity: intensity)
                }

                let laterRain = segments.first(where: { $0.isRain && $0.startMinutes >= nextDry!.endMinutes })
                if laterRain != nil {
                    return .rainingOnAndOff(dryBreakInMinutes: dryIn, intensity: intensity)
                }

                return .rainingStopsDry(dryInMinutes: dryIn, intensity: intensity)
            }
        }

        guard let nextRain = segments.first(where: { $0.isRain && $0.startMinutes >= 0 }) else {
            return .dry
        }

        let startsIn = max(0, nextRain.startMinutes)
        let intensity = peakIntensity(from: points, now: now, startMinutes: nextRain.startMinutes, endMinutes: nextRain.endMinutes)
        let laterRain = segments.first(where: { $0.isRain && $0.startMinutes >= nextRain.endMinutes })
        if laterRain != nil {
            return .dryIntermittentComing(startsInMinutes: startsIn, intensity: intensity)
        }

        return .dryRainComing(startsInMinutes: startsIn, lastsMinutes: max(bucketMinutes, nextRain.duration), intensity: intensity)
    }

    static func segments(
        from points: [RainPoint],
        now: Date,
        horizonMinutes: Int = 90,
        bucketMinutes: Int = 5,
        threshold: Double = 0
    ) -> [RainSegment] {
        let buckets = buckets(from: points, now: now, horizonMinutes: horizonMinutes, bucketMinutes: bucketMinutes, threshold: threshold)
        guard let first = buckets.first else { return [] }

        var segments: [RainSegment] = []
        var currentIsRain = first.isRain
        var currentStart = first.startMinutes
        var currentEnd = first.endMinutes

        for bucket in buckets.dropFirst() {
            if bucket.isRain == currentIsRain && bucket.startMinutes <= currentEnd {
                currentEnd = max(currentEnd, bucket.endMinutes)
            } else {
                segments.append(RainSegment(isRain: currentIsRain, startMinutes: currentStart, endMinutes: currentEnd))
                currentIsRain = bucket.isRain
                currentStart = bucket.startMinutes
                currentEnd = bucket.endMinutes
            }
        }

        segments.append(RainSegment(isRain: currentIsRain, startMinutes: currentStart, endMinutes: currentEnd))
        return segments
    }

    static func peakIntensity(from points: [RainPoint], now: Date, startMinutes: Int, endMinutes: Int) -> RainIntensity {
        let startDate = now.addingTimeInterval(Double(startMinutes) * 60)
        let endDate = now.addingTimeInterval(Double(endMinutes) * 60)
        let maxPrecip = points
            .filter { $0.date >= startDate && $0.date < endDate }
            .map { mmPerHour(from: $0) }
            .max() ?? 0
        return RainIntensity(mmPerHour: maxPrecip)
    }

    private static func buckets(
        from points: [RainPoint],
        now: Date,
        horizonMinutes: Int,
        bucketMinutes: Int,
        threshold: Double
    ) -> [RainBucket] {
        points.compactMap { point in
            let startMinutes = minutesOffset(for: point.date, now: now)
            let endMinutes = startMinutes + bucketMinutes
            guard endMinutes > 0 else { return nil }
            guard startMinutes <= horizonMinutes else { return nil }
            let isRain = point.value > threshold || (point.precipitation ?? 0) > 0
            return RainBucket(startMinutes: startMinutes, endMinutes: endMinutes, isRain: isRain)
        }
    }

    private static func minutesOffset(for date: Date, now: Date) -> Int {
        let diff = date.timeIntervalSince(now) / 60
        return Int(floor(diff))
    }

    private static func mmPerHour(from point: RainPoint) -> Double {
        if let precipitation = point.precipitation {
            return precipitation
        }
        guard point.value > 0 else { return 0 }
        return pow(10, (point.value - 109) / 32)
    }
}
