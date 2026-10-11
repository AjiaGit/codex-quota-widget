import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));

test('an inactive compact panel accepts its first click and opens details once', { skip: process.platform !== 'darwin' }, () => {
  const temp = mkdtempSync(join(tmpdir(), 'codex-compact-first-click-'));
  try {
    // Keep the real private view and handlers in one compilation unit; replace only the app entry point.
    const widget = readFileSync(join(root, 'macos/MacWidget.swift'), 'utf8');
    const main = widget.lastIndexOf('@main\nprivate struct Main');
    assert.ok(main > 0, 'the widget application has a replaceable test entry point');
    const harness = join(temp, 'CompactClick.swift');
    writeFileSync(harness, widget.slice(0, main) + `
@main private struct CompactClickTest {
  static func main() throws {
    _ = NSApplication.shared
    let panel = WidgetPanel(contentRect: NSRect(x: 0, y: 0, width: 78, height: 86),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let view = CompactView(frame: NSRect(x: 0, y: 0, width: 78, height: 86))
    panel.contentView = view
    var opened = 0
    view.onClick = { opened += 1 }
    let down = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 39, y: 43),
      modifierFlags: [], timestamp: 1, windowNumber: panel.windowNumber, context: nil,
      eventNumber: 1, clickCount: 1, pressure: 1)!
    let up = NSEvent.mouseEvent(with: .leftMouseUp, location: NSPoint(x: 39, y: 43),
      modifierFlags: [], timestamp: 1.1, windowNumber: panel.windowNumber, context: nil,
      eventNumber: 2, clickCount: 1, pressure: 0)!
    let accepts = view.acceptsFirstMouse(for: down)
    // AppKit asks this before delivering mouseDown to a view in an inactive window.
    if accepts { view.mouseDown(with: down); view.mouseUp(with: up) }
    let result: [String: Any] = ["inactive": !panel.isKeyWindow,
      "acceptsFirstMouse": accepts, "opens": opened]
    print(String(data: try JSONSerialization.data(withJSONObject: result), encoding: .utf8)!)
  }
}
`);
    const sdk = spawnSync('/usr/bin/xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).stdout.trim();
    const executable = join(temp, 'test');
    const cache = join(temp, 'modules');
    const compiled = spawnSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-target',
      `${process.arch === 'arm64' ? 'arm64' : 'x86_64'}-apple-macosx13.0`, '-sdk', sdk,
      '-module-cache-path', cache, join(root, 'macos/NativeSupport.swift'), harness, '-o', executable],
      { encoding: 'utf8', env: { ...process.env, CLANG_MODULE_CACHE_PATH: cache, SWIFT_MODULE_CACHE_PATH: cache } });
    assert.equal(compiled.status, 0, compiled.stderr);
    const result = spawnSync(executable, { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), { inactive: true, acceptsFirstMouse: true, opens: 1 });
  } finally { rmSync(temp, { recursive: true, force: true }); }
});
