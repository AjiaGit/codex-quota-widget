import test from 'node:test';
import assert from 'node:assert/strict';
import {createAnnouncementStore,queryExternal} from '../external.mjs';
import {externalRefreshDelay} from '../monitor.mjs';
const now=Date.parse('2026-10-17T02:00:00Z'),url='https://x.com/thsottiaux/status/1000000000000000991';
test('quiet periods still check for the first preview each minute and source failures back off',()=>{
  assert.equal(externalRefreshDelay({announcements:{items:[]}},now),60000);
  assert.equal(externalRefreshDelay({announcements:{providerHealth:[{status:'unavailable'},{status:'unavailable'}]}},now,3),240000);
});
test('public timing trace distinguishes first seen, classification, notification and indicator report without message bodies',async()=>{
  let clock=now;
  const store=await createAnnouncementStore({now:()=>clock});
  const row={kind:'regular',sourceUrl:url,certainty:'announced',announcedAt:'2026-10-17T01:59:00Z',
    summary:'FABRICATED BODY MUST NOT ENTER TIMING TRACE',announcementBasis:'original',statementBasis:'original'};
  await store.update({status:'ok',sourceUpdatedAt:new Date(clock).toISOString(),items:[row],history:[]});
  assert.equal(store.state.previewTrace.length,1);
  const first=store.state.previewTrace[0];assert.equal(first.firstSeenAt,now);assert.equal(first.classifiedAt,now);assert.equal(first.notifiedAt,now);
  assert.equal(first.indicatorReportedAt,null);assert.equal(JSON.stringify(store.state.previewTrace).includes('FABRICATED BODY'),false);
  clock+=15000;
  assert.equal(typeof store.recordIndicator,'function');
  await store.recordIndicator([{id:url+'#regular',version:'wrong'}]);assert.equal(store.state.previewTrace[0].indicatorReportedAt,null);
  await store.recordIndicator(store.alerts.unread);assert.equal(store.state.previewTrace[0].indicatorReportedAt,now+15000);
  assert.equal(store.alerts.unread.length,1,'Reporting a rendered dot does not acknowledge the message');
});
test('small provider clock skew does not reject a freshly generated feed while future post times stay invalid',async()=>{
  const result=await queryExternal({now,fetchFn:async address=>({ok:true,json:async()=>address.endsWith('/api/feed')?
    {version:1,profile:{handle:'thsottiaux'},fetched_at:'2026-10-17T02:00:01Z',tweets:[{id:url.split('/').at(-1),url,text:'Global reset landing soon.',at:'2026-10-17T01:59:00Z'}],events:[]}:
    {coverage:'partial',events:[],resetArchiveSyncedAt:'2026-10-17T02:00:01Z'}})});
  assert.equal(result.announcements.status,'ok');
  assert.equal(result.announcements.items[0].certainty,'announced');
  const store=await createAnnouncementStore({now:()=>now});await store.update(result.announcements);
  assert.equal(store.state.stale,false);assert.equal(store.alerts.unread.length,1);
});
