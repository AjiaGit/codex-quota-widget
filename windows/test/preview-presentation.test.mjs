import test from 'node:test';
import assert from 'node:assert/strict';
import * as presentation from '../public/app.mjs';
const {deriveAnnouncementsView,deriveResetActivityView,visibleAnnouncementView}=presentation;
const now=Date.parse('2026-10-15T05:30:00Z'),url='https://x.com/thsottiaux/status/1000000000000000901';
const preview={id:url+'#regular',sourceUrl:url,kind:'regular',announcedAt:'2026-10-15T04:56:07Z',certainty:'announced',
  announcementBasis:'original',statementBasis:'original',summary:'Landing within the next 2 hours',scheduleText:'within the next 2 hours',
  scheduledFrom:'2026-10-15T04:56:07Z',scheduledAt:'2026-10-15T06:56:07Z',schedulePrecision:'window',sourceSites:['codex-reset.com']};
const feed=items=>({status:'ok',sourceUpdatedAt:new Date(now).toISOString(),items,history:[]});
test('a preview exposes its original body and local estimated deadline without a disclosure or duplicate source link',()=>{
  for(const language of ['zh-CN','en']) {
    const row=deriveAnnouncementsView(feed([preview]),now,'Asia/Shanghai',language).rows[0];
    assert.equal(row.previewPriority,true);
    assert.equal(row.previewText,'Landing within the next 2 hours');
    assert.match(row.plannedText,/14:56/);
    assert.match(row.plannedText,language==='en'?/before|by/i:/前/);
    assert.equal(row.monitorSourceUrl,null);
    assert.equal(typeof row.noticeVersion,'string');
    assert.equal(row.display.summary,'','The visible body is not repeated inside message details');
  }
});
test('active previews remain ahead of newer reports while paging and collapse retain every record',()=>{
  const reports=Array.from({length:7},(_,i)=>({...preview,id:`report-${i}`,certainty:'unconfirmed',announcedAt:new Date(now-i*1000).toISOString(),announcementBasis:null}));
  const activity=deriveResetActivityView({status:'unavailable'},feed([preview,...reports]),now,'UTC','en');
  const first=visibleAnnouncementView(activity);assert.equal(first.rows[0].id,preview.id);assert.equal(first.rows.length,3);
  assert.equal(first.nextCount,3);assert.equal(visibleAnnouncementView(activity,{limit:9}).rows.length,8);
  assert.equal(visibleAnnouncementView(activity,{limit:3}).rows.length,3);
});
test('a past estimated window loses preview priority without claiming completion',()=>{
  const result=deriveAnnouncementsView(feed([preview]),now+3*3600000,'UTC','zh-CN');
  const row=[...result.rows,...result.history][0];assert.equal(row.previewPriority,false);
  assert.match(row.display.status,/预计.*已过/);assert.equal(row.completedText,'');
});
test('textual EOD is shown literally while a missing time is labeled unknown',()=>{
  const textual={...preview,scheduledAt:null,scheduledFrom:null,schedulePrecision:'text',scheduleText:'by EOD PST time'};
  assert.match(deriveAnnouncementsView(feed([textual]),now,'UTC','en').rows[0].plannedText,/EOD PST time/);
  const missing={...textual,scheduleText:null,schedulePrecision:null};
  assert.match(deriveAnnouncementsView(feed([missing]),now,'UTC','zh-CN').rows[0].plannedText,/时间.*未公布/);
});
test('read requests include only the actually visible message version',()=>{
  assert.equal(typeof presentation.announcementReadsForReading,'function');
  const {announcementReadsForReading}=presentation;
  const row=deriveAnnouncementsView(feed([preview]),now,'UTC','en').rows[0];
  const alerts={unread:[{id:row.id,kind:'regular',version:row.noticeVersion}]};
  assert.deepEqual(announcementReadsForReading(alerts,{rows:[row]},true),[{id:row.id,version:row.noticeVersion}]);
  assert.deepEqual(announcementReadsForReading(alerts,{rows:[row]},false),[]);
  assert.deepEqual(announcementReadsForReading({unread:[{...alerts.unread[0],version:'changed'}]},{rows:[row]},true),[]);
});
