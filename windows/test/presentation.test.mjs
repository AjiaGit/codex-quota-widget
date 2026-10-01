import test from 'node:test';
import assert from 'node:assert/strict';

let deriveView, deriveExternalView;
try {
  ({ deriveView, deriveExternalView } = await import('../public/app.mjs'));
} catch {
  // The first TDD run fails through the feature assertion below.
}

const reset = 1791073298 * 1000;

test('shows local reset time and remaining time for a fresh weekly sample', () => {
  assert.equal(typeof deriveView, 'function');
  const view = deriveView({ status: 'ok', remainingPercent: 39, resetsAt: reset / 1000,
    updatedAt: reset - 65 * 60 * 1000 }, reset - 60 * 60 * 1000, 'Asia/Hong_Kong');
  assert.equal(view.percentText, '39%');
  assert.match(view.resetText, /2026.*10.*04.*08:21/);
  assert.equal(view.countdownText, '1小时');
  assert.equal(view.tone, 'warning');
});

test('shows reset cards and the five-hour window only for Plus', () => {
  const now = reset - 60 * 60 * 1000;
  const plus = deriveView({ status: 'ok', plan: 'plus', resetCards: 2,
    remainingPercent: 39, resetsAt: reset / 1000, updatedAt: now,
    fiveHour: { remainingPercent: 55, resetsAt: (now + 2 * 60 * 60 * 1000) / 1000 },
  }, now, 'Asia/Hong_Kong');
  assert.equal(plus.cardsText, '2 次');
  assert.equal(plus.showFiveHour, true);
  assert.equal(plus.fiveHourText, '55% 剩余');
  const pro = deriveView({ status: 'ok', plan: 'pro', resetCards: 0,
    remainingPercent: 39, resetsAt: reset / 1000, updatedAt: now,
    fiveHour: { remainingPercent: 55, resetsAt: (now + 2 * 60 * 60 * 1000) / 1000 },
  }, now, 'Asia/Hong_Kong');
  assert.equal(pro.cardsText, '0 次');
  assert.equal(pro.showFiveHour, false);
});

test('labels external reset history and odds separately', () => {
  assert.equal(typeof deriveExternalView, 'function');
  const view = deriveExternalView({ status: 'ok',
    lastGlobal: { announcedAt: '2026-09-26T00:07:13Z', deliveredAt: '2026-09-26T18:17:54Z', scope: 'paid', sourceUpdatedAt: '2026-09-29T08:56:59Z' },
    forecast: { next24h: 15, next48h: 33, next7d: 69, sourceUpdatedAt: '2026-09-29T08:56:59Z' },
  }, 'Asia/Hong_Kong','zh-CN',Date.parse('2026-09-29T09:00:00Z'));
  assert.match(view.announcementText, /09.*26.*08:07/);
  assert.match(view.deliveryText, /09.*27.*02:17/);
  assert.equal(view.oddsText, '24 小时 15% · 48 小时 33% · 7 天 69%');
});

test('hides an old percentage rather than presenting it as current', () => {
  assert.equal(typeof deriveView, 'function');
  const view = deriveView({ status: 'ok', remainingPercent: 39, resetsAt: reset / 1000,
    updatedAt: reset - 12 * 60 * 1000 }, reset - 60 * 1000, 'Asia/Hong_Kong');
  assert.equal(view.percentText, '—');
  assert.equal(view.statusText, '数据已过期');
});

test('does not keep showing a percentage after the reset instant', () => {
  assert.equal(typeof deriveView, 'function');
  const view = deriveView({ status: 'ok', remainingPercent: 39, resetsAt: reset / 1000,
    updatedAt: reset - 60 * 1000 }, reset + 1000, 'Asia/Hong_Kong');
  assert.equal(view.percentText, '—');
  assert.equal(view.statusText, '等待新周期数据');
});
