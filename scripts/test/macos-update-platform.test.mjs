import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import { join } from 'node:path';

const url = new URL('../macos-update-platform.mjs', import.meta.url);
async function api() { assert.ok(existsSync(fileURLToPath(url)), 'native update adapter must exist'); return import(url.href); }
const commit = 'a'.repeat(40);
const run = () => ({ databaseId: 101, headSha: commit, event: 'workflow_dispatch', workflowName: 'Build packages', status: 'completed', conclusion: 'success', jobs: ['macOS arm64', 'macOS x64', 'Windows x64'].map(name => ({ name, conclusion: 'success' })) });
const artifact = () => ({ id: 501, name: 'CodexQuotaWidget-0.1.0-macos-arm64', expired: false, digest: `sha256:${'b'.repeat(64)}`, workflow_run: { id: 101, head_sha: commit } });

test('CI proof requires the exact run and commit plus all three successful required jobs', async () => {
  const { validateRunProof } = await api();
  validateRunProof(run(), { run: 101, commit });
  for (const patch of [{ databaseId: 102 }, { headSha: 'c'.repeat(40) }, { status: 'in_progress' }, { conclusion: 'failure' }, { jobs: run().jobs.slice(0, 2) }, { jobs: run().jobs.map(j => ({ ...j, conclusion: j.name === 'Windows x64' ? 'skipped' : 'success' })) }]) {
    assert.throws(() => validateRunProof({ ...run(), ...patch }, { run: 101, commit }));
  }
});

test('artifact selection rejects duplicates, expired uploads, wrong provenance and missing digests', async () => {
  const { selectArtifact } = await api();
  const spec = { run: 101, commit, name: artifact().name };
  assert.equal(selectArtifact([artifact()], spec).id, 501);
  for (const values of [[], [artifact(), artifact()], [{ ...artifact(), expired: true }], [{ ...artifact(), digest: null }], [{ ...artifact(), workflow_run: { id: 102, head_sha: commit } }], [{ ...artifact(), workflow_run: { id: 101, head_sha: 'c'.repeat(40) } }]]) {
    assert.throws(() => selectArtifact(values, spec));
  }
});

test('checksum parsing binds one SHA256 to the exact expected inner filename', async () => {
  const { parseChecksum } = await api();
  const name = 'CodexQuotaWidget-0.1.0-macos-arm64.zip', digest = 'b'.repeat(64);
  assert.equal(parseChecksum(`${digest}  ${name}\r\n`, name), digest);
  assert.equal(parseChecksum(`${digest} *${name}\n`, name), digest);
  for (const text of [`${digest} other.zip`, `${digest}  ${name}\n${digest} extra.zip`, `bad  ${name}`, `${digest}  ../${name}`]) assert.throws(() => parseChecksum(text, name));
});

test('archive preflight rejects escapes, absolute paths, unexpected roots and symlink entries', async () => {
  const { validateArchive } = await api();
  validateArchive(['Codex Quota Widget.app/', 'Codex Quota Widget.app/Contents/Info.plist', '__MACOSX/Codex Quota Widget.app/._Contents'], '-rw-r--r-- test', ['Codex Quota Widget.app', '__MACOSX']);
  for (const names of [['../settings.json'], ['/Applications/Other.app'], ['Codex Quota Widget.app/../../data'], ['C:\\data'], ['Other.app/Contents/Info.plist'], ['Codex Quota Widget.app\\..\\data']]) assert.throws(() => validateArchive(names, '', ['Codex Quota Widget.app']));
  assert.throws(() => validateArchive(['Codex Quota Widget.app/link'], 'lrwxr-xr-x  3.0 unx file', ['Codex Quota Widget.app']));
});

test('the native adapter validates server CI evidence rather than trusting config passed flags', async () => {
  const { createMacPlatform } = await api();
  const command = (file, args) => {
    if (file === 'git') return '0.1.0\n';
    if (args[0] === 'run') return JSON.stringify({ ...run(), conclusion: 'failure' });
    throw Error('Download must not happen for a failed CI run');
  };
  const adapter = createMacPlatform({ command, arch: 'arm64' });
  await assert.rejects(adapter.validateRelease({ run: 101, commit, dataPath: join(homedir(), 'Library/Application Support/CodexWeeklyMonitor'), verified: true, ciPassed: true }), /CI did not succeed/);
});

test('CI provenance rejects PR merge packages and an unrelated workflow even when jobs and head SHA match', async () => {
  const { validateRunProof } = await api();
  for (const patch of [{ event: 'pull_request' }, { event: undefined }, { workflowName: 'Unrelated workflow' }]) assert.throws(() => validateRunProof({ ...run(), ...patch }, { run: 101, commit }));
  validateRunProof({ ...run(), event: 'push' }, { run: 101, commit });
});

test('native preparation rejects a wrong state directory before CI download or Stop can act on the real application', async () => {
  const { createMacPlatform } = await api();
  let commands = 0;
  const adapter = createMacPlatform({ command() { commands++; return JSON.stringify(run()); }, arch: 'arm64' });
  const dataPath = join(homedir(), 'wrong-state-directory');
  await assert.rejects(adapter.validateRelease({ run: 101, commit, dataPath }), /data|state/i);
  await assert.rejects(adapter.stop('/Applications/FABRICATED.app', dataPath), /data|state/i);
  await assert.rejects(adapter.verifyRuntime({ appPath: '/Applications/FABRICATED.app', dataPath }), /data|state/i);
  assert.equal(commands, 0, 'the wrong state directory must fail before any native or network command');
});

test('native preferences read errors propagate instead of creating an empty preservation baseline', async () => {
  const { createMacPlatform } = await api();
  const adapter = createMacPlatform({ command() { throw Error('FABRICATED preferences I/O failure'); }, arch: 'arm64' });
  await assert.rejects(adapter.preferences(), /preferences I\/O failure/);
});
