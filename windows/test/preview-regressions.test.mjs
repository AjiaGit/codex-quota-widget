import test from 'node:test';
import assert from 'node:assert/strict';
import {queryExternal,createAnnouncementStore} from '../external.mjs';
import {parsePreviewTime} from '../public/preview.mjs';
import {deriveAnnouncementsView} from '../public/app.mjs';
// FABRICATED original posts. Each case reproduces a whole-change review finding.
const now=Date.parse('2026-10-17T02:00:00Z'),iso=value=>new Date(value).toISOString();
const url=id=>`https://x.com/thsottiaux/status/100000000000000${id}`;
const post=(id,text,at=now-60000,parent=null)=>({id:url(id).split('/').at(-1),url:url(id),text,at:iso(at),kind:'signal',
  ...(parent?{replying_to:'thsottiaux',in_reply_to_tweet_id:parent.id}:{} )});
async function fixture() {
  let clock=now-120000;
  const store=await createAnnouncementStore({now:()=>clock});
  await store.update({status:'ok',sourceUpdatedAt:iso(clock),items:[],history:[]});clock=now;
  return {store,async send(posts) {
    clock+=1000;
    const result=await queryExternal({now:clock,fetchFn:async address=>({ok:true,json:async()=>address.endsWith('/api/feed')?
      {version:1,profile:{handle:'thsottiaux'},fetched_at:iso(clock),tweets:posts,events:[]}:{coverage:'partial',events:[],resetArchiveSyncedAt:iso(clock)}})});
    await store.update(result.announcements);
  },ack:()=>store.acknowledge(store.alerts.unread)};
}
test('cancelling a merged time reply clears its parent deadline and notifies once without resurrecting the reply',async()=>{
  const f=await fixture(),a=post('301','We will perform a global reset.',now-120000),b=post('302','Landing within the next 2 hours',now-60000,a);
  await f.send([a,b]);await f.ack();
  const c=post('303','Global reset cancelled.',now,b);
  await f.send([c]);
  const parent=[...f.store.state.items,...f.store.state.history].find(row=>row.sourceUrl===a.url);
  assert.equal(parent.correction,'cancelled');assert.equal(parent.scheduledAt,null);
  assert.deepEqual(f.store.alerts.unread.map(row=>row.id),[c.url+'#regular']);
  await f.ack();await f.send([a,b,c]);assert.deepEqual(f.store.alerts.unread,[]);
  assert.equal(f.store.state.items.some(row=>row.sourceUrl===b.url),false);
});
test('a fresh reply-only time update alerts under the final canonical preview identity',async()=>{
  const f=await fixture(),a=post('304','We will perform a global reset.',now-120000);
  await f.send([a]);await f.ack();
  const b=post('305','Global reset at 06:00 UTC.',now-60000,a);await f.send([b]);
  assert.equal(f.store.state.items.length,1);assert.equal(f.store.state.items[0].scheduledAt,'2026-10-17T06:00:00.000Z');
  assert.deepEqual(f.store.alerts.unread.map(row=>row.id),[a.url+'#regular']);
});
test('same-post original cancellation and postponement re-alert only once and retire the old estimate',async()=>{
  for(const [text,correction] of [['Global reset cancelled.','cancelled'],['Global reset delayed.','delayed']]) {
    const f=await fixture(),a=post('306','Global reset at 05:00 UTC.');await f.send([a]);await f.ack();
    await f.send([{...a,text}]);
    const row=[...f.store.state.items,...f.store.state.history].find(row=>row.sourceUrl===a.url);
    assert.equal(row.correction,correction);assert.equal(row.scheduledAt,null);
    const visible=deriveAnnouncementsView(f.store.state,now+10000,'UTC','zh-CN').rows.find(record=>record.id===a.url+'#regular');
    assert.equal(visible.previewPriority,true,'A changed older preview must be easy to find after clicking its dot');
    assert.match(visible.display.title,correction==='cancelled'?/取消/:/延期/);
    assert.deepEqual(f.store.alerts.unread.map(row=>row.id),[a.url+'#regular']);
    await f.ack();await f.send([{...a,text}]);assert.deepEqual(f.store.alerts.unread,[]);
  }
});
test('cancelling a still-future preview re-alerts even when its original publication is two days old',async()=>{
  const f=await fixture(),a=post('313','Global reset at 2026-10-18T05:00:00Z.',now-48*3600000);
  await f.send([a]);await f.ack();await f.send([{...a,text:'Global reset cancelled.'}]);
  assert.equal(f.store.alerts.unread.length,1);
});
test('an authoritative edit from exact time to tomorrow removes the obsolete precise deadline',async()=>{
  const f=await fixture(),a=post('307','Global reset at 05:00 UTC.');await f.send([a]);await f.ack();
  await f.send([{...a,text:'Global reset tomorrow.'}]);
  assert.equal(f.store.state.items[0].scheduledAt,null);assert.equal(f.store.state.items[0].scheduleText,'tomorrow');
  assert.equal(f.store.alerts.unread.length,1);
});
test('date-qualified clocks use the associated date or retain the complete uncertain expression',()=>{
  assert.equal(parsePreviewTime('Global reset tomorrow at 07:00 UTC.','2026-10-17T02:00:00Z').scheduledAt,'2026-10-18T07:00:00.000Z');
  const calendar=parsePreviewTime('Global reset on October 19 at 07:00 UTC.','2026-10-17T02:00:00Z');
  assert.equal(calendar.scheduledAt,null);assert.match(calendar.scheduleText,/October 19.*07:00 UTC/);
});
test('an edited merged reply carries scope changes into the canonical preview and re-alerts',async()=>{
  const f=await fixture(),a=post('308','We will perform a global reset.',now-120000),b=post('309','Landing within the next 2 hours',now-60000,a);
  await f.send([a,b]);await f.ack();
  await f.send([a,{...b,text:'Landing within the next 2 hours for paid accounts'}]);
  assert.equal(f.store.state.items[0].scope,'paid');
  assert.deepEqual(f.store.alerts.unread.map(row=>row.id),[a.url+'#regular']);
});
test('the sole source action follows the completion statement actually displayed',()=>{
  const a=url('310'),b=url('311'),c=url('312');
  const row={id:a+'#regular',kind:'regular',sourceUrl:a,previewSourceUrl:b,announcedAt:iso(now-120000),
    deliveredAt:iso(now-1000),deliverySourceUrl:c,certainty:'announced',summary:'Global reset is complete.',completionTimeBasis:'announcement',statementBasis:'original'};
  const shown=deriveAnnouncementsView({items:[row]},now,'UTC','en').rows[0];
  assert.equal(shown.sourceUrl,c);
});
