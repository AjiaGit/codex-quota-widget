import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readdirSync, realpathSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const cli = fileURLToPath(new URL('../update-macos.mjs', import.meta.url));
function invoke(t, args) {
  assert.ok(existsSync(cli), 'the documented Mac update command must exist');
  const cwd = realpathSync(mkdtempSync(join(tmpdir(), 'quota-cli-')));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  const result = spawnSync(process.execPath, [cli, ...args], { cwd, encoding: 'utf8', timeout: 10000 });
  assert.deepEqual(readdirSync(cwd), [], 'help and rejected arguments cannot create update files');
  return result;
}
test('Mac update help describes preparation, normal launch, verification and automatic retention', t => {
  const result = invoke(t, ['--help']);
  assert.equal(result.status, 0, result.stderr);
  for (const word of ['prepare --config', 'verify --receipt', 'launch', 'rollback', 'cleanup']) assert.ok(result.stdout.includes(word));
});
for (const args of [[], ['cleanup'], ['verify', '--passed', 'true'], ['prepare', '--config'], ['prepare', '--config', 'a.json', '--force']]) {
  test(`Mac updater rejects unsupported or incomplete arguments: ${args.join(' ') || '(none)'}`, t => {
    const result = invoke(t, args);
    assert.equal(result.status, 1);
    assert.ok(result.stderr.trim());
  });
}
