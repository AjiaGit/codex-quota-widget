import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeResets, normalizeForecast } from '../external.mjs';

const now = Date.parse('2026-09-29T09:00:00Z');

test('uses the latest recorded regular global reset and delivery evidence', () => {
  const result = normalizeResets({
    schema_version: 1, generated_at: '2026-09-29T08:56:59Z', events: [
      { kind: 'banked', date: '2026-09-28', announced_at: '2026-09-28T00:00:00Z' },
      { kind: 'regular', scope: 'paid', date: '2026-09-26',
        announced_at: '2026-09-26T00:07:13Z', delivered_at: '2026-09-26T18:17:54Z',
        url: 'https://x.com/example', delivered_source_url: 'https://x.com/delivery' },
    ],
  }, now);
  assert.deepEqual(result, {
    announcedAt: '2026-09-26T00:07:13Z', deliveredAt: '2026-09-26T18:17:54Z',
    scope: 'paid', sourceUrl: 'https://x.com/example', deliverySourceUrl: 'https://x.com/delivery',
    sourceUpdatedAt: '2026-09-29T08:56:59Z',
  });
});

test('does not claim delivery from an announcement alone', () => {
  const result = normalizeResets({ schema_version: 1, generated_at: '2026-09-29T08:56:59Z', events: [
    { kind: 'regular', scope: 'all', announced_at: '2026-09-26T00:07:13Z', delivered_at: null },
  ] }, now);
  assert.equal(result.deliveredAt, null);
  assert.equal(normalizeResets({ schema_version: 1, generated_at: '2026-09-26T00:00:00Z', events: [] }, now), null);
});

test('reads the published 24h, 48h and seven-day historical odds', () => {
  assert.deepEqual(normalizeForecast({
    schema_version: 1, generated_at: '2026-09-29T08:56:59Z', available: true,
    probabilities: { raw_24h: 0.1458, raw_48h: 0.3333, raw_7d: 0.6875 },
    source: 'https://whenreset.app/api/forecast',
  }, now), { next24h: 15, next48h: 33, next7d: 69, sourceUpdatedAt: '2026-09-29T08:56:59Z' });
});

test('declines unavailable, invalid and stale odds', () => {
  const sample = { schema_version: 1, generated_at: '2026-09-29T08:56:59Z', available: true,
    probabilities: { raw_24h: 0.1, raw_48h: 0.3, raw_7d: 0.6 } };
  assert.equal(normalizeForecast({ ...sample, available: false }, now), null);
  assert.equal(normalizeForecast({ ...sample, probabilities: { ...sample.probabilities, raw_48h: 1.5 } }, now), null);
  assert.equal(normalizeForecast({ ...sample, generated_at: '2026-09-27T00:00:00Z' }, now), null);
});
