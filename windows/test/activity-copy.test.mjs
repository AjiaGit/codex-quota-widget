import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { queryExternal, createAnnouncementStore } from '../external.mjs';
import { deriveAnnouncementsView, deriveRecoveryView } from '../public/app.mjs';

// FABRICATED: attribution must follow actual evidence, never just a post URL.
const now = Date.parse('2026-10-15T06:00:00Z');
const url = 'https://x.com/thsottiaux/status/1000000000000000701';
const record = extra => ({id:url+'#banked',kind:'banked',sourceUrl:url,
  announcedAt:'2026-10-15T04:00:00Z',certainty:'announced',...extra});
function view(item, historical=false, language='zh-CN') {
  const result=deriveAnnouncementsView({status:'ok',sourceUpdatedAt:new Date(now).toISOString(),
    items:historical?[]:[item],history:historical?[item]:[]},now,'UTC',language);
  return [...result.rows,...result.history][0];
}

test('a post link alone cannot turn a monitoring record into a publisher statement',()=>{
  const item=record({sourceSites:['codexreset.dev'],deliveredAt:'2026-10-15T05:00:00Z'});
  const row=view(item);
  assert.equal(row.display.title,'codexreset.dev 表示：重置卡已发放');
  assert.equal(row.phase,'delivered');
  assert.doesNotMatch(row.display.title,/Tibo/);
  assert.match(row.display.label,/codexreset.dev/);
  const legacy=view(record({deliveredAt:item.deliveredAt}));
  assert.match(legacy.display.label,/收录网站未记录/);
  assert.doesNotMatch(legacy.display.label,/codex-reset\.com/);
});

test('verified original statement metadata separates a promise from reported completion for both kinds',()=>{
  for(const [kind,subject,action] of [['banked','重置卡','赠送重置卡'],['regular','额度','重置额度']]){
    const item=record({kind,announcementBasis:'original',sourceSites:['codex-reset.com']});
    const upcoming=view(item);
    assert.equal(upcoming.display.title,`Tibo 预告：将${action}`);
    assert.equal(upcoming.display.completionMissing,false);
    assert.match(upcoming.plannedText,/具体时间尚未公布/);
    const done=view({...item,deliveredAt:'2026-10-15T05:00:00Z',completionTimeBasis:'announcement'});
    assert.equal(done.display.title,`Tibo 表示：${subject}已${kind==='banked'?'发放':'重置'}`);
    assert.match(done.completedText,/完成消息发布/);
    assert.match(done.display.detailFacts.join(' '),/不能据此确认本账号/);
  }
});

test('withdrawal preserves completed evidence and waiting never asserts non-delivery',()=>{
  const completed=view(record({sourceWithdrawn:true,deliveredAt:'2026-10-15T05:00:00Z',
    completionTimeBasis:'announcement',sourceSites:['codex-reset.com']}));
  assert.equal(completed.display.title,'Tibo 表示：重置卡已发放');
  assert.match(completed.display.status,/撤下/);
  assert.match(completed.completedText,/完成消息发布/);
  const waiting=view(record({scheduledAt:'2026-10-15T05:00:00Z',sourceSites:['codex-reset.com']}));
  assert.match(waiting.display.title,/预告：将赠送重置卡/);
  assert.match(waiting.display.status,/预计时间已过.*发放完成消息/);
  assert.doesNotMatch(waiting.display.status,/尚未发放/);
});

test('site hints never guess an event kind and unknown historical messages never become future promises',()=>{
  for(const kind of ['banked','regular']){
    const hint=view(record({kind,kindKnown:false,certainty:'unconfirmed',sourceHint:'active'}));
    assert.equal(hint.display.title,'重置相关消息待核实');
    assert.match(hint.display.label,/收录网站未记录/);
    assert.match(hint.display.status,/暂无法判断具体事项/);
    assert.equal(hint.display.completionMissing,false);
    const historical=view(record({kind}),true);
    assert.doesNotMatch(historical.display.title,/将赠送|将重置/);
    assert.match(historical.display.status,/是否已.*尚不明确/);
  }
  const recovered=deriveRecoveryView({status:'ok',recoveryHistory:{status:'ok',records:[{
    observedFrom:now-60000,detectedAt:now,beforePercent:20,afterPercent:80}]}},'zh-CN','UTC',now);
  assert.equal(recovered.rows[0].display.title,'本账号额度已恢复');
});

test('provider attribution survives store persistence, partial mirrors and restart without unread changes',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-copy-'));
  try{
    const primary={version:1,fetched_at:new Date(now).toISOString(),profile:{handle:'thsottiaux'},tweets:[{
      id:'1000000000000000701',url,text:'We will grant a banked reset.',at:'2026-10-15T04:00:00Z'}],events:[]};
    const external=await queryExternal({now,fetchFn:async provider=>({ok:true,json:async()=>provider.includes('/api/feed')?primary:{events:[],coverage:'partial'}})});
    const item=external.announcements.items[0];
    assert.deepEqual(item.sourceSites,['codex-reset.com']);
    assert.equal(item.announcementBasis,'original');
    const file=join(directory,'announcements.json'), store=await createAnnouncementStore({file,now:()=>now});
    await store.update(external.announcements);
    const alerts=store.alerts;
    await store.update({...external.announcements,items:[record({sourceSites:['codexreset.dev']})]});
    assert.deepEqual(store.alerts,alerts);
    const restarted=await createAnnouncementStore({file,now:()=>now});
    const persisted=restarted.state.items[0];
    assert.deepEqual(persisted.sourceSites,['codex-reset.com','codexreset.dev']);
    assert.equal(persisted.announcementBasis,'original');
    assert.match(view(persisted).display.title,/^Tibo 预告/);
    assert.equal(view(persisted).display.label,'消息收录：codex-reset.com / codexreset.dev');
  }finally{await rm(directory,{recursive:true,force:true});}
});
