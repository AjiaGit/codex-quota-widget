import Foundation

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
        case "brand": pair = ("Codex Quota", "Codex 周额度")
        case "reading": pair = ("Reading…", "正在读取")
        case "updated": pair = ("Updated", "已更新")
        case "unavailable": pair = ("Unavailable", "暂不可用")
        case "sign_in": pair = ("Sign in", "请登录")
        case "install_cli": pair = ("Install CLI", "请安装 CLI")
        case "compact": pair = ("Compact", "极简")
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
        case "cli_missing": pair = ("Codex CLI was not found. Install Codex CLI or the Codex desktop app, then reopen this widget.", "未找到 Codex CLI。请安装 Codex CLI 或 Codex 桌面应用，然后重新打开此工具。")
        case "signed_out": pair = ("Sign in to Codex, or run codex login in Terminal, then choose Refresh.", "请先登录 Codex，或在终端运行 codex login，然后点击刷新。")
        case "timeout": pair = ("Codex took too long to respond. Check your connection and choose Refresh.", "Codex 查询超时。请检查网络，然后点击刷新。")
        case "network": pair = ("Codex could not connect. Check your connection and choose Refresh.", "Codex 无法连接。请检查网络，然后点击刷新。")
        case "unsupported": pair = ("This account does not provide a seven-day Codex quota.", "当前账号未提供七天 Codex 额度。")
        case "service_unavailable": pair = ("The local service is unavailable. Reopen Codex Quota Widget.", "本机额度服务暂不可用，请重新打开 Codex 周额度工具。")
        case "settings_failed": pair = ("The language could not be saved. Reopen the widget and try again.", "无法保存语言设置，请重新打开工具后再试。")
        case "query_failed": pair = ("Quota is unavailable. Choose Refresh to try again.", "额度暂不可用，请点击刷新重试。")
        default: pair = (key, key)
        }
        return (chinese ? pair.1 : pair.0).replacingOccurrences(of: "{value}", with: value.map(String.init) ?? "—")
    }
}

struct NativeUsage {
    let percent: Int?
    let errorCode: String?
    let loading: Bool

    init(object: [String: Any]?, now: Date = Date()) {
        loading = object?["status"] as? String == "loading"
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

    func status(_ localizer: NativeLocalizer) -> String {
        if percent != nil { return localizer.text("updated") }
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

    func setLanguage(_ language: NativeLanguage, completion: @escaping (Bool) -> Void) {
        session.dataTask(with: Self.languageRequest(language)) { _, response, error in
            let saved = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { completion(saved) }
        }.resume()
    }
}
