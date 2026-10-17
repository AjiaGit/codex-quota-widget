import AppKit
import WebKit

private let baseURL = URL(string: "http://127.0.0.1:39224/")!
private let minimumDetail = NSSize(width: 330, height: 430)
private let minimumCompact = NSSize(width: 36, height: 36)
private let detailBackground = NSColor(srgbRed: 32 / 255, green: 37 / 255, blue: 45 / 255, alpha: 1)
private let quotaAccent = NSColor(srgbRed: 36 / 255, green: 211 / 255, blue: 165 / 255, alpha: 1)
private let quotaDanger = NSColor(srgbRed: 250 / 255, green: 125 / 255, blue: 121 / 255, alpha: 1)
private let quotaTrack = NSColor(srgbRed: 61 / 255, green: 72 / 255, blue: 85 / 255, alpha: 1)
private let headerMuted = NSColor(srgbRed: 161 / 255, green: 170 / 255, blue: 182 / 255, alpha: 1)

private final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class ToolbarButton: NSButton {
    enum Symbol { case refresh, compact, hide }
    private let symbol: Symbol
    private var hoverArea: NSTrackingArea?
    private var hovered = false

    init(symbol: Symbol, target: AnyObject?, action: Selector?) {
        self.symbol = symbol
        super.init(frame: .zero)
        self.target = target
        self.action = action
        title = ""
        isBordered = false
        setButtonType(.momentaryPushIn)
        focusRingType = .none
    }
    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        if let hoverArea { removeTrackingArea(hoverArea) }
        hoverArea = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(hoverArea!)
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        needsDisplay = true
        return accepted
    }
    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        needsDisplay = true
        return accepted
    }

    override func draw(_ dirtyRect: NSRect) {
        let focused = window?.firstResponder === self
        let backdrop = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        if hovered || isHighlighted || focused {
            NSColor.white.withAlphaComponent(isHighlighted ? 0.12 : 0.06).setFill()
            backdrop.fill()
        }
        if focused {
            NSColor.white.withAlphaComponent(0.4).setStroke()
            backdrop.lineWidth = 1
            backdrop.stroke()
        }
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let path = NSBezierPath()
        switch symbol {
        case .refresh:
            path.appendArc(withCenter: center, radius: 6, startAngle: 40, endAngle: 340, clockwise: false)
            let angle = CGFloat(340) * .pi / 180
            let tip = NSPoint(x: center.x + cos(angle) * 6, y: center.y + sin(angle) * 6)
            let tangent = NSPoint(x: -sin(angle), y: cos(angle))
            let back = NSPoint(x: tip.x - tangent.x * 3.2, y: tip.y - tangent.y * 3.2)
            path.move(to: NSPoint(x: back.x - tangent.y * 2.6, y: back.y + tangent.x * 2.6))
            path.line(to: tip)
            path.line(to: NSPoint(x: back.x + tangent.y * 2.6, y: back.y - tangent.x * 2.6))
        case .compact:
            path.move(to: NSPoint(x: center.x - 6.5, y: center.y))
            path.line(to: NSPoint(x: center.x + 6.5, y: center.y))
        case .hide:
            path.move(to: NSPoint(x: center.x - 5, y: center.y - 5))
            path.line(to: NSPoint(x: center.x + 5, y: center.y + 5))
            path.move(to: NSPoint(x: center.x - 5, y: center.y + 5))
            path.line(to: NSPoint(x: center.x + 5, y: center.y - 5))
        }
        path.lineWidth = 1.6
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        (hovered || focused || isHighlighted ? NSColor.white : headerMuted).setStroke()
        path.stroke()
    }
}

private enum ResizeEdge: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight, left, right, top, bottom

    var cursor: NSCursor {
        if #unavailable(macOS 15.0) {
            switch self {
            case .left, .right: return .resizeLeftRight
            case .top, .bottom: return .resizeUpDown
            default: return .crosshair
            }
        }
        if #available(macOS 15.0, *) {
        let position: NSCursor.FrameResizePosition
        switch self {
        case .topLeft: position = .topLeft
        case .topRight: position = .topRight
        case .bottomLeft: position = .bottomLeft
        case .bottomRight: position = .bottomRight
        case .left: position = .left
        case .right: position = .right
        case .top: position = .top
        case .bottom: position = .bottom
        }
        return NSCursor.frameResize(position: position, directions: .all)
        }
        return .arrow
    }

    var movesLeft: Bool { self == .left || self == .topLeft || self == .bottomLeft }
    var movesRight: Bool { self == .right || self == .topRight || self == .bottomRight }
    var movesTop: Bool { self == .top || self == .topLeft || self == .topRight }
    var movesBottom: Bool { self == .bottom || self == .bottomLeft || self == .bottomRight }
}

private func resizedFrame(_ frame: NSRect, from edge: ResizeEdge, delta: NSPoint,
                          minimum: NSSize) -> NSRect {
    var left = frame.minX, right = frame.maxX
    var bottom = frame.minY, top = frame.maxY
    if edge.movesLeft { left = min(left + delta.x, right - minimum.width) }
    if edge.movesRight { right = max(right + delta.x, left + minimum.width) }
    if edge.movesBottom { bottom = min(bottom + delta.y, top - minimum.height) }
    if edge.movesTop { top = max(top + delta.y, bottom + minimum.height) }
    return NSRect(x: left, y: bottom, width: right - left, height: top - bottom)
}

private func stateDirectory() -> URL {
    nativeStateDirectory()
}

private func savedFrame(_ key: String, fallback: NSRect) -> NSRect {
    guard let text = UserDefaults.standard.string(forKey: key) else { return fallback }
    let rect = NSRectFromString(text)
    guard rect.width > 0, rect.height > 0 else { return fallback }
    return rect
}

private func visibleFrame(_ rect: NSRect) -> NSRect {
    let screens = NSScreen.screens
    let screen = screens.first { $0.visibleFrame.intersects(rect) } ?? NSScreen.main
    guard let bounds = screen?.visibleFrame else { return rect }
    let width = min(rect.width, bounds.width)
    let height = min(rect.height, bounds.height)
    return NSRect(x: min(max(rect.minX, bounds.minX), bounds.maxX - width),
                  y: min(max(rect.minY, bounds.minY), bounds.maxY - height),
                  width: width, height: height)
}

private func boundsForWindow(_ window: NSWindow?) -> NSRect {
    let frame = window?.frame ?? .zero
    return NSScreen.screens.max(by: {
        $0.visibleFrame.intersection(frame).width * $0.visibleFrame.intersection(frame).height <
        $1.visibleFrame.intersection(frame).width * $1.visibleFrame.intersection(frame).height
    })?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
}

private func boundedMove(_ frame: NSRect, mouse: NSPoint) -> NSRect {
    let bounds = NSScreen.screens.first { $0.frame.contains(mouse) }?.visibleFrame
        ?? NSScreen.main?.visibleFrame ?? frame
    let width = min(frame.width, bounds.width), height = min(frame.height, bounds.height)
    return NSRect(x: min(max(frame.minX, bounds.minX), bounds.maxX - width),
                  y: min(max(frame.minY, bounds.minY), bounds.maxY - height),
                  width: width, height: height)
}

private func boundedResize(_ frame: NSRect, from edge: ResizeEdge, delta: NSPoint,
                           minimum: NSSize, in bounds: NSRect) -> NSRect {
    let requested = resizedFrame(frame, from: edge, delta: delta, minimum: minimum)
    var left = requested.minX, right = requested.maxX
    var bottom = requested.minY, top = requested.maxY
    if edge.movesLeft { left = max(left, bounds.minX) }
    if edge.movesRight { right = min(right, bounds.maxX) }
    if edge.movesBottom { bottom = max(bottom, bounds.minY) }
    if edge.movesTop { top = min(top, bounds.maxY) }
    return NSRect(x: left, y: bottom, width: right - left, height: top - bottom)
}

private final class DragBar: NSView {
    private var startFrame = NSRect.zero
    private var startMouse = NSPoint.zero

    override func mouseDown(with event: NSEvent) {
        startFrame = window?.frame ?? .zero
        startMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let candidate = startFrame.offsetBy(dx: mouse.x - startMouse.x,
                                            dy: mouse.y - startMouse.y)
        window.setFrame(boundedMove(candidate, mouse: mouse), display: true)
    }
    override func viewDidChangeEffectiveAppearance() { needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) { detailBackground.setFill(); NSBezierPath(rect: bounds).fill() }
}

private final class ResizeGrip: NSView {
    var minimum = minimumDetail
    var edge: ResizeEdge = .bottomRight
    var onResizeBegin: (() -> Void)?
    private var startFrame = NSRect.zero
    private var startMouse = NSPoint.zero
    private var resizeBounds = NSRect.zero
    private var hoverArea: NSTrackingArea?
    private var didBeginResizing = false

    override func updateTrackingAreas() {
        if let hoverArea { removeTrackingArea(hoverArea) }
        hoverArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(hoverArea!)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { edge.cursor.set() }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    override func mouseDown(with event: NSEvent) {
        startFrame = window?.frame ?? .zero
        startMouse = NSEvent.mouseLocation
        resizeBounds = boundsForWindow(window)
        didBeginResizing = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        if !didBeginResizing {
            didBeginResizing = true
            onResizeBegin?()
        }
        let mouse = NSEvent.mouseLocation
        let delta = NSPoint(x: mouse.x - startMouse.x, y: mouse.y - startMouse.y)
        window.setFrame(boundedResize(startFrame, from: edge, delta: delta,
                                      minimum: minimum, in: resizeBounds), display: true)
        edge.cursor.set()
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: edge.cursor) }
}

private final class CompactView: NSView {
    // Let a click open details even when another app currently owns the focus.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var percent: Int? { didSet { needsDisplay = true } }
    var hasNotice = false { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?
    private var startFrame = NSRect.zero
    private var startMouse = NSPoint.zero
    private var resizeBounds = NSRect.zero
    private var dragged = false
    private var resizingEdge: ResizeEdge?
    private var hoverArea: NSTrackingArea?

    private func resizeRect(for edge: ResizeEdge) -> NSRect {
        let corner = max(10, min(18, min(bounds.width, bounds.height) * 0.28))
        let strip = max(6, min(9, min(bounds.width, bounds.height) * 0.16))
        switch edge {
        case .topLeft: return NSRect(x: 0, y: bounds.maxY - corner, width: corner, height: corner)
        case .topRight: return NSRect(x: bounds.maxX - corner, y: bounds.maxY - corner,
                                      width: corner, height: corner)
        case .bottomLeft: return NSRect(x: 0, y: 0, width: corner, height: corner)
        case .bottomRight: return NSRect(x: bounds.maxX - corner, y: 0, width: corner, height: corner)
        case .left: return NSRect(x: 0, y: corner, width: strip, height: bounds.height - 2 * corner)
        case .right: return NSRect(x: bounds.maxX - strip, y: corner,
                                   width: strip, height: bounds.height - 2 * corner)
        case .top: return NSRect(x: corner, y: bounds.maxY - strip,
                                 width: bounds.width - 2 * corner, height: strip)
        case .bottom: return NSRect(x: corner, y: 0, width: bounds.width - 2 * corner, height: strip)
        }
    }

    private func resizeEdge(at point: NSPoint) -> ResizeEdge? {
        guard bounds.contains(point) else { return nil }
        return ResizeEdge.allCases.first { resizeRect(for: $0).contains(point) }
    }

    private func updateCursor(for event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        (resizeEdge(at: point)?.cursor ?? NSCursor.arrow).set()
    }

    override func updateTrackingAreas() {
        if let hoverArea { removeTrackingArea(hoverArea) }
        hoverArea = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(hoverArea!)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { updateCursor(for: event) }
    override func mouseMoved(with event: NSEvent) { updateCursor(for: event) }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    override func mouseDown(with event: NSEvent) {
        startFrame = window?.frame ?? .zero
        startMouse = NSEvent.mouseLocation
        resizeBounds = boundsForWindow(window)
        dragged = false
        let point = convert(event.locationInWindow, from: nil)
        resizingEdge = resizeEdge(at: point)
        if let resizingEdge { resizingEdge.cursor.set() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - startMouse.x
        let dy = mouse.y - startMouse.y
        if abs(dx) + abs(dy) < 3 { return }
        dragged = true
        if let resizingEdge {
            window.setFrame(boundedResize(startFrame, from: resizingEdge,
                                          delta: NSPoint(x: dx, y: dy),
                                          minimum: minimumCompact, in: resizeBounds), display: true)
            resizingEdge.cursor.set()
        } else {
            let candidate = startFrame.offsetBy(dx: dx, dy: dy)
            window.setFrame(boundedMove(candidate, mouse: mouse), display: true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let noticeClicked = hasNotice && nativeCompactNoticeRect(in: bounds).insetBy(dx: -2, dy: -2)
            .contains(convert(event.locationInWindow, from: nil))
        if !dragged && (resizingEdge == nil || noticeClicked) { onClick?() }
    }

    override func viewDidChangeEffectiveAppearance() { needsDisplay = true }

    override func resetCursorRects() {
        for edge in ResizeEdge.allCases {
            addCursorRect(resizeRect(for: edge), cursor: edge.cursor)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        detailBackground.setFill()
        let cornerRadius = min(15, min(bounds.width, bounds.height) / 4)
        NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        let diameter = max(20, min(bounds.width, bounds.height) - 11)
        let ringRect = NSRect(x: (bounds.width - diameter) / 2,
                              y: (bounds.height - diameter) / 2,
                              width: diameter, height: diameter)
        let track = NSBezierPath(ovalIn: ringRect)
        track.lineWidth = max(3, diameter * 0.09)
        quotaTrack.setStroke()
        track.stroke()
        if let percent, percent > 0 {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: bounds.midX, y: bounds.midY),
                          radius: diameter / 2, startAngle: 90,
                          endAngle: 90 - CGFloat(percent) * 3.6, clockwise: true)
            arc.lineWidth = track.lineWidth
            arc.lineCapStyle = .round
            let color = percent <= 10 ? quotaDanger : quotaAccent
            color.setStroke()
            arc.stroke()
        }
        let label = percent.map(String.init) ?? "—"
        let baseFontSize = max(10, min(27, diameter * 0.38))
        let font = NSFont.systemFont(ofSize: label.count >= 3 ? baseFontSize * 0.82 : baseFontSize,
                                     weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font,
            .foregroundColor: NSColor.white]
        let size = (label as NSString).size(withAttributes: attributes)
        (label as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2,
                                            y: bounds.midY - size.height / 2), withAttributes: attributes)
        if hasNotice {
            let notice = NSBezierPath(ovalIn: nativeCompactNoticeRect(in: bounds))
            detailBackground.setStroke()
            notice.lineWidth = 2
            notice.stroke()
            NSColor(srgbRed: 246 / 255, green: 202 / 255, blue: 105 / 255, alpha: 1).setFill()
            notice.fill()
        }
    }
}

private final class WidgetApp: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private var panel: NSPanel!
    private var root: NSView!
    private var web: WKWebView!
    private var compact: CompactView!
    private var dragBar: DragBar!
    private var brandLabel: NSTextField!
    private var statusLabel: NSTextField!
    private var grips: [ResizeEdge: ResizeGrip] = [:]
    private var collapseButton: NSButton!
    private var refreshButton: NSButton!
    private var hideButton: NSButton!
    private var statusItem: NSStatusItem!
    private var visibilityMenuItem: NSMenuItem!
    private var languageMenu: NSMenu!
    private var menuItems: [String: NSMenuItem] = [:]
    private let client = NativeServiceClient()
    private var localizer = NativeLocalizer(setting: NativeLanguage.saved(at: nativeStateDirectory()))
    private var usage = NativeUsage(object: ["status": "loading"])
    private var announcementAlerts = NativeAnnouncementAlerts(object: nil)
    private var didPresentSetupNotice = false
    private var isCompact = UserDefaults.standard.bool(forKey: "compact")
    private var transitioning = false
    private var pollTimer: Timer?
    private var ageTimer: Timer?
    private var outsideClickMonitor: Any?
    private var automaticDetailHeight = UserDefaults.standard.object(forKey: "detailAutoHeight") as? Bool ?? true
    private var detailMeasurement: NativeDetailMeasurement?
    private var fittingDetailHeight = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: stateDirectory(), withIntermediateDirectories: true)
        try? String(ProcessInfo.processInfo.processIdentifier).write(
            to: stateDirectory().appendingPathComponent("widget.pid"), atomically: true, encoding: .utf8)
        let defaultFrame = NSRect(x: (NSScreen.main?.visibleFrame.maxX ?? 800) - 626,
                                  y: (NSScreen.main?.visibleFrame.maxY ?? 800) - 620,
                                  width: 606, height: 585)
        if UserDefaults.standard.integer(forKey: "detailLayoutVersion") < 4 {
            let previous = savedFrame("detailFrame", fallback: defaultFrame)
            let updated = NSRect(x: previous.minX, y: previous.maxY - 585, width: 606, height: 585)
            UserDefaults.standard.set(NSStringFromRect(visibleFrame(updated)), forKey: "detailFrame")
            automaticDetailHeight = true
            UserDefaults.standard.set(true, forKey: "detailAutoHeight")
            UserDefaults.standard.set(4, forKey: "detailLayoutVersion")
        }
        let detailFrame = visibleFrame(savedFrame("detailFrame", fallback: defaultFrame))
        let frame = isCompact
            ? savedFrame("compactFrame", fallback: NSRect(x: defaultFrame.maxX - 78,
                                                           y: defaultFrame.maxY - 86,
                                                           width: 78, height: 86))
            : detailFrame
        panel = WidgetPanel(contentRect: visibleFrame(frame), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false
        root = NSView(frame: NSRect(origin: .zero, size: frame.size))
        root.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        root.layer?.backgroundColor = detailBackground.cgColor
        root.layer?.cornerRadius = 15
        root.layer?.masksToBounds = true
        panel.contentView = root

        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "detailLayout")
        configuration.userContentController.add(self, name: "announcementRead")
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: detailFrame.width,
                                      height: max(0, detailFrame.height - 60)), configuration: configuration)
        web.navigationDelegate = self
        web.uiDelegate = self
        // Explicit layout keeps the hidden detail document at its detail width in Compact mode.
        web.autoresizingMask = []
        web.underPageBackgroundColor = detailBackground
        var embeddedURL = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        embeddedURL.queryItems = [URLQueryItem(name: "embedded", value: "1")]
        web.load(URLRequest(url: embeddedURL.url!))
        root.addSubview(web)

        compact = CompactView(frame: .zero)
        compact.onClick = { [weak self] in self?.setCompact(false) }
        root.addSubview(compact)
        dragBar = DragBar(frame: .zero)
        root.addSubview(dragBar)
        brandLabel = NSTextField(labelWithString: localizer.text("brand"))
        brandLabel.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
        brandLabel.textColor = .white
        root.addSubview(brandLabel)
        statusLabel = NSTextField(labelWithString: localizer.text("reading"))
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = headerMuted
        root.addSubview(statusLabel)
        refreshButton = ToolbarButton(symbol: .refresh, target: self, action: #selector(refresh))
        root.addSubview(refreshButton)
        collapseButton = ToolbarButton(symbol: .compact, target: self, action: #selector(collapse))
        root.addSubview(collapseButton)
        hideButton = ToolbarButton(symbol: .hide, target: self, action: #selector(hide))
        root.addSubview(hideButton)
        refreshButton.nextKeyView = collapseButton
        collapseButton.nextKeyView = hideButton
        hideButton.nextKeyView = web
        web.nextKeyView = refreshButton
        for edge in ResizeEdge.allCases {
            let grip = ResizeGrip(frame: .zero)
            grip.edge = edge
            grip.onResizeBegin = { [weak self] in
                self?.automaticDetailHeight = false
                UserDefaults.standard.set(false, forKey: "detailAutoHeight")
            }
            grips[edge] = grip
            root.addSubview(grip)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "—"
        statusItem.button?.toolTip = localizer.text("quota_tooltip")
        let menu = NSMenu()
        visibilityMenuItem = NSMenuItem(title: localizer.text("hide"), action: #selector(toggleVisibility), keyEquivalent: "")
        menu.addItem(visibilityMenuItem)
        for (key, action) in [("toggle", #selector(toggle)), ("refresh_quota", #selector(refresh)),
                              ("open_page", #selector(openPage))] {
            let item = NSMenuItem(title: localizer.text(key), action: action, keyEquivalent: "")
            menuItems[key] = item
            menu.addItem(item)
        }
        let languageItem = NSMenuItem(title: localizer.text("language"), action: nil, keyEquivalent: "")
        menuItems["language"] = languageItem
        languageMenu = NSMenu()
        for language in NativeLanguage.allCases {
            let item = NSMenuItem(title: localizer.text(language.rawValue), action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.representedObject = language.rawValue
            item.target = self
            languageMenu.addItem(item)
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: localizer.text("quit"), action: #selector(quitAll), keyEquivalent: "")
        menuItems["quit"] = quitItem
        menu.addItem(quitItem)
        for item in menu.items { item.target = self }
        menu.delegate = self
        statusItem.menu = menu

        layoutViews()
        saveFrame()
        panel.orderFrontRegardless()
        publishDetailVisibility()
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.poll() }
        ageTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateStatusText()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screenConfigurationChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wokeFromSleep),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(settingsChanged),
            name: NSNotification.Name("local.codex.weeklymonitor.settingsChanged"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(cacheRefreshed),
            name: NSNotification.Name("local.codex.weeklymonitor.cacheRefreshed"), object: nil)
        updateNativeText()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
        ageTimer?.invalidate()
        pollTimer?.invalidate()
        web.configuration.userContentController.removeScriptMessageHandler(forName: "detailLayout")
        let pidFile = stateDirectory().appendingPathComponent("widget.pid")
        if (try? String(contentsOf: pidFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
            == String(ProcessInfo.processInfo.processIdentifier) {
            try? FileManager.default.removeItem(at: pidFile)
        }
    }

    private func layoutViews() {
        guard let root else { return }
        let w = root.bounds.width, h = root.bounds.height
        compact.frame = root.bounds
        compact.isHidden = !isCompact
        web.isHidden = isCompact
        dragBar.isHidden = isCompact
        brandLabel.isHidden = isCompact
        statusLabel.isHidden = isCompact
        collapseButton.isHidden = isCompact
        refreshButton.isHidden = isCompact
        hideButton.isHidden = isCompact
        for grip in grips.values { grip.isHidden = isCompact }
        if !isCompact {
            brandLabel.font = NSFont.monospacedSystemFont(ofSize: w < 520 ? 17 : 20, weight: .bold)
            let brandWidth = ceil((brandLabel.stringValue as NSString).size(withAttributes: [.font: brandLabel.font!]).width) + 2
            let statusWidth = ceil((statusLabel.stringValue as NSString).size(withAttributes: [.font: statusLabel.font!]).width) + 2
            let header = NativeDetailHeaderLayout(size: root.bounds.size, brandWidth: brandWidth, statusWidth: statusWidth)
            web.frame = header.content
            dragBar.frame = header.header
            brandLabel.frame = header.brand
            statusLabel.frame = header.status
            refreshButton.frame = header.refresh
            collapseButton.frame = header.compact
            hideButton.frame = header.hide
            let corner: CGFloat = 18, strip: CGFloat = 9
            grips[.topLeft]?.frame = NSRect(x: 0, y: h - corner, width: corner, height: corner)
            grips[.topRight]?.frame = NSRect(x: w - corner, y: h - corner, width: corner, height: corner)
            grips[.bottomLeft]?.frame = NSRect(x: 0, y: 0, width: corner, height: corner)
            grips[.bottomRight]?.frame = NSRect(x: w - corner, y: 0, width: corner, height: corner)
            grips[.left]?.frame = NSRect(x: 0, y: corner, width: strip, height: h - 2 * corner)
            grips[.right]?.frame = NSRect(x: w - strip, y: corner, width: strip, height: h - 2 * corner)
            grips[.top]?.frame = NSRect(x: corner, y: h - strip, width: w - 2 * corner, height: strip)
            grips[.bottom]?.frame = NSRect(x: corner, y: 0, width: w - 2 * corner, height: strip)
        }
    }

    func windowDidResize(_ notification: Notification) { layoutViews(); saveFrame() }
    func windowDidMove(_ notification: Notification) { saveFrame() }
    @objc private func screenConfigurationChanged() {
        panel.setFrame(visibleFrame(panel.frame), display: true)
        fitDetailHeight()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.orderFrontRegardless()
        publishDetailVisibility()
        refresh()
        return true
    }
    private func saveFrame() {
        guard panel != nil, !transitioning else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame),
                                  forKey: isCompact ? "compactFrame" : "detailFrame")
    }

    private func setCompact(_ value: Bool) {
        guard value != isCompact else { panel.orderFrontRegardless(); return }
        saveFrame()
        let current = panel.frame
        let fallbackHeight: CGFloat = value ? 86 : 630
        let saved = savedFrame(value ? "compactFrame" : "detailFrame",
                               fallback: NSRect(x: current.minX, y: current.maxY - fallbackHeight,
                                                width: value ? 78 : 606,
                                                height: fallbackHeight))
        let width = max(value ? minimumCompact.width : minimumDetail.width, saved.width)
        let height = max(value ? minimumCompact.height : minimumDetail.height, saved.height)
        isCompact = value
        UserDefaults.standard.set(value, forKey: "compact")
        transitioning = true
        publishDetailVisibility()
        let target = visibleFrame(NSRect(x: saved.minX, y: saved.minY,
                                         width: width, height: height))
        layoutViews()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.26
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            self?.transitioning = false
            self?.layoutViews()
            self?.saveFrame()
            self?.fitDetailHeight()
            self?.publishDetailVisibility()
        })
        panel.orderFrontRegardless()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        localizer.setting = NativeLanguage.saved(at: stateDirectory())
        updateNativeText()
    }

    private func updateNativeText() {
        brandLabel.stringValue = localizer.text("brand")
        panel.title = localizer.text("brand")
        collapseButton.toolTip = localizer.text("return_compact")
        collapseButton.setAccessibilityLabel(localizer.text("return_compact"))
        refreshButton.toolTip = localizer.text("refresh_quota")
        refreshButton.setAccessibilityLabel(localizer.text("refresh_quota"))
        hideButton.toolTip = localizer.text("hide")
        hideButton.setAccessibilityLabel(localizer.text("hide"))
        visibilityMenuItem.title = localizer.text(panel.isVisible ? "hide" : "show")
        for (key, item) in menuItems { item.title = localizer.text(key) }
        for item in languageMenu.items {
            guard let value = item.representedObject as? String else { continue }
            item.title = localizer.text(value)
            item.state = value == localizer.setting.rawValue ? .on : .off
        }
        statusItem.button?.toolTip = usage.tooltip(localizer)
        compact.toolTip = [usage.tooltip(localizer), announcementAlerts.tooltip(localizer)].filter { !$0.isEmpty }.joined(separator: "\n")
        compact.setAccessibilityLabel(compact.toolTip)
        updateStatusText()
    }

    private func updateStatusText() {
        statusLabel.stringValue = usage.status(localizer)
        statusLabel.toolTip = usage.tooltip(localizer)
        layoutViews()
        fitDetailHeight()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.webView === web, message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == baseURL.scheme,
              message.frameInfo.securityOrigin.host == baseURL.host,
              message.frameInfo.securityOrigin.port == baseURL.port else { return }
        if message.name == "announcementRead" { pollAnnouncementAlerts(); return }
        guard message.name == "detailLayout", !transitioning,
              let measurement = NativeDetailMeasurement(object: message.body,
                  documentURL: message.frameInfo.request.url, isMainFrame: message.frameInfo.isMainFrame,
                  expectedURL: baseURL, viewWidth: web.bounds.width) else { return }
        detailMeasurement = measurement
        fitDetailHeight()
    }

    private func fitDetailHeight() {
        guard !isCompact, automaticDetailHeight, !transitioning, !fittingDetailHeight,
              let measurement = detailMeasurement,
              abs(measurement.width - web.bounds.width) <= 2,
              let fitted = nativeDetailFittedFrame(panel.frame, contentHeight: measurement.height,
                  headerHeight: dragBar.frame.height, in: boundsForWindow(panel)),
              abs(fitted.height - panel.frame.height) > 0.5 || abs(fitted.minY - panel.frame.minY) > 0.5 else { return }
        fittingDetailHeight = true
        panel.setFrame(fitted, display: true)
        fittingDetailHeight = false
        layoutViews()
        saveFrame()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = NativeLanguage(rawValue: raw) else { return }
        client.setLanguage(language) { [weak self] saved in
            guard let self else { return }
            if saved {
                self.localizer.setting = language
                self.updateNativeText()
                self.web.reload()
                DistributedNotificationCenter.default().postNotificationName(
                    NSNotification.Name("local.codex.weeklymonitor.settingsChanged"), object: nil,
                    userInfo: nil, deliverImmediately: true)
            } else { self.presentNotice("settings_failed") }
        }
    }

    private func presentNotice(_ key: String) {
        let alert = NSAlert()
        alert.messageText = localizer.text("brand")
        alert.informativeText = localizer.text(key)
        alert.addButton(withTitle: localizer.text("ok"))
        alert.runModal()
    }

    @objc private func wokeFromSleep() { refresh() }
    @objc private func settingsChanged() {
        localizer.setting = NativeLanguage.saved(at: stateDirectory())
        updateNativeText()
        web.reload()
    }
    @objc private func cacheRefreshed() { poll(force: true); web.reload() }

    @objc private func toggleVisibility() {
        if panel.isVisible { hide() } else { show() }
    }
    @objc private func show() { panel.orderFrontRegardless(); publishDetailVisibility() }
    @objc private func hide() { panel.orderOut(nil); publishDetailVisibility() }
    @objc private func collapse() { setCompact(true) }
    @objc private func toggle() { setCompact(!isCompact) }
    @objc private func openPage() { NSWorkspace.shared.open(baseURL) }
    @objc private func refresh() {
        client.refresh { [weak self] in
            self?.poll(force: true, notifyDock: true)
            self?.web.reload()
        }
    }
    @objc private func quitAll() {
        let stop = nativeServiceDirectory().appendingPathComponent("Stop.command")
        if FileManager.default.fileExists(atPath: stop.path) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [stop.path]
            try? task.run()
        } else { NSApp.terminate(nil) }
    }

    private func poll(force: Bool = false, notifyDock: Bool = false) {
        pollAnnouncementAlerts()
        client.fetch(force: force) { [weak self] usage, language in
            guard let self else { return }
            self.usage = usage
            self.localizer.setting = language ?? NativeLanguage.saved(at: stateDirectory())
            self.compact.percent = usage.percent
            self.statusItem.button?.title = usage.percent.map { "\($0)%" } ?? "—"
            self.updateNativeText()
            if notifyDock {
                DistributedNotificationCenter.default().postNotificationName(
                    NSNotification.Name("local.codex.weeklymonitor.usageUpdated"), object: nil,
                    userInfo: nil, deliverImmediately: true)
            }
            if !self.didPresentSetupNotice, let code = usage.errorCode,
               code == "cli_missing" || code == "signed_out" {
                self.didPresentSetupNotice = true
                self.presentNotice(code)
            }
        }
    }

    private func pollAnnouncementAlerts() {
        client.fetchAnnouncementAlerts { [weak self] alerts in
            guard let self, let alerts else { return }
            self.announcementAlerts = alerts
            self.compact.hasNotice = alerts.hasUnread
            if self.isCompact && self.panel.isVisible { self.client.reportIndicator(alerts) }
            self.updateNativeText()
        }
    }

    private func publishDetailVisibility() {
        let visible = !isCompact && panel.isVisible && !transitioning
        if visible && outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                guard let self, NSApp.modalWindow == nil,
                      nativeShouldCollapseDetail(at: NSEvent.mouseLocation, frame: self.panel.frame,
                        isCompact: self.isCompact, isVisible: self.panel.isVisible,
                        transitioning: self.transitioning) else { return }
                self.setCompact(true)
            }
        } else if !visible, let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        web.evaluateJavaScript("window.dispatchEvent(new CustomEvent('quota-detail-visibility', {detail: \(visible ? "true" : "false")}))", completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        publishDetailVisibility()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           url.host != "127.0.0.1" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }
}

@main
private struct Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = WidgetApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
