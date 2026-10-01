import AppKit

private let accent = NSColor(srgbRed: 36 / 255, green: 211 / 255, blue: 165 / 255, alpha: 1)
private let danger = NSColor(srgbRed: 250 / 255, green: 125 / 255, blue: 121 / 255, alpha: 1)
private let track = NSColor(srgbRed: 61 / 255, green: 72 / 255, blue: 85 / 255, alpha: 1)

private func dockImage(percent: Int?) -> (NSImage, NSBitmapImageRep) {
    let side = 512
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
    NSColor(srgbRed: 32 / 255, green: 37 / 255, blue: 45 / 255, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 16, y: 16, width: 480, height: 480),
                 xRadius: 106, yRadius: 106).fill()
    let circle = NSBezierPath(ovalIn: NSRect(x: 91, y: 91, width: 330, height: 330))
    circle.lineWidth = 32
    track.setStroke()
    circle.stroke()
    if let percent, percent > 0 {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: NSPoint(x: 256, y: 256), radius: 165,
                      startAngle: 90, endAngle: 90 - CGFloat(percent) * 3.6,
                      clockwise: true)
        arc.lineWidth = 32
        arc.lineCapStyle = .round
        (percent <= 10 ? danger : accent).setStroke()
        arc.stroke()
    }
    let label = percent.map(String.init) ?? "—"
    let fontSize: CGFloat = label.count >= 3 ? 132 : 151
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    let text = label as NSString
    let size = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: 256 - size.width / 2, y: 256 - size.height / 2),
              withAttributes: attrs)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    let image = NSImage(size: NSSize(width: side, height: side))
    image.addRepresentation(bitmap)
    return (image, bitmap)
}

private final class DockLauncher: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var pollTimer: Timer?
    private var percent: Int?
    private let root = nativeServiceDirectory()
    private let state = nativeStateDirectory()
    private let client = NativeServiceClient()
    private var localizer = NativeLocalizer(setting: NativeLanguage.saved(at: nativeStateDirectory()))
    private var appMenu: NSMenu!
    private var languageMenu: NSMenu!
    private var menuItems: [String: NSMenuItem] = [:]
    private var starter: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
        try? String(ProcessInfo.processInfo.processIdentifier).write(
            to: state.appendingPathComponent("launcher.pid"), atomically: true, encoding: .utf8)
        updateIcon(nil)
        configureMenu()
        startWidget()
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.poll()
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wokeFromSleep),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(usageUpdated),
            name: NSNotification.Name("local.codex.weeklymonitor.usageUpdated"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(settingsChanged),
            name: NSNotification.Name("local.codex.weeklymonitor.settingsChanged"), object: nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                        hasVisibleWindows flag: Bool) -> Bool {
        startWidget()
        poll(force: true)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        let pidFile = state.appendingPathComponent("launcher.pid")
        if (try? String(contentsOf: pidFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
            == String(ProcessInfo.processInfo.processIdentifier) {
            try? FileManager.default.removeItem(at: pidFile)
        }
        let stop = root.appendingPathComponent("Stop.command")
        if FileManager.default.fileExists(atPath: stop.path) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [stop.path, "--from-launcher"]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
        }
    }

    private func startWidget() {
        guard starter?.isRunning != true else { return }
        let script = root.appendingPathComponent("Start.command")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script.path, "--widget-only"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { [weak self] task in
            if task.terminationStatus == 0 {
                DispatchQueue.main.async { self?.poll(force: true) }
            }
        }
        do { try task.run(); starter = task }
        catch { presentNotice("service_unavailable") }
    }

    private func updateIcon(_ value: Int?) {
        guard value != percent || NSApp.applicationIconImage == nil else { return }
        percent = value
        NSApp.applicationIconImage = dockImage(percent: value).0
        NSApp.dockTile.display()
    }

    private func poll(force: Bool = false) {
        client.fetch(force: force) { [weak self] usage, language in
            guard let self else { return }
            self.localizer.setting = language ?? NativeLanguage.saved(at: self.state)
            self.updateIcon(usage.percent)
            self.updateMenu()
        }
    }

    private func configureMenu() {
        let main = NSMenu()
        let item = NSMenuItem()
        appMenu = NSMenu()
        item.submenu = appMenu
        main.addItem(item)
        for (key, action, shortcut) in [("show", #selector(showWidget), ""),
                                        ("refresh_quota", #selector(refresh), "r"),
                                        ("open_page", #selector(openPage), "")] {
            let entry = NSMenuItem(title: localizer.text(key), action: action, keyEquivalent: shortcut)
            entry.target = self
            menuItems[key] = entry
            appMenu.addItem(entry)
        }
        let languages = NSMenuItem(title: localizer.text("language"), action: nil, keyEquivalent: "")
        menuItems["language"] = languages
        languageMenu = NSMenu()
        for language in NativeLanguage.allCases {
            let entry = NSMenuItem(title: localizer.text(language.rawValue), action: #selector(selectLanguage(_:)), keyEquivalent: "")
            entry.representedObject = language.rawValue
            entry.target = self
            languageMenu.addItem(entry)
        }
        languages.submenu = languageMenu
        appMenu.addItem(languages)
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: localizer.text("quit"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menuItems["quit"] = quit
        appMenu.addItem(quit)
        appMenu.delegate = self
        NSApp.mainMenu = main
        updateMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        localizer.setting = NativeLanguage.saved(at: state)
        updateMenu()
    }

    private func updateMenu() {
        appMenu.title = localizer.text("brand")
        NSApp.mainMenu?.items.first?.title = localizer.text("brand")
        for (key, item) in menuItems { item.title = localizer.text(key) }
        for item in languageMenu.items {
            guard let value = item.representedObject as? String else { continue }
            item.title = localizer.text(value)
            item.state = value == localizer.setting.rawValue ? .on : .off
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let language = NativeLanguage(rawValue: value) else { return }
        client.setLanguage(language) { [weak self] saved in
            guard let self else { return }
            if saved {
                self.localizer.setting = language
                self.updateMenu()
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

    @objc private func showWidget() { startWidget() }
    @objc private func openPage() { NSWorkspace.shared.open(NativeServiceClient.baseURL) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func usageUpdated() { poll(force: true) }
    @objc private func settingsChanged() {
        localizer.setting = NativeLanguage.saved(at: state)
        updateMenu()
    }
    @objc private func wokeFromSleep() { poll(force: true) }
    @objc private func refresh() {
        client.refresh { [weak self] in
            self?.poll(force: true)
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("local.codex.weeklymonitor.cacheRefreshed"), object: nil,
                userInfo: nil, deliverImmediately: true)
        }
    }
}

@main
private struct Main {
    static func main() {
        if let status = nativeProcessGuardCommand(CommandLine.arguments) { exit(status) }
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--icon-png" {
            let bitmap = dockImage(percent: nil).1
            guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
            do { try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2])) }
            catch { exit(1) }
            return
        }
        let app = NSApplication.shared
        let delegate = DockLauncher()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
