import test from 'node:test';
import assert from 'node:assert/strict';

let deriveView;
try {
  ({ deriveView } = await import('../public/app.mjs'));
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
