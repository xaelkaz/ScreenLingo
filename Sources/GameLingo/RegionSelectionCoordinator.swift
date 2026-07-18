import AppKit

@MainActor
final class RegionSelectionCoordinator {
    private var windows: [SelectionWindow] = []
    private var keyMonitor: Any?
    private var cursorIsPushed = false
    private var selectionStart: CGPoint?
    private var currentSelection: CGRect?
    private var onSelection: ((CGRect) -> Void)?
    private var onCancel: (() -> Void)?

    func begin(onSelection: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        cancel(notify: false)

        self.onSelection = onSelection
        self.onCancel = onCancel
        NSCursor.crosshair.push()
        cursorIsPushed = true

        windows = NSScreen.screens.map { screen in
            let window = SelectionWindow(screen: screen)
            let view = RegionSelectionView(screenFrame: screen.frame, coordinator: self)
            window.contentView = view
            window.orderFrontRegardless()
            return window
        }

        windows.first?.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancel()
                return nil
            }
            return event
        }
    }

    func cancel() {
        cancel(notify: true)
    }

    fileprivate func mouseDown(at point: CGPoint) {
        selectionStart = point
        currentSelection = CGRect(origin: point, size: .zero)
        redraw()
    }

    fileprivate func mouseDragged(to point: CGPoint) {
        guard let selectionStart else { return }
        currentSelection = CGRect(
            x: min(selectionStart.x, point.x),
            y: min(selectionStart.y, point.y),
            width: abs(point.x - selectionStart.x),
            height: abs(point.y - selectionStart.y)
        )
        redraw()
    }

    fileprivate func mouseUp(at point: CGPoint) {
        mouseDragged(to: point)
        guard let selection = currentSelection, selection.width >= 8, selection.height >= 8 else {
            cancel()
            return
        }

        let callback = onSelection
        finish()
        callback?(selection.integral)
    }

    fileprivate func selection(in screenFrame: CGRect) -> CGRect? {
        guard let currentSelection else { return nil }
        let intersection = currentSelection.intersection(screenFrame)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return nil }
        return intersection.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    private func redraw() {
        windows.forEach { $0.contentView?.needsDisplay = true }
    }

    private func cancel(notify: Bool) {
        let callback = notify ? onCancel : nil
        finish()
        callback?()
    }

    private func finish() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        selectionStart = nil
        currentSelection = nil
        onSelection = nil
        onCancel = nil
        if cursorIsPushed {
            NSCursor.pop()
            cursorIsPushed = false
        }
    }
}

final class SelectionWindow: NSPanel {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        sharingType = .none
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class RegionSelectionView: NSView {
    private let screenFrame: CGRect
    private weak var coordinator: RegionSelectionCoordinator?

    init(screenFrame: CGRect, coordinator: RegionSelectionCoordinator) {
        self.screenFrame = screenFrame
        self.coordinator = coordinator
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        coordinator?.mouseDown(at: NSEvent.mouseLocation)
    }

    override func mouseDragged(with event: NSEvent) {
        coordinator?.mouseDragged(to: NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        coordinator?.mouseUp(at: NSEvent.mouseLocation)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let dimPath = NSBezierPath(rect: bounds)
        if let selection = coordinator?.selection(in: screenFrame) {
            dimPath.appendRect(selection)
            dimPath.windingRule = .evenOdd
        }

        NSColor.black.withAlphaComponent(0.42).setFill()
        dimPath.fill()

        if let selection = coordinator?.selection(in: screenFrame) {
            let border = NSBezierPath(roundedRect: selection.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
            border.lineWidth = 2
            NSColor.systemYellow.setStroke()
            border.stroke()

            if selection.width > 100, selection.height > 40 {
                let sizeText = "\(Int(selection.width)) × \(Int(selection.height))"
                drawBadge(sizeText, at: CGPoint(x: selection.minX + 8, y: selection.minY + 8))
            }
        } else {
            drawInstruction()
        }
    }

    private func drawInstruction() {
        let text = "Arrastra para seleccionar el texto  •  Esc para cancelar"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let padding = CGSize(width: 24, height: 14)
        let textSize = attributed.size()
        let rect = CGRect(
            x: (bounds.width - textSize.width - padding.width) / 2,
            y: bounds.height - textSize.height - padding.height - 46,
            width: textSize.width + padding.width,
            height: textSize.height + padding.height
        )

        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9).fill()
        attributed.draw(at: CGPoint(x: rect.minX + padding.width / 2, y: rect.minY + padding.height / 2))
    }

    private func drawBadge(_ text: String, at origin: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let rect = CGRect(x: origin.x, y: origin.y, width: textSize.width + 12, height: textSize.height + 7)
        NSColor.black.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
        attributed.draw(at: CGPoint(x: rect.minX + 6, y: rect.minY + 3.5))
    }
}
