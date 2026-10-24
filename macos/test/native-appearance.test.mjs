import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('../..', import.meta.url));

test('widget content and compact drawing stay dark under both app appearances without changing native menus', { skip: process.platform !== 'darwin' }, () => {
  const temp = mkdtempSync(join(tmpdir(), 'codex-native-appearance-'));
  try {
    const source = readFileSync(join(root, 'macos/MacWidget.swift'), 'utf8');
    const mainStart = source.indexOf('@main\nprivate struct Main');
    const rootStart = source.indexOf('        root = NSView(frame:');
    const rootEnd = source.indexOf('        panel.contentView = root', rootStart);
    assert.ok(mainStart > 0 && rootStart > 0 && rootEnd > rootStart, 'production widget setup is available');
    const harness = join(temp, 'appearance.swift');
    writeFileSync(harness, source.slice(0, mainStart) + `
@main struct AppearanceTest {
  static func main() throws {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    var results: [[String: Any]] = []
    for name in [NSAppearance.Name.aqua, .darkAqua, .aqua] {
      app.appearance = NSAppearance(named: name)
      let frame = NSRect(x: 0, y: 0, width: 78, height: 86)
      let panel = NSPanel(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
      var root: NSView!
${source.slice(rootStart, rootEnd)}
      panel.contentView = root
      let compact = CompactView(frame: root.bounds)
      compact.percent = 74
      root.addSubview(compact)
      let image = compact.bitmapImageRepForCachingDisplay(in: compact.bounds)!
      compact.cacheDisplay(in: compact.bounds, to: image)
      // Respect the display profile before reading raw pixels (e.g. Display P3).
      let sampled = image.converting(to: .sRGB, renderingIntent: .default)!
      var pixel = [Int](repeating: 0, count: sampled.samplesPerPixel)
      sampled.getPixel(&pixel, atX: sampled.pixelsWide / 2, y: 2)
      if CommandLine.arguments.count > 1 {
        let path = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(name.rawValue + ".png")
        try image.representation(using: .png, properties: [:])!.write(to: path)
      }
      let menuHost = NSView()
      results.append([
        "requested": name.rawValue,
        "contentDark": root.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua,
        "nativeAppearance": menuHost.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])!.rawValue,
        "applicationAppearance": app.appearance!.name.rawValue,
        "background": Array(pixel.prefix(3))
      ])
      panel.close()
    }
    print(String(data: try JSONSerialization.data(withJSONObject: results), encoding: .utf8)!)
  }
}
`);
    const sdk = existsSync('/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk')
      ? '/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk'
      : spawnSync('/usr/bin/xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).stdout.trim();
    const executable = join(temp, 'appearance');
    const compiled = spawnSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-sdk', sdk, '-module-cache-path', join(temp, 'modules'),
      '-framework', 'AppKit', '-framework', 'WebKit', join(root, 'macos/NativeSupport.swift'), harness, '-o', executable], { encoding: 'utf8' });
    assert.equal(compiled.status, 0, compiled.stderr);
    const evidence = process.env.CODEX_APPEARANCE_EVIDENCE_DIR;
    const result = spawnSync(executable, evidence ? [evidence] : [], { encoding: 'utf8', timeout: 20000 });
    assert.equal(result.status, 0, result.stderr || result.error?.message);
    if (evidence) writeFileSync(join(evidence, 'native-appearance.json'), result.stdout);
    const rows = JSON.parse(result.stdout);
    assert.equal(rows.length, 3);
    for (const row of rows) {
      assert.equal(row.contentDark, true, `content remains dark when the app uses ${row.requested}`);
      assert.deepEqual(row.background, [32, 37, 45], 'compact background uses the accepted deep gray');
      assert.equal(row.applicationAppearance, row.requested, 'content policy never overrides the application appearance');
      assert.equal(row.nativeAppearance, row.requested, 'views outside widget content keep the native appearance');
    }
  } finally { rmSync(temp, { recursive: true, force: true }); }
});
