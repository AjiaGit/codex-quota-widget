import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeResets, normalizeForecast, queryExternal } from '../external.mjs';

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

test('reconciliation requires two complete fresh valid feeds and includes schedules absent from history', async () => {
  const event={kind:'regular',url:'https://example.org/record',ts:'2026-09-28T00:00:00Z',announced_at:'2026-09-28T00:00:00Z'};
  const resets={schema_version:1,generated_at:new Date(now).toISOString(),events:[event]};
  const scheduled={day:'2026-09-30',scheduled_for:'2026-09-30T17:00:00Z',announced_at:'2026-09-28T00:00:00Z',certainty:'announced',url:'https://example.org/scheduled'};
  const announcements={schema:'whenreset/v1',generated_at:new Date(now).toISOString(),products:{codex:{scheduled,events:[]}}};
  const query=async(resetValue,announcementValue=announcements)=>queryExternal({now,fetchFn:async url=>{
    if(url.includes('forecast'))return {ok:true,json:async()=>({})};
    const value=url.includes('whenreset')?announcementValue:resetValue;
    if(value instanceof Error)throw value;
    return {ok:true,json:async()=>value};
  }});
  const good=await query(resets);
  assert.deepEqual(good.announcements.reconciledIds,['https://example.org/record#regular','https://example.org/scheduled#regular']);
  for(const bad of [new Error('network'),{...resets,generated_at:'2026-09-25T00:00:00Z'},{...resets,events:[event,{kind:'unexpected',url:'https://example.org/bad'}]}]) {
    assert.equal((await query(bad)).announcements.reconciledIds,undefined,'One unavailable, stale or malformed feed cannot withdraw cached records');
  }
  assert.equal((await query(resets,{...announcements,products:{codex:{scheduled:{...scheduled,kind:'unexpected'},events:[]}}})).announcements.reconciledIds,undefined);
});
