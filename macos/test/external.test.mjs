import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeAnnouncements, normalizeResets, queryExternal } from '../external.mjs';

const now = Date.parse('2026-09-29T09:00:00Z');

test('an expired but valid announcement response preserves its source time and explains the expiry', () => {
  const data={schema:'whenreset/v1',generated_at:'2026-09-26T00:00:00Z',products:{codex:{scheduled:null,events:[]}}};
  const result=normalizeAnnouncements(data,now);
  assert.equal(result.reason,'source-stale');
  assert.equal(result.sourceUpdatedAt,'2026-09-26T00:00:00.000Z');
  assert.equal(result.status,'unavailable');
  assert.equal(result.stale,true);
  assert.equal(normalizeAnnouncements({...data,schema:'invalid'},now).reason,'invalid-data');
});

test('a failed request and unusable announcement data have different reasons',async()=>{
  for(const [response,reason] of [
    [new Error('offline'),'request-failed'],
    [{schema:'unexpected',generated_at:new Date(now).toISOString()},'invalid-data'],
  ]) {
    const result=await queryExternal({now,fetchFn:async url=>{
      if(!url.includes('codex-reset.com'))throw new Error('offline');
      if(response instanceof Error)throw response;
      return {ok:true,json:async()=>response};
    }});
    assert.equal(result.announcements.reason,reason);
  }
});

test('an HTTP success with non-JSON content is unusable data rather than a connection failure',async()=>{
  const result=await queryExternal({now,fetchFn:async()=>({ok:true,json:async()=>{throw new SyntaxError('Not JSON');}})});
  assert.equal(result.announcements.reason,'invalid-data');
});

test('expired malformed schedules and imprecise source timestamps are not classified as source delays',()=>{
  const raw={schema:'whenreset/v1',generated_at:'2026-09-26T00:00:00Z',products:{codex:{scheduled:null,events:[]}}};
  for(const data of [
    {...raw,products:{codex:{scheduled:123,events:[]}}},
    {...raw,generated_at:'2026-09-26'},
    {...raw,generated_at:'2026-02-30T00:00:00Z'},
  ])assert.equal(normalizeAnnouncements(data,now).reason,'invalid-data');
});

test('public refresh queries only reset records and preserves confirmed announcements without forecasts', async () => {
  const urls=[];
  const event={id:'1000000000000000003',text:'Global reset by EOD.',url:'https://x.com/thsottiaux/status/1000000000000000003',at:'2026-09-29T08:00:00Z'};
  const result=await queryExternal({now,fetchFn:async url=>{
    urls.push(url);
    return {ok:true,json:async()=>url.includes('codex-reset.com')
      ? {version:1,fetched_at:new Date(now).toISOString(),profile:{handle:'thsottiaux'},stale:false,tweets:[event],events:[]}
      : {coverage:'partial',events:[],count:0,timezone:'UTC'}};
  }});
  assert.deepEqual(urls.sort(),['https://codex-reset.com/api/feed','https://codexreset.dev/api/status'].sort());
  assert.equal(Object.hasOwn(result,'forecast'),false);
  assert.equal(result.announcements.items[0].certainty,'announced');
  assert.equal(result.lastGlobal.sourceUrl,event.url);
});

test('fresh announcement data remains usable when the secondary reset feed is unavailable', async () => {
  const result=await queryExternal({now,fetchFn:async url=>{
    if(!url.includes('codex-reset.com'))throw Error('offline');
    return {ok:true,json:async()=>({version:1,fetched_at:new Date(now).toISOString(),profile:{handle:'thsottiaux'},stale:false,tweets:[],events:[]})};
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

test('partial providers cannot withdraw records by absence, even when both responses are fresh', async () => {
  const event={type:'global_reset',status:'recorded',source_url:'https://x.com/thsottiaux/status/1000000000000000004',announced_at:'2026-09-28T00:00:00Z',retrieved_at:new Date(now).toISOString(),time_basis:'announcement',evidence_text:'All propagated.'};
  const resets={coverage:'partial',events:[event],count:1,timezone:'UTC'};
  const announcements={version:1,fetched_at:new Date(now).toISOString(),profile:{handle:'thsottiaux'},stale:false,tweets:[],events:[]};
  const query=async(resetValue,announcementValue=announcements)=>queryExternal({now,fetchFn:async url=>{
    const value=url.includes('codex-reset.com')?announcementValue:resetValue;
    if(value instanceof Error)throw value;
    return {ok:true,json:async()=>value};
  }});
  const good=await query(resets);
  assert.equal(good.announcements.status,'ok');
  assert.equal(good.announcements.reconciledIds,undefined);
  for(const bad of [new Error('network'),{...resets,events:[{...event,retrieved_at:'2026-09-25T00:00:00Z'}]},{...resets,events:[event,{kind:'unexpected',url:'https://example.org/bad'}]}]) {
    assert.equal((await query(bad)).announcements.reconciledIds,undefined,'One unavailable, stale or malformed feed cannot withdraw cached records');
  }
  assert.equal((await query(resets,{...announcements,tweets:[{url:'javascript:invalid'}]})).announcements.reconciledIds,undefined);
});
