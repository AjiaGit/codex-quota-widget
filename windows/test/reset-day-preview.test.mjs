import test from 'node:test';
import assert from 'node:assert/strict';
import {queryExternal,createAnnouncementStore} from '../external.mjs';
import {parsePreviewTime} from '../public/preview.mjs';
import {deriveAnnouncementsView} from '../public/app.mjs';

// Fabricated identities and posts: a reset-day reply crosses the Pacific date boundary.
const now=Date.parse('2026-10-22T10:00:00Z');
const url=id=>`https://x.com/thsottiaux/status/100000000000000${id}`;
const parent={id:'1000000000000000901',url:url('0901'),at:'2026-10-22T06:50:00Z',kind:'candidate',
  text:'Day 17/ You expected a feature, but no, it’s reset day today.\n\nPlease enable account protection; you don’t want to wait for an incident.'};
const reply={id:'1000000000000000902',url:url('0902'),at:'2026-10-22T06:51:00Z',kind:'signal',
  text:'Lands tomorrow before 10am PST.',is_reply:true,replying_to:'thsottiaux',in_reply_to_tweet_id:parent.id};
async function query(posts) {
  return queryExternal({now,fetchFn:async address=>({ok:true,json:async()=>address.endsWith('/api/feed')?
    {version:1,profile:{handle:'thsottiaux'},fetched_at:new Date(now).toISOString(),stale:false,tweets:posts,events:[]}:
    {coverage:'partial',events:[]}})});
}
test('an explicit reset-day context makes its same-author Lands reply a timed quota preview',async()=>{
  const result=await query([parent,reply]);
  const row=result.announcements.items.find(item=>item.sourceUrl===reply.url);
  assert.equal(row?.certainty,'announced');
  assert.equal(row.kind,'regular');
  assert.equal(row.announcementBasis,'original');
  assert.equal(row.deliveredAt,null);
  assert.equal(row.scope,null,'A campaign day does not prove which accounts are eligible');
  assert.equal(row.scheduleText,'tomorrow before 10am PST');
  // Publication was October 21 at 22:51 PST: tomorrow is October 22 in PST.
  assert.equal(row.scheduledAt,'2026-10-22T18:00:00.000Z');
  assert.equal(row.schedulePrecision,'deadline');
  const shown=deriveAnnouncementsView(result.announcements,now,'Asia/Shanghai','zh-CN').rows.find(item=>item.id===row.id);
  assert.equal(shown.previewPriority,true);
});
test('a previously observed unconfirmed reply creates one reminder when it becomes a verified preview',async()=>{
  const store=await createAnnouncementStore({now:()=>now});
  await store.update((await query([reply])).announcements);
  assert.deepEqual(store.alerts.unread,[]);
  const recognized=(await query([parent,reply])).announcements;
  await store.update(recognized);
  assert.deepEqual(store.alerts.unread.map(item=>item.id),[reply.url+'#regular']);
  await store.update(recognized);
  assert.equal(store.alerts.unread.length,1);
  await store.acknowledge(store.alerts.unread);
  await store.update(recognized);
  assert.deepEqual(store.alerts.unread,[]);
});
test('Lands replies cannot borrow a feature, uncertain, cancelled, foreign or out-of-campaign topic',async()=>{
  const cases=[
    [{...parent,text:'Day 17/ Faster search today.'},reply],
    [{...parent,text:'Day 17/ Maybe it’s reset day today.'},reply],
    [{...parent,text:'Day 17/ It is not reset day today.'},reply],
    [{...parent,text:'Day 17/ If it’s reset day today, we will say so.'},reply],
    [{...parent,text:'Day 17/ It’s reset day today.\nGlobal reset cancelled.'},reply],
    [{...parent,text:'Day 29/ It’s reset day today.'},reply],
    [{...parent,at:'2026-09-22T06:50:00Z'},reply],
    [parent,{...reply,replying_to:'someone_else'}],
    [parent,{...reply,in_reply_to_tweet_id:'1000000000000000999'}],
    [parent,{...reply,text:'Maybe lands tomorrow before 10am PST.'}],
    [parent,{...reply,text:'Landed yesterday.'}],
    [reply],
  ];
  for(const posts of cases) {
    const result=await query(posts);
    const store=await createAnnouncementStore({now:()=>now});
    await store.update(result.announcements);
    assert.deepEqual(store.alerts.unread,[],posts.map(item=>item.text).join('\n'));
    assert.equal(result.announcements.items.some(item=>item.certainty==='announced'),false);
  }
});
test('explicit Pacific clocks anchor relative days in the stated zone and retain deadline precision',()=>{
  for(const [text,published,want,precision] of [
    ['Lands tomorrow before 10am PST.','2026-10-22T06:51:00Z','2026-10-22T18:00:00.000Z','deadline'],
    ['Lands tomorrow before 10am PDT.','2026-10-22T06:51:00Z','2026-10-22T17:00:00.000Z','deadline'],
    ['Lands tomorrow before 10am PST.','2026-10-22T08:01:00Z','2026-10-23T18:00:00.000Z','deadline'],
    ['Lands today at 12am PST.','2026-10-22T07:51:00Z','2026-10-21T08:00:00.000Z','instant'],
    ['Lands today by 12pm PDT.','2026-10-22T06:51:00Z','2026-10-21T19:00:00.000Z','deadline'],
    ['Lands before 9:30pm PST tomorrow.','2026-10-22T06:51:00Z','2026-10-23T05:30:00.000Z','deadline'],
  ]) {
    const result=parsePreviewTime(text,published);
    assert.equal(result.scheduledAt,want,text);
    assert.equal(result.schedulePrecision,precision);
  }
});
test('ambiguous Pacific calendar expressions retain the full words instead of inventing an exact time',()=>{
  for(const expression of ['on October 24 before 10am PST','before 10am PST next Monday',
    'tomorrow before 10am PT','today before 10am PST tomorrow']) {
    const result=parsePreviewTime('Lands '+expression+'.',reply.at);
    assert.equal(result.scheduledAt,null);
    assert.equal(result.scheduleText,expression);
    assert.equal(result.schedulePrecision,'text');
  }
});
test('a Lands reply cannot turn a reset-button or reset-UI update into a quota promise',async()=>{
  for(const text of ['The global reset button redesign is ready for testing.','Day 17/ Global reset UI improvements.']) {
    const result=await query([{...parent,text},reply]);
    const store=await createAnnouncementStore({now:()=>now});await store.update(result.announcements);
    assert.deepEqual(store.alerts.unread,[],text);
  }
});
test('campaign context retains a later governing condition, pronoun negation or cancellation',async()=>{
  for(const text of ['Day 17/ Reset\nIt will happen only if all checks pass.',
    'Day 17/ It’s reset day today.\nIt will happen only if all checks pass.',
    'Day 17/ It’s reset day today.\nIt is not happening today.',
    'Day 17/ It’s reset day today.\nIt is cancelled.']) {
    const result=await query([{...parent,text},reply]);
    const store=await createAnnouncementStore({now:()=>now});await store.update(result.announcements);
    assert.deepEqual(store.alerts.unread,[],text);
  }
});
test('unsupported bare calendar qualifiers cannot silently become the publication date',()=>{
  for(const expression of ['before 10am PST Friday','before 10am PST October 24',
    'this Friday before 10am PST','tomorrow morning before 10am PST',
    '2026-10-24 before 10am PST','before 10am PST 2026-10-24']) {
    const result=parsePreviewTime('Lands '+expression+'.',reply.at);
    assert.equal(result.scheduledAt,null,expression);
    assert.equal(result.scheduleText,expression);
    assert.equal(result.schedulePrecision,'text');
  }
});
test('Pacific dates require a complete explicit day expression instead of a guessed default date',()=>{
  for(const expression of ['before 10am PST 10/24','before 10am PST Oct 24','before 10am PST Fri',
    'in 2 days before 10am PST','tomorrow before 10am PST Oct 24','tomorrow before 10am PST for a future date',
    'Friday tomorrow before 10am PST','before 10am PST']) {
    const result=parsePreviewTime('Lands '+expression+'.',reply.at);
    assert.equal(result.scheduledAt,null,expression);
    assert.equal(result.scheduleText,expression);
    assert.equal(result.schedulePrecision,'text');
  }
  assert.equal(parsePreviewTime('Global reset tomorrow before 10am PST.',reply.at).scheduledAt,'2026-10-22T18:00:00.000Z');
});
