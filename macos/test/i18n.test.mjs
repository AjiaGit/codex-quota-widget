import test from 'node:test';
import assert from 'node:assert/strict';
import { dictionaries, resolveLanguage, t } from '../public/i18n.mjs';
import { deriveResetDetails } from '../public/app.mjs';
test('locale selection follows Chinese systems, respects manual selection and falls back to English',()=>{
  assert.equal(resolveLanguage('auto','zh-Hans-CN'),'zh-CN');
  assert.equal(resolveLanguage('auto','fr-FR'),'en');
  assert.equal(resolveLanguage('en','zh-CN'),'en');
  assert.equal(resolveLanguage('zh-CN','en-US'),'zh-CN');
  assert.deepEqual(Object.keys(dictionaries.en).sort(),Object.keys(dictionaries['zh-CN']).sort());
  assert.equal(t('unknown','refresh'),'Refresh now');
});
test('unknown and empty reset detail lists remain distinct and missing dates are not invented',()=>{
  const fresh={status:'ok',updatedAt:Date.now(),resetsAt:Date.now()/1000+3600,remainingPercent:50};
  assert.match(deriveResetDetails({...fresh,resetDetails:null}).note,/not provided/);
  assert.match(deriveResetDetails({...fresh,resetDetails:[]}).note,/No detail rows/);
  const result=deriveResetDetails({...fresh,resetDetails:[{title:null,grantedAt:null,expiresAt:null}]});
  assert.equal(result.rows[0].granted,'Granted: Not provided');
  assert.equal(result.rows[0].expires,'Expires: Not provided');
});
