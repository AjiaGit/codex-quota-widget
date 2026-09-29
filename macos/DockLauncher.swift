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
    let label = percent.map { "\($0)%" } ?? "—"
    let fontSize: CGFloat = label.count >= 4 ? 119 : 151
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

private final class DockLauncher: NSObject, NSApplicationDelegate {
    private var pollTimer: Timer?
    private var percent: Int?
    private let root = Bundle.main.bundleURL.deletingLastPathComponent()
    private let state = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexWeeklyMonitor", isDirectory: true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
        try? String(ProcessInfo.processInfo.processIdentifier).write(
            to: state.appendingPathComponent("launcher.pid"), atomically: true, encoding: .utf8)
        updateIcon(nil)
        startWidget()
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                        hasVisibleWindows flag: Bool) -> Bool {
        startWidget()
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
            task.arguments = [stop.path]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
        }
    }

    private func startWidget() {
        let script = root.appendingPathComponent("Start.command")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    private func updateIcon(_ value: Int?) {
        guard value != percent || NSApp.applicationIconImage == nil else { return }
        percent = value
        NSApp.applicationIconImage = dockImage(percent: value).0
        NSApp.dockTile.display()
    }

    private func poll() {
        let url = URL(string: "http://127.0.0.1:39224/api/usage")!
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            var value: Int?
            if let data,
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               object["status"] as? String == "ok",
               let updated = object["updatedAt"] as? Double,
               let reset = object["resetsAt"] as? Double,
               Date().timeIntervalSince1970 * 1000 - updated <= 600_000,
               reset > Date().timeIntervalSince1970,
               let remaining = object["remainingPercent"] as? Int {
                value = max(0, min(100, remaining))
            }
            DispatchQueue.main.async { self?.updateIcon(value) }
        }.resume()
    }
}

@main
private struct Main {
    static func main() {
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
