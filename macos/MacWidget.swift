import AppKit
import WebKit

private let baseURL = URL(string: "http://127.0.0.1:39224/")!
private let minimumDetail = NSSize(width: 330, height: 430)
private let minimumCompact = NSSize(width: 58, height: 58)

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

private final class DragBar: NSView {
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override func viewDidChangeEffectiveAppearance() { needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) { NSColor.windowBackgroundColor.setFill(); NSBezierPath(rect: bounds).fill() }
}

private final class ResizeGrip: NSView {
    var minimum = minimumDetail
    private var startFrame = NSRect.zero
    private var startMouse = NSPoint.zero

    override func mouseDown(with event: NSEvent) {
        startFrame = window?.frame ?? .zero
        startMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let width = max(minimum.width, startFrame.width + mouse.x - startMouse.x)
        let height = max(minimum.height, startFrame.height - mouse.y + startMouse.y)
        window.setFrame(NSRect(x: startFrame.minX, y: startFrame.maxY - height,
                               width: width, height: height), display: true)
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }
}

private final class CompactView: NSView {
    var percent: Int? { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?
    private var startFrame = NSRect.zero
    private var startMouse = NSPoint.zero
    private var dragged = false
    private var resizing = false

    override func mouseDown(with event: NSEvent) {
        startFrame = window?.frame ?? .zero
        startMouse = NSEvent.mouseLocation
        dragged = false
        let point = convert(event.locationInWindow, from: nil)
        resizing = point.x > bounds.maxX - 16 && point.y < 16
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - startMouse.x
        let dy = mouse.y - startMouse.y
        if abs(dx) + abs(dy) < 3 { return }
        dragged = true
        if resizing {
            let width = max(minimumCompact.width, startFrame.width + dx)
            let height = max(minimumCompact.height, startFrame.height - dy)
            window.setFrame(NSRect(x: startFrame.minX, y: startFrame.maxY - height,
                                   width: width, height: height), display: true)
        } else {
            window.setFrameOrigin(NSPoint(x: startFrame.minX + dx, y: startFrame.minY + dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !dragged { onClick?() }
    }

    override func viewDidChangeEffectiveAppearance() { needsDisplay = true }

    override func resetCursorRects() {
        addCursorRect(NSRect(x: bounds.maxX - 16, y: 0, width: 16, height: 16), cursor: .resizeLeftRight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let background = dark ? NSColor(srgbRed: 0.12, green: 0.15, blue: 0.17, alpha: 0.96)
                              : NSColor(srgbRed: 0.96, green: 0.98, blue: 0.97, alpha: 0.97)
        background.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 15, yRadius: 15).fill()
        let diameter = max(34, min(bounds.width - 17, bounds.height - 17))
        let ringRect = NSRect(x: (bounds.width - diameter) / 2,
                              y: (bounds.height - diameter) / 2,
                              width: diameter, height: diameter)
        let track = NSBezierPath(ovalIn: ringRect)
        track.lineWidth = max(5, diameter * 0.09)
        (dark ? NSColor(srgbRed: 0.24, green: 0.28, blue: 0.32, alpha: 1)
              : NSColor(srgbRed: 0.80, green: 0.85, blue: 0.84, alpha: 1)).setStroke()
        track.stroke()
        if let percent, percent > 0 {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: bounds.midX, y: bounds.midY),
                          radius: diameter / 2, startAngle: 90,
                          endAngle: 90 - CGFloat(percent) * 3.6, clockwise: true)
            arc.lineWidth = track.lineWidth
            arc.lineCapStyle = .round
            let color = percent <= 10 ? NSColor.systemRed : percent <= 50 ? NSColor.systemOrange : NSColor.systemMint
            color.setStroke()
            arc.stroke()
        }
        let label = percent.map(String.init) ?? "—"
        let font = NSFont.systemFont(ofSize: max(15, min(27, diameter * 0.36)), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font,
            .foregroundColor: dark ? NSColor.white : NSColor.black]
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
    private var grip: ResizeGrip!
    private var collapseButton: NSButton!
    private var hideButton: NSButton!
    private var statusItem: NSStatusItem!
    private var isCompact = UserDefaults.standard.bool(forKey: "compact")
    private var transitioning = false
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: stateDirectory(), withIntermediateDirectories: true)
        try? String(ProcessInfo.processInfo.processIdentifier).write(
            to: stateDirectory().appendingPathComponent("widget.pid"), atomically: true, encoding: .utf8)
        let defaultFrame = NSRect(x: (NSScreen.main?.visibleFrame.maxX ?? 800) - 460,
                                  y: (NSScreen.main?.visibleFrame.maxY ?? 800) - 650,
                                  width: 440, height: 630)
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
        panel.hidesOnDeactivate = false
        root = NSView(frame: NSRect(origin: .zero, size: frame.size))
        root.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        root.layer?.cornerRadius = 15
        root.layer?.masksToBounds = true
        panel.contentView = root

        web = WKWebView(frame: .zero)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.autoresizingMask = [.width, .height]
        web.load(URLRequest(url: baseURL))
        root.addSubview(web)

        compact = CompactView(frame: .zero)
        compact.onClick = { [weak self] in self?.setCompact(false) }
        root.addSubview(compact)
        dragBar = DragBar(frame: .zero)
        root.addSubview(dragBar)
        collapseButton = NSButton(title: "极简", target: self, action: #selector(collapse))
        collapseButton.bezelStyle = .rounded
        root.addSubview(collapseButton)
        hideButton = NSButton(title: "隐藏", target: self, action: #selector(hide))
        hideButton.bezelStyle = .rounded
        root.addSubview(hideButton)
        grip = ResizeGrip(frame: .zero)
        root.addSubview(grip)

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
        panel.orderFrontRegardless()
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.poll() }
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
        collapseButton.isHidden = isCompact
        hideButton.isHidden = isCompact
        grip.isHidden = isCompact
        if !isCompact {
            web.frame = NSRect(x: 0, y: 0, width: w, height: max(0, h - 38))
            dragBar.frame = NSRect(x: 0, y: h - 38, width: w, height: 38)
            collapseButton.frame = NSRect(x: max(4, w - 142), y: h - 33, width: 64, height: 27)
            hideButton.frame = NSRect(x: max(4, w - 74), y: h - 33, width: 64, height: 27)
            grip.frame = NSRect(x: w - 22, y: 0, width: 22, height: 22)
        }
    }

    func windowDidResize(_ notification: Notification) { layoutViews(); saveFrame() }
    func windowDidMove(_ notification: Notification) { saveFrame() }
    private func saveFrame() {
        guard panel != nil, !transitioning else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame),
                                  forKey: isCompact ? "compactFrame" : "detailFrame")
    }

    private func setCompact(_ value: Bool) {
        guard value != isCompact else { panel.orderFrontRegardless(); return }
        saveFrame()
        let current = panel.frame
        let saved = savedFrame(value ? "compactFrame" : "detailFrame",
                               fallback: NSRect(x: current.minX, y: current.minY,
                                                width: value ? 78 : 440,
                                                height: value ? 86 : 630))
        let width = max(value ? minimumCompact.width : minimumDetail.width, saved.width)
        let height = max(value ? minimumCompact.height : minimumDetail.height, saved.height)
        isCompact = value
        UserDefaults.standard.set(value, forKey: "compact")
        transitioning = true
        let target = visibleFrame(NSRect(x: current.minX, y: current.maxY - height,
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
