import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const checker = fileURLToPath(new URL('../check-shared.mjs', import.meta.url));

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'quota-shared-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  for (const platform of ['macos', 'windows']) {
    for (const [name, contents] of [
      ['monitor.mjs', 'export const value = 1;\n'],
      ['public/app.mjs', 'export const title = "Quota";\n'],
      ['public/assets/icon.svg', '<svg/>\n'],
      ['test/quota.test.mjs', '// shared test\n'],
    ]) write(root, platform, name, contents);
  }
  return root;
}

function write(root, platform, name, contents) {
  const path = join(root, platform, name);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, contents);
}

function check(root, cwd = root) {
  const result = spawnSync(process.execPath, [checker, root], { cwd, encoding: 'utf8' });
  assert.ifError(result.error);
  return { status: result.status, output: result.stdout + result.stderr };
}

test('identical service, nested browser assets, and shared tests pass without rewriting files', t => {
  const root = fixture(t);
  const before = readFileSync(join(root, 'windows', 'public/app.mjs'));
  const result = check(root, tmpdir());
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, /4 shared files/);
  assert.deepEqual(readFileSync(join(root, 'windows', 'public/app.mjs')), before);
});

test('changed service, browser assets, and shared tests fail with the affected path', t => {
  for (const name of ['monitor.mjs', 'public/assets/icon.svg', 'test/quota.test.mjs']) {
    const root = fixture(t);
    write(root, 'windows', name, 'out of sync\n');
    const result = check(root);
    assert.equal(result.status, 1, result.output);
    assert.ok(result.output.includes(name), result.output);
    assert.match(result.output, /differs/);
  }
});

test('new shared files on either platform cannot silently escape the check', t => {
  for (const platform of ['macos', 'windows']) {
    for (const name of ['new-service.mjs', 'public/nested/new.json', 'test/new.test.mjs']) {
      const root = fixture(t);
      write(root, platform, name, '{}\n');
      const result = check(root);
      assert.equal(result.status, 1, result.output);
      assert.ok(result.output.includes(name), result.output);
      assert.match(result.output, /missing/);
    }
  }
});

test('deleted counterparts fail even when all remaining files still match', t => {
  for (const platform of ['macos', 'windows']) {
    const root = fixture(t);
    rmSync(join(root, platform, 'monitor.mjs'));
    const result = check(root);
    assert.equal(result.status, 1, result.output);
    assert.ok(result.output.includes(`${platform}/monitor.mjs`), result.output);
    assert.match(result.output, /missing/);
  }
});

test('platform-native implementations and native test files may differ independently', t => {
  const root = fixture(t);
  write(root, 'macos', 'MacWidget.swift', '// macOS window\n');
  write(root, 'windows', 'Widget.ps1', '# Windows window\r\n');
  write(root, 'macos', 'test/native.test.mjs', '// macOS only\n');
  write(root, 'windows', 'test/native-layout.tests.ps1', '# Windows only\r\n');
  const result = check(root);
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, /4 shared files/);
});

test('known Finder and Explorer metadata do not create false shared-file mismatches', t => {
  const root = fixture(t);
  write(root, 'macos', 'public/.DS_Store', 'Finder metadata');
  write(root, 'windows', 'public/assets/Thumbs.db', 'Explorer metadata');
  const result = check(root);
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, /4 shared files/);
  write(root, 'macos', 'public/.new-asset', 'real shared asset');
  const newAsset = check(root);
  assert.equal(newAsset.status, 1, newAsset.output);
  assert.match(newAsset.output, /missing: windows\/public\/\.new-asset/);
});

test('symbolic links in shared files or directories cannot bypass the check', async t => {
  for (const name of ['linked.mjs', 'public/linked.mjs', 'public/linked-folder', 'test/linked.test.mjs', 'test/linked-folder', 'public', '']) {
    await t.test(name || 'platform directory', t => {
      const root = fixture(t);
      const target = join(root, 'target');
      const directory = !name || name === 'public' || name.endsWith('folder');
      if (directory) mkdirSync(target);
      else writeFileSync(target, 'linked contents\n');
      for (const platform of ['macos', 'windows']) {
        const path = join(root, platform, name);
        if (existsSync(path)) rmSync(path, { recursive: true });
        try {
          symlinkSync(target, path, directory ? 'junction' : 'file');
        } catch (error) {
          if (process.platform === 'win32' && error.code === 'EPERM' && !directory) {
            t.skip('Windows does not grant this process file-symlink privileges');
            return;
          }
          throw error;
        }
      }
      const result = check(root);
      assert.equal(result.status, 1, result.output);
      assert.ok(result.output.includes(`macos${name ? `/${name}` : ''}`), result.output);
      assert.match(result.output, /symbolic link/);
    });
  }
});

test('empty or incomplete platform trees fail instead of claiming parity', t => {
  for (const empty of [false, true]) {
    const root = fixture(t);
    if (empty) {
      for (const platform of ['macos', 'windows']) {
        rmSync(join(root, platform), { recursive: true });
        mkdirSync(join(root, platform, 'public'), { recursive: true });
        mkdirSync(join(root, platform, 'test'), { recursive: true });
      }
    } else rmSync(join(root, 'windows'), { recursive: true });
    const result = check(root);
    assert.equal(result.status, 1, result.output);
    assert.match(result.output, empty ? /no shared files/ : /windows/);
  }
});

test('the core command blocks out-of-sync sources before executing test suites', t => {
  const root = fixture(t);
  for (const name of ['check-shared.mjs', 'core-test.mjs']) {
    write(root, 'scripts', name, readFileSync(new URL(`../${name}`, import.meta.url)));
  }
  const marker = join(root, 'executed');
  const sentinel = `import {writeFileSync} from 'node:fs';\nwriteFileSync(${JSON.stringify(marker)}, 'executed');\n`;
  write(root, 'scripts', 'test/sentinel.test.mjs', sentinel);
  for (const platform of ['macos', 'windows']) write(root, platform, 'test/sentinel.test.mjs', sentinel);
  write(root, 'windows', 'monitor.mjs', '// drift\n');
  const result = spawnSync(process.execPath, [join(root, 'scripts/core-test.mjs')], { cwd: root, encoding: 'utf8' });
  assert.ifError(result.error);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /differs: macos\/monitor\.mjs <> windows\/monitor\.mjs/);
  assert.equal(existsSync(marker), false, 'No tests should run after the equality gate fails');
});

test('the CLI uses its repository location when no root is supplied', () => {
  const result = spawnSync(process.execPath, [checker], { cwd: tmpdir(), encoding: 'utf8' });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /shared files/);
});
