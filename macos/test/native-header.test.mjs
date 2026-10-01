import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
const native = join(root, 'macos', 'NativeSupport.swift');
const moduleCache = process.platform === 'darwin' ? mkdtempSync(join(tmpdir(), 'codex-native-header-modules-')) : null;
after(() => { if (moduleCache) rmSync(moduleCache, { recursive: true, force: true }); });

function runNative(source) {
  const temp = mkdtempSync(join(tmpdir(), 'codex-native-header-'));
  try {
    const harness = join(temp, 'main.swift');
    writeFileSync(harness, source);
    const executable = join(temp, 'test');
    const sdk = existsSync('/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk')
      ? '/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk'
      : spawnSync('/usr/bin/xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).stdout.trim();
    const compiled = spawnSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-target', `${process.arch === 'arm64' ? 'arm64' : 'x86_64'}-apple-macosx13.0`, '-sdk', sdk,
      '-module-cache-path', moduleCache, native, harness, '-o', executable], {
      encoding: 'utf8', env: { ...process.env, CLANG_MODULE_CACHE_PATH: moduleCache, SWIFT_MODULE_CACHE_PATH: moduleCache },
    });
    assert.equal(compiled.status, 0, compiled.stderr);
    const result = spawnSync(executable, { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(result.stdout);
  } finally { rmSync(temp, { recursive: true, force: true }); }
}

test('compact notices validate kinds, localize their tooltip and stay inside the smallest widget', { skip: process.platform !== 'darwin' }, () => {
  const output = runNative(`import Foundation
import CoreGraphics
@main struct NoticeTest {
  static func main() throws {
    let grant = NativeAnnouncementAlerts(object: ["unread": [["id": "https://example.org/grant#banked", "kind": "banked"]]])
    let reset = NativeAnnouncementAlerts(object: ["unread": [["id": "https://example.org/reset#regular", "kind": "regular"]]])
    let invalid = NativeAnnouncementAlerts(object: ["unread": [["id": "javascript:alert(1)#banked", "kind": "banked"], ["id": "https://example.org/hint#hinted", "kind": "hinted"]]])
    let both = NativeAnnouncementAlerts(object: ["unread": [["id": "https://example.org/grant#banked", "kind": "banked"], ["id": "https://example.org/reset#regular", "kind": "regular"]]])
    let frames = [36.0, 48.0, 100.0].map { side -> [Double] in
      let rect = nativeCompactNoticeRect(in: CGRect(x: 0, y: 0, width: side, height: side))
      return [side, Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height)]
    }
    let result: [String: Any] = ["grant": grant.tooltip(NativeLocalizer(setting: .simplifiedChinese)),
      "reset": reset.tooltip(NativeLocalizer(setting: .english)), "both": both.tooltip(NativeLocalizer(setting: .english)),
      "invalid": invalid.hasUnread, "frames": frames]
    print(String(data: try JSONSerialization.data(withJSONObject: result), encoding: .utf8)!)
  }
}`);
  assert.match(output.grant, /新的重置次数赠送公告/);
  assert.match(output.reset, /global reset/);
  assert.match(output.both, /banked reset grant.*global reset/);
  assert.equal(output.invalid, false);
  for (const [side,x,y,width,height] of output.frames) {
    assert.ok(width >= 5 && width <= 8 && width === height);
    assert.ok(x >= 5 && y >= 5 && x + width <= side - 5 && y + height <= side - 5);
  }
});

test('native header reports the successful cache age in the selected language', { skip: process.platform !== 'darwin' }, () => {
  const output = runNative(`import Foundation
@main struct HeaderTest {
  static func main() throws {
    let now = Date()
    let usage = NativeUsage(object: ["status": "ok", "updatedAt": now.addingTimeInterval(-125).timeIntervalSince1970 * 1000,
      "resetsAt": now.addingTimeInterval(3600).timeIntervalSince1970, "remainingPercent": 42], now: now)
    let en = NativeLocalizer(setting: .english), zh = NativeLocalizer(setting: .simplifiedChinese)
    let recent = NativeUsage(object: ["status": "ok", "updatedAt": now.addingTimeInterval(-59).timeIntervalSince1970 * 1000,
      "resetsAt": now.addingTimeInterval(3600).timeIntervalSince1970, "remainingPercent": 42], now: now)
    let future = NativeUsage(object: ["status": "ok", "updatedAt": now.addingTimeInterval(30).timeIntervalSince1970 * 1000,
      "resetsAt": now.addingTimeInterval(3600).timeIntervalSince1970, "remainingPercent": 42], now: now)
    let signedOut = NativeUsage(object: ["status": "unavailable", "errorCode": "signed_out", "updatedAt": now.timeIntervalSince1970 * 1000], now: now)
    let missingCLI = NativeUsage(object: ["status": "unavailable", "errorCode": "cli_missing"], now: now)
    let output = ["en": usage.status(en, now: now), "zh": usage.status(zh, now: now),
      "later": usage.status(en, now: now.addingTimeInterval(60)),
      "recent": recent.status(zh, now: now), "future": future.status(en, now: now),
      "signedOut": signedOut.status(zh, now: now.addingTimeInterval(30)),
      "missingCLI": missingCLI.status(en, now: now.addingTimeInterval(30)),
      "unavailable": NativeUsage(object: nil, now: now).status(en, now: now)]
    print(String(data: try JSONSerialization.data(withJSONObject: output), encoding: .utf8)!)
  }
}`);
  assert.equal(output.en, 'Updated 2 min ago');
  assert.equal(output.zh, '2 分钟前更新');
  assert.equal(output.later, 'Updated 3 min ago', 'the same cached usage ages locally');
  assert.equal(output.recent, '刚刚更新');
  assert.equal(output.future, 'Updated just now', 'small clock differences never show a negative age');
  assert.equal(output.signedOut, '请登录', 'local age updates preserve the useful error status');
  assert.equal(output.missingCLI, 'Install CLI');
  assert.equal(output.unavailable, 'Unavailable');
});

test('native detail keeps time visible without overlapping toolbar or scrolling content at narrow widths', { skip: process.platform !== 'darwin' }, () => {
  const output = runNative(`import Foundation
import CoreGraphics
@main struct HeaderTest {
  static func main() throws {
    func rect(_ value: CGRect) -> [Double] {
      [Double(value.minX), Double(value.minY), Double(value.width), Double(value.height)]
    }
    let output = [330.0, 440.0, 606.0].map { width -> [String: Any] in
      let layout = NativeDetailHeaderLayout(size: CGSize(width: width, height: 585), brandWidth: 160, statusWidth: 145)
      return ["width": width, "stacked": layout.isStacked,
        "brand": rect(layout.brand), "status": rect(layout.status),
        "toolbar": [rect(layout.refresh), rect(layout.compact), rect(layout.hide)],
        "header": rect(layout.header), "content": rect(layout.content)]
    }
    print(String(data: try JSONSerialization.data(withJSONObject: output), encoding: .utf8)!)
  }
}`);
  const intersects = (a, b) => a[0] < b[0] + b[2] && a[0] + a[2] > b[0]
    && a[1] < b[1] + b[3] && a[1] + a[3] > b[1];
  for (const layout of output) {
    assert.ok(layout.status[2] >= 145 && layout.status[3] >= 20, 'status remains fully visible');
    assert.ok(!intersects(layout.brand, layout.status), 'brand does not cover the timestamp');
    assert.ok(layout.content[1] + layout.content[3] <= layout.header[1], 'content starts below the complete header');
    let previousRight = -1;
    for (const button of layout.toolbar) {
      assert.ok(button[0] > previousRight, 'refresh, compact, hide retain their left-to-right order');
      assert.deepEqual(button.slice(2), [32, 32], 'each icon has an equal usable hit target');
      assert.ok(!intersects(layout.brand, button));
      assert.ok(!intersects(layout.status, button));
      assert.ok(button[0] + button[2] <= layout.width - 12, 'toolbar stays inside the resize edge');
      previousRight = button[0] + button[2];
    }
  }
  assert.equal(output[0].stacked, true);
  assert.ok(output[0].status[1] + output[0].status[3] <= output[0].brand[1]);
  assert.equal(output[2].stacked, false);
  assert.ok(Math.abs(output[2].brand[1] - output[2].status[1]) <= 5, 'default width uses one header line');
});

test('native automatic detail height fits content, preserves the top and compact frame, and caps at the screen', { skip: process.platform !== 'darwin' }, () => {
  const output = runNative(`import Foundation
import CoreGraphics
@main struct FitTest {
  static func main() throws {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let current = CGRect(x: 800, y: 200, width: 606, height: 585)
    func rect(_ value: CGRect?) -> Any {
      guard let value else { return NSNull() }
      return [Double(value.minX), Double(value.minY), Double(value.width), Double(value.height)]
    }
    let local = URL(string: "http://127.0.0.1:39224/")!
    func measurement(_ height: Double, _ width: Double = 606,
                     url: String = "http://127.0.0.1:39224/?embedded=1", main: Bool = true) -> NativeDetailMeasurement? {
      NativeDetailMeasurement(object: ["height": height, "width": width], documentURL: URL(string: url),
        isMainFrame: main, expectedURL: local, viewWidth: 606)
    }
    let output: [String: Any] = [
      "fit": rect(nativeDetailFittedFrame(current, contentHeight: 612, headerHeight: 60, in: screen)),
      "narrow": rect(nativeDetailFittedFrame(CGRect(x: 800, y: 200, width: 330, height: 585), contentHeight: 612, headerHeight: 84, in: screen)),
      "screenCap": rect(nativeDetailFittedFrame(current, contentHeight: 1600, headerHeight: 60, in: screen)),
      "small": rect(nativeDetailFittedFrame(current, contentHeight: 1, headerHeight: 60, in: screen)),
      "smallScreen": rect(nativeDetailFittedFrame(current, contentHeight: 1, headerHeight: 60, in: CGRect(x: 0, y: 0, width: 1000, height: 350))),
      "compact": rect(nativeDetailFittedFrame(CGRect(x: 100, y: 200, width: 78, height: 86), contentHeight: 612, headerHeight: 60, in: screen, isCompact: true)),
      "manual": rect(nativeDetailFittedFrame(current, contentHeight: 612, headerHeight: 60, in: screen, automatic: false)),
      "infinite": rect(nativeDetailFittedFrame(current, contentHeight: .infinity, headerHeight: 60, in: screen)),
      "nan": rect(nativeDetailFittedFrame(current, contentHeight: .nan, headerHeight: 60, in: screen)),
      "valid": measurement(612) != nil, "rounded": measurement(612.4)?.height as Any,
      "limited": measurement(100_000)?.height as Any, "invalid": measurement(.infinity) == nil,
      "staleWidth": measurement(612, 330) == nil, "widthSlack": measurement(612, 605.5) != nil,
      "foreign": measurement(612, url: "https://127.0.0.1:39224/") == nil,
      "port": measurement(612, url: "http://127.0.0.1:9999/") == nil,
      "otherPath": measurement(612, url: "http://127.0.0.1:39224/api/usage") == nil,
      "iframe": measurement(612, main: false) == nil]
    print(String(data: try JSONSerialization.data(withJSONObject: output), encoding: .utf8)!)
  }
}`);
  assert.deepEqual(output.fit, [800, 101, 606, 684], '612px content plus60px header plus12px inset fits with original top785');
  assert.deepEqual(output.narrow, [800, 77, 330, 708], 'stacked84px header is included');
  assert.deepEqual(output.screenCap, [800, 0, 606, 900], 'long content stays in the visible screen');
  assert.deepEqual(output.small, [800, 355, 606, 430], 'small content retains the detail minimum');
  assert.deepEqual(output.smallScreen, [394, 0, 606, 350], 'screen bounds take priority over the usual minimum');
  assert.deepEqual(output.compact, [100, 200, 78, 86], 'hidden detail reports never enlarge Compact');
  assert.deepEqual(output.manual, [800, 200, 606, 585], 'automatic sizing respects a manual size');
  assert.equal(output.infinite, null); assert.equal(output.nan, null);
  assert.equal(output.valid, true); assert.equal(output.rounded, 613); assert.equal(output.limited, 20_000);
  for (const key of ['invalid', 'staleWidth', 'widthSlack', 'foreign', 'port', 'otherPath', 'iframe']) assert.equal(output[key], true, key);
});
