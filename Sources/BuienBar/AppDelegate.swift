import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store = ForecastStore()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureURLCache()
        configureStatusItem()
        configurePopover()
        bindStore()
        store.start()
    }

    private func configureURLCache() {
        let cache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "BuienBarCache"
        )
        URLCache.shared = cache
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        DispatchQueue.main.async { [weak self] in
            self?.clampPopoverToScreen(anchor: button)
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        apply(display: store.menuBarDisplay)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 640, height: 800)
        popover.contentViewController = NSHostingController(rootView: ContentView(store: store))
    }

    private func clampPopoverToScreen(anchor button: NSStatusBarButton) {
        guard let window = popover.contentViewController?.view.window else { return }
        let screen = button.window?.screen ?? window.screen ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        var frame = window.frame
        let inset: CGFloat = 8
        let bounds = visibleFrame.insetBy(dx: inset, dy: inset)
        if frame.maxX > bounds.maxX {
            frame.origin.x = bounds.maxX - frame.width
        }
        if frame.minX < bounds.minX {
            frame.origin.x = bounds.minX
        }
        if frame.maxY > bounds.maxY {
            frame.origin.y = bounds.maxY - frame.height
        }
        if frame.minY < bounds.minY {
            frame.origin.y = bounds.minY
        }
        window.setFrame(frame, display: true)
    }

    private func bindStore() {
        store.$menuBarDisplay
            .receive(on: RunLoop.main)
            .sink { [weak self] display in
                self?.apply(display: display)
            }
            .store(in: &cancellables)
    }

    private func apply(display: MenuBarDisplay) {
        guard let button = statusItem.button else { return }
        let title = display.title
        let baseFont = NSFont.menuBarFont(ofSize: 0)
        let fontSize = title.count > 12 ? max(10, baseFont.pointSize - 1) : baseFont.pointSize
        let font = NSFont.menuBarFont(ofSize: fontSize)
        button.font = font
        button.title = title

        if let values = display.sparklineValues, !values.isEmpty {
            let imageHeight: CGFloat = 18
            let baselineOffset = MenuBarSparklineRenderer.baselineOffset(
                for: font,
                imageHeight: imageHeight,
                containerHeight: button.bounds.height,
                fudge: 2
            )
            let sparklineImage = MenuBarSparklineRenderer.image(
                values: values,
                size: NSSize(width: 72, height: imageHeight),
                baselineOffset: baselineOffset
            )
            button.image = sparklineImage
            button.imagePosition = .imageRight
            button.imageScaling = .scaleNone
            return
        }

        button.imagePosition = .imageLeft
        button.imageScaling = .scaleNone
        if let symbolName = display.symbolName, let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "BuienBar") {
            image.isTemplate = true
            button.image = image
        } else {
            button.image = nil
        }
    }
}
