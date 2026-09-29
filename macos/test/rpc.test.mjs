import test from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

let queryAppServer;
try {
  ({ queryAppServer } = await import('../monitor.mjs'));
} catch {
  // The first TDD run fails through the feature assertion below.
}

const fixture = fileURLToPath(new URL('./fake-app-server.mjs', import.meta.url));

test('queries the App Server after its initialization handshake', async () => {
  assert.equal(typeof queryAppServer, 'function');
  const result = await queryAppServer({ command: process.execPath, args: [fixture], timeoutMs: 5000 });
  assert.equal(result.rateLimitsByLimitId.codex.primary.usedPercent, 61);
  assert.equal(result.accountPlanType, 'plus');
});

test('reports an App Server authentication error', async () => {
  assert.equal(typeof queryAppServer, 'function');
  await assert.rejects(
    queryAppServer({ command: process.execPath, args: [fixture, '--error'], timeoutMs: 5000 }),
    /not logged in/,
  );
});
