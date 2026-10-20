import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { normalizeQuota } from '../quota.mjs';
import * as monitor from '../monitor.mjs';
import * as view from '../public/app.mjs';

const weekly = { rateLimits: { primary: { usedPercent: 25, resetsAt: 1900000000, windowDurationMins: 10080 } } };
test('reset detail rows keep authority and omit opaque identifiers', () => {
  const result = normalizeQuota({ ...weekly, rateLimitResetCredits: { availableCount: 3, credits: [
    { id: 'private-credit', title: 'Bonus reset', description: 'One reset', grantedAt: 1800000000, expiresAt: 1900000000 },
    { id: 'second', grantedAt: -1, expiresAt: null },
  ] } });
  assert.equal(result.resetCards, 3);
  assert.deepEqual(result.resetDetails, [
    { title: 'Bonus reset', description: 'One reset', grantedAt: 1800000000, expiresAt: 1900000000 },
    { title: null, description: null, grantedAt: null, expiresAt: null },
  ]);
  assert.equal(JSON.stringify(result).includes('private-credit'), false);
  assert.equal(normalizeQuota(weekly).resetDetails, null);
  assert.deepEqual(normalizeQuota({ ...weekly, rateLimitResetCredits: { availableCount: 2, credits: [] } }).resetDetails, []);
});

test('English presentation includes localized countdown, counts and errors', () => {
  const now = 1800000000000;
  const result = view.deriveView({ status: 'ok', remainingPercent: 75, resetsAt: (now + 36*3600000)/1000, updatedAt: now, resetCards: 2 }, now, 'UTC', 'en');
  assert.equal(result.statusText, 'Updated');
  assert.equal(result.countdownText, '1d 12h');
  assert.equal(result.cardsText, '2');
  assert.match(view.deriveView({status:'unavailable',errorCode:'signed_out'},now,'UTC','en').message, /Sign in/);
});

test('saved language is validated and persists without losing other settings', async () => {
  assert.equal(typeof monitor.readSettings, 'function');
  assert.equal(typeof monitor.saveSettings, 'function');
  const directory = await mkdtemp(join(tmpdir(), 'quota-settings-'));
  try {
    const path = join(directory, 'settings.json');
    assert.deepEqual(await monitor.readSettings(path), { language: 'auto' });
    await monitor.saveSettings({language:'en'},path);
    assert.equal((await monitor.readSettings(path)).language,'en');
    await assert.rejects(monitor.saveSettings({language:'invalid'},path));
    assert.equal(JSON.parse(await readFile(path,'utf8')).language,'en');
  } finally { await rm(directory,{recursive:true,force:true}); }
});

test('refresh coalesces simultaneous consumers and backs off after transient failures', async () => {
  assert.equal(typeof monitor.createQuotaCache,'function');
  let calls = 0, now = 0;
  let fail = true;
  const cache = monitor.createQuotaCache({ now:()=>now, query:async()=>{
    calls++; if(fail) throw Object.assign(new Error('private diagnostics'), {code:'network'});
    return weekly;
  }});
  await Promise.all([cache.refresh(),cache.refresh()]);
  assert.equal(calls,1);
  assert.equal(cache.state.errorCode,'network');
  assert.equal(JSON.stringify(cache.state).includes('private diagnostics'),false);
  now=14999; await cache.refreshIfDue(); assert.equal(calls,1);
  now=15000; fail=false; await cache.refreshIfDue(); assert.equal(calls,2);
  assert.equal(cache.state.status,'ok');
  now=75000; await cache.refreshIfDue(); assert.equal(calls,3);
});

test('repeated errors use 15, 30 and capped 60 second retries and catch up after sleep', async () => {
  let now=0,calls=0;
  const cache=monitor.createQuotaCache({now:()=>now,query:async()=>{calls++;throw Object.assign(new Error('offline'),{code:'network'});}});
  await cache.refresh();assert.equal(cache.state.nextRetryAt,15000);
  now=15000;await cache.refreshIfDue();assert.equal(cache.state.nextRetryAt,45000);
  now=45000;await cache.refreshIfDue();assert.equal(cache.state.nextRetryAt,105000);
  now=105000;await cache.refreshIfDue();assert.equal(cache.state.nextRetryAt,165000);
  now=3600000;await cache.refreshIfDue();assert.equal(calls,5);
});
