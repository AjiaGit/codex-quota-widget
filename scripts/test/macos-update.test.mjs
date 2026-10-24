import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const moduleURL = new URL('../macos-update.mjs', import.meta.url);
const sha = digit => digit.repeat(40);
const json = (file, value) => { mkdirSync(dirname(file), { recursive: true }); writeFileSync(file, JSON.stringify(value)); };
const read = file => JSON.parse(readFileSync(file, 'utf8'));
async function engine() {
  assert.ok(existsSync(fileURLToPath(moduleURL)), 'the maintained prepare/verify update pipeline must exist');
  return import(moduleURL.href);
}
function fixture(t) {
  // Match production canonicalization, including Windows DOS short-name aliases.
  const root = realpathSync.native(mkdtempSync(join(tmpdir(), 'quota-update-')));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const config = { appPath: join(root, 'Applications', 'Quota.app'), dataPath: join(root, 'data'), workspace: join(root, 'cache'), evidencePath: join(root, 'evidence'), commit: sha('a'), run: 101 };
  mkdirSync(config.appPath, { recursive: true });
  writeFileSync(join(config.appPath, 'payload'), 'version-original');
  mkdirSync(config.dataPath);
  json(join(config.dataPath, 'settings.json'), { language: 'zh-CN' });
  json(join(config.dataPath, 'quota-recovery.json'), { salt: 'FABRICATED', accounts: { test: { trackingSince: 100, records: [{ id: 'recovery-1', before: 4, after: 100 }] } } });
  json(join(config.dataPath, 'announcements.json'), { items: [{ sourceUrl: 'https://example.invalid/FABRICATED-current' }], history: [{ sourceUrl: 'https://example.invalid/FABRICATED-history' }] });
  mkdirSync(config.evidencePath);
  writeFileSync(join(config.evidencePath, 'existing-test.log'), 'KEEP TEST LOG');
  const faults = {};
  const running = new Set();
  const operations = {
    async validateRelease(c) { if (faults.ci) throw Error('CI failed'); return { commit: c.commit, run: c.run, artifactId: 501, digest: 'FABRICATED' }; },
    async stage(c, paths) {
      mkdirSync(paths.candidate, { recursive: true });
      writeFileSync(join(paths.candidate, 'payload'), `version-${c.commit[0]}`);
      writeFileSync(paths.outerArchive, 'FABRICATED ZIP');
      mkdirSync(dirname(paths.package), { recursive: true });
      writeFileSync(paths.package, 'FABRICATED PACKAGE');
      return { packageSha256: 'FABRICATED' };
    },
    async validateApp() { if (faults.signature) throw Error('invalid signature'); },
    async stop() { if (faults.stop) throw Error('cannot stop'); },
    async preferences() { return { widget: { compactFrame: '{{10,20},{52,76}}', detailAutoHeight: true }, launcher: {} }; },
    async verifyRuntime() { if (faults.runtime) throw Error('wrong process'); return { processOwnership: true, health: true, usage: true }; },
    async isRunning(path) { return running.has(path); },
    remove(path) { if (faults.remove) throw Error('FABRICATED EACCES'); rmSync(path, { recursive: true, force: false }); },
  };
  return { root, config, operations, faults, running };
}

test('two successful managed updates keep only current and immediate rollback while preserving every evidence and data snapshot', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const settings = readFileSync(join(f.config.dataPath, 'settings.json'));
  const first = await prepareUpdate(f.config, f.operations);
  assert.equal(readFileSync(join(f.config.appPath, 'payload'), 'utf8'), 'version-a');
  assert.equal(readFileSync(join(first.paths.rollback, 'payload'), 'utf8'), 'version-original');
  assert.ok(existsSync(first.paths.package), 'prepare cannot clean before validation');
  await verifyUpdate(first.receiptPath, f.operations);
  assert.ok(!existsSync(first.paths.package));
  writeFileSync(join(dirname(first.receiptPath), 'physical-test.log'), 'KEEP PHYSICAL EVIDENCE');
  const second = await prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations);
  assert.ok(existsSync(first.paths.rollback), 'old rollback remains until the new installation is validated');
  const result = await verifyUpdate(second.receiptPath, f.operations);
  assert.equal(result.cleanup.blocked.length, 0);
  assert.equal(readFileSync(join(f.config.appPath, 'payload'), 'utf8'), 'version-b');
  assert.equal(readFileSync(join(second.paths.rollback, 'payload'), 'utf8'), 'version-a');
  assert.ok(!existsSync(first.paths.rollback));
  assert.ok(!existsSync(second.paths.outerArchive) && !existsSync(second.paths.package));
  assert.equal(readFileSync(join(dirname(first.receiptPath), 'physical-test.log'), 'utf8'), 'KEEP PHYSICAL EVIDENCE');
  assert.ok(existsSync(join(first.dataBackup, 'quota-recovery.json')));
  assert.ok(existsSync(join(second.dataBackup, 'announcements.json')));
  assert.deepEqual(readFileSync(join(f.config.dataPath, 'settings.json')), settings);
  assert.equal(readFileSync(join(f.config.evidencePath, 'existing-test.log'), 'utf8'), 'KEEP TEST LOG');
  const again = await verifyUpdate(second.receiptPath, f.operations);
  assert.equal(again.cleanup.removed.length, 0, 'verification and cleanup are idempotent');
});

for (const fault of ['ci', 'signature', 'stop']) test(`${fault} failure preserves the installed app and never prunes the latest rollback`, async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations);
  await verifyUpdate(first.receiptPath, f.operations);
  f.faults[fault] = true;
  await assert.rejects(prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations));
  assert.equal(readFileSync(join(f.config.appPath, 'payload'), 'utf8'), 'version-a');
  assert.ok(existsSync(first.paths.rollback));
  assert.ok(existsSync(join(first.dataBackup, 'settings.json')));
});

test('a failed runtime check cannot be bypassed by a receipt claiming verified and prevents cleanup', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations); await verifyUpdate(first.receiptPath, f.operations);
  const second = await prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations);
  const receipt = read(second.receiptPath); receipt.verified = true; json(second.receiptPath, receipt);
  f.faults.runtime = true;
  await assert.rejects(verifyUpdate(second.receiptPath, f.operations), /wrong process/);
  assert.ok(existsSync(first.paths.rollback) && existsSync(second.paths.package));
});

for (const alteration of ['payload', 'settings', 'history', 'recovery', 'rollback']) test(`changed ${alteration} blocks validation and preserves old artifacts`, async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations);
  if (alteration === 'payload') writeFileSync(join(f.config.appPath, 'payload'), 'TAMPERED');
  if (alteration === 'settings') json(join(f.config.dataPath, 'settings.json'), { language: 'en' });
  if (alteration === 'history') json(join(f.config.dataPath, 'announcements.json'), { items: [], history: [] });
  if (alteration === 'recovery') json(join(f.config.dataPath, 'quota-recovery.json'), { salt: 'FABRICATED', accounts: {} });
  if (alteration === 'rollback') writeFileSync(join(first.paths.rollback, 'payload'), 'TAMPERED');
  await assert.rejects(verifyUpdate(first.receiptPath, f.operations));
  assert.ok(existsSync(first.paths.package) && existsSync(first.paths.rollback));
});

test('another prepare is rejected while an installation is awaiting verification', async t => {
  const { prepareUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations);
  await assert.rejects(prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations), /pending|unverified/i);
  assert.equal(readFileSync(join(first.paths.rollback, 'payload'), 'utf8'), 'version-original');
});

test('data, evidence and application path overlap is rejected before any file is changed', async t => {
  const { prepareUpdate } = await engine();
  const f = fixture(t);
  for (const config of [{ ...f.config, workspace: f.config.dataPath }, { ...f.config, evidencePath: join(f.config.workspace, 'records') }, { ...f.config, workspace: dirname(f.config.appPath) }, { ...f.config, dataPath: f.config.appPath }]) {
    await assert.rejects(prepareUpdate(config, f.operations), /overlap|disjoint/i);
  }
  assert.equal(readFileSync(join(f.config.appPath, 'payload'), 'utf8'), 'version-original');
});

test('a nonempty unowned cache is rejected instead of adopted or recursively cleaned', async t => {
  const { prepareUpdate } = await engine();
  const f = fixture(t);
  mkdirSync(f.config.workspace); writeFileSync(join(f.config.workspace, 'unrelated.log'), 'KEEP');
  await assert.rejects(prepareUpdate(f.config, f.operations), /unowned|unrecognized|empty/i);
  assert.equal(readFileSync(join(f.config.workspace, 'unrelated.log'), 'utf8'), 'KEEP');
});

test('a retained data backup changed after preparation blocks cleanup', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations);
  writeFileSync(join(first.dataBackup, 'settings.json'), 'CHANGED');
  await assert.rejects(verifyUpdate(first.receiptPath, f.operations));
  assert.ok(existsSync(first.paths.package));
});

test('running or changed old rollback is preserved and cleanup can be retried after the running app stops', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations); await verifyUpdate(first.receiptPath, f.operations);
  const second = await prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations);
  f.running.add(first.paths.rollback);
  const blocked = await verifyUpdate(second.receiptPath, f.operations);
  assert.ok(blocked.cleanup.blocked.length);
  assert.ok(existsSync(first.paths.rollback) && existsSync(second.paths.rollback));
  f.running.clear();
  const done = await verifyUpdate(second.receiptPath, f.operations);
  assert.equal(done.cleanup.blocked.length, 0);
  assert.ok(!existsSync(first.paths.rollback));
});

test('a cleanup I/O failure keeps a durable verified receipt and supports a safe retry', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations); await verifyUpdate(first.receiptPath, f.operations);
  const second = await prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations);
  f.faults.remove = true;
  const blocked = await verifyUpdate(second.receiptPath, f.operations);
  assert.ok(blocked.cleanup.blocked.length);
  assert.ok(read(second.receiptPath).verification);
  assert.ok(existsSync(second.paths.rollback));
  f.faults.remove = false;
  await verifyUpdate(second.receiptPath, f.operations);
  assert.ok(!existsSync(first.paths.rollback));
  assert.ok(existsSync(join(first.dataBackup, 'settings.json')));
});

test('symlinked old rollback cannot redirect deletion into evidence or data', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations); await verifyUpdate(first.receiptPath, f.operations);
  const second = await prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations);
  rmSync(first.paths.rollback, { recursive: true });
  symlinkSync(f.config.evidencePath, first.paths.rollback, process.platform === 'win32' ? 'junction' : 'dir');
  const result = await verifyUpdate(second.receiptPath, f.operations);
  assert.ok(result.cleanup.blocked.length);
  assert.equal(readFileSync(join(f.config.evidencePath, 'existing-test.log'), 'utf8'), 'KEEP TEST LOG');
  assert.ok(existsSync(second.paths.rollback));
});

test('unregistered app copies and files beside artifacts are never selected for cleanup', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations);
  const unrelated = join(first.paths.runRoot, 'Other.app');
  cpSync(f.config.appPath, unrelated, { recursive: true });
  writeFileSync(join(first.paths.runRoot, 'test.log'), 'KEEP CACHE-ADJACENT LOG');
  await verifyUpdate(first.receiptPath, f.operations);
  assert.equal(readFileSync(join(unrelated, 'payload'), 'utf8'), 'version-a');
  assert.equal(readFileSync(join(first.paths.runRoot, 'test.log'), 'utf8'), 'KEEP CACHE-ADJACENT LOG');
});

test('an overlapping second updater cannot acquire the installation lock', async t => {
  const { prepareUpdate } = await engine();
  const f = fixture(t);
  let release;
  f.operations.validateRelease = () => new Promise(resolve => { release = () => resolve({ commit: f.config.commit, run: f.config.run }); });
  const pending = prepareUpdate(f.config, f.operations);
  const deadline = Date.now() + 2000;
  while (!release && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 1));
  if (!release) { await pending; assert.fail('prepare never reached release validation'); }
  await assert.rejects(prepareUpdate({ ...f.config, workspace: join(f.root, 'another-cache') }, f.operations), /lock|in progress/i);
  release(); await pending;
});

test('a post-replacement signature failure restores the pre-update application without pruning old backups', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations); await verifyUpdate(first.receiptPath, f.operations);
  f.operations.validateApp = async (path, candidate) => { if (path === f.config.appPath && candidate) throw Error('post-swap verification failed'); };
  await assert.rejects(prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations), /post-swap/);
  assert.equal(readFileSync(join(f.config.appPath, 'payload'), 'utf8'), 'version-a');
  assert.ok(existsSync(first.paths.rollback));
});

test('edited old rollback blocks all pruning rather than deleting user-modified contents', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations); await verifyUpdate(first.receiptPath, f.operations);
  const second = await prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations);
  writeFileSync(join(first.paths.rollback, 'extra.txt'), 'USER FILE');
  const result = await verifyUpdate(second.receiptPath, f.operations);
  assert.ok(result.cleanup.blocked.length);
  assert.equal(readFileSync(join(first.paths.rollback, 'extra.txt'), 'utf8'), 'USER FILE');
  assert.ok(existsSync(second.paths.package));
});

test('receipt-supplied cleanup paths do not redirect the fixed artifact selection', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const first = await prepareUpdate(f.config, f.operations);
  const receipt = read(first.receiptPath);receipt.paths.rollback=f.config.dataPath;receipt.paths.package=join(f.config.evidencePath,'existing-test.log');json(first.receiptPath,receipt);
  await verifyUpdate(first.receiptPath, f.operations);
  assert.ok(existsSync(first.paths.rollback));
  assert.equal(readFileSync(join(f.config.evidencePath, 'existing-test.log'), 'utf8'), 'KEEP TEST LOG');
});

test('first managed update imports the explicitly selected prior rollback and prunes it only after verification', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  const legacy = join(f.root, 'old-evidence', 'previous-app', 'Previous.app');
  cpSync(f.config.appPath, legacy, { recursive: true });
  writeFileSync(join(dirname(legacy), 'physical-test.log'), 'KEEP LEGACY TEST');
  const first = await prepareUpdate({ ...f.config, previousRollback: legacy }, f.operations);
  assert.ok(first.legacyImport && existsSync(first.legacyImport.rollback), 'the existing backup is registered, not silently forgotten');
  assert.ok(!existsSync(legacy));
  await verifyUpdate(first.receiptPath, f.operations);
  assert.ok(!existsSync(first.legacyImport.rollback));
  assert.ok(existsSync(first.paths.rollback));
  assert.equal(readFileSync(join(dirname(legacy), 'physical-test.log'), 'utf8'), 'KEEP LEGACY TEST');
});

test('failed first installation restores the imported rollback at its previous path', async t => {
  const { prepareUpdate } = await engine();
  const f = fixture(t);
  const legacy = join(f.root, 'legacy', 'Previous.app');
  cpSync(f.config.appPath, legacy, { recursive: true });
  f.operations.validateApp = async (path, candidate) => { if (path === f.config.appPath && candidate) throw Error('post-swap failed'); };
  await assert.rejects(prepareUpdate({ ...f.config, previousRollback: legacy }, f.operations), /post-swap/);
  assert.equal(readFileSync(join(legacy, 'payload'), 'utf8'), 'version-original');
  assert.equal(readFileSync(join(f.config.appPath, 'payload'), 'utf8'), 'version-original');
});

test('a modified extracted app from a failed replacement blocks later cleanup and preserves its extra files', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t);
  f.operations.validateApp = async (path, candidate) => { if (path === f.config.appPath && candidate) throw Error('post-swap failed'); };
  await assert.rejects(prepareUpdate(f.config, f.operations), /post-swap/);
  const registry = read(join(f.config.workspace, 'catalog.json'));
  const failed = read(join(f.config.evidencePath, registry.entries[0], 'transaction.json'));
  writeFileSync(join(failed.paths.candidate, 'physical-test.log'), 'KEEP MODIFIED CANDIDATE');
  f.operations.validateApp = async () => {};
  const second = await prepareUpdate({ ...f.config, commit: sha('b'), run: 102 }, f.operations);
  const result = await verifyUpdate(second.receiptPath, f.operations);
  assert.ok(result.cleanup.blocked.length, 'changed extracted app cannot be deleted');
  assert.equal(readFileSync(join(failed.paths.candidate, 'physical-test.log'), 'utf8'), 'KEEP MODIFIED CANDIDATE');
  assert.ok(existsSync(second.paths.package));
});

test('case aliases on an insensitive filesystem cannot bypass the protected-root overlap check', async t => {
  const { prepareUpdate, safePath } = await engine();
  const f = fixture(t), alias = f.config.appPath.toUpperCase();
  if (!existsSync(alias)) { t.skip('filesystem is case sensitive'); return; }
  assert.equal(safePath(alias), f.config.appPath, 'existing aliases must resolve to the same canonical path');
  await assert.rejects(prepareUpdate({ ...f.config, evidencePath: join(alias, 'evidence') }, f.operations), /overlap|disjoint/i);
  assert.deepEqual(Object.keys((await engine()).manifest(f.config.appPath)), ['payload']);
});

test('a surviving application process blocks backup and replacement even if the Stop helper reports success', async t => {
  const { prepareUpdate } = await engine();
  const f = fixture(t);
  f.running.add(f.config.appPath);
  await assert.rejects(prepareUpdate(f.config, f.operations), /still running/i);
  assert.equal(readFileSync(join(f.config.appPath, 'payload'), 'utf8'), 'version-original');
  const registry = read(join(f.config.workspace, 'catalog.json'));
  const receipt = read(join(f.config.evidencePath, registry.entries[0], 'transaction.json'));
  assert.equal(receipt.status, 'failed');
  assert.equal(receipt.dataBackup, undefined, 'no live state may be backed up as a stopped baseline');
  assert.ok(existsSync(receipt.paths.package), 'failed validation cannot prune');
});

test('two kinds from the same original URL cannot conceal the loss of one public record', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t), sourceUrl = 'https://example.invalid/FABRICATED-two-kinds';
  const records = ['regular', 'banked'].map(kind => ({ id: sourceUrl + '#' + kind, kind, sourceUrl }));
  json(join(f.config.dataPath, 'announcements.json'), { items: [], history: records });
  const first = await prepareUpdate(f.config, f.operations);
  json(join(f.config.dataPath, 'announcements.json'), { items: [], history: records.slice(0, 1) });
  await assert.rejects(verifyUpdate(first.receiptPath, f.operations), /Public history/);
  assert.ok(existsSync(first.paths.rollback) && existsSync(first.paths.package));
});

test('same-kind record consolidation preserves both source lineages without blocking a verified update', async t => {
  const { prepareUpdate, verifyUpdate } = await engine();
  const f = fixture(t), a = 'https://example.invalid/FABRICATED-preview', b = 'https://example.invalid/FABRICATED-completion';
  json(join(f.config.dataPath, 'announcements.json'), { items: [{ kind: 'regular', sourceUrl: a }], history: [{ kind: 'regular', sourceUrl: b }] });
  const first = await prepareUpdate(f.config, f.operations);
  json(join(f.config.dataPath, 'announcements.json'), { items: [], history: [{ kind: 'regular', sourceUrl: a, deliverySourceUrl: b }] });
  const result = await verifyUpdate(first.receiptPath, f.operations);
  assert.equal(result.cleanup.blocked.length, 0);
});
