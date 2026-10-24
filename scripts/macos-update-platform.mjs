import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { closeSync, existsSync, mkdirSync, openSync, readFileSync, renameSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { hashFile, safePath } from './macos-update.mjs';

const repo = 'AjiaGit/codex-quota-widget';
const checkout = fileURLToPath(new URL('../', import.meta.url));
const requiredJobs = ['macOS arm64', 'macOS x64', 'Windows x64'];
const execute = (file, args, options = {}) => execFileSync(file, args, { encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024, ...options });
const readJson = path => { safePath(path); return JSON.parse(readFileSync(path, 'utf8')); };

export function validateRunProof(value, spec) {
  assert.equal(value.databaseId, spec.run, 'Wrong CI run');
  assert.equal(value.headSha, spec.commit, 'Wrong CI commit');
  // The PR workflow checks out a synthetic merge, which is not its headSha.
  assert.ok(['push', 'workflow_dispatch'].includes(value.event), 'CI must build the requested commit, not a PR merge');
  assert.equal(value.workflowName, 'Build packages', 'Wrong package workflow');
  assert.equal(value.status, 'completed', 'CI is incomplete');
  assert.equal(value.conclusion, 'success', 'CI did not succeed');
  for (const name of requiredJobs) {
    const matches = value.jobs.filter(job => job.name === name);
    assert.ok(matches.length === 1 && matches[0].conclusion === 'success', `Required CI job failed or missing: ${name}`);
  }
}
export function selectArtifact(artifacts, spec) {
  const matches = artifacts.filter(value => value.name === spec.name);
  assert.equal(matches.length, 1, 'Exactly one requested artifact is required');
  const artifact = matches[0];
  assert.ok(Number.isSafeInteger(artifact.id) && artifact.id > 0 && artifact.expired === false, 'Invalid or expired CI artifact');
  assert.match(artifact.digest || '', /^sha256:[0-9a-f]{64}$/, 'Artifact digest missing');
  assert.equal(artifact.workflow_run?.id, spec.run, 'Artifact belongs to a different run');
  assert.equal(artifact.workflow_run?.head_sha, spec.commit, 'Artifact belongs to a different commit');
  return artifact;
}
export function parseChecksum(text, expectedName) {
  const match = text.trim().match(/^([0-9a-f]{64})[ \t]+\*?([^\r\n]+)$/);
  assert.ok(match && match[2] === expectedName, 'Checksum must name exactly the expected package');
  return match[1];
}
export function validateArchive(names, details, roots) {
  assert.ok(names.length > 0, 'Empty archive');
  for (const name of names) {
    assert.ok(name && !name.startsWith('/') && !name.includes('\\') && !name.includes('\0') && !/^[A-Za-z]:/.test(name), 'Unsafe archive path');
    assert.ok(!name.split('/').some(part => part === '..' || part === '.'), 'Archive traversal rejected');
    assert.ok(roots.some(root => name === root || name.startsWith(root + '/')), 'Unexpected archive root');
  }
  assert.ok(!details.split('\n').some(line => /^l.{9}\s/.test(line)), 'Archive symlinks are unsupported');
}
function live(pid) { try { process.kill(pid, 0); return true; } catch (error) { return error.code !== 'ESRCH'; } }
function nativeState(path) {
  assert.equal(safePath(path), safePath(join(homedir(), 'Library/Application Support/CodexWeeklyMonitor')), 'Native dataPath must match the application state directory');
}

export function createMacPlatform({ command = execute, arch = process.arch, request = async path => {
  const response = await fetch(`http://127.0.0.1:39224${path}`, { signal: AbortSignal.timeout(10000) });
  assert.ok(response.ok, 'Local service request failed'); return response.json();
}, download = (artifact, destination) => {
  const fd = openSync(destination, 'wx', 0o600);
  try {
    const result = spawnSync('gh', ['api', `repos/${repo}/actions/artifacts/${artifact.id}/zip`], { stdio: ['ignore', fd, 'pipe'], timeout: 180000 });
    assert.equal(result.status, 0, 'CI artifact download failed');
  } finally { closeSync(fd); }
} } = {}) {
  assert.ok(['arm64', 'x64'].includes(arch), 'Unsupported Mac architecture');
  const inspectZip = (path, roots) => {
    const names = command('/usr/bin/unzip', ['-Z1', path]).trim().split(/\r?\n/);
    validateArchive(names, command('/usr/bin/unzip', ['-Z', '-l', path]), roots);
    return names;
  };
  const processList = () => command('/bin/ps', ['-axo', 'pid=,command=']).split('\n').map(line => line.trim().match(/^(\d+)\s+(.+)$/)).filter(Boolean).map(match => ({ pid: Number(match[1]), command: match[2] }));
  return {
    async validateRelease(config) {
      nativeState(config.dataPath);
      const proof = JSON.parse(command('gh', ['run', 'view', String(config.run), '--repo', repo, '--json', 'databaseId,headSha,event,workflowName,status,conclusion,jobs,url']));
      validateRunProof(proof, config);
      const version = command('git', ['show', `${config.commit}:VERSION`], { cwd: checkout }).trim();
      assert.match(version, /^\d+\.\d+\.\d+$/, 'Invalid target version');
      const name = `CodexQuotaWidget-${version}-macos-${arch}`;
      const listing = JSON.parse(command('gh', ['api', `repos/${repo}/actions/runs/${config.run}/artifacts?name=${name}`]));
      const artifact = selectArtifact(listing.artifacts, { ...config, name });
      return { commit: config.commit, run: config.run, url: proof.url, artifact, packageName: `${name}.zip` };
    },
    async stage(config, paths, ci) {
      await download(ci.artifact, paths.outerArchive);
      assert.equal(hashFile(paths.outerArchive), ci.artifact.digest.slice(7), 'Downloaded artifact digest mismatch');
      const outer = inspectZip(paths.outerArchive, [ci.packageName, 'SHA256SUMS']);
      assert.equal(outer.length, 2, 'Unexpected outer artifact files');
      assert.deepEqual(new Set(outer), new Set([ci.packageName, 'SHA256SUMS']));
      const directory = dirname(paths.package); mkdirSync(directory, { recursive: true });
      command('/usr/bin/ditto', ['-x', '-k', paths.outerArchive, directory]);
      const packagePath = safePath(join(directory, ci.packageName));
      const expected = parseChecksum(readFileSync(join(directory, 'SHA256SUMS'), 'utf8'), ci.packageName);
      assert.equal(hashFile(packagePath), expected, 'Inner package checksum mismatch');
      renameSync(packagePath, paths.package);
      inspectZip(paths.package, ['Codex Quota Widget.app', '__MACOSX']);
      mkdirSync(dirname(paths.candidate), { recursive: true });
      command('/usr/bin/ditto', ['-x', '-k', paths.package, dirname(paths.candidate)]);
      return { packageName: ci.packageName, packageSha256: expected, artifactId: ci.artifact.id, artifactDigest: ci.artifact.digest };
    },
    async validateApp(app, candidate) {
      safePath(app);
      const info = JSON.parse(command('/usr/bin/plutil', ['-convert', 'json', '-o', '-', join(app, 'Contents/Info.plist')]));
      assert.equal(info.CFBundleIdentifier, 'local.codex.weeklymonitor.launcher', 'Not a quota widget launcher');
      const helper = join(app, 'Contents/Helpers/QuotaWidget.app');
      const inner = JSON.parse(command('/usr/bin/plutil', ['-convert', 'json', '-o', '-', join(helper, 'Contents/Info.plist')]));
      assert.equal(inner.CFBundleIdentifier, 'local.codex.weeklymonitor', 'Not a quota widget helper');
      command('/usr/bin/codesign', ['--verify', '--deep', '--strict', app]);
      if (candidate) {
        const runtime = join(app, 'Contents/Resources/service/runtime/node');
        assert.equal(command(runtime, ['--version']).trim(), 'v24.19.0', 'Unexpected bundled runtime');
        for (const binary of [join(app, 'Contents/MacOS/Launch'), join(helper, 'Contents/MacOS/CodexQuota'), runtime]) {
          const type = command('/usr/bin/file', ['-b', binary]);
          assert.ok(type.includes('Mach-O') && new RegExp(`\\b${arch === 'arm64' ? 'arm64' : 'x86_64'}\\b`).test(type), 'Wrong native architecture');
        }
      }
    },
    async stop(app, data) {
      nativeState(data);
      const pids = ['launcher.pid', 'monitor.pid', 'widget.pid'].map(name => join(data, name)).filter(existsSync).map(file => {
        safePath(file); const text = readFileSync(file, 'utf8').trim(); assert.match(text, /^\d+$/); return Number(text);
      });
      command('/bin/bash', [join(app, 'Contents/Resources/service/Stop.command')]);
      const deadline = Date.now() + 40000;
      while (pids.some(live) && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 100));
      assert.ok(!pids.some(live), 'The old application has not stopped');
    },
    async preferences() {
      const result = {};
      for (const domain of ['local.codex.weeklymonitor', 'local.codex.weeklymonitor.launcher']) {
        const xml = command('/usr/bin/defaults', ['export', domain, '-']);
        result[domain] = JSON.parse(command('/usr/bin/plutil', ['-convert', 'json', '-o', '-', '-'], { input: xml }));
      }
      return result;
    },
    async verifyRuntime(config) {
      nativeState(config.dataPath);
      const launcher = join(config.appPath, 'Contents/MacOS/Launch');
      const service = join(config.appPath, 'Contents/Resources/service');
      const roles = [
        ['launcher.pid', launcher, null],
        ['monitor.pid', join(service, 'runtime/node'), join(service, 'monitor.mjs')],
        ['widget.pid', join(config.appPath, 'Contents/Helpers/QuotaWidget.app/Contents/MacOS/CodexQuota'), null],
      ];
      const rows = processList(), observed = [];
      for (const [filename, executable, script] of roles) {
        const file = safePath(join(config.dataPath, filename));
        const text = readFileSync(file, 'utf8').trim(); assert.match(text, /^\d+$/);
        const pid = Number(text); observed.push(pid);
        const owns = value => {
          try { command(launcher, ['--owns-process', String(value), executable, ...(script ? [script] : [])]); return true; }
          catch { return false; }
        };
        assert.ok(owns(pid), 'A recorded process belongs to a different installation');
        const candidates = rows.filter(row => row.command === executable || row.command.startsWith(executable + ' '));
        assert.equal(candidates.filter(row => owns(row.pid)).length, 1, 'Expected exactly one owned process for each role');
      }
      assert.equal(new Set(observed).size, 3, 'Process roles must be distinct');
      const health = await request('/health'); assert.equal(health.app, 'codex-weekly-monitor', 'Wrong local service');
      const usage = await request('/api/usage');
      assert.ok(usage.status === 'ok' && Number.isFinite(usage.updatedAt) && Date.now() - usage.updatedAt < 600000 && usage.updatedAt <= Date.now() + 60000 && usage.resetsAt * 1000 > Date.now() && usage.remainingPercent >= 0 && usage.remainingPercent <= 100, 'Quota is unavailable or stale; retry verification after recovery');
      return { ownedProcesses: 3, serviceHealthy: true, quotaReadable: true };
    },
    async isRunning(app) { return processList().some(row => row.command.includes(app + '/')); },
    remove(path) { rmSync(path, { recursive: true, force: false }); },
  };
}
