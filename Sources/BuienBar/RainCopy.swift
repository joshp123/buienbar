import Foundation

enum RainCopy {
    static func menuBarText(for pattern: RainPattern) -> String {
        switch pattern {
        case .dry:
            return "Dry"
        case .rainingStopsDry(let minutes, _):
            return "Dry in \(displayMinutes(minutes))m"
        case .rainingOnAndOff(let minutes, _):
            return "On/off · dry in \(displayMinutes(minutes))m"
        case .rainingContinues:
            return "Raining"
        case .dryRainComing(let minutes, let lasts, _):
            if lasts <= 15 {
                return "Shower in \(displayMinutes(minutes))m"
            }
            return "Rain in \(displayMinutes(minutes))m"
        case .dryIntermittentComing(let minutes, _):
            return "Showers in \(displayMinutes(minutes))m"
        }
    }

    static func headerText(for pattern: RainPattern) -> String {
        switch pattern {
        case .dry:
            return "Dry"
        case .rainingStopsDry(let minutes, _):
            return "Dry in ~\(displayMinutes(minutes))m"
        case .rainingOnAndOff:
            return "Rain on and off"
        case .rainingContinues:
            return "Raining"
        case .dryRainComing(let minutes, _, _):
            return "Rain in \(displayMinutes(minutes))m"
        case .dryIntermittentComing(let minutes, _):
            return "Showers from \(displayMinutes(minutes))m"
        }
    }

    static func subtitleText(for pattern: RainPattern) -> String {
        switch pattern {
        case .dry:
            return "No rain expected"
        case .rainingStopsDry(_, let intensity):
            return "\(intensityLabel(intensity)) rain"
        case .rainingOnAndOff(let minutes, let intensity):
            return "\(intensityLabel(intensity)) · dry break in ~\(displayMinutes(minutes))m"
        case .rainingContinues(let intensity):
            return "\(intensityLabel(intensity)) rain continues"
        case .dryRainComing(_, let lasts, let intensity):
            return "\(intensityLabel(intensity)) rain for ~\(displayMinutes(lasts))m"
        case .dryIntermittentComing(_, let intensity):
            return "\(intensityLabel(intensity)) showers on and off"
        }
    }

    static func symbolName(for pattern: RainPattern) -> String {
        switch pattern {
        case .dry:
            return "cloud.sun.fill"
        default:
            return "cloud.rain.fill"
        }
    }

    private static func intensityLabel(_ intensity: RainIntensity) -> String {
        switch intensity {
        case .trace:
            return "Drizzle"
        case .light:
            return "Light"
        case .moderate:
            return "Moderate"
        case .heavy:
            return "Heavy"
        }
    }

    private static func displayMinutes(_ minutes: Int) -> Int {
        max(1, minutes)
    }
}
