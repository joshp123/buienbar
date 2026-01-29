import AppKit

enum MenuBarSparklineRenderer {
    static func baselineOffset(
        for font: NSFont,
        imageHeight: CGFloat,
        containerHeight: CGFloat,
        fudge: CGFloat = 0
    ) -> CGFloat {
        let textAscent = font.ascender
        let textDescent = abs(font.descender)
        let textHeight = textAscent + textDescent
        let baselineFromTop = (containerHeight - textHeight) / 2 + textAscent
        let imageBottomFromTop = (containerHeight - imageHeight) / 2
        let baselineWithinImageFromTop = baselineFromTop - imageBottomFromTop
        let baselineFromBottom = imageHeight - baselineWithinImageFromTop
        return max(0, baselineFromBottom + fudge)
    }

    static func image(
        values: [Double],
        size: NSSize = NSSize(width: 72, height: 18),
        baselineOffset: CGFloat = 0
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let clamped = values.map { min(100, max(0, $0)) }
        let count = max(clamped.count, 1)
        let spacing: CGFloat = 0.5
        let totalSpacing = CGFloat(count - 1) * spacing
        let barWidth = max(1, floor((size.width - totalSpacing) / CGFloat(count)))
        let totalWidth = CGFloat(count) * barWidth + totalSpacing
        let startX = max(0, (size.width - totalWidth) / 2)
        let maxHeight = max(1, size.height - baselineOffset - 1)

        let barColor = NSColor.controlAccentColor.withAlphaComponent(0.95)
        for (index, value) in clamped.enumerated() {
            guard value > 0 else { continue }
            let normalized = sqrt(value / 100)
            let height = max(2, CGFloat(normalized) * maxHeight)
            let x = startX + CGFloat(index) * (barWidth + spacing)
            let rect = NSRect(x: x, y: baselineOffset, width: barWidth, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1)
            barColor.setFill()
            path.fill()
        }

        let basePath = NSBezierPath()
        basePath.move(to: NSPoint(x: startX, y: baselineOffset))
        basePath.line(to: NSPoint(x: startX + totalWidth, y: baselineOffset))
        NSColor.secondaryLabelColor.setStroke()
        basePath.lineWidth = 0.5
        basePath.stroke()

        let nowPath = NSBezierPath()
        let nowX = startX + 0.5
        nowPath.move(to: NSPoint(x: nowX, y: baselineOffset))
        nowPath.line(to: NSPoint(x: nowX, y: size.height - 1))
        nowPath.setLineDash([2, 2], count: 2, phase: 0)
        NSColor.secondaryLabelColor.setStroke()
        nowPath.lineWidth = 1
        nowPath.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
