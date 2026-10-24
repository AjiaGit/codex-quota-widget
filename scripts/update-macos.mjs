#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { prepareUpdate, safePath, verifyUpdate } from './macos-update.mjs';
import { createMacPlatform } from './macos-update-platform.mjs';

const args = process.argv.slice(2);
try {
  if (args.length === 1 && args[0] === '--help') {
    console.log(`Mac update workflow (Node.js 24+, macOS, gh authenticated):
  node scripts/update-macos.mjs prepare --config /absolute/update-config.json
  Open the installed app normally to launch the new version.
  node scripts/update-macos.mjs verify --receipt /absolute/transaction.json

Prepare validates the exact successful CI package, stops the app, saves data and
preferences, and replaces the installation in place. Config requires appPath,
dataPath, workspace, evidencePath, full commit and numeric run. On first use,
previousRollback may name the one existing rollback to migrate into management.
Verify checks payload, running processes, quota, settings and history, then runs
automatic cleanup: keep the current app and immediate pre-update rollback.
Data backups and test records stay outside the disposable artifact cache.
Exit status: 0 success, 1 failed verification/update, 2 verified but cleanup blocked.`);
  } else {
    assert.ok(args.length === 3 && ((args[0] === 'prepare' && args[1] === '--config') || (args[0] === 'verify' && args[1] === '--receipt')), 'Use prepare --config PATH or verify --receipt PATH; see --help');
    assert.equal(process.platform, 'darwin', 'Actual update operations require macOS');
    assert.ok(Number(process.versions.node.split('.')[0]) >= 24, 'Node.js 24 or newer is required');
    const file = safePath(args[2]), platform = createMacPlatform();
    if (args[0] === 'prepare') {
      const result = await prepareUpdate(JSON.parse(readFileSync(file, 'utf8')), platform);
      console.log(JSON.stringify({ status: result.status, commit: result.config.commit, run: result.config.run, receiptPath: result.receiptPath, rollback: result.paths.rollback, next: 'Open the installed app, then verify this receipt. No cleanup has run.' }, null, 2));
    } else {
      const result = await verifyUpdate(file, platform);
      console.log(JSON.stringify({ status: 'verified', ...result }, null, 2));
      if (result.cleanup.blocked.length) process.exitCode = 2;
    }
  }
} catch (error) {
  // Avoid dumping settings/history comparison values or local account state.
  console.error(String(error.message).split('\n')[0]);
  process.exitCode = 1;
}
