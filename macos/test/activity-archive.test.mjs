import test from 'node:test';
import assert from 'node:assert/strict';
import {deriveResetActivityView,visibleAnnouncementView,announcementReadsForReading} from '../public/app.mjs';
import {createAnnouncementStore} from '../external.mjs';
import {t} from '../public/i18n.mjs';

// FABRICATED messages and account readings; never reads the signed-in account.
const now=Date.parse('2026-10-17T12:00:00Z'),hour=3600000,iso=value=>new Date(value).toISOString();
const url='https://x.com/thsottiaux/status/1000000000000000991';
const preview=extra=>({id:url+'#regular',kind:'regular',sourceUrl:url,announcedAt:iso(now-hour),
  certainty:'announced',announcementBasis:'original',statementBasis:'original',scheduledAt:iso(now+hour),
  scheduleText:'at 13:00 UTC',summary:'We will reset quota at 13:00 UTC.',...extra});
const feed=(items=[],history=[],clock=now)=>({status:'ok',stale:false,sourceUpdatedAt:iso(clock),items,history});

test('archived records stay folded and never count as current messages or visible unread',()=>{
  const history=Array.from({length:8},(_,i)=>({id:'old-'+i,kind:'regular',announcedAt:now-i*hour}));
  const activity={rows:[],history};
  const alerts={unread:history.map(row=>({...row,version:'v1'}))};
  const folded=visibleAnnouncementView(activity);
  assert.deepEqual(folded.rows,[]);
  assert.deepEqual(folded.history,[]);
  assert.equal(folded.historyTotal,8);
  assert.deepEqual(announcementReadsForReading(alerts,folded,true),[]);
  assert.equal(t('zh-CN','activityEmpty'),'暂无新消息');
  assert.equal(t('en','activityEmpty'),'No new messages');
});

test('history opens with three, appends three, and folds without losing stored records',()=>{
  const history=Array.from({length:8},(_,i)=>({id:'old-'+i,kind:'regular',announcedAt:now-i*hour,noticeVersion:'v1'}));
  const activity={rows:[],history};
  const alerts={unread:history.map(row=>({id:row.id,kind:row.kind,version:'v1'}))};
  const first=visibleAnnouncementView(activity,{historyOpen:true});
  assert.deepEqual(first.history.map(row=>row.id),['old-0','old-1','old-2']);
  assert.equal(first.historyNextCount,3);
  assert.deepEqual(announcementReadsForReading(alerts,first,true).map(row=>row.id),['old-0','old-1','old-2']);
  const second=visibleAnnouncementView(activity,{historyOpen:true,historyLimit:6});
  assert.equal(second.history.length,6);
  assert.equal(second.historyNextCount,2);
  const all=visibleAnnouncementView(activity,{historyOpen:true,historyLimit:9});
  assert.equal(all.history.length,8);
  assert.equal(all.historyNextCount,0);
  assert.deepEqual(visibleAnnouncementView(activity,{historyOpen:false,historyLimit:9}).history,[]);
  assert.equal(visibleAnnouncementView(activity,{historyOpen:true}).history.length,3);
  assert.equal(history.length,8);
});

test('current messages page independently of history and all valid previews remain outside it',()=>{
  const rows=Array.from({length:7},(_,i)=>({id:'current-'+i,announcedAt:now-i,previewPriority:i>=3}));
  const page=visibleAnnouncementView({rows,history:[{id:'old',announcedAt:now+1}]});
  assert.deepEqual(page.rows.map(row=>row.id),['current-3','current-4','current-5','current-6']);
  assert.equal(page.nextCount,3);
  assert.equal(page.historyTotal,1);
  assert.equal(visibleAnnouncementView({rows,history:[]},{limit:7}).rows.length,7);
});

test('a valid preview stays visible even when its source puts it in history',()=>{
  const item=preview({announcedAt:iso(now-30*hour),scheduledAt:iso(now+hour)});
  const activity=deriveResetActivityView(null,feed([], [item]),now,'UTC','zh-CN');
  assert.deepEqual(activity.rows.map(row=>row.id),[item.id]);
  assert.deepEqual(activity.history,[]);
  assert.match(activity.rows[0].display.facts.join(' '),/预计/);
  assert.doesNotMatch(activity.rows[0].display.title,/较早|后续/);
});

test('expired previews and day-old records archive without claiming quota reset completion',()=>{
  const expired=preview({scheduledAt:iso(now)});
  const oldHint={id:'hint',kind:'regular',certainty:'unconfirmed',sourceUrl:'https://example.invalid/hint',announcedAt:iso(now-24*hour)};
  const oldDone={...preview({id:'done',announcedAt:iso(now-26*hour),deliveredAt:iso(now-24*hour)})};
  const quota={status:'ok',recoveryHistory:{status:'ok',records:[{observedFrom:now-25*hour,detectedAt:now-24*hour,beforePercent:5,afterPercent:100}]}};
  const activity=deriveResetActivityView(quota,feed([expired,oldHint,oldDone]),now,'UTC','zh-CN');
  assert.deepEqual(activity.rows,[]);
  assert.equal(activity.history.length,4);
  const row=activity.history.find(row=>row.id===expired.id);
  assert.equal(row.completedText,'');
  assert.equal(row.display.category,'预告');
  assert.equal(row.display.status,'预计时段已过，暂无后续更新。');
  assert.match(activity.latestRecoveryText,/最近检测到额度恢复/);
});

test('linked important corrections resurface from history for a day without inventing completion',()=>{
  const parent=preview({scheduledAt:iso(now-hour)});
  const cancellation=preview({id:'cancel',sourceUrl:'https://x.com/thsottiaux/status/1000000000000000992',
    announcedAt:iso(now-60000),correction:'cancelled',relatedUrls:[url],scheduledAt:null});
  const activity=deriveResetActivityView(null,feed([], [parent,cancellation]),now,'UTC','zh-CN');
  assert.deepEqual(activity.rows.map(row=>row.id),['cancel']);
  assert.equal(activity.rows[0].completedText,'');
  assert.match(activity.rows[0].display.title,/取消/);
  const later=deriveResetActivityView(null,feed([], [parent,cancellation]),now+24*hour,'UTC','zh-CN');
  assert.deepEqual(later.rows,[]);
});

test('an archived preview with a changed deadline resurfaces and re-notifies only its new version',async()=>{
  let clock=now;
  const store=await createAnnouncementStore({now:()=>clock});
  const item=preview();
  await store.update(feed([item]));
  const original=store.alerts.unread[0];
  await store.acknowledge([original]);
  clock=now+2*hour;
  await store.update(feed([item],[],clock));
  assert.equal(deriveResetActivityView(null,store.state,clock,'UTC','en').rows.length,0);
  const changed={...item,scheduledAt:iso(now+4*hour)};
  await store.update(feed([changed],[],clock));
  assert.equal(store.alerts.unread.length,1);
  assert.notEqual(store.alerts.unread[0].version,original.version);
  const shown=visibleAnnouncementView(deriveResetActivityView(null,store.state,clock,'UTC','en'));
  assert.equal(shown.rows[0].id,item.id);
  assert.deepEqual(announcementReadsForReading(store.alerts,{rows:[{id:item.id,noticeVersion:original.version}]},true),[]);
  await store.acknowledge(announcementReadsForReading(store.alerts,shown,true));
  await store.update(feed([changed],[],clock));
  assert.deepEqual(store.alerts.unread,[]);
});

test('an important old-post correction still surfaces while the service keeps its new reminder active',()=>{
  const item=preview({announcedAt:iso(now-30*hour),correction:'cancelled',scheduledAt:null,previewPriority:true});
  const cached={...feed([], [item]),lastFetchedAt:now,previewTrace:[{id:item.id,notifiedAt:now}]};
  const activity=deriveResetActivityView(null,cached,now,'UTC','en');
  assert.deepEqual(activity.rows.map(row=>row.id),[item.id]);
  assert.equal(activity.rows[0].previewPriority,true);
  assert.match(activity.rows[0].display.title,/cancelled/);
  const offline=deriveResetActivityView(null,{...cached,status:'unavailable',stale:true},now+25*hour,'UTC','en');
  assert.deepEqual(offline.rows,[],'An old cached priority flag cannot prevent automatic archiving forever');
  assert.equal(offline.history.length,1);
});
