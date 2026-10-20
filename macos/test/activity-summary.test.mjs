import test from 'node:test';
import assert from 'node:assert/strict';
import {deriveRecoveryView,deriveResetActivityView,deriveAnnouncementsView,visibleAnnouncementView,announcementIdsForReading} from '../public/app.mjs';

// FABRICATED: a later public message cannot move the account's recovery time.
const now=Date.parse('2026-10-16T06:00:00Z');
const record=age=>({observedFrom:now-age-60000,detectedAt:now-age,beforePercent:20,afterPercent:80});
const quota=records=>({status:'ok',recoveryHistory:{status:'ok',records}});
const message=extra=>({id:'fabricated-public',kind:'regular',sourceUrl:'https://example.invalid/fabricated',
  announcedAt:new Date(now-60000).toISOString(),certainty:'unconfirmed',kindKnown:true,
  sourceSites:['codex-reset.com'],...extra});

test('the recovery summary uses the newest valid account record, independent of newer public messages',()=>{
  const state=quota([record(3600000),record(120000)]);
  for(const [language,expected] of [['zh-CN','最近检测到额度恢复：10/16 13:58'],['en','Last quota recovery noticed: 10/16, 13:58']]) {
    const local=deriveRecoveryView(state,language,'Asia/Shanghai',now);
    assert.equal(local.latestDetectedAt,now-120000);
    assert.equal(local.latestText,expected);
    const activity=deriveResetActivityView(state,{items:[message()]},now,'Asia/Shanghai',language);
    assert.equal(activity.rows[0].id,'fabricated-public');
    assert.equal(activity.latestRecoveryText,expected);
    assert.equal(activity.rows.filter(row=>row.kind==='recovery').length,2,'No inferred event merging');
  }
});

test('no recovery and unavailable tracking have distinct summaries, including account changes and failed reads',()=>{
  const ready=deriveRecoveryView(quota([]),'zh-CN','UTC',now);
  assert.equal(ready.latestDetectedAt,null);
  assert.equal(ready.latestText,'最近检测到额度恢复：暂无记录');
  for(const state of [{status:'loading'},{status:'unavailable',recoveryHistory:quota([record(60000)]).recoveryHistory},
    {status:'ok',recoveryHistory:{status:'unavailable',records:[record(60000)]}}]) {
    const view=deriveRecoveryView(state,'zh-CN','UTC',now);
    assert.equal(view.latestDetectedAt,null);
    assert.equal(view.latestText,'最近检测到额度恢复：暂不可用');
  }
  const unsaved=quota([record(60000)]);unsaved.recoveryHistory.status='unsaved';
  assert.equal(deriveRecoveryView(unsaved,'en','UTC',now).latestDetectedAt,now-60000);
});

test('invalid or future records cannot replace the historical account summary',()=>{
  const valid=record(120000);
  const records=[record(-60000),{...record(60000),afterPercent:20},{...record(60000),beforePercent:20.5},
    {...record(60000),observedFrom:null},valid];
  const view=deriveRecoveryView(quota(records),'en','UTC',now);
  assert.equal(view.rows.length,1);
  assert.equal(view.latestDetectedAt,valid.detectedAt);
  assert.match(view.latestText,/13:58|05:58/);
});

test('public messages and website observations have separate labels, attribution and verification help',()=>{
  for(const [language,label,title,observationLabel] of [
    ['zh-CN','公开消息 · 待核实','额度重置相关消息','网站监测 · 完成消息'],
    ['en','Public message · Unverified','Quota-reset news','Website monitoring · Completion update']]) {
    const pending=deriveAnnouncementsView({items:[message()]},now,'UTC',language).rows[0];
    assert.equal(pending.display.recordLabel,label);
    assert.equal(pending.display.title,title);
    assert.match(pending.display.label,/codex-reset\.com/,'Collecting website remains visible');
    assert.equal(pending.display.category,language==='en'?'Unverified update':'待核实消息');
    assert.equal(pending.display.status,'','The repeated explanation belongs in the disclosure');
    assert.ok(pending.display.help);
    const observed=deriveAnnouncementsView({items:[message({certainty:'announced',deliveredAt:new Date(now-60000).toISOString(),
      statementBasis:'observation',scope:'monitoring',completionTimeBasis:'observation'})]},now,'UTC',language).rows[0];
    assert.equal(observed.display.recordLabel,observationLabel);
    assert.match(observed.display.title,language==='en'?/monitoring/:/监测账号/);
  }
});

test('three-record batches preserve chronology, collapse and unread boundaries without truncating history',()=>{
  const rows=Array.from({length:7},(_,i)=>({id:'row-'+i,kind:'regular',announcedAt:100-i}));
  const activity={rows:rows.filter((_,i)=>i%2===0),history:rows.filter((_,i)=>i%2===1)};
  const before=JSON.stringify(activity),alerts={unread:rows};
  for(const limit of [undefined,0,NaN,-1]) {
    const first=visibleAnnouncementView(activity,{limit});
    assert.deepEqual(first.rows.map(row=>row.id),['row-0','row-2','row-4']);
    assert.equal(first.nextCount,1);assert.equal(first.canCollapse,false);
    assert.deepEqual(announcementIdsForReading(alerts,first,true),['row-0','row-2','row-4']);
  }
  const second=visibleAnnouncementView(activity,{limit:6});
  assert.equal(second.rows.length,4);assert.equal(second.nextCount,0);assert.equal(second.canCollapse,true);
  assert.equal(announcementIdsForReading(alerts,second,true).includes('row-1'),false);
  const all=visibleAnnouncementView(activity,{limit:9});
  assert.equal(all.rows.length,4);assert.equal(all.nextCount,0);
  assert.equal(visibleAnnouncementView(activity,{historyOpen:true}).history.length,3);
  assert.equal(visibleAnnouncementView(activity,{limit:3}).rows.length,3);
  assert.equal(JSON.stringify(activity),before);
});
