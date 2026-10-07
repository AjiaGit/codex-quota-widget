import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeResets, queryExternal } from '../external.mjs';

const now = Date.parse('2026-09-29T09:00:00Z');

test('public refresh queries only reset records and preserves confirmed announcements without forecasts', async () => {
  const urls=[];
  const event={kind:'regular',certainty:'announced',url:'https://example.org/reset',ts:'2026-09-29T08:00:00Z',announced_at:'2026-09-29T08:00:00Z'};
  const result=await queryExternal({now,fetchFn:async url=>{
    urls.push(url);
    return {ok:true,json:async()=>url.includes('whenreset')
      ? {schema:'whenreset/v1',generated_at:new Date(now).toISOString(),products:{codex:{scheduled:null,events:[event]}}}
      : {schema_version:1,generated_at:new Date(now).toISOString(),events:[event]}};
  }});
  assert.deepEqual(urls.sort(),['https://codexreset.ai/api/v1/resets.json','https://whenreset.app/api/v1/resets.json'].sort());
  assert.equal(Object.hasOwn(result,'forecast'),false);
  assert.equal(result.announcements.items[0].certainty,'announced');
  assert.equal(result.lastGlobal.sourceUrl,event.url);
});

test('fresh announcement data remains usable when the secondary reset feed is unavailable', async () => {
  const result=await queryExternal({now,fetchFn:async url=>{
    if(!url.includes('whenreset'))throw Error('offline');
    return {ok:true,json:async()=>({schema:'whenreset/v1',generated_at:new Date(now).toISOString(),products:{codex:{scheduled:null,events:[]}}})};
  }});
  assert.equal(result.status,'ok');
  assert.equal(result.announcements.status,'ok');
});

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

test('reconciliation requires two complete fresh valid feeds and includes schedules absent from history', async () => {
  const event={kind:'regular',url:'https://example.org/record',ts:'2026-09-28T00:00:00Z',announced_at:'2026-09-28T00:00:00Z'};
  const resets={schema_version:1,generated_at:new Date(now).toISOString(),events:[event]};
  const scheduled={day:'2026-09-30',scheduled_for:'2026-09-30T17:00:00Z',announced_at:'2026-09-28T00:00:00Z',certainty:'announced',url:'https://example.org/scheduled'};
  const announcements={schema:'whenreset/v1',generated_at:new Date(now).toISOString(),products:{codex:{scheduled,events:[]}}};
  const query=async(resetValue,announcementValue=announcements)=>queryExternal({now,fetchFn:async url=>{
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
