import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
const native = join(root, 'macos', 'NativeSupport.swift');

test('native captions and actionable errors use the saved language and system fallback', { skip: process.platform !== 'darwin' }, () => {
  assert.ok(existsSync(native), 'native language handling is available to both applications');
  const temp = mkdtempSync(join(tmpdir(), 'codex-native-test-'));
  try {
    const harness = join(temp, 'main.swift');
    writeFileSync(harness, `import Foundation
final class LocalService: URLProtocol {
  static var counts: [String: Int] = [:]
  static let lock = NSLock()
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let path = request.url!.path
    Self.lock.lock(); Self.counts[path, default: 0] += 1; Self.lock.unlock()
    let now = Date().timeIntervalSince1970
    let body: [String: Any] = path == "/api/settings" ? ["language": "zh-CN"]
      : ["status": "ok", "updatedAt": now * 1000, "resetsAt": now + 60, "remainingPercent": 42]
    client!.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
      httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
    client!.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: body))
    client!.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
@main struct NativeTest {
  static func main() throws {
    let en = NativeLocalizer(setting: .english, systemLanguage: "zh-CN")
    let zh = NativeLocalizer(setting: .simplifiedChinese, systemLanguage: "en-US")
    let automatic = NativeLocalizer(setting: .automatic, systemLanguage: "zh-Hans-CN")
    let fallback = NativeLocalizer(setting: .automatic, systemLanguage: "fr-FR")
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let valid = NativeUsage(object: ["status": "ok", "updatedAt": 1_999_999_999_000.0,
       "resetsAt": 2_000_000_060.0, "remainingPercent": 120], now: now)
    let expired = NativeUsage(object: ["status": "ok", "updatedAt": 1_999_999_999_000.0,
       "resetsAt": 1_999_999_999.0, "remainingPercent": 24], now: now)
    let signedOut = NativeUsage(object: ["status": "unavailable", "errorCode": "signed_out",
       "message": "private account error"], now: now)
    let missing = NativeUsage(object: ["status": "unavailable", "errorCode": "cli_missing"], now: now)
    let unknown = NativeUsage(object: ["status": "unavailable", "errorCode": "internal_account_failure"], now: now)
    let stale = NativeUsage(object: ["status": "ok", "updatedAt": 1_999_999_300_000.0,
       "resetsAt": 2_000_000_060.0, "remainingPercent": 24], now: now)
    let directory = URL(fileURLWithPath: CommandLine.arguments[1])
    let settingsFile = directory.appendingPathComponent("settings.json")
    try Data(#"{"language":"zh-CN"}"#.utf8).write(to: settingsFile)
    let saved = NativeLanguage.saved(at: directory)
    try Data("broken JSON".utf8).write(to: settingsFile)
    let malformed = NativeLanguage.saved(at: directory)
    let request = NativeServiceClient.languageRequest(.simplifiedChinese)
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [LocalService.self]
    var uptime: TimeInterval = 0
    let service = NativeServiceClient(session: URLSession(configuration: config), clock: { uptime })
    var reads = 0, refreshes = 0
    func waitFor(_ check: () -> Bool) {
      let deadline = Date().addingTimeInterval(3)
      while !check() && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    }
    service.fetch { _, _ in reads += 1 }; waitFor { reads == 1 }
    uptime = 30; service.fetch { _, _ in reads += 1 }
    RunLoop.current.run(until: Date().addingTimeInterval(0.03))
    uptime = 59; service.fetch { _, _ in reads += 1 }
    RunLoop.current.run(until: Date().addingTimeInterval(0.03))
    uptime = 60; service.fetch { _, _ in reads += 1 }; waitFor { reads == 2 }
    service.refresh { refreshes += 1 }
    service.refresh { refreshes += 1 }
    waitFor { refreshes == 1 }
    service.fetch(force: true) { _, _ in reads += 1 }; waitFor { reads == 3 }
    let output: [String: Any] = [
       "brand": en.text("brand"), "auto": automatic.text("refresh"), "fallback": fallback.text("refresh"),
       "zhBrand": zh.text("brand"), "percent": valid.percent as Any,
       "expired": expired.percent == nil, "stale": stale.percent == nil,
       "saved": saved.rawValue, "malformed": malformed.rawValue,
       "usageReads": LocalService.counts["/api/usage"] as Any,
       "settingsReads": LocalService.counts["/api/settings"] as Any,
       "refreshRequests": LocalService.counts["/api/refresh"] as Any,
       "refreshCompletions": refreshes, "readCompletions": reads,
       "signedOut": signedOut.tooltip(en),
       "missing": missing.tooltip(zh), "unknown": unknown.tooltip(en),
       "requestMethod": request.httpMethod as Any,
       "requestOrigin": request.value(forHTTPHeaderField: "Origin") as Any,
       "requestType": request.value(forHTTPHeaderField: "Content-Type") as Any,
       "requestBody": String(data: request.httpBody!, encoding: .utf8)!]
    print(String(data: try JSONSerialization.data(withJSONObject: output), encoding: .utf8)!)
  }
}
`);
    const executable = join(temp, 'test');
    const sdk = existsSync('/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk')
      ? '/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk'
      : spawnSync('/usr/bin/xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).stdout.trim();
    const compiled = spawnSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-target', `${process.arch === 'arm64' ? 'arm64' : 'x86_64'}-apple-macosx13.0`, '-sdk', sdk, '-module-cache-path', join(temp, 'module-cache'), native, harness, '-o', executable], { encoding: 'utf8', env: { ...process.env, CLANG_MODULE_CACHE_PATH: join(temp, 'module-cache'), SWIFT_MODULE_CACHE_PATH: join(temp, 'module-cache') } });
    assert.equal(compiled.status, 0, compiled.stderr);
    const result = spawnSync(executable, [temp], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    const output = JSON.parse(result.stdout);
    assert.equal(output.brand, 'Codex Quota');
    assert.equal(output.zhBrand, 'Codex 周额度');
    assert.equal(output.auto, '刷新');
    assert.equal(output.fallback, 'Refresh');
    assert.equal(output.percent, 100);
    assert.equal(output.expired, true);
    assert.equal(output.stale, true);
    assert.equal(output.saved, 'zh-CN');
    assert.equal(output.malformed, 'auto');
    assert.equal(output.usageReads, 3, 'no cache polls at 30 or 59 seconds; next poll at 60 plus forced read');
    assert.equal(output.settingsReads, 3);
    assert.equal(output.refreshRequests, 1, 'overlapping manual actions share one refresh request');
    assert.equal(output.refreshCompletions, 1);
    assert.equal(output.readCompletions, 3);
    assert.match(output.signedOut, /codex login/);
    assert.doesNotMatch(output.signedOut, /private account/);
    assert.match(output.missing, /Codex CLI/);
    assert.match(output.missing, /安装/);
    assert.match(output.unknown, /Refresh/);
    assert.equal(output.requestMethod, 'POST');
    assert.equal(output.requestOrigin, 'http://127.0.0.1:39224');
    assert.equal(output.requestType, 'application/json');
    assert.deepEqual(JSON.parse(output.requestBody), { language: 'zh-CN' });
  } finally { rmSync(temp, { recursive: true, force: true }); }
});

test('Stop verifies the executed script, rejecting prefix impostors and target paths carried as ordinary arguments', { skip: process.platform !== 'darwin' }, async context => {
  const inspection = spawnSync('/bin/ps', ['-p', String(process.pid), '-o', 'command='], { encoding: 'utf8' });
  if (inspection.status !== 0) { context.skip('Process inspection is denied in this sandbox'); return; }
  const temp = realpathSync(mkdtempSync(join(tmpdir(), 'codex-native owned-stop-')));
  const children = [];
  try {
    const state = join(temp, 'Library', 'Application Support', 'CodexWeeklyMonitor');
    assert.equal(spawnSync('/bin/mkdir', ['-p', state]).status, 0);
    const stopper = join(temp, 'Stop.command');
    writeFileSync(stopper, readFileSync(join(root, 'macos', 'Stop.command')));
    writeFileSync(join(temp, 'NativeSupport.swift'), readFileSync(native));
    assert.equal(spawnSync('/bin/mkdir', ['-p', join(temp, 'runtime')]).status, 0);
    symlinkSync(process.execPath, join(temp, 'runtime', 'node'));
    const monitor = join(temp, 'monitor.mjs');
    const cases = [
      { script: join(temp, 'monitor.mjs-other'), args: [], owned: false },
      { script: join(temp, 'foreign.mjs'), args: [monitor], owned: false },
      { script: monitor, args: ['ordinary-extra-argument'], owned: false },
      { script: join(temp, 'foreign.mjs'), args: [join(temp, 'Codex 周额度.app', 'Contents', 'MacOS', 'CodexQuota')], owned: false, pidFile: 'widget.pid' },
      { script: monitor, args: [], owned: true },
    ];
    for (const scenario of cases) {
      const script = scenario.script;
      writeFileSync(script, 'setInterval(() => {}, 1000); console.log("ready");');
      const child = spawn(process.execPath, [script, ...scenario.args], { stdio: ['ignore', 'pipe', 'pipe'] });
      children.push(child);
      await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error('test process did not start')), 3000);
        child.stdout.once('data', () => { clearTimeout(timeout); resolve(); });
        child.once('error', error => { clearTimeout(timeout); reject(error); });
        child.once('exit', () => { clearTimeout(timeout); reject(new Error('test process exited before readiness')); });
      });
      const file = join(state, scenario.pidFile ?? 'monitor.pid');
      writeFileSync(file, String(child.pid));
      const stopped = spawnSync('/bin/bash', [stopper], { env: { ...process.env, HOME: temp }, encoding: 'utf8' });
      assert.equal(stopped.status, 0, stopped.stderr);
      await new Promise(resolve => setTimeout(resolve, 100));
      if (!scenario.owned) {
        assert.equal(child.exitCode, null);
        assert.equal(child.signalCode, null);
        assert.equal(existsSync(file), true);
      } else {
        assert.equal(child.signalCode, 'SIGTERM');
        assert.equal(existsSync(file), false);
        writeFileSync(file, String(child.pid));
        const stale = spawnSync('/bin/bash', [stopper], { env: { ...process.env, HOME: temp }, encoding: 'utf8' });
        assert.equal(stale.status, 0, stale.stderr);
        assert.equal(readFileSync(file, 'utf8'), String(child.pid), 'a stale record is preserved');
      }
    }
  } finally {
    for (const child of children) child.kill();
    rmSync(temp, { recursive: true, force: true });
  }
});

test('Stop preserves a PID file and process owned by a different installation', { skip: process.platform !== 'darwin' }, () => {
  const temp = mkdtempSync(join(tmpdir(), 'codex-native-stop-'));
  try {
    const state = join(temp, 'Library', 'Application Support', 'CodexWeeklyMonitor');
    const mkdir = spawnSync('/bin/mkdir', ['-p', state]);
    assert.equal(mkdir.status, 0);
    const pidFile = join(state, 'widget.pid');
    writeFileSync(pidFile, `${process.pid}\n`);
    const stopper = join(temp, 'Stop.command');
    writeFileSync(stopper, readFileSync(join(root, 'macos', 'Stop.command')));
    writeFileSync(join(temp, 'NativeSupport.swift'), readFileSync(native));
    const result = spawnSync('/bin/bash', [stopper], { env: { ...process.env, HOME: temp }, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    assert.ok(existsSync(pidFile), 'a different installation retains its process record');
    assert.equal(readFileSync(pidFile, 'utf8'), `${process.pid}\n`);
  } finally { rmSync(temp, { recursive: true, force: true }); }
});

test('macOS build rejects missing bundled Node with an actionable error before producing an app', { skip: process.platform !== 'darwin' }, () => {
  const temp = mkdtempSync(join(tmpdir(), 'codex-native-build-'));
  try {
    const result = spawnSync('/bin/bash', [join(root, 'scripts', 'build-macos.sh')], { env: { ...process.env, NODE_ROOT: join(temp, 'missing-node'), OUTPUT_DIR: join(temp, 'out'), ARCH: process.arch === 'arm64' ? 'arm64' : 'x86_64' }, encoding: 'utf8' });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /NODE_ROOT.*bin\/node.*LICENSE/);
    assert.equal(existsSync(join(temp, 'out', 'Codex Quota Widget.app')), false);
  } finally { rmSync(temp, { recursive: true, force: true }); }
});

test('macOS build reports a missing selected lipo tool without blaming the Node architecture', { skip: process.platform !== 'darwin' }, () => {
  const temp = mkdtempSync(join(tmpdir(), 'codex-native-build-tool-'));
  try {
    assert.equal(spawnSync('/bin/mkdir', ['-p', join(temp, 'node', 'bin')]).status, 0);
    symlinkSync(process.execPath, join(temp, 'node', 'bin', 'node'));
    writeFileSync(join(temp, 'node', 'LICENSE'), 'non-shipping fixture');
    const result = spawnSync('/bin/bash', [join(root, 'scripts', 'build-macos.sh')], {
      env: { ...process.env, NODE_ROOT: join(temp, 'node'), OUTPUT_DIR: join(temp, 'out'),
        ARCH: process.arch === 'arm64' ? 'arm64' : 'x86_64', DEVELOPER_DIR: join(temp, 'missing-xcode') }, encoding: 'utf8' });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /lipo was not found/);
    assert.doesNotMatch(result.stderr, /does not contain the requested architecture/);
    assert.equal(existsSync(join(temp, 'out', 'Codex Quota Widget.app')), false);
  } finally { rmSync(temp, { recursive: true, force: true }); }
});
