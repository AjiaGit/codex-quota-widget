import test from 'node:test';
import assert from 'node:assert/strict';
import {deriveView, deriveResetDetails, deriveAnnouncementsView, derivePublicStatus} from '../public/app.mjs';
const now=Date.parse('2026-10-01T02:00:00Z');
const quota={status:'ok',updatedAt:now,resetsAt:now/1000+3600,remainingPercent:73,resetCards:1,resetDetails:[{title:'Actual API grant',grantedAt:now/1000-3600}]};
const announcements={status:'ok',stale:false,sourceUpdatedAt:new Date(now).toISOString(),items:[],history:[]};

test('a stale empty announcement cache does not assert there are no announcements',()=>{
  const result=deriveAnnouncementsView(announcements,now+86400001,'UTC','en');
  assert.equal(result.notice,'Announcement information unavailable');
});
test('announcement freshness is independent of retired forecast data and the successful HTTP status',()=>{
  const state={status:'ok',announcements};
  assert.equal(derivePublicStatus(state,now,'UTC','en'),'');
  assert.match(derivePublicStatus(state,now+86400001,'UTC','en'),/pending update/);
});
test('stale personal reset details are not shown as a currently available grant',()=>{
  assert.equal(deriveResetDetails(quota,'en','UTC',now).rows.length,1);
  const result=deriveResetDetails(quota,'en','UTC',now+600001);
  assert.deepEqual(result.rows,[]);
  assert.match(result.note,/expired/);
});
test('future query timestamps and malformed quota percentages never show a usable quota',()=>{
  for(const invalid of [{...quota,updatedAt:now+3600000},{...quota,remainingPercent:NaN},{...quota,remainingPercent:101}])
    assert.equal(deriveView(invalid,now,'UTC','en').percentText,'—');
});
