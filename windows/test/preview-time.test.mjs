import test from 'node:test';
import assert from 'node:assert/strict';
import { queryExternal, createAnnouncementStore } from '../external.mjs';

// Fabricated public identities and response bodies; exact expectations are hand-derived.
const now=Date.parse('2026-10-15T05:30:00Z');
const url=id=>`https://x.com/thsottiaux/status/100000000000000${id}`;
const post=(id,text,extra={})=>({id:url(id).split('/').at(-1),url:url(id),at:'2026-10-15T04:56:07Z',text,kind:'signal',...extra});
async function query(posts,time=now) {
  return queryExternal({now:time,fetchFn:async address=>({ok:true,json:async()=>address.endsWith('/api/feed')?
    {version:1,profile:{handle:'thsottiaux'},fetched_at:new Date(time).toISOString(),stale:false,tweets:posts,events:[]}:
    {coverage:'partial',events:[]}})});
}
test('relative preview deadline starts at original publication and survives persistence normalization',async()=>{
  const data=await query([post('201','Global reset landing within the next 2 hours.')]);
  const row=data.announcements.items[0];
  assert.equal(row.certainty,'announced');
  assert.equal(row.scheduleText,'within the next 2 hours');
  assert.equal(row.scheduledFrom,'2026-10-15T04:56:07.000Z');
  assert.equal(row.scheduledAt,'2026-10-15T06:56:07.000Z');
  assert.equal(row.schedulePrecision,'window');
  const store=await createAnnouncementStore({now:()=>now});
  await store.update(data.announcements);
  assert.equal(store.state.items[0].scheduledFrom,'2026-10-15T04:56:07.000Z');
  assert.equal(store.state.items[0].scheduleText,'within the next 2 hours');
});
test('a time reply to an explicit Reset day in the verified campaign has quota context',async()=>{
  const parent=post('202','The reports of my reset button being lost are greatly exaggerated\n\nDay 10/ Reset',{kind:'other',at:'2026-10-15T04:55:51Z'});
  const reply=post('203','Landing within the next 2 hours',{is_reply:true,replying_to:'thsottiaux',in_reply_to_tweet_id:parent.id});
  const result=await query([reply,parent]);
  const row=result.announcements.history.find(item=>item.sourceUrl===reply.url);
  assert.equal(row?.certainty,'announced');
  assert.equal(row.kind,'regular');
  assert.equal(row.statementBasis,'original');
  assert.equal(row.scheduledAt,'2026-10-15T06:56:07.000Z');
  assert.deepEqual(row.relatedUrls,[parent.url]);
});
test('activity slogans outside their verified campaign or about features cannot supply quota context',async()=>{
  for(const [text,time,author] of [
    ['Day 10/ Faster editor',now,'thsottiaux'],['Day 29/ Reset',now,'thsottiaux'],
    ['Day 10/ Reset',Date.parse('2026-11-15T05:30:00Z'),'thsottiaux'],
    ['Day 10/ Reset',now,'someone_else'],['Day 10/ Maybe reset?',now,'thsottiaux'],
  ]) {
    const stamp=new Date(time-120000).toISOString();
    const parent=post('204',text,{kind:'other',at:stamp});
    const reply=post('205','Landing within the next 2 hours',{at:stamp,is_reply:true,replying_to:author,in_reply_to_tweet_id:parent.id});
    assert.equal((await query([parent,reply],time)).announcements.history.some(item=>item.certainty==='announced'),false);
  }
});
test('explicit UTC and ISO times keep their stated precision while EOD stays textual',async()=>{
  for(const [text,wantAt,wantText] of [
    ['Global reset at 07:00 UTC.','2026-10-15T07:00:00.000Z','at 07:00 UTC'],
    ['Global reset at 2026-10-15T09:00:00+02:00.','2026-10-15T07:00:00.000Z','at 2026-10-15T09:00:00+02:00'],
    ['Global reset landing by EOD PST time.',null,'by EOD PST time'],
    ['Global reset tomorrow.',null,'tomorrow'],
  ]) {
    const row=(await query([post('206',text)])).announcements.items[0];
    assert.equal(row.scheduledAt,wantAt,text);
    assert.equal(row.scheduleText,wantText,text);
  }
});
test('a reset preview without a promised time never borrows the fetch time',async()=>{
  const row=(await query([post('207','We will perform a global reset.')])).announcements.items[0];
  assert.equal(row.scheduledAt,null);
  assert.equal(row.scheduleText,null);
  assert.equal(row.schedulePrecision,null);
});
