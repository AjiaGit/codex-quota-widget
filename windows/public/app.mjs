import { t, resolveLanguage, formatDate, formatRelativeUpdate, formatShortDate } from './i18n.mjs';
const TEN_MINUTES = 10 * 60 * 1000;
const PUBLIC_MAX_AGE = 24 * 60 * 60 * 1000;
function publicSourceFresh(state,now) {
  const stamp=Date.parse(state?.sourceUpdatedAt);
  return Number.isFinite(stamp)&&stamp<=now+5*60000&&now-stamp<=PUBLIC_MAX_AGE;
}
function forecastForView(state,now) {
  const forecast=state?.status==='ok'?state.forecast:null;
  if(!publicSourceFresh(forecast,now))return null;
  const values=[forecast.next24h,forecast.next48h,forecast.next7d];
  return values.every(value=>Number.isFinite(value)&&value>=0&&value<=100)&&values[0]<=values[1]&&values[1]<=values[2]?forecast:null;
}
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
  if(!Number.isFinite(state.updatedAt)||state.updatedAt>now+60000||now-state.updatedAt>TEN_MINUTES)return unavailable(t(language,'stale'),t(language,'waitingData'));
  if(!Number.isFinite(resetMs)||now>=resetMs)return unavailable(t(language,'waiting'),t(language,'resetPassed'));
  if(!Number.isFinite(state.remainingPercent)||state.remainingPercent<0||state.remainingPercent>100)return unavailable(t(language,'unavailable'),t(language,'unsupported'));
  const percent=Math.max(0,Math.min(100,Math.round(state.remainingPercent))),shortReset=state.fiveHour?.resetsAt*1000;
  const shortValid=state.plan==='plus'&&Number.isFinite(shortReset)&&shortReset>now&&Number.isFinite(state.fiveHour?.remainingPercent)&&state.fiveHour.remainingPercent>=0&&state.fiveHour.remainingPercent<=100;
  return {statusText:t(language,'updated'),message:t(language,'weekly'),percentText:`${percent}%`,ringPercent:percent,tone:percent<=10?'danger':percent<=50?'warning':'healthy',resetText:formatDate(resetMs,timeZone,language),countdownText:formatCountdown(resetMs-now,language),updatedText:formatDate(state.updatedAt,timeZone,language),cardsText:Number.isSafeInteger(state.resetCards)&&state.resetCards>=0?t(language,state.resetCards===1?'resetOne':'resetCount',{count:state.resetCards}):'—',showFiveHour:state.plan==='plus',cardsCountText:Number.isSafeInteger(state.resetCards)&&state.resetCards>=0?(language==='en'?String(state.resetCards):t(language,state.resetCards===1?'resetOne':'resetCount',{count:state.resetCards})):'—',fiveHourPercentText:shortValid?`${Math.round(state.fiveHour.remainingPercent)}%`:t(language,'unavailable'),fiveHourText:shortValid?t(language,'percentRemaining',{percent:Math.round(state.fiveHour.remainingPercent)}):t(language,'unavailable'),fiveHourResetText:shortValid?formatDate(shortReset,timeZone,language):'—'};
}
export function deriveExternalView(state,timeZone=Intl.DateTimeFormat().resolvedOptions().timeZone,language='zh-CN',now=Date.now()) {
  const last=state?.status==='ok'&&publicSourceFresh(state.lastGlobal,now)?state.lastGlobal:null,forecast=forecastForView(state,now),scope=t(language,last?.scope==='paid'?'paid':last?.scope==='all'?'all':'unknownScope');
  return {announcementText:last?.announcedAt?`${formatDate(Date.parse(last.announcedAt),timeZone,language)} · ${scope}`:t(language,'unavailable'),deliveryText:last?.deliveredAt?`${formatDate(Date.parse(last.deliveredAt),timeZone,language)} · ${t(language,'delivered')}`:t(language,'deliveryUnknown'),oddsText:forecast?t(language,'oddsValue',{a:forecast.next24h,b:forecast.next48h,c:forecast.next7d}):t(language,'unavailable'),sourceText:forecast?.sourceUpdatedAt?`${t(language,'dataTime')} ${formatDate(Date.parse(forecast.sourceUpdatedAt),timeZone,language)}`:t(language,'sourceUnavailable')};
}
export function deriveResetDetails(state,language='en',timeZone=Intl.DateTimeFormat().resolvedOptions().timeZone,now=Date.now()) {
  if(deriveView(state,now,timeZone,language).percentText==='—')return {note:t(language,'detailsPending'),rows:[]};
  const rows=Array.isArray(state.resetDetails)?state.resetDetails:null;
  return {note:t(language,rows===null?'detailsUnknown':rows.length?'detailsPartial':'detailsEmpty'),rows:(rows||[]).map(row=>({title:row.title||t(language,'genericReset'),description:row.description||'',granted:t(language,'granted')+': '+(row.grantedAt?formatDate(row.grantedAt*1000,timeZone,language):t(language,'dateUnknown')),expires:t(language,'expires')+': '+(row.expiresAt?formatDate(row.expiresAt*1000,timeZone,language):t(language,'dateUnknown'))}))};
}
function safeSource(value) { try { const url=new URL(value);return url.protocol==='https:' && !url.username && !url.password ? url.href : null; } catch { return null; } }
export function deriveAnnouncementsView(state,now=Date.now(),timeZone=Intl.DateTimeFormat().resolvedOptions().timeZone,language='en') {
  const rows=[],history=[],seen=new Set();
  const renderItem=item=>{
    if(!['banked','regular'].includes(item?.kind)||!safeSource(item.sourceUrl))return null;
    const delivered=Date.parse(item.deliveredAt),announced=Date.parse(item.announcedAt),scheduled=Date.parse(item.scheduledAt);
    const confirmed=Number.isFinite(delivered)&&delivered<=now&&(!Number.isFinite(announced)||delivered>=announced);
    const day=typeof item.scheduledDate==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(item.scheduledDate)?Date.parse(item.scheduledDate+'T00:00:00Z'):NaN;
    const phase=confirmed?(now-delivered>=86400000?'archived':'delivered'):Number.isFinite(scheduled)?(scheduled<=now?'waiting':'upcoming'):Number.isFinite(day)?(now>=day+86400000?'waiting':'upcoming'):'announced';
    const planDate=Number.isFinite(scheduled)?scheduled:day;
    const plannedDate=Number.isFinite(planDate)?formatShortDate(planDate,Number.isFinite(scheduled)?timeZone:'UTC',language,now,!Number.isFinite(scheduled)):'';
    const scopeText=item.scope==='paid'?t(language,'paid'):item.scope==='all'?t(language,'all'):(language==='zh-CN'?item.scopeLabel:item.scope)||t(language,'unknownScope');
    const plannedText=plannedDate?`${t(language,phase==='upcoming'?'scheduled':'original')} ${plannedDate}`:'';
    const completedText=confirmed?`${t(language,'completed')} ${formatShortDate(delivered,timeZone,language,now)}`:'';
    const announcedText=!plannedText&&!completedText&&Number.isFinite(announced)?`${t(language,'announcement')} ${formatShortDate(announced,timeZone,language,now)}`:'';
    const status=confirmed?t(language,item.kind==='banked'?'grantDone':'resetDone'):t(language,phase==='waiting'?'waitingDelivery':phase==='upcoming'?'upcoming':'announcedWaiting');
    return {id:item.id||item.sourceUrl+'#'+item.kind,kind:item.kind,phase,title:t(language,item.kind==='banked'?'confirmedGrant':'confirmedReset'),status,
      plannedText,completedText,announcedText,scopeText,retentionText:phase==='delivered'?t(language,'retention'):'',
      timeText:[completedText||plannedText||announcedText,scopeText].filter(Boolean).join(' · '),
      sourceUrl:safeSource(item.sourceUrl),deliverySourceUrl:confirmed?safeSource(item.deliverySourceUrl):null,
      summary:language==='zh-CN'?(item.summaryZh||item.summary||''):(item.summary||'')};
  };
  for(const item of state?.items||[]){const row=renderItem(item);if(!row)continue;if(row.phase==='archived')history.push(row);else rows.push(row);seen.add(row.id);}
  for(const item of state?.history||[]){const row=renderItem(item);if(row&&!seen.has(row.id)){history.push(row);seen.add(row.id);}}
  return {rows,history,notice:state?.stale||state?.status!=='ok'||!publicSourceFresh(state,now)?t(language,rows.length?'informationPending':'announcementsUnavailable'):rows.length?'':t(language,'noAnnouncements')};
}
export function derivePublicStatus(state,now=Date.now(),timeZone=Intl.DateTimeFormat().resolvedOptions().timeZone,language='en') {
  if(forecastForView(state,now)&&state.announcements?.status==='ok'&&!state.announcements.stale&&publicSourceFresh(state.announcements,now))return '';
  if(state?.status==='loading')return '';
  const stamp=Date.parse(state?.announcements?.sourceUpdatedAt);
  const last=Number.isFinite(stamp)&&stamp<=now?`${t(language,'lastSuccess')} ${formatShortDate(stamp,timeZone,language,now)}`:'';
  return [t(language,'publicPending'),last].filter(Boolean).join(' · ');
}
if(typeof document!=='undefined') {
  document.body.dataset.embedded=String(new URLSearchParams(location.search).get('embedded')==='1');
  const byId=id=>document.getElementById(id),root=byId('card'),refreshButton=byId('refresh');
  let state={status:'loading'},externalState={status:'loading'},loading=false,setting='auto';
  const renderedLists=new Map();
  const replaceList=(id,signature,children)=>{if(renderedLists.get(id)===signature)return;byId(id).replaceChildren(...children());renderedLists.set(id,signature);};
  const language=()=>resolveLanguage(setting,navigator.language);
  let measurementRequested=false;
  function reportDetailLayout() {
    if(!window.webkit?.messageHandlers?.detailLayout||measurementRequested||state.status==='loading'||externalState.status==='loading')return;
    measurementRequested=true;
    requestAnimationFrame(()=>{
      measurementRequested=false;
      // Measure natural content rather than the card's viewport minimum height.
      const bottom=Math.max(0,...Array.from(root.children).filter(node=>node.getClientRects().length).map(node=>node.getBoundingClientRect().bottom+window.scrollY));
      const height=Math.ceil(bottom+parseFloat(getComputedStyle(root).paddingBottom));
      window.webkit.messageHandlers.detailLayout.postMessage({height,width:window.innerWidth});
    });
  }
  const layoutObserver=new ResizeObserver(reportDetailLayout);layoutObserver.observe(root);
  document.addEventListener('toggle',reportDetailLayout,true);
  function render() {
    const lang=language(),view=deriveView(state,Date.now(),undefined,lang);
    document.documentElement.lang=lang;document.title=t(lang,'brand');
    document.querySelectorAll('[data-i18n]').forEach(node=>node.textContent=t(lang,node.dataset.i18n));
    root.dataset.tone=view.tone;root.style.setProperty('--ring-value',`${view.ringPercent}%`);
    for(const[id,key]of Object.entries({percent:'percentText',caption:'message',countdown:'countdownText',cards:'cardsCountText','five-hour-value':'fiveHourPercentText'}))byId(id).textContent=view[key]??'—';
    byId('status').textContent=view.percentText==='—'?view.statusText:formatRelativeUpdate(state.updatedAt,Date.now(),lang);
    byId('reset').textContent=view.percentText==='—'?'—':formatShortDate(state.resetsAt*1000,undefined,lang);
    byId('five-hour-reset').textContent=view.fiveHourResetText==='—'?'—':formatShortDate(state.fiveHour.resetsAt*1000,undefined,lang);
    refreshButton.setAttribute('aria-label',t(lang,'refresh'));refreshButton.title=t(lang,'refresh');
    byId('caption').hidden=view.percentText!=='—';
    byId('five-hour').hidden=!view.showFiveHour;
    const publicStatus=derivePublicStatus(externalState,Date.now(),undefined,lang);
    document.querySelector('.announcements').setAttribute('aria-label',t(lang,'confirmedAnnouncements'));
    byId('public-status').textContent=publicStatus;byId('public-status').hidden=!publicStatus;
    const forecast=forecastForView(externalState,Date.now());
    for(const[id,key]of Object.entries({'odds-24h':'next24h','odds-48h':'next48h','odds-7d':'next7d'}))byId(id).textContent=forecast?forecast[key]+'%':'—';
    const announcements=deriveAnnouncementsView(externalState.announcements,Date.now(),undefined,lang);
    const icon=(kind)=>{
      const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('aria-hidden','true');svg.classList.add('section-icon');
      const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',kind==='banked'?'M3 9h18v4H3zM5 13v9h14v-9M12 9v13M12 9H8a3 3 0 1 1 3-3l1 3Zm0 0h4a3 3 0 1 0-3-3l-1 3Z':'M4 9h4l11-5v16l-11-5H4V9Zm4 6 2 7H6l-2-7M22 9v6');svg.append(path);return svg;
    };
    const announcementNode=(row,history=false)=>{
      const item=document.createElement(history?'li':'article');item.className='announcement';item.dataset.phase=row.phase;
      if(!history)item.append(icon(row.kind));
      const content=document.createElement('div');content.className='announcement-content';
      const heading=document.createElement(history?'strong':'h2');heading.textContent=row.title;content.append(heading);
      if(row.phase!=='upcoming'){const phase=document.createElement('p');phase.className='phase';phase.textContent=row.status;content.append(phase);}
      let factLine;
      for(const text of[row.plannedText,row.completedText,row.announcedText].filter(Boolean)){factLine=document.createElement('p');factLine.className='announcement-fact';factLine.textContent=text;content.append(factLine);}
      if(!factLine){factLine=document.createElement('p');content.append(factLine);}
      const scope=document.createElement('span');scope.className='announcement-scope';scope.textContent=row.scopeText;factLine.append(scope);
      if(history&&row.summary){const p=document.createElement('p');p.textContent=row.summary;content.append(p);}
      const line=document.createElement('p');line.className='announcement-source';
      for(const[url,key]of[[row.sourceUrl,'viewAnnouncement'],[row.deliverySourceUrl,'delivery']])if(url){if(line.childNodes.length)line.append(document.createTextNode(' · '));const link=document.createElement('a');link.href=url;link.target='_blank';link.rel='noopener noreferrer';link.textContent=t(lang,key);line.append(link);}
      content.append(line);
      if(row.retentionText&&!history){const p=document.createElement('p');p.className='retention-note';p.textContent=row.retentionText;content.append(p);}
      item.append(content);return item;
    };
    replaceList('announcement-list',JSON.stringify([lang,announcements.rows]),()=>announcements.rows.map(row=>announcementNode(row)));
    const notice=announcements.rows.length&&publicStatus?'':announcements.notice;
    byId('announcement-notice').textContent=notice;byId('announcement-notice').hidden=!notice;
    replaceList('announcement-history-list',JSON.stringify([lang,announcements.history]),()=>{
      if(announcements.history.length)return announcements.history.map(row=>announcementNode(row,true));
      const item=document.createElement('li');item.textContent=t(lang,'historyEmpty');return [item];
    });
    const details=deriveResetDetails(state,lang);byId('reset-details-note').textContent=details.note;
    replaceList('reset-details-list',JSON.stringify([lang,details.rows]),()=>details.rows.map(row=>{const item=document.createElement('li'),title=document.createElement('strong');title.textContent=row.title;item.append(title);for(const text of[row.description,row.granted,row.expires].filter(Boolean)){const line=document.createElement('p');line.textContent=text;item.append(line);}return item;}));
    byId('ring').setAttribute('aria-label',t(lang,'weekly'));byId('ring').setAttribute('aria-valuenow',String(view.ringPercent));byId('ring').setAttribute('aria-valuetext',view.percentText==='—'?view.statusText:t(lang,'percentRemaining',{percent:view.ringPercent}));
    byId('language').value=setting;refreshButton.disabled=loading;byId('setup-link').hidden=state.errorCode!=='cli_missing';
    reportDetailLayout();
  }
  async function loadExternal(){try{const response=await fetch('/api/external',{cache:'no-store'});if(!response.ok)throw Error();externalState=await response.json();}catch{externalState={...externalState,status:'unavailable',announcements:{...externalState.announcements,status:'unavailable',stale:true}};}render();}
  async function loadSettings(){try{const response=await fetch('/api/settings',{cache:'no-store'});if(response.ok)setting=(await response.json()).language;}catch{}render();}
  async function load(force=false){if(loading)return;loading=true;render();try{const response=await fetch(force?'/api/refresh':'/api/usage',{method:force?'POST':'GET',cache:'no-store'});if(!response.ok)throw Error();state=await response.json();}catch{state={status:'unavailable',errorCode:'service_unavailable'};}finally{loading=false;render();loadExternal();loadSettings();}}
  byId('language').addEventListener('change',async event=>{try{const response=await fetch('/api/settings',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({language:event.target.value})});if(response.ok)setting=(await response.json()).language;}catch{}render();});
  refreshButton.addEventListener('click',()=>load(true));document.addEventListener('visibilitychange',()=>{if(!document.hidden)load();});setInterval(()=>load(),60000);setInterval(render,30000);render();load();
}
