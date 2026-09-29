import AppKit
import WebKit

private let baseURL = URL(string: "http://127.0.0.1:39224/")!
private let minimumDetail = NSSize(width: 330, height: 430)
private let minimumCompact = NSSize(width: 36, height: 36)
private let detailBackground = NSColor(srgbRed: 32 / 255, green: 37 / 255, blue: 45 / 255, alpha: 1)
private let quotaAccent = NSColor(srgbRed: 36 / 255, green: 211 / 255, blue: 165 / 255, alpha: 1)
private let quotaDanger = NSColor(srgbRed: 250 / 255, green: 125 / 255, blue: 121 / 255, alpha: 1)
private let quotaTrack = NSColor(srgbRed: 61 / 255, green: 72 / 255, blue: 85 / 255, alpha: 1)

private enum ResizeEdge: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight, left, right, top, bottom

    var cursor: NSCursor {
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
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexWeeklyMonitor", isDirectory: true)
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
    private var startFrame = NSRect.zero
    private var startMouse = NSPoint.zero
    private var resizeBounds = NSRect.zero
    private var hoverArea: NSTrackingArea?

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
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let delta = NSPoint(x: mouse.x - startMouse.x, y: mouse.y - startMouse.y)
        window.setFrame(boundedResize(startFrame, from: edge, delta: delta,
                                      minimum: minimum, in: resizeBounds), display: true)
        edge.cursor.set()
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: edge.cursor) }
}

private final class CompactView: NSView {
    var percent: Int? { didSet { needsDisplay = true } }
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
        if !dragged && resizingEdge == nil { onClick?() }
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
    }
}

private final class WidgetApp: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
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
    private var isCompact = UserDefaults.standard.bool(forKey: "compact")
    private var transitioning = false
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: stateDirectory(), withIntermediateDirectories: true)
        try? String(ProcessInfo.processInfo.processIdentifier).write(
            to: stateDirectory().appendingPathComponent("widget.pid"), atomically: true, encoding: .utf8)
        let defaultFrame = NSRect(x: (NSScreen.main?.visibleFrame.maxX ?? 800) - 626,
                                  y: (NSScreen.main?.visibleFrame.maxY ?? 800) - 620,
                                  width: 606, height: 585)
        if UserDefaults.standard.integer(forKey: "detailLayoutVersion") < 2 {
            let previous = savedFrame("detailFrame", fallback: defaultFrame)
            let updated = NSRect(x: previous.minX, y: previous.maxY - 585, width: 606, height: 585)
            UserDefaults.standard.set(NSStringFromRect(visibleFrame(updated)), forKey: "detailFrame")
            UserDefaults.standard.set(2, forKey: "detailLayoutVersion")
        }
        let frame = isCompact
            ? savedFrame("compactFrame", fallback: NSRect(x: defaultFrame.maxX - 78,
                                                           y: defaultFrame.maxY - 86,
                                                           width: 78, height: 86))
            : savedFrame("detailFrame", fallback: defaultFrame)
        panel = NSPanel(contentRect: visibleFrame(frame), styleMask: [.borderless, .nonactivatingPanel],
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

        web = WKWebView(frame: .zero)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.autoresizingMask = [.width, .height]
        web.underPageBackgroundColor = detailBackground
        web.load(URLRequest(url: baseURL))
        root.addSubview(web)

        compact = CompactView(frame: .zero)
        compact.onClick = { [weak self] in self?.setCompact(false) }
        root.addSubview(compact)
        dragBar = DragBar(frame: .zero)
        root.addSubview(dragBar)
        brandLabel = NSTextField(labelWithString: "Codex 周额度")
        brandLabel.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
        brandLabel.textColor = .white
        root.addSubview(brandLabel)
        statusLabel = NSTextField(labelWithString: "正在读取")
        statusLabel.font = NSFont.systemFont(ofSize: 17, weight: .medium)
        statusLabel.textColor = NSColor(srgbRed: 161 / 255, green: 170 / 255, blue: 182 / 255, alpha: 1)
        root.addSubview(statusLabel)
        collapseButton = NSButton(title: "极简", target: self, action: #selector(collapse))
        collapseButton.isBordered = false
        collapseButton.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        collapseButton.contentTintColor = NSColor(srgbRed: 36 / 255, green: 211 / 255, blue: 165 / 255, alpha: 1)
        root.addSubview(collapseButton)
        refreshButton = NSButton(title: "刷新", target: self, action: #selector(refresh))
        refreshButton.isBordered = false
        refreshButton.font = NSFont.systemFont(ofSize: 17, weight: .medium)
        refreshButton.contentTintColor = NSColor(srgbRed: 161 / 255, green: 170 / 255, blue: 182 / 255, alpha: 1)
        root.addSubview(refreshButton)
        hideButton = NSButton(title: "×", target: self, action: #selector(hide))
        hideButton.isBordered = false
        hideButton.font = NSFont.systemFont(ofSize: 22, weight: .regular)
        hideButton.contentTintColor = NSColor(srgbRed: 161 / 255, green: 170 / 255, blue: 182 / 255, alpha: 1)
        root.addSubview(hideButton)
        for edge in ResizeEdge.allCases {
            let grip = ResizeGrip(frame: .zero)
            grip.edge = edge
            grips[edge] = grip
            root.addSubview(grip)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "—"
        statusItem.button?.toolTip = "Codex 本周额度"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示悬浮窗", action: #selector(show), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "切换极简／详细", action: #selector(toggle), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "刷新额度", action: #selector(refresh), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "在浏览器中打开详细页", action: #selector(openPage), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出监控工具", action: #selector(quitAll), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        statusItem.menu = menu

        layoutViews()
        saveFrame()
        panel.orderFrontRegardless()
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.poll() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenConfigurationChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
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
        statusLabel.isHidden = isCompact || w < 520
        collapseButton.isHidden = isCompact
        refreshButton.isHidden = isCompact
        hideButton.isHidden = isCompact
        for grip in grips.values { grip.isHidden = isCompact }
        if !isCompact {
            web.frame = NSRect(x: 0, y: 0, width: w, height: max(0, h - 60))
            dragBar.frame = NSRect(x: 0, y: h - 60, width: w, height: 60)
            brandLabel.frame = NSRect(x: w < 520 ? 12 : 30, y: h - 43, width: w < 520 ? 136 : 190, height: 28)
            statusLabel.frame = NSRect(x: 235, y: h - 42, width: max(0, w - 410), height: 27)
            collapseButton.frame = NSRect(x: w - 202, y: h - 45, width: 62, height: 32)
            refreshButton.frame = NSRect(x: w - 127, y: h - 45, width: 62, height: 32)
            hideButton.frame = NSRect(x: w - 51, y: h - 45, width: 32, height: 32)
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
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.orderFrontRegardless()
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
                                                width: value ? 78 : 440,
                                                height: fallbackHeight))
        let width = max(value ? minimumCompact.width : minimumDetail.width, saved.width)
        let height = max(value ? minimumCompact.height : minimumDetail.height, saved.height)
        isCompact = value
        UserDefaults.standard.set(value, forKey: "compact")
        transitioning = true
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
        })
        panel.orderFrontRegardless()
    }

    @objc private func show() { panel.orderFrontRegardless() }
    @objc private func hide() { panel.orderOut(nil) }
    @objc private func collapse() { setCompact(true) }
    @objc private func toggle() { setCompact(!isCompact) }
    @objc private func openPage() { NSWorkspace.shared.open(baseURL) }
    @objc private func refresh() {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/refresh"))
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.poll()
                self?.web.reload()
            }
        }.resume()
    }
    @objc private func quitAll() {
        let package = Bundle.main.bundleURL.deletingLastPathComponent()
        let stop = package.appendingPathComponent("Stop.command")
        if FileManager.default.fileExists(atPath: stop.path) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [stop.path]
            try? task.run()
        } else { NSApp.terminate(nil) }
    }

    private func poll() {
        let url = baseURL.appendingPathComponent("api/usage")
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            var percent: Int? = nil
            if let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               object["status"] as? String == "ok",
               let updated = object["updatedAt"] as? Double,
               let reset = object["resetsAt"] as? Double,
               Date().timeIntervalSince1970 * 1000 - updated <= 600_000,
               reset > Date().timeIntervalSince1970,
               let value = object["remainingPercent"] as? Int {
                percent = max(0, min(100, value))
            }
            DispatchQueue.main.async {
                self?.compact.percent = percent
                self?.statusItem.button?.title = percent.map { "\($0)%" } ?? "—"
                self?.statusItem.button?.toolTip = percent.map { "本周剩余 \($0)%" } ?? "Codex 额度暂不可用"
                self?.statusLabel.stringValue = percent == nil ? "暂不可用" : "数据已更新"
            }
        }.resume()
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
