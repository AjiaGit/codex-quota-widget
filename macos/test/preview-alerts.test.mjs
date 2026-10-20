import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm,readFile,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createAnnouncementStore,queryExternal} from '../external.mjs';
const now=Date.parse('2026-10-17T02:00:00Z'),iso=value=>new Date(value).toISOString();
const url='https://x.com/thsottiaux/status/1000000000000000801';
const item=extra=>({id:url+'#regular',kind:'regular',sourceUrl:url,announcedAt:iso(now-60000),certainty:'announced',
  scheduledAt:iso(now+3600000),schedulePrecision:'instant',summary:'Global reset at 03:00 UTC.',statementBasis:'original',
  announcementBasis:'original',evidenceUpdatedAt:iso(now),sourceSites:['codex-reset.com'],...extra});
const input=(items,time=now)=>({status:'ok',stale:false,sourceUpdatedAt:iso(time),items,history:items});
async function tracked(file) {
  let clock=now-120000;
  const store=await createAnnouncementStore({file,now:()=>clock});
  await store.update(input([],clock));clock=now;
  return {store,setTime:time=>clock=time};
}
test('only trusted quota previews create unread, including an active preview on first use',async()=>{
  for(const row of [item({deliveredAt:iso(now-1000)}),item({kind:'banked',id:url+'#banked'}),
    item({certainty:'unconfirmed',sourceHint:'recent'}),item({announcementBasis:null}),
    item({scheduledAt:iso(now-1000)}),item({sourceWithdrawn:true})]) {
    const {store}=await tracked();await store.update(input([row]));assert.equal(store.alerts.unread.length,0,JSON.stringify(row));
  }
  const store=await createAnnouncementStore({now:()=>now});await store.update(input([item()]));
  assert.equal(store.alerts.unread.length,1);
});
test('meaningful deadline and scope changes re-notify once while ordinary wording and repeats stay read',async()=>{
  const {store}=await tracked();await store.update(input([item()]));
  const original=store.alerts.unread[0];assert.equal(typeof original.version,'string');
  await store.acknowledge([original]);
  await store.update(input([item({summary:'Global reset at 03:00 UTC. Enjoy!'})]));assert.equal(store.alerts.unread.length,0);
  await store.update(input([item({scheduledAt:iso(now+7200000)})]));assert.equal(store.alerts.unread.length,1);
  const updated=store.alerts.unread[0];assert.notEqual(updated.version,original.version);
  await store.acknowledge([original]);assert.equal(store.alerts.unread.length,1,'An old visible version cannot mark the new time as read');
  await store.acknowledge([updated]);await store.update(input([item({scheduledAt:iso(now+7200000),scope:'paid'})]));
  assert.equal(store.alerts.unread.length,1);
  await store.acknowledge(store.alerts.unread);await store.update(input([item({scheduledAt:iso(now+7200000),scope:'paid'})]));
  assert.equal(store.alerts.unread.length,0);
});
test('a completion clears a preview notice without creating another notification',async()=>{
  const {store}=await tracked();await store.update(input([item()]));
  await store.update(input([item({deliveredAt:iso(now),deliverySourceUrl:url,completionTimeBasis:'announcement'})]));
  assert.deepEqual(store.alerts.unread,[]);
});
test('only a correction explicitly linked to a previously known preview re-notifies',async()=>{
  const {store}=await tracked();await store.update(input([item()]));await store.acknowledge(store.alerts.unread);
  const correctedUrl='https://x.com/thsottiaux/status/1000000000000000802';
  const correction=item({sourceUrl:correctedUrl,id:correctedUrl+'#regular',announcedAt:iso(now),certainty:'unconfirmed',
    scheduledAt:null,correction:'cancelled',relatedUrls:[url],summary:'Global reset cancelled.'});
  await store.update(input([item(),correction]));assert.equal(store.alerts.unread.length,1);
  assert.equal(store.alerts.unread[0].id,correction.id);
  await store.acknowledge(store.alerts.unread);await store.update(input([item(),correction]));assert.equal(store.alerts.unread.length,0);
  const other=await tracked();await other.store.update(input([correction]));assert.equal(other.store.alerts.unread.length,0);
});
test('a stale older edit cannot roll back an already read schedule or re-notify',async()=>{
  const {store}=await tracked();const updated=item({scheduledAt:iso(now+7200000),evidenceUpdatedAt:iso(now)});
  await store.update(input([updated]));await store.acknowledge(store.alerts.unread);
  await store.update(input([item({evidenceUpdatedAt:iso(now-60000)})]));
  assert.equal(store.state.items[0].scheduledAt,updated.scheduledAt);assert.equal(store.alerts.unread.length,0);
});
test('new preview tracking survives restart and safely migrates old hint/completion unread',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-preview-'));
  try {
    const file=join(directory,'announcements.json'),{store}=await tracked(file);
    await store.update(input([item()]));await store.acknowledge(store.alerts.unread);
    let restarted=await createAnnouncementStore({file,now:()=>now});await restarted.update(input([item()]));
    assert.deepEqual(restarted.alerts.unread,[]);
    const saved=JSON.parse(await readFile(file,'utf8'));delete saved.alertTracking.previewVersions;
    saved.items=[item({certainty:'unconfirmed',sourceHint:'recent'})];saved.history=saved.items;
    saved.alertTracking.unread=[{id:url+'#regular',kind:'regular',sourceHint:true}];
    await writeFile(file,JSON.stringify(saved));restarted=await createAnnouncementStore({file,now:()=>now});
    assert.deepEqual(restarted.alerts.unread,[]);assert.equal(restarted.state.history.length,1);
  } finally {await rm(directory,{recursive:true,force:true});}
});
test('an explicitly related time reply updates one preview and keeps its verified time source',async()=>{
  const parent={id:url.split('/').at(-1),url,at:iso(now-120000),text:'We will perform a global reset.',kind:'signal'};
  const replyUrl='https://x.com/thsottiaux/status/1000000000000000803';
  const reply={id:replyUrl.split('/').at(-1),url:replyUrl,at:iso(now-60000),text:'Landing within the next 2 hours',kind:'signal',replying_to:'thsottiaux',in_reply_to_tweet_id:parent.id};
  const result=await queryExternal({now,fetchFn:async address=>({ok:true,json:async()=>address.endsWith('/api/feed')?
    {version:1,profile:{handle:'thsottiaux'},fetched_at:iso(now),tweets:[reply,parent],events:[]}:{coverage:'partial',events:[]}})});
  assert.equal(result.announcements.items.length,1);
  const row=result.announcements.items[0];assert.equal(row.sourceUrl,url);
  assert.equal(row.previewSourceUrl,replyUrl);
  assert.equal(row.scheduledAt,'2026-10-17T03:59:00.000Z');
});
test('passing the estimated window archives a preview and retires its unread dot',async()=>{
  const {store,setTime}=await tracked();await store.update(input([item()]));
  setTime(now+3600001);
  assert.equal(store.state.items.length,0);
  assert.equal(store.state.history[0].sourceUrl,url);
  assert.deepEqual(store.alerts.unread,[]);
});
