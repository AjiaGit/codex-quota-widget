import Foundation
import CoreGraphics
import Darwin

let nativeProcessGuardVersion = "CodexQuotaProcessGuard/1"

/// Read argument boundaries from the kernel. Rendered `ps` text loses those boundaries.
private func nativeProcessArguments(_ pid: pid_t) -> (executable: String, arguments: [String])? {
    var limit: Int32 = 0
    var limitSize = MemoryLayout<Int32>.size
    var limitMIB: [Int32] = [CTL_KERN, KERN_ARGMAX]
    guard sysctl(&limitMIB, 2, &limit, &limitSize, nil, 0) == 0,
          limit > 0, limit <= 16 * 1024 * 1024 else { return nil }
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var bytes = [UInt8](repeating: 0, count: Int(limit))
    var size = bytes.count
    let result = bytes.withUnsafeMutableBytes { buffer in
        sysctl(&mib, 3, buffer.baseAddress, &size, nil, 0)
    }
    guard result == 0, size > MemoryLayout<Int32>.size else { return nil }
    var argc: Int32 = 0
    withUnsafeMutableBytes(of: &argc) { destination in
        destination.copyBytes(from: bytes.prefix(MemoryLayout<Int32>.size))
    }
    guard argc > 0, argc <= 4096 else { return nil }
    var offset = MemoryLayout<Int32>.size
    func nextString() -> String? {
        guard offset < size else { return nil }
        let start = offset
        while offset < size, bytes[offset] != 0 { offset += 1 }
        guard offset < size else { return nil }
        let value = String(bytes: bytes[start..<offset], encoding: .utf8)
        offset += 1
        return value
    }
    guard let executable = nextString(), executable.hasPrefix("/") else { return nil }
    // KERN_PROCARGS2 pads the executable path before argv[0]. Environment is never read.
    while offset < size, bytes[offset] == 0 { offset += 1 }
    var arguments: [String] = []
    for _ in 0..<argc {
        guard let argument = nextString() else { return nil }
        arguments.append(argument)
    }
    return (executable, arguments)
}

func nativeProcessMatches(pid: pid_t, executable: String, script: String? = nil) -> Bool {
    guard pid > 1, executable.hasPrefix("/"),
          let process = nativeProcessArguments(pid) else { return false }
    func canonical(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }
    let expectedExecutable = canonical(executable)
    guard canonical(process.executable) == expectedExecutable else { return false }
    guard let script else { return true }
    // Start invokes exactly `node <absolute monitor.mjs>`. An ordinary argument cannot own a PID.
    return script.hasPrefix("/") && process.arguments.count == 2
        && process.arguments[1].hasPrefix("/")
        && canonical(process.arguments[0]) == expectedExecutable
        && canonical(process.arguments[1]) == canonical(script)
}

/// A non-GUI mode shared by the prebuilt launcher and the source stop guard.
func nativeProcessGuardCommand(_ arguments: [String]) -> Int32? {
    guard arguments.count > 1 else { return nil }
    if arguments[1] == "--process-guard-version" {
        print(nativeProcessGuardVersion)
        return 0
    }
    guard arguments[1] == "--owns-process" else { return nil }
    guard arguments.count == 4 || arguments.count == 5,
          let pid = pid_t(arguments[2]) else { return 1 }
    return nativeProcessMatches(pid: pid, executable: arguments[3],
                                script: arguments.count == 5 ? arguments[4] : nil) ? 0 : 1
}

#if PROCESS_GUARD_ONLY
@main
private struct NativeProcessGuardMain {
    static func main() { exit(nativeProcessGuardCommand(CommandLine.arguments) ?? 1) }
}
#endif

enum NativeLanguage: String, CaseIterable {
    case automatic = "auto"
    case english = "en"
    case simplifiedChinese = "zh-CN"

    static func saved(at directory: URL) -> NativeLanguage {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("settings.json")),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object["language"] as? String else { return .automatic }
        return NativeLanguage(rawValue: value) ?? .automatic
    }
}

struct NativeLocalizer {
    var setting: NativeLanguage
    var systemLanguage = Locale.preferredLanguages.first ?? "en"

    var resolved: NativeLanguage {
        if setting != .automatic { return setting }
        return systemLanguage.lowercased().hasPrefix("zh") ? .simplifiedChinese : .english
    }

    func text(_ key: String, value: Int? = nil) -> String {
        let chinese = resolved == .simplifiedChinese
        let pair: (String, String)
        switch key {
        case "brand": pair = ("Codex Quota", "Codex 额度悬浮窗")
        case "reading": pair = ("Reading…", "正在读取")
        case "updated": pair = ("Updated", "已更新")
        case "updated_just_now": pair = ("Updated just now", "刚刚更新")
        case "updated_minutes": pair = ("Updated {value} min ago", "{value} 分钟前更新")
        case "unavailable": pair = ("Unavailable", "暂不可用")
        case "sign_in": pair = ("Sign in", "请登录")
        case "install_cli": pair = ("Install CLI", "请安装 CLI")
        case "compact": pair = ("Compact", "极简")
        case "return_compact": pair = ("Return to Compact", "返回极简模式")
        case "refresh": pair = ("Refresh", "刷新")
        case "hide": pair = ("Hide Widget", "隐藏悬浮窗")
        case "show": pair = ("Show Widget", "显示悬浮窗")
        case "toggle": pair = ("Switch Compact / Detail", "切换极简／详细")
        case "refresh_quota": pair = ("Refresh Quota", "刷新额度")
        case "open_page": pair = ("Open Details in Browser", "在浏览器中打开详细页")
        case "quit": pair = ("Quit Codex Quota Widget", "退出监控工具")
        case "language": pair = ("Language", "语言")
        case "auto": pair = ("Follow System", "跟随系统")
        case "en": pair = ("English", "英语")
        case "zh-CN": pair = ("Simplified Chinese", "简体中文")
        case "ok": pair = ("OK", "好")
        case "remaining": pair = ("Weekly quota remaining: {value}%", "本周剩余 {value}%")
        case "quota_tooltip": pair = ("Codex weekly quota", "Codex 本周额度")
        case "new_grant": pair = ("New reset credit update · Click for details", "有新的重置卡消息，点击查看详情")
        case "new_global_reset": pair = ("New quota-reset notice or change · Click for details", "有新的额度重置预告或变更，点击查看详情")
        case "new_announcements": pair = ("New reset credit and quota-reset updates · Click for details", "有新的重置卡和额度重置消息，点击查看详情")
        case "new_source_hints": pair = ("New monitoring-site hint · Click for details", "有新的监控网站提示，点击查看详情")
        case "new_public_updates": pair = ("New reset updates · Click for details", "有新的重置动态，点击查看详情")
        case "cli_missing": pair = ("Codex CLI was not found. Install Codex CLI or the Codex desktop app, then reopen this widget.", "未找到 Codex CLI。请安装 Codex CLI 或 Codex 桌面应用，然后重新打开此工具。")
        case "signed_out": pair = ("Sign in to Codex, or run codex login in Terminal, then choose Refresh.", "请先登录 Codex，或在终端运行 codex login，然后点击刷新。")
        case "timeout": pair = ("Codex took too long to respond. Check your connection and choose Refresh.", "Codex 查询超时。请检查网络，然后点击刷新。")
        case "network": pair = ("Codex could not connect. Check your connection and choose Refresh.", "Codex 无法连接。请检查网络，然后点击刷新。")
        case "unsupported": pair = ("This account does not provide a seven-day Codex quota.", "当前账号未提供七天 Codex 额度。")
        case "service_unavailable": pair = ("The local service is unavailable. Reopen Codex Quota Widget.", "本机额度服务暂不可用，请重新打开 Codex 额度悬浮窗。")
        case "settings_failed": pair = ("The language could not be saved. Reopen the widget and try again.", "无法保存语言设置，请重新打开工具后再试。")
        case "query_failed": pair = ("Quota is unavailable. Choose Refresh to try again.", "额度暂不可用，请点击刷新重试。")
        default: pair = (key, key)
        }
        return (chinese ? pair.1 : pair.0).replacingOccurrences(of: "{value}", with: value.map(String.init) ?? "—")
    }
}

struct NativeAnnouncementAlerts {
    let ids: [String]
    let visibleEntries: [[String: String]]
    private let kinds: Set<String>
    private let hasSourceHints: Bool
    private let hasAnnouncements: Bool
    var hasUnread: Bool { !ids.isEmpty }

    init(object: [String: Any]?) {
        let entries = (object?["unread"] as? [[String: Any]] ?? []).prefix(100).filter { row in
            guard let id = row["id"] as? String, let kind = row["kind"] as? String,
                  ["banked", "regular"].contains(kind), id.hasSuffix("#" + kind),
                  let url = URL(string: String(id.dropLast(kind.count + 1))) else { return false }
            return url.scheme == "https" && url.host != nil && url.user == nil && url.password == nil
        }
        ids = entries.compactMap { $0["id"] as? String }
        visibleEntries = entries.compactMap { row in
            guard let id = row["id"] as? String, let version = row["version"] as? String, version.count <= 4096 else { return nil }
            return ["id": id, "version": version]
        }
        kinds = Set(entries.compactMap { $0["kind"] as? String })
        hasSourceHints = entries.contains { $0["sourceHint"] as? Bool == true }
        hasAnnouncements = entries.contains { $0["sourceHint"] as? Bool != true }
    }

    func tooltip(_ localizer: NativeLocalizer) -> String {
        guard hasUnread else { return "" }
        if hasSourceHints { return localizer.text(hasAnnouncements ? "new_public_updates" : "new_source_hints") }
        return localizer.text(kinds.count > 1 ? "new_announcements" : kinds.contains("banked") ? "new_grant" : "new_global_reset")
    }
}

func nativeCompactNoticeRect(in bounds: CGRect) -> CGRect {
    let diameter = max(5, min(8, min(bounds.width, bounds.height) * 0.12))
    return CGRect(x: bounds.maxX - diameter - 5, y: bounds.maxY - diameter - 5,
                  width: diameter, height: diameter)
}

/// Keep the fixed header separate from the scrolling detail content at every supported width.
struct NativeDetailHeaderLayout {
    let isStacked: Bool
    let header: CGRect
    let content: CGRect
    let brand: CGRect
    let status: CGRect
    let refresh: CGRect
    let compact: CGRect
    let hide: CGRect

    init(size: CGSize, brandWidth: CGFloat, statusWidth: CGFloat) {
        let width = size.width, height = size.height
        let inset: CGFloat = width < 520 ? 16 : 30
        let target: CGFloat = 32, gap: CGFloat = 4, rightInset: CGFloat = 16
        let toolbarX = width - rightInset - 3 * target - 2 * gap
        let textWidth = max(0, toolbarX - 12 - inset)
        isStacked = brandWidth + 18 + statusWidth > textWidth
        let headerHeight: CGFloat = isStacked ? 84 : 60
        header = CGRect(x: 0, y: max(0, height - headerHeight), width: width, height: min(height, headerHeight))
        content = CGRect(x: 0, y: 0, width: width, height: max(0, height - headerHeight))
        brand = CGRect(x: inset, y: height - 45, width: min(brandWidth, textWidth), height: 28)
        status = isStacked
            ? CGRect(x: inset, y: height - 72, width: max(0, width - 2 * inset), height: 20)
            : CGRect(x: brand.maxX + 18, y: height - 42,
                     width: max(0, toolbarX - 12 - brand.maxX - 18), height: 22)
        refresh = CGRect(x: toolbarX, y: height - 46, width: target, height: target)
        compact = refresh.offsetBy(dx: target + gap, dy: 0)
        hide = compact.offsetBy(dx: target + gap, dy: 0)
    }
}

/// Only the current, local top-level document can change the native detail size.
struct NativeDetailMeasurement {
    let height: CGFloat
    let width: CGFloat

    init?(object: Any, documentURL: URL?, isMainFrame: Bool, expectedURL: URL, viewWidth: CGFloat) {
        guard isMainFrame, let documentURL,
              documentURL.scheme == expectedURL.scheme, documentURL.host == expectedURL.host,
              documentURL.port == expectedURL.port, documentURL.path == expectedURL.path,
              documentURL.user == nil, documentURL.password == nil,
              let object = object as? [String: Any],
              let height = object["height"] as? Double, let width = object["width"] as? Double,
              height.isFinite, height > 0, width.isFinite, width > 0,
              viewWidth.isFinite, viewWidth > 0, abs(width - Double(viewWidth)) <= 2 else { return nil }
        self.height = CGFloat(min(20_000, ceil(height)))
        self.width = CGFloat(width)
    }
}

/// Resize downward from the saved top edge, moving that edge only when the screen requires it.
func nativeDetailFittedFrame(_ frame: CGRect, contentHeight: CGFloat, headerHeight: CGFloat,
                             in screen: CGRect, isCompact: Bool = false, automatic: Bool = true) -> CGRect? {
    guard contentHeight.isFinite, contentHeight > 0, headerHeight.isFinite, headerHeight >= 0,
          [frame.minX, frame.minY, frame.width, frame.height,
           screen.minX, screen.minY, screen.width, screen.height].allSatisfy({ $0.isFinite }),
          frame.width > 0, frame.height > 0, screen.width > 0, screen.height > 0 else { return nil }
    if isCompact || !automatic { return frame }
    let width = min(frame.width, screen.width)
    let height = min(max(430, ceil(contentHeight + headerHeight + 12)), screen.height)
    let x = min(max(frame.minX, screen.minX), screen.maxX - width)
    let y = min(max(frame.maxY - height, screen.minY), screen.maxY - height)
    return CGRect(x: x, y: y, width: width, height: height)
}

func nativeShouldCollapseDetail(at point: CGPoint, frame: CGRect, isCompact: Bool,
                                isVisible: Bool, transitioning: Bool) -> Bool {
    !isCompact && isVisible && !transitioning && !frame.contains(point)
}

struct NativeUsage {
    let percent: Int?
    let errorCode: String?
    let loading: Bool
    let updatedAt: Date?

    init(object: [String: Any]?, now: Date = Date()) {
        loading = object?["status"] as? String == "loading"
        if let updated = object?["updatedAt"] as? Double,
           updated.isFinite, updated <= now.timeIntervalSince1970 * 1000 + 60_000 {
            updatedAt = Date(timeIntervalSince1970: updated / 1000)
        } else { updatedAt = nil }
        let allowed = ["cli_missing", "signed_out", "timeout", "network", "unsupported", "service_unavailable", "query_failed"]
        let suppliedCode = object?["errorCode"] as? String
        errorCode = suppliedCode.flatMap { allowed.contains($0) ? $0 : "query_failed" }
            ?? (object == nil ? "service_unavailable" : nil)
        guard object?["status"] as? String == "ok",
              let updated = object?["updatedAt"] as? Double,
              let reset = object?["resetsAt"] as? Double,
              let remaining = object?["remainingPercent"] as? Int,
              updated.isFinite, reset.isFinite,
              now.timeIntervalSince1970 * 1000 - updated <= 600_000,
              updated <= now.timeIntervalSince1970 * 1000 + 60_000,
              reset > now.timeIntervalSince1970 else {
            percent = nil
            return
        }
        percent = max(0, min(100, remaining))
    }

    func status(_ localizer: NativeLocalizer, now: Date = Date()) -> String {
        if percent != nil, let updatedAt {
            let minutes = max(0, Int(now.timeIntervalSince(updatedAt) / 60))
            return localizer.text(minutes == 0 ? "updated_just_now" : "updated_minutes", value: minutes)
        }
        if loading { return localizer.text("reading") }
        if errorCode == "signed_out" { return localizer.text("sign_in") }
        if errorCode == "cli_missing" { return localizer.text("install_cli") }
        return localizer.text("unavailable")
    }

    func tooltip(_ localizer: NativeLocalizer) -> String {
        if let percent { return localizer.text("remaining", value: percent) }
        if loading { return localizer.text("reading") }
        return localizer.text(errorCode ?? "query_failed")
    }
}

func nativeStateDirectory() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexWeeklyMonitor", isDirectory: true)
}

/// The regular app keeps the service in Resources; the accessory app is in Helpers.
func nativeServiceDirectory(bundle: Bundle = .main) -> URL {
    let candidates = [
        bundle.resourceURL?.appendingPathComponent("service", isDirectory: true),
        bundle.bundleURL.deletingLastPathComponent(),
        bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/service", isDirectory: true)
    ].compactMap { $0 }
    return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("Start.command").path) }
        ?? bundle.bundleURL.deletingLastPathComponent()
}

final class NativeServiceClient {
    static let baseURL = URL(string: "http://127.0.0.1:39224/")!
    private let session: URLSession
    private let clock: () -> TimeInterval
    private var lastFetch: TimeInterval = -.infinity
    private var fetching = false
    private var refreshing = false
    private var fetchingAlerts = false
    private var pendingFetch: ((NativeUsage, NativeLanguage?) -> Void)?

    init(session: URLSession = .shared,
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.session = session
        self.clock = clock
    }

    static func languageRequest(_ language: NativeLanguage) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/settings"))
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("http://127.0.0.1:39224", forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["language": language.rawValue])
        return request
    }

    static func indicatorRequest(_ alerts: NativeAnnouncementAlerts) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/announcement-alerts/shown"))
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("http://127.0.0.1:39224", forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["ids": alerts.visibleEntries])
        return request
    }
    private var reportedIndicator = ""
    func reportIndicator(_ alerts: NativeAnnouncementAlerts) {
        guard !alerts.visibleEntries.isEmpty else { reportedIndicator = ""; return }
        let request = Self.indicatorRequest(alerts)
        let key = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        guard reportedIndicator != key else { return }
        reportedIndicator = key
        session.dataTask(with: request) { [weak self] _, response, _ in
            if (response as? HTTPURLResponse)?.statusCode != 200 {
                DispatchQueue.main.async { if self?.reportedIndicator == key { self?.reportedIndicator = "" } }
            }
        }.resume()
    }

    /// These reads only retrieve the service cache. The service owns the CLI schedule.
    func fetch(force: Bool = false, completion: @escaping (NativeUsage, NativeLanguage?) -> Void) {
        precondition(Thread.isMainThread)
        let now = clock()
        if fetching {
            if force { pendingFetch = completion }
            return
        }
        guard force || now - lastFetch >= 60 else { return }
        fetching = true
        lastFetch = now
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api/usage"))
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: request) { [weak self] data, response, _ in
            let object = (response as? HTTPURLResponse)?.statusCode == 200
                ? data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } : nil
            let usage = NativeUsage(object: object)
            var settingsRequest = URLRequest(url: Self.baseURL.appendingPathComponent("api/settings"))
            settingsRequest.timeoutInterval = 8
            settingsRequest.cachePolicy = .reloadIgnoringLocalCacheData
            self?.session.dataTask(with: settingsRequest) { data, response, _ in
                let object = (response as? HTTPURLResponse)?.statusCode == 200
                    ? data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } : nil
                let language = (object?["language"] as? String).flatMap(NativeLanguage.init(rawValue:))
                DispatchQueue.main.async {
                    self?.fetching = false
                    completion(usage, language)
                    if let pending = self?.pendingFetch {
                        self?.pendingFetch = nil
                        self?.fetch(force: true, completion: pending)
                    }
                }
            }.resume()
        }.resume()
    }

    func refresh(completion: @escaping () -> Void) {
        precondition(Thread.isMainThread)
        if refreshing { return }
        refreshing = true
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api/refresh"))
        request.httpMethod = "POST"
        request.setValue("http://127.0.0.1:39224", forHTTPHeaderField: "Origin")
        request.timeoutInterval = 30
        session.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.refreshing = false
                completion()
            }
        }.resume()
    }

    func fetchAnnouncementAlerts(completion: @escaping (NativeAnnouncementAlerts?) -> Void) {
        precondition(Thread.isMainThread)
        guard !fetchingAlerts else { return }
        fetchingAlerts = true
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api/announcement-alerts"))
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: request) { [weak self] data, response, _ in
            let object = (response as? HTTPURLResponse)?.statusCode == 200
                ? data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } : nil
            DispatchQueue.main.async {
                self?.fetchingAlerts = false
                completion(object.map { NativeAnnouncementAlerts(object: $0) })
            }
        }.resume()
    }

    func setLanguage(_ language: NativeLanguage, completion: @escaping (Bool) -> Void) {
        session.dataTask(with: Self.languageRequest(language)) { _, response, error in
            let saved = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { completion(saved) }
        }.resume()
    }
}
