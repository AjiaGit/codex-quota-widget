import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, rm} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import * as presentation from '../public/app.mjs';
const {deriveResetActivityView,derivePublicNotice}=presentation;
import {createAnnouncementStore,normalizeAnnouncements} from '../external.mjs';

const now=Date.parse('2026-10-07T04:00:00Z');
const item=(id,age,extra={})=>({id,kind:'regular',sourceUrl:`https://example.org/${id}`,announcedAt:new Date(now-age).toISOString(),...extra});
const recovery=(age)=>({observedFrom:now-age-60000,detectedAt:now-age,beforePercent:45,afterPercent:99});

test('a local public request failure replaces the prior source reason while preserving saved records',()=>{
  assert.equal(typeof presentation.publicRequestFailure,'function');
  for(const reason of ['source-stale','invalid-data']){
    const state={status:'ok',announcements:{status:'unavailable',reason,stale:true,sourceUpdatedAt:new Date(now-80*3600000).toISOString(),history:[item('saved',60000)],items:[]}};
    const original=JSON.stringify(state);
    const failed=presentation.publicRequestFailure(state);
    assert.equal(failed.announcements.reason,'request-failed');
    assert.equal(derivePublicNotice(failed,now,'UTC','en').failed,true);
    assert.equal(failed.announcements.history.length,1);
    assert.equal(failed.announcements.sourceUpdatedAt,state.announcements.sourceUpdatedAt);
    assert.equal(JSON.stringify(state),original);
  }
});

test('retaining a pending announcement after a fresh incomplete update does not claim a stale source',async()=>{
  let clock=now;
  const store=await createAnnouncementStore({now:()=>clock});
  await store.update({status:'ok',sourceUpdatedAt:new Date(clock).toISOString(),items:[item('pending',60000,{certainty:'announced'})],history:[]});
  clock+=60000;
  await store.update({status:'ok',sourceUpdatedAt:new Date(clock).toISOString(),items:[],history:[]});
  assert.equal(store.state.stale,true);
  assert.equal(store.state.items.length,1);
  const current=derivePublicNotice({status:'ok',announcements:store.state},clock,'UTC','en');
  const expired=derivePublicNotice({status:'ok',announcements:{...store.state,reason:'source-stale'}},clock,'UTC','en');
  assert.equal(current.visible,true);
  assert.equal(current.reason,null);
  assert.notEqual(current.title,expired.title);
  assert.equal(current.help,'');
});

test('expired source data remains distinct from a request failure through the cache and public notice',async()=>{
  let clock=now-80*3600000;
  const sourceTime=new Date(clock).toISOString();
  const store=await createAnnouncementStore({now:()=>clock});
  const raw={schema:'whenreset/v1',generated_at:sourceTime,products:{codex:{scheduled:null,events:[{kind:'regular',url:'https://example.org/saved',announced_at:sourceTime}]}}};
  await store.update(normalizeAnnouncements(raw,clock));
  const fetched=store.state.lastFetchedAt;
  clock=now;
  await store.update(normalizeAnnouncements(raw,clock));
  const expired=derivePublicNotice({status:'ok',announcements:store.state},clock,'Asia/Shanghai','zh-CN');
  assert.equal(expired.reason,'source-stale');
  assert.equal(expired.failed,false);
  assert.equal(expired.visible,true);
  assert.equal(expired.hasCache,true);
  assert.match(expired.sourceUpdatedText,/10\/04.*04:00/);
  assert.equal(store.state.lastFetchedAt,fetched,'An old source response does not become a successful fresh retrieval');
  assert.equal(store.state.history.length,1,'The stale response preserves saved records');
  await store.update({status:'unavailable',reason:'request-failed'});
  const failed=derivePublicNotice({status:'unavailable',announcements:store.state},clock,'Asia/Shanghai','zh-CN');
  assert.equal(failed.reason,'request-failed');
  assert.equal(failed.failed,true);
  assert.notEqual(failed.title,expired.title);
  assert.equal(failed.sourceUpdatedText,expired.sourceUpdatedText);
  await store.update({status:'unavailable',reason:'invalid-data'});
  const invalid=derivePublicNotice({status:'unavailable',announcements:store.state},clock,'Asia/Shanghai','zh-CN');
  assert.equal(invalid.reason,'invalid-data');
  assert.notEqual(invalid.title,failed.title);
  assert.notEqual(invalid.title,expired.title);
  await store.update(normalizeAnnouncements({...raw,generated_at:new Date(clock).toISOString()},clock));
  const refreshed=derivePublicNotice({status:'ok',announcements:store.state},clock,'UTC','en');
  assert.equal(refreshed.visible,false);
  assert.equal(refreshed.reason,null);
});

test('compact activity keeps every confirmed pending event and the latest personal and public records',()=>{
  const quota={status:'ok',recoveryHistory:{status:'ok',records:[recovery(60000),recovery(120000)]}};
  const feed={status:'ok',sourceUpdatedAt:new Date(now).toISOString(),items:[
    item('latest',30000),item('older',180000),
    item('grant',240000,{kind:'banked',certainty:'announced'}),
    item('reset',300000,{certainty:'announced',scheduledAt:new Date(now+3600000).toISOString()}),
  ],history:[]};
  const original=JSON.stringify([quota,feed]);
  const view=deriveResetActivityView(quota,feed,now,'Asia/Shanghai','en');
  assert.ok(Array.isArray(view.featuredRows),'The default list separates featured records from earlier ones');
  assert.deepEqual(view.featuredRows.map(row=>row.id||row.detectedAt),['latest',now-60000,'grant','reset']);
  assert.deepEqual(view.earlierRows.map(row=>row.id||row.detectedAt),[now-120000,'older']);
  assert.equal(JSON.stringify([quota,feed]),original,'Presentation does not mutate or erase stored records');
});

test('last successful public fetch survives a failed refresh and restart, separate from source publication',async()=>{
  const dir=await mkdtemp(join(tmpdir(),'quota-fetch-time-'));
  try{
    let clock=now;
    const file=join(dir,'announcements.json');
    let store=await createAnnouncementStore({file,now:()=>clock});
    await store.update({status:'ok',stale:false,sourceUpdatedAt:new Date(now-3600000).toISOString(),items:[item('saved',180000)],history:[]});
    assert.equal(store.state.lastFetchedAt,now);
    clock+=60000;
    await store.update({status:'unavailable'});
    assert.equal(store.state.lastFetchedAt,now);
    store=await createAnnouncementStore({file,now:()=>clock});
    assert.equal(store.state.lastFetchedAt,now);
    const notice=derivePublicNotice({status:'unavailable',announcements:store.state},clock,'Asia/Shanghai','en');
    assert.equal(notice.hasCache,true);
    assert.match(notice.lastFetchedText,/12:00/);
    assert.ok(!notice.lastFetchedText.includes('11:00'),'Source generation time is not represented as retrieval time');
  }finally{await rm(dir,{recursive:true,force:true});}
});

test('public refresh failure without cache differs from successful empty data without affecting account data',()=>{
  assert.equal(typeof derivePublicNotice,'function');
  const fresh={status:'ok',announcements:{status:'ok',stale:false,sourceUpdatedAt:new Date(now).toISOString(),items:[],history:[]}};
  assert.equal(derivePublicNotice(fresh,now,'UTC','en').visible,false);
  const failed=derivePublicNotice({status:'unavailable',announcements:{status:'unavailable',items:[],history:[]}},now,'UTC','en');
  assert.equal(failed.visible,true);
  assert.equal(failed.hasCache,false);
  assert.equal(failed.lastFetchedText,'');
});

test('account recovery display omits percentages and groups the local timezone',()=>{
  const quota={status:'ok',recoveryHistory:{status:'ok',records:[recovery(60000)]}};
  const row=deriveResetActivityView(quota,{items:[],history:[]},now,'Asia/Shanghai','zh-CN').rows[0];
  assert.ok(row.display,'A recovery has its own compact display');
  assert.equal(row.display.title,'本账号额度已恢复');
  assert.doesNotMatch(JSON.stringify(row.display),/45%|99%|→/);
  assert.match(row.display.facts[0],/本机发现.*11:59/);
  assert.doesNotMatch(row.display.facts[0],/UTC/);
  assert.match(row.display.help,/不是准确重置/);
});

test('source-reported completion remains distinct from confirmed delivery',()=>{
  const feed={status:'ok',items:[item('reported',60000,{summaryZh:'来源称已执行额度重置，适用所有账号。',scope:'all'})],history:[]};
  const row=presentation.deriveAnnouncementsView(feed,now,'Asia/Shanghai','zh-CN').rows[0];
  assert.ok(row.display,'Public records have compact display facts');
  assert.equal(row.phase,'unconfirmed');
  assert.equal(row.display.title,'额度重置消息');
  assert.equal(row.display.completionMissing,true);
  assert.match(row.display.facts[0],/发布.*11:59/);
  assert.match(row.display.scope,/(?:网站|来源)标注/);
});

test('compact planned times keep an explicit offset when a future event crosses DST',()=>{
  const clock=Date.parse('2026-10-31T12:00:00Z');
  const row=presentation.deriveAnnouncementsView({items:[{id:'dst',kind:'regular',certainty:'announced',sourceUrl:'https://example.org/dst',announcedAt:new Date(clock).toISOString(),scheduledAt:'2026-11-02T12:00:00Z'}],history:[]},clock,'America/Los_Angeles','en').rows[0];
  assert.ok(row.display);
  assert.match(row.display.facts[0],/UTC-08:00/);
  assert.doesNotMatch(row.display.detailFacts.join(' '),/UTC-07:00/);
});

test('collapsed earlier and history announcements remain unread until those sections are opened',()=>{
  const activity={featuredRows:[{id:'featured',kind:'regular'}],earlierRows:[{id:'earlier',kind:'banked'}],history:[{id:'history',kind:'regular'}]};
  const alerts={unread:[{id:'featured',kind:'regular'},{id:'earlier',kind:'banked'},{id:'history',kind:'regular'}]};
  assert.equal(typeof presentation.visibleAnnouncementView,'function');
  assert.deepEqual(presentation.announcementIdsForReading(alerts,presentation.visibleAnnouncementView(activity),true),['featured']);
  assert.deepEqual(presentation.announcementIdsForReading(alerts,presentation.visibleAnnouncementView(activity,{earlierOpen:true,historyOpen:true}),true),['featured','earlier','history']);
});

test('negated and conditional source summaries never turn into visible claims of completion',()=>{
  for(const summary of ['No quota was reset; the earlier report was incorrect.','If your quota was reset, please report it.']){
    const row=presentation.deriveAnnouncementsView({items:[item('conditional',60000,{summary})],history:[]},now,'UTC','en').rows[0];
    assert.equal(row.phase,'unconfirmed');
    assert.doesNotMatch(row.display.title,/was reset|completed|delivered/i);
    assert.equal(row.display.completionMissing,true);
  }
});
