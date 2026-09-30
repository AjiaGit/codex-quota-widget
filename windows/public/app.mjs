import { t, resolveLanguage, formatDate } from './i18n.mjs';
const TEN_MINUTES = 10 * 60 * 1000;
function formatCountdown(milliseconds, language) {
  const minutes=Math.max(0,Math.ceil(milliseconds/60000));
  const days=Math.floor(minutes/1440),hours=Math.floor((minutes%1440)/60),rest=minutes%60;
  return days?t(language,'daysHours',{days,hours}):hours?t(language,rest?'hoursMinutes':'hoursOnly',{hours,minutes:rest}):t(language,'minutesOnly',{minutes:rest});
}
export function deriveView(state,now=Date.now(),timeZone=Intl.DateTimeFormat().resolvedOptions().timeZone,language='zh-CN') {
  const unavailable=(statusText,message)=>({statusText,message,percentText:'—',ringPercent:0,tone:'muted',resetText:'—',countdownText:'—',updatedText:'—',cardsText:'—',showFiveHour:false,fiveHourText:'—',fiveHourResetText:'—'});
  if(state?.status==='loading')return unavailable(t(language,'loading'),t(language,'querying'));
  if(state?.status!=='ok')return unavailable(t(language,'unavailable'),t(language,state?.errorCode||'query_failed'));
  const resetMs=state.resetsAt*1000;
  if(!Number.isFinite(state.updatedAt)||now-state.updatedAt>TEN_MINUTES)return unavailable(t(language,'stale'),t(language,'waitingData'));
  if(!Number.isFinite(resetMs)||now>=resetMs)return unavailable(t(language,'waiting'),t(language,'resetPassed'));
  const percent=Math.max(0,Math.min(100,Math.round(state.remainingPercent))),shortReset=state.fiveHour?.resetsAt*1000;
  const shortValid=state.plan==='plus'&&Number.isFinite(shortReset)&&shortReset>now&&Number.isFinite(state.fiveHour?.remainingPercent)&&state.fiveHour.remainingPercent>=0&&state.fiveHour.remainingPercent<=100;
  return {statusText:t(language,'updated'),message:t(language,'weekly'),percentText:`${percent}%`,ringPercent:percent,tone:percent<=10?'danger':percent<=50?'warning':'healthy',resetText:formatDate(resetMs,timeZone,language),countdownText:formatCountdown(resetMs-now,language),updatedText:formatDate(state.updatedAt,timeZone,language),cardsText:Number.isSafeInteger(state.resetCards)&&state.resetCards>=0?t(language,state.resetCards===1?'resetOne':'resetCount',{count:state.resetCards}):'—',showFiveHour:state.plan==='plus',fiveHourText:shortValid?t(language,'percentRemaining',{percent:Math.round(state.fiveHour.remainingPercent)}):t(language,'unavailable'),fiveHourResetText:shortValid?formatDate(shortReset,timeZone,language):'—'};
}
export function deriveExternalView(state,timeZone=Intl.DateTimeFormat().resolvedOptions().timeZone,language='zh-CN') {
  const last=state?.status==='ok'?state.lastGlobal:null,forecast=state?.status==='ok'?state.forecast:null,scope=t(language,last?.scope==='paid'?'paid':last?.scope==='all'?'all':'unknownScope');
  return {announcementText:last?.announcedAt?`${formatDate(Date.parse(last.announcedAt),timeZone,language)} · ${scope}`:t(language,'unavailable'),deliveryText:last?.deliveredAt?`${formatDate(Date.parse(last.deliveredAt),timeZone,language)} · ${t(language,'delivered')}`:t(language,'deliveryUnknown'),oddsText:forecast?t(language,'oddsValue',{a:forecast.next24h,b:forecast.next48h,c:forecast.next7d}):t(language,'unavailable'),sourceText:forecast?.sourceUpdatedAt?`${t(language,'dataTime')} ${formatDate(Date.parse(forecast.sourceUpdatedAt),timeZone,language)}`:t(language,'sourceUnavailable')};
}
export function deriveResetDetails(state,language='en',timeZone=Intl.DateTimeFormat().resolvedOptions().timeZone) {
  const rows=state?.status==='ok'&&Array.isArray(state.resetDetails)?state.resetDetails:null;
  return {note:t(language,rows===null?'detailsUnknown':rows.length?'detailsPartial':'detailsEmpty'),rows:(rows||[]).map(row=>({title:row.title||t(language,'genericReset'),description:row.description||'',granted:t(language,'granted')+': '+(row.grantedAt?formatDate(row.grantedAt*1000,timeZone,language):t(language,'dateUnknown')),expires:t(language,'expires')+': '+(row.expiresAt?formatDate(row.expiresAt*1000,timeZone,language):t(language,'dateUnknown'))}))};
}
if(typeof document!=='undefined') {
  document.body.dataset.embedded=String(new URLSearchParams(location.search).get('embedded')==='1');
  const byId=id=>document.getElementById(id),root=byId('card'),refreshButton=byId('refresh');
  let state={status:'loading'},externalState={status:'loading'},loading=false,setting='auto';
  const language=()=>resolveLanguage(setting,navigator.language);
  function render() {
    const lang=language(),view=deriveView(state,Date.now(),undefined,lang);
    document.documentElement.lang=lang;document.title=t(lang,'brand');
    document.querySelectorAll('[data-i18n]').forEach(node=>node.textContent=t(lang,node.dataset.i18n));
    root.dataset.tone=view.tone;root.style.setProperty('--ring-value',`${view.ringPercent}%`);
    for(const[id,key]of Object.entries({percent:'percentText',status:'statusText',caption:'message',reset:'resetText',countdown:'countdownText',updated:'updatedText',cards:'cardsText','five-hour-value':'fiveHourText','five-hour-reset':'fiveHourResetText'}))byId(id).textContent=view[key];
    byId('caption').hidden=view.percentText!=='—';
    byId('five-hour').hidden=!view.showFiveHour;
    const external=deriveExternalView(externalState,undefined,lang);
    for(const[id,key]of Object.entries({'global-announcement':'announcementText','global-delivery':'deliveryText','global-odds':'oddsText','external-updated':'sourceText'}))byId(id).textContent=external[key];
    const details=deriveResetDetails(state,lang);byId('reset-details-note').textContent=details.note;
    byId('reset-details-list').replaceChildren(...details.rows.map(row=>{const item=document.createElement('li'),title=document.createElement('strong');title.textContent=row.title;item.append(title);for(const text of[row.description,row.granted,row.expires].filter(Boolean)){const line=document.createElement('p');line.textContent=text;item.append(line);}return item;}));
    byId('ring').setAttribute('aria-label',t(lang,'weekly'));byId('ring').setAttribute('aria-valuenow',String(view.ringPercent));byId('ring').setAttribute('aria-valuetext',view.percentText==='—'?view.statusText:t(lang,'percentRemaining',{percent:view.ringPercent}));
    byId('language').value=setting;refreshButton.disabled=loading;byId('setup-link').hidden=state.errorCode!=='cli_missing';
  }
  async function loadExternal(){try{const response=await fetch('/api/external',{cache:'no-store'});if(!response.ok)throw Error();externalState=await response.json();}catch{externalState={status:'unavailable'};}render();}
  async function loadSettings(){try{const response=await fetch('/api/settings',{cache:'no-store'});if(response.ok)setting=(await response.json()).language;}catch{}render();}
  async function load(force=false){if(loading)return;loading=true;render();try{const response=await fetch(force?'/api/refresh':'/api/usage',{method:force?'POST':'GET',cache:'no-store'});if(!response.ok)throw Error();state=await response.json();}catch{state={status:'unavailable',errorCode:'service_unavailable'};}finally{loading=false;render();loadExternal();loadSettings();}}
  byId('language').addEventListener('change',async event=>{try{const response=await fetch('/api/settings',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({language:event.target.value})});if(response.ok)setting=(await response.json()).language;}catch{}render();});
  refreshButton.addEventListener('click',()=>load(true));document.addEventListener('visibilitychange',()=>{if(!document.hidden)load();});setInterval(()=>load(),60000);setInterval(render,30000);render();load();
}
