#!/usr/bin/env node
import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('../', import.meta.url));
const shared = spawnSync(process.execPath, [join(root, 'scripts', 'check-shared.mjs')], {
  cwd: root, env: process.env, stdio: 'inherit',
});
if (shared.error) throw shared.error;
if (shared.status !== 0) process.exit(shared.status ?? 1);

for (const platform of ['scripts', 'macos', 'windows']) {
  const directory = join(root, platform, 'test');
  const tests = readdirSync(directory)
    .filter(name => name.endsWith('.test.mjs') && !name.startsWith('native'))
    .sort()
    .map(name => join(directory, name));
  if (!tests.length) throw new Error(`No core tests found for ${platform}`);
  console.log(platform === 'scripts' ? 'Running repository tooling tests' : `Running ${platform} core tests`);
  const result = spawnSync(process.execPath, ['--test', ...tests], {
    cwd: root, env: process.env, stdio: 'inherit',
  });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
