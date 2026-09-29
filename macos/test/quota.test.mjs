import test from 'node:test';
import assert from 'node:assert/strict';

let normalizeQuota;
try {
  ({ normalizeQuota } = await import('../quota.mjs'));
} catch {
  // The first TDD run must fail as an assertion before the module exists.
}

test('exposes a quota normalizer', () => {
  assert.equal(typeof normalizeQuota, 'function');
});

test('selects only the seven-day Codex window and reports remaining percent', () => {
  assert.deepEqual(normalizeQuota({
    rateLimitsByLimitId: {
      codex: {
        primary: { usedPercent: 61, windowDurationMins: 10080, resetsAt: 1791073298 },
        secondary: { usedPercent: 90, windowDurationMins: 300, resetsAt: 1790500000 },
      },
      base_model_inference: {
        primary: { usedPercent: 0, windowDurationMins: 10080, resetsAt: 1791278281 },
      },
    },
  }), { remainingPercent: 39, resetsAt: 1791073298, plan: 'unknown', fiveHour: null, resetCards: null });
});

test('finds the weekly window in secondary or the legacy single-bucket view', () => {
  assert.deepEqual(normalizeQuota({ rateLimitsByLimitId: { codex: {
    primary: { usedPercent: 30, windowDurationMins: 300, resetsAt: 1 },
    secondary: { usedPercent: 25, windowDurationMins: 10080, resetsAt: 1791073298 },
  } } }), { remainingPercent: 75, resetsAt: 1791073298, plan: 'unknown', fiveHour: null, resetCards: null });
  assert.deepEqual(normalizeQuota({ rateLimits: {
    primary: { usedPercent: 0, windowDurationMins: 10080, resetsAt: 1791073298 },
  } }), { remainingPercent: 100, resetsAt: 1791073298, plan: 'unknown', fiveHour: null, resetCards: null });
});

test('declines to label a missing or invalid window as weekly usage', () => {
  const shortWindow = { rateLimitsByLimitId: { codex: {
    primary: { usedPercent: 20, windowDurationMins: 300, resetsAt: 1791073298 },
  } } };
  assert.equal(normalizeQuota(shortWindow), null);
  assert.equal(normalizeQuota({ rateLimitsByLimitId: { codex: {
    primary: { usedPercent: 101, windowDurationMins: 10080, resetsAt: 1791073298 },
  } } }), null);
  assert.equal(normalizeQuota({ rateLimitsByLimitId: { codex: {
    primary: { usedPercent: 20, windowDurationMins: 10080, resetsAt: null },
  } } }), null);
});

test('shows a five-hour window for Plus regardless of primary/secondary ordering', () => {
  const sample = { rateLimitsByLimitId: { codex: {
    planType: 'plus',
    primary: { usedPercent: 40, windowDurationMins: 300, resetsAt: 1790679000 },
    secondary: { usedPercent: 25, windowDurationMins: 10080, resetsAt: 1791073298 },
  } } };
  assert.deepEqual(normalizeQuota(sample), {
    remainingPercent: 75, resetsAt: 1791073298, plan: 'plus', resetCards: null,
    fiveHour: { remainingPercent: 60, resetsAt: 1790679000 },
  });
});

test('hides five-hour usage for Pro and does not guess an unknown plan', () => {
  const bucket = {
    primary: { usedPercent: 25, windowDurationMins: 10080, resetsAt: 1791073298 },
    secondary: { usedPercent: 40, windowDurationMins: 300, resetsAt: 1790679000 },
  };
  assert.deepEqual(normalizeQuota({ rateLimitsByLimitId: { codex: { ...bucket, planType: 'prolite' } } }), {
    remainingPercent: 75, resetsAt: 1791073298, plan: 'pro', fiveHour: null, resetCards: null,
  });
  assert.deepEqual(normalizeQuota({ rateLimitsByLimitId: { codex: bucket } }), {
    remainingPercent: 75, resetsAt: 1791073298, plan: 'unknown', fiveHour: null, resetCards: null,
  });
});

test('Plus without a reported five-hour window leaves it unavailable', () => {
  const bucket = { primary: { usedPercent: 25, windowDurationMins: 10080, resetsAt: 1791073298 } };
  assert.deepEqual(normalizeQuota({ rateLimitsByLimitId: { codex: bucket } }, 'plus'), {
    remainingPercent: 75, resetsAt: 1791073298, plan: 'plus', fiveHour: null, resetCards: null,
  });
});

test('uses the authoritative available reset-card count', () => {
  const rateLimits = { rateLimitsByLimitId: { codex: {
    planType: 'pro', primary: { usedPercent: 25, windowDurationMins: 10080, resetsAt: 1791073298 },
  } }, rateLimitResetCredits: { availableCount: 2, credits: [] } };
  assert.equal(normalizeQuota(rateLimits).resetCards, 2);
  assert.equal(normalizeQuota({ ...rateLimits, rateLimitResetCredits: { credits: [] } }).resetCards, null);
});
