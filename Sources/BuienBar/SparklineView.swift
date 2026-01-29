import SwiftUI

struct SparklineView: View {
    let title: String
    let points: [RainPoint]
    let rangeMinutes: Int

    private let axisWidth: CGFloat = 64
    private let chartHeight: CGFloat = 112

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .frame(width: 40, alignment: .leading)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    SparklineChart(points: points)
                        .frame(height: chartHeight)
                    SparklineAxisLabels()
                        .frame(width: axisWidth, height: chartHeight)
                }

                HStack(spacing: 0) {
                    SparklineTimeRow(points: points, rangeMinutes: rangeMinutes)
                    Spacer(minLength: 0)
                        .frame(width: axisWidth)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct SparklineAxisLabels: View {
    var body: some View {
        VStack(alignment: .trailing) {
            Text("Heavy")
            Spacer()
            Text("Moderate")
            Spacer()
            Text("Light")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
    }
}

private struct SparklineTimeRow: View {
    let points: [RainPoint]
    let rangeMinutes: Int

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var labels: (String, String, String) {
        if let first = points.first?.date, let last = points.last?.date {
            let middle = points[points.count / 2].date
            return (
                Self.formatter.string(from: first),
                Self.formatter.string(from: middle),
                Self.formatter.string(from: last)
            )
        }

        let midMinutes = max(1, rangeMinutes / 2)
        return ("Now", Self.relativeLabel(for: midMinutes), Self.relativeLabel(for: rangeMinutes))
    }

    var body: some View {
        let (start, mid, end) = labels
        return HStack {
            Text(start)
            Spacer()
            Text(mid)
            Spacer()
            Text(end)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
    }

    private static func relativeLabel(for minutes: Int) -> String {
        guard minutes > 0 else { return "Now" }
        if minutes % 60 == 0 {
            return "+\(minutes / 60)h"
        }
        return "+\(minutes)m"
    }
}

private struct SparklineChart: View {
    let points: [RainPoint]

    private let rows: Int = 3
    private let columns: Int = 12

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let cornerRadius: CGFloat = 6
            let background = Path(roundedRect: rect, cornerRadius: cornerRadius)
            context.fill(background, with: .color(Color.gray.opacity(0.05)))

            func yPosition(for value: Double) -> CGFloat {
                let clamped = max(0, min(100, value))
                let normalized = clamped / 100
                return size.height - CGFloat(normalized) * size.height
            }

            let gridColor = Color.gray.opacity(0.32)
            for row in 0...rows {
                let y = size.height * CGFloat(row) / CGFloat(rows)
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(gridColor), lineWidth: 0.7)
            }

            for column in 0...columns {
                let x = size.width * CGFloat(column) / CGFloat(columns)
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(gridColor.opacity(0.4)), lineWidth: 0.5)
            }

            var nowLine = Path()
            let nowX: CGFloat = 6
            nowLine.move(to: CGPoint(x: nowX, y: 0))
            nowLine.addLine(to: CGPoint(x: nowX, y: size.height))
            context.stroke(nowLine, with: .color(Color.blue.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            let values = points.map { $0.value }
            guard !values.isEmpty else { return }
            let maxValue = values.max() ?? 0
            guard maxValue > 0 else { return }

            let linePath = Path { path in
                for (index, value) in values.enumerated() {
                    let x = size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = yPosition(for: value)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }

            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()

            context.fill(fillPath, with: .color(Color.blue.opacity(0.18)))
            context.stroke(linePath, with: .color(Color.blue.opacity(0.9)), lineWidth: 2.0)
        }
    }
}

enum SparklineFormatter {
    private static let bars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

    static func string(from points: [RainPoint], maxCount: Int = 12) -> String {
        guard !points.isEmpty else { return "—" }
        let values = points.map { $0.value }
        let sampled = downsample(values, to: maxCount)
        return sampled.map { bar(for: $0) }.joined()
    }

    private static func downsample(_ values: [Double], to maxCount: Int) -> [Double] {
        guard values.count > maxCount, maxCount > 1 else { return values }
        let stride = Double(values.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { index in
            let rawIndex = Int(round(Double(index) * stride))
            return values[min(rawIndex, values.count - 1)]
        }
    }

    private static func bar(for value: Double) -> String {
        let clamped = max(0, min(100, value))
        if clamped == 0 {
            return bars.first ?? "▁"
        }
        let step = 100.0 / Double(bars.count - 1)
        let index = min(Int(round(clamped / step)), bars.count - 1)
        return bars[index]
    }
}
