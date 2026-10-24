import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { closeSync, cpSync, existsSync, lstatSync, mkdirSync, openSync, readFileSync, readdirSync, readlinkSync, readSync, realpathSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, parse, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const owner = 'codex-quota-managed-updates/v1';
const repository = fileURLToPath(new URL('../', import.meta.url));
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const inside = (parent, child) => child === parent || (!relative(parent, child).startsWith(`..${sep}`) && relative(parent, child) !== '..' && !isAbsolute(relative(parent, child)));

export function safePath(value) {
  assert.equal(typeof value, 'string', 'An absolute path is required');
  assert.ok(isAbsolute(value) && !value.includes('\0'), 'An absolute path is required');
  const path = resolve(value);
  let part = parse(path).root;
  for (const name of path.slice(part.length).split(sep).filter(Boolean)) {
    part = join(part, name);
    try {
      assert.ok(!lstatSync(part).isSymbolicLink(), `Symlink path rejected: ${part}`);
      // APFS/NTFS may accept differently cased names for the same directory.
      part = realpathSync.native(part);
    }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  return part;
}

export function hashFile(path) {
  safePath(path);
  const hash = createHash('sha256');
  const fd = openSync(path, 'r');
  try {
    const buffer = Buffer.alloc(1024 * 1024);
    let size;
    // Explicit positions keep the hash bounded in memory on bundled runtimes.
    let position = 0;
    while ((size = readSync(fd, buffer, 0, buffer.length, position)) > 0) { hash.update(buffer.subarray(0, size)); position += size; }
  } finally { closeSync(fd); }
  return hash.digest('hex');
}

export function manifest(root) {
  safePath(root);
  assert.ok(lstatSync(root).isDirectory(), 'A bundle or data directory is required');
  const entries = {};
  function visit(directory) {
    for (const item of readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const path = join(directory, item.name), name = relative(root, path).split(sep).join('/');
      const stat = lstatSync(path);
      if (item.isSymbolicLink()) entries[name] = { link: readlinkSync(path) };
      else if (item.isDirectory()) { entries[name] = { directory: true }; visit(path); }
      else { assert.ok(item.isFile(), 'Unsupported file in update input'); entries[name] = { sha256: hashFile(path), executable: Boolean(stat.mode & 0o111) }; }
    }
  }
  visit(root);
  return entries;
}

function readJson(path) { safePath(path); return JSON.parse(readFileSync(path, 'utf8')); }
function writeJson(path, value) {
  safePath(path); mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  const temporary = `${path}.${randomUUID()}.tmp`;
  try { writeFileSync(temporary, JSON.stringify(value, null, 2) + '\n', { flag: 'wx', mode: 0o600 }); renameSync(temporary, path); }
  finally { if (existsSync(temporary)) rmSync(temporary); }
}
function normalize(config) {
  const result = { ...config };
  for (const key of ['appPath', 'dataPath', 'workspace', 'evidencePath']) result[key] = safePath(config[key]);
  const roots = ['appPath', 'dataPath', 'workspace', 'evidencePath'];
  if (config.previousRollback !== undefined) {
    result.previousRollback = safePath(config.previousRollback);
    assert.ok(result.previousRollback.endsWith('.app'), 'Previous rollback must be an app bundle');
    roots.push('previousRollback');
  }
  for (let a = 0; a < roots.length; a++) for (let b = a + 1; b < roots.length; b++) {
    assert.ok(!inside(result[roots[a]], result[roots[b]]) && !inside(result[roots[b]], result[roots[a]]), 'Application, data, cache and evidence paths must be disjoint (no overlap)');
  }
  assert.ok(!inside(repository, result.workspace) && !inside(repository, result.evidencePath), 'Generated update files must be outside the repository');
  assert.ok(result.appPath.endsWith('.app') && lstatSync(result.appPath).isDirectory(), 'An existing app installation is required');
  assert.ok(lstatSync(result.dataPath).isDirectory(), 'An existing data directory is required');
  return result;
}
function identity(config) { return Object.fromEntries(['appPath', 'dataPath', 'workspace', 'evidencePath'].map(key => [key, config[key]])); }
function withLock(config, action) {
  const path = `${config.appPath}.update-lock`;
  let fd;
  try { fd = openSync(path, 'wx', 0o600); }
  catch (error) { if (error.code === 'EEXIST') throw Error('Another update is in progress; inspect the installation lock before retrying'); throw error; }
  const inode = lstatSync(path).ino;
  return Promise.resolve().then(action).finally(() => { closeSync(fd); if (existsSync(path) && lstatSync(path).ino === inode) rmSync(path); });
}
function catalog(config, create = false) {
  const marker = join(config.workspace, 'owner.json');
  if (!existsSync(marker)) {
    assert.ok(create, 'Unrecognized update workspace');
    assert.ok(!existsSync(config.workspace) || readdirSync(config.workspace).length === 0, 'Refusing a nonempty unowned workspace');
    mkdirSync(config.workspace, { recursive: true, mode: 0o700 });
    writeJson(marker, { owner, ...identity(config) });
    writeJson(join(config.workspace, 'catalog.json'), { owner, entries: [], pending: null, verified: null });
  }
  assert.deepEqual(readJson(marker), { owner, ...identity(config) }, 'Workspace ownership mismatch');
  const value = readJson(join(config.workspace, 'catalog.json'));
  assert.equal(value.owner, owner);
  assert.ok(Array.isArray(value.entries) && value.entries.every(id => uuid.test(id)) && new Set(value.entries).size === value.entries.length, 'Invalid update catalog');
  for (const id of [value.pending, value.verified]) assert.ok(id === null || value.entries.includes(id), 'Unknown catalog transaction');
  return value;
}
function saveCatalog(config, value) { writeJson(join(config.workspace, 'catalog.json'), value); }
function paths(config, id) {
  assert.ok(uuid.test(id), 'Invalid transaction ID');
  const runRoot = join(config.workspace, 'updates', id);
  return { runRoot, candidate: join(runRoot, 'expanded', 'Codex Quota Widget.app'), rollback: join(runRoot, 'rollback.app'), outerArchive: join(runRoot, 'artifact.zip'), package: join(runRoot, 'download', 'package.zip') };
}
function receiptPath(config, id) { return join(config.evidencePath, id, 'transaction.json'); }
function saveReceipt(value) { writeJson(receiptPath(value.config, value.id), value); }
function loadReceipt(config, id) {
  const result = readJson(receiptPath(config, id));
  assert.equal(result.owner, owner); assert.equal(result.id, id);
  assert.deepEqual(identity(result.config), identity(config), 'Receipt ownership mismatch');
  return result;
}
function sameManifest(path, wanted, reason) { assert.deepEqual(manifest(path), wanted, reason); }
async function importRollback(receipt, registry, platform) {
  const config = receipt.config, source = config.previousRollback;
  if (registry.verified || !source) return;
  safePath(source);
  assert.ok(lstatSync(source).isDirectory(), 'The selected previous rollback is missing');
  await platform.validateApp(source, false);
  assert.ok(!await platform.isRunning(source), 'The selected previous rollback is running');
  assert.equal(statSync(source).dev, statSync(config.appPath).dev, 'Previous rollback must be on the installation filesystem');
  const id = randomUUID(), location = paths(config, id);
  mkdirSync(location.runRoot, { recursive: true, mode: 0o700 });
  writeJson(join(location.runRoot, 'owner.json'), { owner, id, appPath: config.appPath });
  const imported = { owner, id, config, status: 'importing', source, beforeManifest: manifest(source) };
  registry.entries.push(id);
  receipt.legacyImport = { id, source, rollback: location.rollback };
  saveReceipt(imported); saveReceipt(receipt); saveCatalog(config, registry);
  renameSync(source, location.rollback);
  imported.status = 'imported'; saveReceipt(imported);
}
function restoreImportedRollback(receipt) {
  if (!receipt.legacyImport) return;
  const { id, source } = receipt.legacyImport, location = paths(receipt.config, id);
  const imported = loadReceipt(receipt.config, id);
  safePath(source);
  if (existsSync(location.rollback)) {
    assert.ok(!existsSync(source), 'Previous rollback source is occupied; manual recovery required');
    sameManifest(location.rollback, imported.beforeManifest, 'Imported rollback changed');
    renameSync(location.rollback, source);
  }
  sameManifest(source, imported.beforeManifest, 'Previous rollback could not be restored');
  imported.status = 'restored'; saveReceipt(imported);
}
function sources(data) {
  // The same post may carry both a regular reset and banked reset credits.
  // Same-kind consolidation can retain a source as a preview/completion alias.
  return new Set([...(data.items || []), ...(data.history || [])].flatMap(row =>
    [row.sourceUrl, row.previewSourceUrl, row.deliverySourceUrl, ...(row.previewAliases || [])]
      .filter(Boolean).map(url => JSON.stringify([row.kind ?? null, url]))));
}
function preserveData(receipt) {
  const before = receipt.dataBackup, after = receipt.config.dataPath;
  sameManifest(before, receipt.dataBackupManifest, 'Saved data backup changed');
  const settings = join(before, 'settings.json');
  if (existsSync(settings)) assert.deepEqual(readFileSync(join(after, 'settings.json')), readFileSync(settings), 'Settings changed');
  if (existsSync(join(before, 'quota-recovery.json'))) {
    const old = readJson(join(before, 'quota-recovery.json')), current = readJson(join(after, 'quota-recovery.json'));
    assert.equal(current.salt, old.salt, 'Recovery identity changed');
    for (const [id, account] of Object.entries(old.accounts)) {
      assert.ok(current.accounts[id], 'Recovery account missing');
      assert.equal(current.accounts[id].trackingSince, account.trackingSince);
      for (const row of account.records) assert.ok(current.accounts[id].records.some(value => { try { assert.deepEqual(value, row); return true; } catch { return false; } }), 'Recovery record missing');
    }
  }
  if (existsSync(join(before, 'announcements.json'))) {
    const current = sources(readJson(join(after, 'announcements.json')));
    for (const url of sources(readJson(join(before, 'announcements.json')))) assert.ok(current.has(url), 'Public history source missing');
  }
}
function preservePreferences(before, after) {
  for (const [domain, values] of Object.entries(before)) {
    for (const [key, value] of Object.entries(values)) {
      const current = after[domain]?.[key];
      if (key === 'detailFrame' && values.detailAutoHeight !== false) {
        const numbers = text => String(text).match(/-?\d+(?:\.\d+)?/g)?.map(Number) || [];
        const a = numbers(value), b = numbers(current);
        assert.ok(a.length === 4 && b.length === 4 && Math.abs(a[0] - b[0]) < 1 && Math.abs(a[2] - b[2]) < 1 && Math.abs(a[1] + a[3] - b[1] - b[3]) < 1, 'Window position or width changed');
      } else assert.deepEqual(current, value, 'Native preference changed');
    }
  }
}

export async function prepareUpdate(input, platform) {
  const config = normalize(input);
  assert.match(config.commit, /^[0-9a-f]{40}$/, 'An exact commit is required');
  assert.ok(Number.isSafeInteger(config.run) && config.run > 0, 'An exact CI run is required');
  return withLock(config, async () => {
    const registry = catalog(config, true);
    assert.equal(registry.pending, null, 'An unverified update is pending; verify it before another prepare');
    await platform.validateApp(config.appPath, false);
    const id = randomUUID(), location = paths(config, id);
    mkdirSync(location.runRoot, { recursive: true, mode: 0o700 });
    assert.equal(statSync(config.appPath).dev, statSync(location.runRoot).dev, 'Cache and app must be on the same filesystem');
    writeJson(join(location.runRoot, 'owner.json'), { owner, id, appPath: config.appPath });
    const receipt = { owner, id, config, paths: location, status: 'preparing', createdAt: new Date().toISOString() };
    registry.entries.push(id); registry.pending = id;
    saveReceipt(receipt); saveCatalog(config, registry);
    let swapped = false;
    try {
      receipt.ci = await platform.validateRelease(config);
      receipt.package = await platform.stage(config, location, receipt.ci);
      await platform.validateApp(location.candidate, true);
      receipt.beforeManifest = manifest(config.appPath);
      receipt.installedManifest = manifest(location.candidate);
      receipt.status = 'staged'; saveReceipt(receipt);
      await platform.stop(config.appPath, config.dataPath);
      assert.ok(!await platform.isRunning(config.appPath), 'The application is still running after Stop; inspect missing or stale PID files');
      receipt.preferences = await platform.preferences();
      receipt.dataBackup = join(config.evidencePath, id, 'data-before');
      assert.ok(!existsSync(receipt.dataBackup), 'Data backup already exists');
      cpSync(config.dataPath, receipt.dataBackup, { recursive: true, dereference: false, preserveTimestamps: true });
      receipt.dataBackupManifest = manifest(receipt.dataBackup);
      sameManifest(location.candidate, receipt.installedManifest, 'Staged app changed before replacement');
      sameManifest(config.appPath, receipt.beforeManifest, 'Installed app changed before replacement');
      saveReceipt(receipt);
      await importRollback(receipt, registry, platform);
      renameSync(config.appPath, location.rollback);
      receipt.status = 'backed-up'; saveReceipt(receipt);
      renameSync(location.candidate, config.appPath); swapped = true;
      await platform.validateApp(config.appPath, true);
      sameManifest(config.appPath, receipt.installedManifest, 'Installed payload mismatch');
      receipt.status = 'installed'; saveReceipt(receipt);
      return { ...receipt, receiptPath: receiptPath(config, id) };
    } catch (error) {
      try {
        if (swapped) { sameManifest(config.appPath, receipt.installedManifest, 'New app changed during failed install'); renameSync(config.appPath, location.candidate); }
        if (!existsSync(config.appPath) && existsSync(location.rollback)) {
          sameManifest(location.rollback, receipt.beforeManifest, 'Rollback app changed'); renameSync(location.rollback, config.appPath);
        }
        if (receipt.beforeManifest) sameManifest(config.appPath, receipt.beforeManifest, 'Existing app could not be restored');
        restoreImportedRollback(receipt);
        receipt.status = 'failed'; registry.pending = null;
      } catch { receipt.status = 'needs-recovery'; }
      receipt.error = error.message; saveReceipt(receipt); saveCatalog(config, registry);
      throw error;
    }
  });
}

async function prune(config, registry, current, platform) {
  const cleanup = { removed: [], blocked: [] }, plan = [];
  for (const id of registry.entries) {
    try {
      const location = paths(config, id);
      assert.deepEqual(readJson(join(location.runRoot, 'owner.json')), { owner, id, appPath: config.appPath }, 'Artifact ownership mismatch');
      const receipt = loadReceipt(config, id);
      const artifacts = [[location.outerArchive, false], [location.package, false], [location.candidate, true]];
      if (id !== current.id) artifacts.push([location.rollback, true]);
      for (const [path, app] of artifacts) {
        // lstat, rather than existsSync, also notices broken symbolic links.
        let stat; try { stat = lstatSync(path); } catch (error) { if (error.code === 'ENOENT') continue; throw error; }
        safePath(path);
        assert.ok(!stat.isSymbolicLink() && (app ? stat.isDirectory() : stat.isFile()), 'Unexpected artifact type');
        if (app) {
          assert.ok(!await platform.isRunning(path), 'Registered app is still running');
          if (path === location.rollback) sameManifest(path, receipt.beforeManifest, 'Old rollback was modified');
          else {
            assert.ok(receipt.installedManifest, 'Extracted app has no complete saved manifest; inspect it before cleanup');
            sameManifest(path, receipt.installedManifest, 'Extracted app was modified');
          }
        }
        plan.push({ path, device: stat.dev, inode: stat.ino });
      }
    } catch (error) { cleanup.blocked.push({ id, error: error.message }); }
  }
  if (cleanup.blocked.length) return cleanup;
  for (const item of plan) {
    try {
      safePath(item.path);
      const stat = lstatSync(item.path);
      assert.equal(stat.dev, item.device); assert.equal(stat.ino, item.inode, 'Artifact identity changed');
      platform.remove(item.path);
      cleanup.removed.push(item.path);
      current.cleanup = cleanup; saveReceipt(current);
    } catch (error) { cleanup.blocked.push({ path: item.path, error: error.message }); break; }
  }
  return cleanup;
}

export async function verifyUpdate(path, platform) {
  const initial = readJson(safePath(path)), config = normalize(initial.config);
  assert.ok(uuid.test(initial.id) && safePath(path) === receiptPath(config, initial.id), 'Unexpected receipt location');
  return withLock(config, async () => {
    const registry = catalog(config), receipt = loadReceipt(config, initial.id);
    assert.ok(registry.pending === receipt.id || (!registry.pending && registry.verified === receipt.id), 'This is not the current update transaction');
    const location = paths(config, receipt.id);
    sameManifest(config.appPath, receipt.installedManifest, 'Installed payload changed');
    sameManifest(location.rollback, receipt.beforeManifest, 'Latest rollback changed');
    await platform.validateApp(config.appPath, true);
    const runtime = await platform.verifyRuntime(config);
    // A receipt cannot self-assert success: real runtime and payload checks always run.
    if (registry.pending === receipt.id) {
      preserveData(receipt);
      preservePreferences(receipt.preferences, await platform.preferences());
    } else sameManifest(receipt.dataBackup, receipt.dataBackupManifest, 'Saved data backup changed');
    receipt.verification = { at: new Date().toISOString(), runtime, payload: true, data: true, preferences: true };
    receipt.status = 'verified'; saveReceipt(receipt);
    registry.pending = null; registry.verified = receipt.id; saveCatalog(config, registry);
    receipt.cleanup = await prune(config, registry, receipt, platform);
    sameManifest(config.appPath, receipt.installedManifest, 'Retained installation changed');
    sameManifest(location.rollback, receipt.beforeManifest, 'Retained rollback changed');
    saveReceipt(receipt);
    return { receiptPath: path, verification: receipt.verification, cleanup: receipt.cleanup, rollback: location.rollback };
  });
}
