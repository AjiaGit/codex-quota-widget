import { readFile, mkdir, writeFile, rename } from 'node:fs/promises';
import { dirname } from 'node:path';
import { setDefaultResultOrder } from 'node:dns';
import { analyzePublicPost, publicPostIndex } from './public-evidence.mjs';
import { parsePreviewTime, isResetPreview, previewVersion } from './public/preview.mjs';
// Prefer the working IPv4 route on networks whose IPv6 TLS path resets connections.
// This changes only this service process and retains IPv6 as a fallback.
setDefaultResultOrder('ipv4first');
const PROVIDERS = ['https://codex-reset.com/api/feed', 'https://codexreset.dev/api/status'];
const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const SOURCE_MAX_AGE_MS = 30 * 60 * 1000;
const sourceFresh = (value, now) => recentTimestamp(value, now) && now - Date.parse(value) <= SOURCE_MAX_AGE_MS;
// Display provenance only: these fields never determine eligibility or completion.
const sourceSites = value => [...new Set((Array.isArray(value) ? value : [])
  .filter(site => ['codex-reset.com', 'codexreset.dev'].includes(site)))].sort();

function recentTimestamp(value, now) {
  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && timestamp <= now + 5 * 60 * 1000 &&
    now - timestamp <= MAX_AGE_MS;
}

function safeHttpsUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password ? url.href : null;
  } catch { return null; }
}

const emptyAnnouncements = (reason = 'request-failed', sourceUpdatedAt = null) => ({ status: 'unavailable', reason, items: [], history: [], sourceUpdatedAt, lastFetchedAt: null, stale: true });
function preciseTimestamp(value) {
  // A calendar date or an unzoned clock time cannot be converted reliably.
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})$/i.test(value) || !dateOnly(value.slice(0,10))) return NaN;
  return Date.parse(value);
}
function timestamp(value, now, earliest = -Infinity) {
  const ms = preciseTimestamp(value);
  return Number.isFinite(ms) && ms <= now && ms >= earliest ? new Date(ms).toISOString() : null;
}
function dateOnly(value) {
  if(typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
  const ms=Date.parse(value+'T00:00:00Z');
  return Number.isFinite(ms)&&new Date(ms).toISOString().slice(0,10)===value?value:null;
}
const text = value => typeof value === 'string' ? value.slice(0, 2000) : null;
function normalizedAnnouncement(raw, now, scheduled = false, persisted = false) {
  // WhenReset's Codex scheduled object describes a global reset and may omit kind.
  const kind=scheduled && raw?.kind === undefined ? 'regular' : raw?.kind;
  if (!['banked', 'regular'].includes(kind)) return null;
  const sourceUrl = safeHttpsUrl(persisted ? raw.sourceUrl : raw.url);
  if (!sourceUrl) return null;
  const announcedAt = timestamp(persisted ? raw.announcedAt : raw.announced_at ?? raw.ts, now);
  const deliveredAt = timestamp(persisted ? raw.deliveredAt : raw.delivered_at, now, announcedAt ? Date.parse(announcedAt) : -Infinity);
  const schedule = persisted ? raw.scheduledAt : scheduled ? raw.scheduled_for ?? raw.scheduled_at : null;
  const scheduledMs = preciseTimestamp(schedule);
  const sourceHint = persisted && raw.certainty !== 'announced' && !deliveredAt &&
    ['active', 'recent', 'inactive'].includes(raw.sourceHint) ? raw.sourceHint : null;
  return {
    id: sourceUrl + '#' + kind,
    kind, announcedAt, certainty: raw.certainty === 'announced' ? 'announced' : 'unconfirmed',
    scheduledAt: Number.isFinite(scheduledMs) ? new Date(scheduledMs).toISOString() : null,
    scheduledFrom: persisted ? timestamp(raw.scheduledFrom,now) : null,
    scheduleText: persisted ? text(raw.scheduleText) : null,
    schedulePrecision: persisted && ['window','approximate','deadline','instant','text'].includes(raw.schedulePrecision) ? raw.schedulePrecision : null,
    scheduledDate: dateOnly(persisted ? raw.scheduledDate : scheduled ? raw.day ?? raw.date : null),
    scheduledTimeZone: text(persisted ? raw.scheduledTimeZone : scheduled ? raw.tz_label : null),
    deliveredAt, scope: text(raw.scope), scopeLabel: text(persisted ? raw.scopeLabel : raw.scope_label),
    sourceUrl, deliverySourceUrl: deliveredAt ? safeHttpsUrl(persisted ? raw.deliverySourceUrl : raw.delivered_source_url) : null,
    summary: text(raw.summary ?? (scheduled ? raw.note_en : null)), summaryZh: text(persisted ? raw.summaryZh : raw.summary_zh ?? (scheduled ? raw.note_zh : null)),
    sourceHint,
    sourceWithdrawn: sourceHint === 'inactive' || persisted && raw.sourceWithdrawn === true,
    completionTimeBasis: persisted && ['announcement','observation','site-report'].includes(raw.completionTimeBasis) ? raw.completionTimeBasis : null,
    kindBasis: persisted && raw.kindBasis === 'original' ? 'original' : null,
    sourceSites: persisted ? sourceSites(raw.sourceSites) : [],
    announcementBasis: persisted && raw.announcementBasis === 'original' ? 'original' : null,
    statementBasis: persisted && ['original','site','observation'].includes(raw.statementBasis) ? raw.statementBasis : null,
    relatedUrls: persisted ? (Array.isArray(raw.relatedUrls) ? raw.relatedUrls : []).map(officialPostUrl).filter(Boolean).slice(0,5) : [],
    kindKnown: raw.kindKnown !== false,
    correction: persisted && ['not-complete','cancelled','delayed'].includes(raw.correction) ? raw.correction : null,
    correctionSourceUrl: persisted ? officialPostUrl(raw.correctionSourceUrl) : null,
    correctionAt: persisted ? timestamp(raw.correctionAt,now) : null,
    evidenceUpdatedAt: persisted ? timestamp(raw.evidenceUpdatedAt, now) : null,
    evidenceFresh: persisted && raw.evidenceFresh === false ? false : true,
    observationAt: persisted ? timestamp(raw.observationAt, now) : null,
    previewSourceUrl: persisted ? officialPostUrl(raw.previewSourceUrl) : null,
    previewUpdatedAt: persisted ? timestamp(raw.previewUpdatedAt,now) : null,
    evidenceUrl: persisted ? safeHttpsUrl(raw.evidenceUrl) : null,
    multiKind: persisted && raw.multiKind === true,
  };
}
function deduplicate(items, knownItems = []) {
  // The complete original post overrides a mirror's category, including a
  // previously cached category. Keep that authority across partial refreshes.
  const candidates = [...knownItems, ...items];
  const originalKindSets = new Map();
  for(const item of candidates.filter(item => item.kindBasis === 'original')) {
    if(!originalKindSets.has(item.sourceUrl)||!item.multiKind)originalKindSets.set(item.sourceUrl,new Set());
    originalKindSets.get(item.sourceUrl).add(item.kind);
  }
  const multiKindUrls=new Set(candidates.filter(item=>item.multiKind).map(item=>item.sourceUrl));
  const originalKinds = new Map([...originalKindSets].filter(([url,kinds])=>kinds.size===1 && !multiKindUrls.has(url)).map(([url,kinds])=>[url,[...kinds][0]]));
  // A display-only hint and a mirror's generic record refer to the same post.
  // Resolve their category once; confirmed evidence still takes precedence.
  const hintKinds = new Map(candidates.filter(item => item.sourceHint).map(item => [item.sourceUrl, item.kind]));
  for (const item of candidates) if (hintKinds.has(item.sourceUrl) && confirmedAnnouncement(item))
    hintKinds.set(item.sourceUrl, item.kind);
  const map = new Map();
  for (let item of items) {
    const kind = originalKinds.get(item.sourceUrl) || (!originalKindSets.has(item.sourceUrl) && hintKinds.get(item.sourceUrl));
    if (kind) item = { ...item, kind, id: item.sourceUrl + '#' + kind,
      kindBasis: originalKinds.has(item.sourceUrl) ? 'original' : item.kindBasis };
    const previous = map.get(item.id);
    const resolvesLinkedCorrection=item.statementBasis==='original' && item.deliveredAt && item.completionTimeBasis==='announcement' &&
      item.deliverySourceUrl!==item.sourceUrl && item.relatedUrls?.includes(item.sourceUrl) &&
      (Date.parse(item.deliveredAt)>Date.parse(previous?.correctionAt) || item.deliverySourceUrl===previous?.correctionSourceUrl &&
        Date.parse(item.evidenceUpdatedAt)>=Date.parse(previous?.evidenceUpdatedAt));
    if(previous?.deliveredAt && item.correction && item.correctionSourceUrl && item.correctionSourceUrl!==item.sourceUrl &&
      Date.parse(previous.deliveredAt)>Date.parse(item.correctionAt)) {
      map.set(item.id,{...previous,sourceSites:sourceSites([...(previous.sourceSites||[]),...(item.sourceSites||[])])});continue;
    }
    // Fetching the old promise again is not a retraction of a separate later
    // correction. Only new explicitly linked evidence can resolve that lifecycle.
    if(previous?.correction && previous.correctionSourceUrl && previous.correctionSourceUrl!==item.sourceUrl && !item.correction && !resolvesLinkedCorrection) {
      map.set(item.id,{...previous,sourceSites:sourceSites([...(previous.sourceSites||[]),...(item.sourceSites||[])])});continue;
    }
    // A retrieved older original may improve provenance, but cannot reverse a
    // newer original statement (including an explicit withdrawal/correction).
    if(previous?.statementBasis==='original' && item.statementBasis==='original' &&
      Date.parse(previous.evidenceUpdatedAt)>Date.parse(item.evidenceUpdatedAt)) {
      map.set(item.id,{...previous,sourceSites:sourceSites([...(previous.sourceSites||[]),...(item.sourceSites||[])])});continue;
    }
    // Missing/cropped mirror data cannot reverse an explicit original correction.
    if(previous?.correction && previous.statementBasis === 'original' && item.statementBasis !== 'original')continue;
    if(item.correction && item.statementBasis === 'original') {
      map.set(item.id,{...previous,...item,deliveredAt:null,deliverySourceUrl:null,completionTimeBasis:null,
        sourceSites:sourceSites([...(previous?.sourceSites||[]),...(item.sourceSites||[])])});continue;
    }
    // A site's lower-confidence hint cannot replace confirmed wording/evidence.
    if (previous && item.sourceHint && confirmedAnnouncement(previous)) continue;
    if(previous?.sourceHint && item.sourceHint && previous.sourceSites?.includes('codex-reset.com') &&
      !item.sourceSites?.includes('codex-reset.com')) {
      map.set(item.id,{...previous,sourceSites:sourceSites([...(previous.sourceSites||[]),...(item.sourceSites||[])])});continue;
    }
    // A mirror without hint metadata has no authority to change its lifecycle.
    if (previous?.sourceHint && !item.sourceHint && !confirmedAnnouncement(item)) continue;
    if (previous?.sourceHint === 'inactive' && item.sourceHint === 'recent')
      item = { ...item, sourceHint: 'inactive', sourceWithdrawn: true };
    // A partial refresh of the parent alone cannot erase its explicit reply.
    if(previous?.previewSourceUrl&&!item.previewSourceUrl&&!item.scheduleText&&!item.correction) {
      for(const field of ['scheduledAt','scheduledFrom','scheduleText','schedulePrecision','previewSourceUrl','previewUpdatedAt','summary'])item[field]=previous[field];
    }
    map.set(item.id, previous ? { ...previous, ...item,
      announcedAt: item.announcedAt || previous.announcedAt,
      scheduledAt: item.scheduledAt || previous.scheduledAt,
      scheduledDate: item.scheduledDate || previous.scheduledDate,
      certainty: item.certainty === 'announced' || previous.certainty === 'announced' ? 'announced' : 'unconfirmed',
      deliveredAt: item.deliveredAt || previous.deliveredAt,
      kindBasis: item.kindBasis || previous.kindBasis,
      completionTimeBasis: item.deliveredAt ? item.completionTimeBasis : previous.completionTimeBasis,
      deliverySourceUrl: item.deliverySourceUrl || previous.deliverySourceUrl } : item);
    if(previous?.correction && item.statementBasis === 'original' && confirmedAnnouncement(item))map.get(item.id).correction=null;
    if (previous) {
      map.get(item.id).sourceSites = sourceSites([...(previous.sourceSites || []), ...(item.sourceSites || [])]);
      map.get(item.id).announcementBasis = item.announcementBasis || previous.announcementBasis;
    }
    const merged = map.get(item.id);
    if (confirmedAnnouncement(merged)) merged.sourceHint = null;
  }
  // If the original completion post proves a different type, release an older
  // inferred pairing instead of retaining its completion fields through merging.
  const corrections = new Map();
  for(const item of candidates.filter(item=>item.statementBasis==='original')) {
    const key=item.sourceUrl+'#'+item.kind,previous=corrections.get(key);
    if(!previous || !(Date.parse(previous.evidenceUpdatedAt)>Date.parse(item.evidenceUpdatedAt)))corrections.set(key,item);
  }
  for (const item of map.values()) {
    const correction=corrections.get(item.deliverySourceUrl+'#'+item.kind);
    if(item.deliveredAt && item.deliverySourceUrl!==item.sourceUrl && correction?.correction &&
      !(Date.parse(item.evidenceUpdatedAt)>Date.parse(correction.evidenceUpdatedAt))) {
      map.set(item.id,{...item,deliveredAt:null,deliverySourceUrl:null,completionTimeBasis:null,correction:correction.correction,
        correctionSourceUrl:correction.sourceUrl,correctionAt:correction.announcedAt,
        evidenceUpdatedAt:correction.evidenceUpdatedAt,evidenceFresh:correction.evidenceFresh});
      continue;
    }
    const completionKind = originalKinds.get(item.deliverySourceUrl);
    if (item.deliveredAt && item.deliverySourceUrl !== item.sourceUrl && completionKind && completionKind !== item.kind)
      map.set(item.id, { ...item, deliveredAt: null, deliverySourceUrl: null, completionTimeBasis: null });
  }
  // A paired announcement already contains the evidence from its completion post.
  for (const item of map.values()) if (item.deliveredAt && item.deliverySourceUrl && item.deliverySourceUrl !== item.sourceUrl)
    map.delete(item.deliverySourceUrl + '#' + item.kind);
  return [...map.values()];
}

function linkCompletions(items) {
  const records = deduplicate(items).map(item=>({...item})).sort((a,b) => Date.parse(a.announcedAt || 0) - Date.parse(b.announcedAt || 0));
  for(const update of [...records]) {
    if(update.kind!=='regular'||update.certainty!=='announced'||update.deliveredAt||update.correction||update.statementBasis!=='original')continue;
    const parents=records.filter(item=>item!==update&&item.kind===update.kind&&item.certainty==='announced'&&!item.deliveredAt&&!item.correction&&
      update.relatedUrls?.includes(item.sourceUrl)&&Date.parse(item.announcedAt)<Date.parse(update.announcedAt)&&
      (!item.scope||!update.scope||item.scope===update.scope));
    if(parents.length!==1)continue;
    const parent=parents[0];
    if(Date.parse(parent.previewUpdatedAt)>Date.parse(update.announcedAt))continue;
    Object.assign(parent,{...parsePreviewTime(update.summary,update.announcedAt),summary:update.summary,
      previewSourceUrl:update.sourceUrl,previewUpdatedAt:update.announcedAt,evidenceUpdatedAt:update.evidenceUpdatedAt,
      evidenceFresh:update.evidenceFresh,sourceSites:sourceSites([...(parent.sourceSites||[]),...(update.sourceSites||[])])});
    records.splice(records.indexOf(update),1);
  }
  for(const correction of records.filter(item=>item.correction && item.statementBasis==='original')) {
    const targets=records.filter(item=>item!==correction && officialPostUrl(item.sourceUrl) && item.kind===correction.kind &&
      item.announcedAt && correction.announcedAt && Date.parse(item.announcedAt)<Date.parse(correction.announcedAt) &&
      !(Date.parse(item.deliveredAt || item.correctionAt)>Date.parse(correction.announcedAt)) &&
      correction.relatedUrls?.includes(item.sourceUrl) && (!item.scope || !correction.scope || item.scope===correction.scope));
    if(targets.length!==1)continue;
    Object.assign(targets[0],{certainty:'unconfirmed',correction:correction.correction,sourceWithdrawn:true,
      correctionSourceUrl:correction.sourceUrl,correctionAt:correction.announcedAt,
      deliveredAt:null,deliverySourceUrl:null,completionTimeBasis:null,evidenceUpdatedAt:correction.evidenceUpdatedAt,
      evidenceFresh:correction.evidenceFresh});
    // Keep the separately dated correction post as the verifiable source. The
    // original promise remains in history, visibly corrected rather than live.
  }
  for (const completion of [...records]) {
    if (!completion.deliveredAt || completion.completionTimeBasis !== 'announcement' ||
        completion.deliverySourceUrl !== completion.sourceUrl) continue;
    // Associate only one recent, same-kind promise with a later completion statement.
    // Ambiguous multiple promises stay separate rather than guessing a relationship.
    const pending = records.filter(item => item !== completion && !item.deliveredAt && (item.certainty === 'announced' || item.correction) &&
      officialPostUrl(item.sourceUrl) && item.kind === completion.kind && item.announcedAt &&
      Date.parse(item.announcedAt) < Date.parse(completion.deliveredAt) &&
      (!item.correctionAt || Date.parse(completion.deliveredAt)>Date.parse(item.correctionAt) ||
        completion.sourceUrl===item.correctionSourceUrl && Date.parse(completion.evidenceUpdatedAt)>=Date.parse(item.evidenceUpdatedAt)) &&
      (completion.relatedUrls || []).includes(item.sourceUrl) &&
      (!item.scope || !completion.scope || item.scope === completion.scope));
    if (pending.length !== 1) continue;
    const item = pending[0];
    item.deliveredAt = completion.deliveredAt;
    item.deliverySourceUrl = completion.deliverySourceUrl || completion.sourceUrl;
    item.completionTimeBasis = 'announcement';
    item.statementBasis = completion.statementBasis;
    item.evidenceUpdatedAt = completion.evidenceUpdatedAt;
    item.evidenceFresh = completion.evidenceFresh;
    item.summary = completion.summary;
    item.relatedUrls = completion.relatedUrls;
    item.sourceSites = sourceSites([...(item.sourceSites || []), ...(completion.sourceSites || [])]);
    item.sourceWithdrawn = false;
    item.correction = null;
    item.correctionSourceUrl = null;
    item.correctionAt = null;
    records.splice(records.indexOf(completion), 1);
  }
  return deduplicate(records);
}

function officialPostUrl(value) {
  const safe = safeHttpsUrl(value);
  if (!safe) return null;
  const url = new URL(safe);
  return ['x.com','twitter.com','www.twitter.com'].includes(url.hostname) &&
    /^\/thsottiaux\/status\/\d+$/.test(url.pathname) ? 'https://x.com' + url.pathname : null;
}

function publicRecord({kind, url, at, summary, claim, scope = null, kindBasis = null, sourceSite, ...metadata}) {
  if (!kind || !url) return null;
  const announcedAt = at;
  const deliveredAt = claim === 'complete' && at ? at : null;
  return { id: url + '#' + kind, kind, sourceUrl: url, announcedAt, deliveredAt,
    deliverySourceUrl: deliveredAt ? url : null, completionTimeBasis: deliveredAt ? 'announcement' : null,
    certainty: claim === 'announced' || deliveredAt ? 'announced' : 'unconfirmed',
    ...parsePreviewTime(claim === 'announced' ? summary : null,at), scheduledDate: null, scheduledTimeZone: null, scope, scopeLabel: null, kindBasis,
    summary: text(summary), summaryZh: null, sourceHint: null, sourceWithdrawn: false,
    sourceSites: sourceSites([sourceSite]), announcementBasis: claim === 'announced' && metadata.statementBasis === 'original' ? 'original' : null,
    ...metadata };
}

function providerView(records, sourceUpdatedAt, now, stale = false, keepPending = true) {
  const history = deduplicate(records).sort((a,b)=>Date.parse(b.announcedAt || 0)-Date.parse(a.announcedAt || 0));
  const expired = !sourceFresh(sourceUpdatedAt, now) || stale;
  return { status: expired ? 'unavailable' : 'ok', reason: expired ? 'source-stale' : null,
    items: history.filter(item => active(item, now) && (keepPending || item.announcedAt && now - Date.parse(item.announcedAt) < MAX_AGE_MS)),
    history, sourceUpdatedAt, stale: expired };
}

function normalizeCodexFeed(data, now, archiveKinds) {
  if(data?.version!==1 || !Array.isArray(data.tweets) || data.profile?.handle!=='thsottiaux' || !timestamp(data.fetched_at,now))return emptyAnnouncements('invalid-data');
  const events=(Array.isArray(data.events)?data.events:[]);
  const categories=new Map(events.map(event=>[officialPostUrl(event?.url),event?.reset_kind==='banked'||event?.group==='credits'?'banked':event?.group==='reset'?'regular':null]));
  const posts=[...data.tweets,...(Array.isArray(data.radar_context)?data.radar_context:[])];
  const index=publicPostIndex(posts),records=[],decisions=[],fresh=data.stale!==true&&sourceFresh(data.fetched_at,now);
  const currentUrls=new Set(data.tweets.map(post=>officialPostUrl(post?.url)));
  const scopeOf=summary=>/\bpaid accounts\b|\bplus,? pro(?:,? and)? business\b/i.test(summary)?'paid':/\bfree accounts\b/i.test(summary)?'free':/\ball accounts\b/i.test(summary)?'all':null;
  const seen=new Set();
  for(const post of posts) {
    const url=officialPostUrl(post?.url),summary=text(post?.text),at=timestamp(post?.declared_at??post?.at,now);
    if(!url||!summary||!at||seen.has(url))continue;
    seen.add(url);
    const category=archiveKinds.get(url)||categories.get(url);
    const claims=analyzePublicPost(post,index,category);
    decisions.push({postId:String(post.id||'').slice(0,30),reason:claims.length?'classified':'no-reset-context',checkedAt:now});
    for(const evidence of claims) {
      // Radar contains unrelated replies as well: require an archive link or a
      // validated reset-specific quote/reply before admitting its text.
      if(!currentUrls.has(url)&&!category&&!evidence.contextValidated)continue;
      if(evidence.claim==='unconfirmed'&&!evidence.correction &&
        (!category || (!currentUrls.has(url)&&!archiveKinds.has(url)) || now-Date.parse(at)>=MAX_AGE_MS || !fresh ||
          String(post.id)!==url.split('/').at(-1) || currentUrls.has(url)&&post.kind!=='signal'))continue;
      const headline=data.signal,matches=headline?.kind==='signal'&&officialPostUrl(headline.url)===url&&String(headline.tweet_id)===String(post.id);
      const hint=evidence.claim==='unconfirmed'&&!evidence.correction?(matches&&headline.active===false?'inactive':matches&&headline.active===true?'active':'recent'):null;
      const statementBasis=evidence.originalStatement?'original':'site';
      records.push(publicRecord({kind:evidence.kind,url,at,summary,claim:evidence.claim,scope:scopeOf(summary),
        sourceSite:'codex-reset.com',kindBasis:evidence.originalKind?'original':null,statementBasis,
        relatedUrls:evidence.relatedUrls,multiKind:evidence.multiKind,kindKnown:evidence.kindKnown||archiveKinds.has(url),correction:evidence.correction,
        sourceHint:hint,sourceWithdrawn:hint==='inactive',evidenceUpdatedAt:data.fetched_at,evidenceFresh:fresh}));
    }
  }
  for(const event of events) {
    const url=officialPostUrl(event?.url),kind=categories.get(url),at=timestamp(event?.announced_at,now);
    if(!url||!kind||!text(event.summary))continue;
    const bankedTopic=/\bbanked resets?\b|\breset credits?\b/i.test(event.summary);
    const regularTopic=/\b(?:global|quota|codex) resets?\b/i.test(event.summary);
    const ownObservation=event.source==='archive' && at && (kind==='banked'?bankedTopic&&!regularTopic:regularTopic&&!bankedTopic) &&
      !/\b(if|would|could|might|not|never|no)\b|n't\b/i.test(event.summary) &&
      /\b(?:arrived|landed)\b[^.;!?]*\bon our checks\b/i.test(event.summary);
    if(ownObservation) {
      // This is explicitly the website's monitoring claim. The event's timestamp
      // is a site-record time, not independently known observation/account time.
      const recordUrl='https://codex-reset.com/#observed-event-'+url.split('/').at(-1);
      records.push({...publicRecord({kind,url:recordUrl,at,summary:event.summary,claim:'complete',sourceSite:'codex-reset.com',
        statementBasis:'observation',kindKnown:true,evidenceUpdatedAt:data.fetched_at,evidenceFresh:fresh,
        evidenceUrl:url,scope:'monitoring'}),completionTimeBasis:'site-report'});
      continue;
    }
    if(seen.has(url))continue;
    // An archive classification/confidence does not establish an original
    // promise or completion. Preserve this website-only information as a hint.
    records.push(publicRecord({kind,url,at,summary:event.summary,claim:'unconfirmed',sourceSite:'codex-reset.com',
      statementBasis:'site',kindKnown:true,sourceHint:at&&now-Date.parse(at)<MAX_AGE_MS?'recent':null,
      evidenceUpdatedAt:data.fetched_at,evidenceFresh:fresh,evidenceUrl:'https://codex-reset.com/'}));
  }
  for(const entry of Array.isArray(data.banked_observations)?data.banked_observations:[]) {
    const at=timestamp(entry?.at,now);
    if(!/^\d+$/.test(String(entry?.id||''))||entry.kind!=='banked'||entry.source!=='observed'||entry.banked_state!=='available'||!at)continue;
    const url='https://codex-reset.com/#banked-observation-'+entry.id;
    records.push({...publicRecord({kind:'banked',url,at,summary:entry.text,claim:'complete',sourceSite:'codex-reset.com',
      statementBasis:'observation',kindKnown:true,evidenceUpdatedAt:data.fetched_at,evidenceFresh:fresh,
      observationAt:at,evidenceUrl:'https://codex-reset.com/'}),completionTimeBasis:'observation',scope:'monitoring'});
  }
  const headline=data.signal,headlineUrl=officialPostUrl(headline?.url);
  const inactiveHintUrls=fresh&&headline?.kind==='signal'&&headline.active===false&&headlineUrl&&String(headline.tweet_id)===headlineUrl.split('/').at(-1)?[headlineUrl]:[];
  return {...providerView(records,data.fetched_at,now,!fresh),inactiveHintUrls,decisions:decisions.slice(-48)};
}

function normalizeCodexHistory(data, now) {
  if(!Array.isArray(data?.events)||!(['partial','complete'].includes(data.coverage)||['confirmed_today','recorded_today','no_verified_reset','unknown'].includes(data.status)))return emptyAnnouncements('invalid-data');
  const records=[],sourceTimes=[];
  for(const event of data.events) {
    const checked=timestamp(event?.retrieved_at,now);
    if(checked)sourceTimes.push(checked);
    const kind=event?.type==='banked_reset'?'banked':event?.type==='global_reset'?'regular':null;
    const url=officialPostUrl(event?.source_url);
    if(!kind||!url||!['recorded','verified'].includes(event?.status))continue;
    const at=event.time_basis==='announcement'?timestamp(event.announced_at,now):null;
    const summary=event.evidence_text||event.summary;
    const post={url,text:event.evidence_text, ...event};
    const evidence=analyzePublicPost(post,new Map(),kind);
    for(const claim of evidence.length?evidence:[{kind,claim:'unconfirmed',relatedUrls:[],kindKnown:true}]) {
      records.push(publicRecord({kind:claim.kind,url,at,summary,claim:claim.claim,scope:text(event.scope),sourceSite:'codexreset.dev',
        statementBasis:'site',kindKnown:true,relatedUrls:claim.relatedUrls,correction:null,
        sourceHint:claim.claim==='unconfirmed'&&at&&now-Date.parse(at)<MAX_AGE_MS?'recent':null,
        evidenceUpdatedAt:checked,evidenceFresh:sourceFresh(checked,now)}));
    }
  }
  const sourceUpdatedAt=timestamp(data.resetArchiveSyncedAt,now)||sourceTimes.sort().at(-1)||null;
  const upstream=(Array.isArray(data.sources)?data.sources:[]).find(source=>source.id==='codex-resets');
  return providerView(records,sourceUpdatedAt,now,Boolean(upstream&&upstream.status!=='online'),false);
}
const active = (item, now) => !item.sourceWithdrawn && (item.deliveredAt
  ? now - Date.parse(item.deliveredAt) < MAX_AGE_MS
  : item.certainty === 'announced' || item.announcedAt && now - Date.parse(item.announcedAt) < MAX_AGE_MS);
const confirmedAnnouncement = item => item.certainty === 'announced' || Boolean(item.deliveredAt);
const sourceHintNotice = item => ['active', 'recent'].includes(item.sourceHint) && !item.sourceWithdrawn;
const noticeEligible = item => confirmedAnnouncement(item) || sourceHintNotice(item) || Boolean(item.correction);
const noticeStage = item => item.correction ? 'correction:' + item.correction : item.deliveredAt ? 'complete:' + (item.deliverySourceUrl || item.sourceUrl) :
  item.certainty === 'announced' ? 'announced' : 'unconfirmed';
const noticeEntry = item => ({ id: item.id, kind: item.kind,
  ...(!confirmedAnnouncement(item) && sourceHintNotice(item) ? { sourceHint: true } : {}) });

export function normalizeAnnouncements(data, now = Date.now()) {
  const product = data?.products?.codex;
  if (data?.schema !== 'whenreset/v1' || !Number.isFinite(preciseTimestamp(data.generated_at)) || !product ||
      !Object.hasOwn(product, 'scheduled') || !Array.isArray(product.events)) return emptyAnnouncements('invalid-data');
  const signals = product.scheduled === null ? [] : Array.isArray(product.scheduled) ? product.scheduled : [product.scheduled];
  let invalid = false;
  const upcoming = [];
  for (const raw of signals) {
    if (raw?.certainty === 'hinted') continue;
    const item = raw?.certainty === 'announced' ? normalizedAnnouncement(raw, now, true) : null;
    if (item) upcoming.push(item); else invalid = true;
  }
  if (!recentTimestamp(data.generated_at, now)) {
    const expired = now - Date.parse(data.generated_at) > MAX_AGE_MS;
    return emptyAnnouncements(!invalid && expired ? 'source-stale' : 'invalid-data', timestamp(data.generated_at, now));
  }
  const history = product.events.filter(raw => raw?.certainty !== 'hinted').map(raw => normalizedAnnouncement(raw, now)).filter(Boolean);
  const current = history.filter(item => item.announcedAt && now - Date.parse(item.announcedAt) < MAX_AGE_MS ||
    item.deliveredAt && active(item, now));
  const combined = deduplicate([...upcoming, ...current]);
  return { status: invalid ? 'unavailable' : 'ok', reason: invalid ? 'invalid-data' : null, items: combined.filter(item => active(item, now)),
    history: deduplicate(history).sort((a,b) => Date.parse(b.announcedAt || 0) - Date.parse(a.announcedAt || 0)).slice(0,50),
    sourceUpdatedAt: data.generated_at, stale: invalid };
}

export async function createAnnouncementStore({ file, now = Date.now } = {}) {
  let snapshot = emptyAnnouncements(), writes = Promise.resolve();
  let baselineAt = null;
  const observed = new Set(), observedStages = new Map(), unread = new Map(), previewVersions = new Map();
  const canNotify = item => isResetPreview(item,now()) || Boolean(item?.kind==='regular' && item.statementBasis==='original' &&
    ['cancelled','delayed'].includes(item.correction) && (!item.correctionSourceUrl || item.correctionSourceUrl===item.sourceUrl) &&
    now()-Date.parse(item.announcedAt)<MAX_AGE_MS && (item.relatedUrls||[]).some(url=>previewVersions.has(url+'#regular')));
  const previewEntry = item => ({id:item.id,kind:item.kind,version:previewVersion(item)});
  const alertIdentity = id => {
    if(typeof id !== 'string')return null;
    const kind = id.endsWith('#banked') ? 'banked' : id.endsWith('#regular') ? 'regular' : null;
    return kind && safeHttpsUrl(id.slice(0, -kind.length - 1)) ? { id, kind } : null;
  };
  const alerts = () => {
    for(const [id] of unread) {
      const row=[...snapshot.items,...snapshot.history].find(item=>item.id===id);
      if(!row || !canNotify(row))unread.delete(id);
    }
    return {unread:[...unread.values()]};
  };
  const clean = entries => (Array.isArray(entries) ? entries : []).slice(0,100)
    .map(item => normalizedAnnouncement(item, now(), false, true)).filter(Boolean);
  try {
    const saved = JSON.parse(await readFile(file, 'utf8'));
    if (saved.version === 1) snapshot = { ...snapshot, items: clean(saved.items), history: clean(saved.history),
      sourceUpdatedAt: timestamp(saved.sourceUpdatedAt, now()), providerHealth: Array.isArray(saved.providerHealth) ? saved.providerHealth : [],
      diagnostics: Array.isArray(saved.diagnostics) ? saved.diagnostics.slice(-100) : [],
      lastFetchedAt: Number.isFinite(saved.lastFetchedAt) && saved.lastFetchedAt >= 0 && saved.lastFetchedAt <= now() ? saved.lastFetchedAt : null, stale: true };
    const tracking = saved.version === 1 && saved.alertTracking;
    if(tracking?.version === 1 && Number.isFinite(tracking.baselineAt) && tracking.baselineAt <= now()) {
      baselineAt = tracking.baselineAt;
      for(const id of (Array.isArray(tracking.observed) ? tracking.observed : []).slice(-500))if(alertIdentity(id))observed.add(id);
      if(Array.isArray(tracking.observedStages)) {
        for(const entry of tracking.observedStages.slice(-500))if(Array.isArray(entry) && alertIdentity(entry[0]) &&
          (['announced','unconfirmed','correction:not-complete','correction:cancelled','correction:delayed'].includes(entry[1]) ||
            typeof entry[1]==='string' && entry[1].startsWith('complete:') && safeHttpsUrl(entry[1].slice(9))))observedStages.set(...entry.slice(0,2));
      } else {
        // Migrate older caches without replaying their already-observed stages.
        for(const item of [...snapshot.history,...snapshot.items]) {
          if(observed.has(item.id))observedStages.set(item.id,noticeStage(item));
          const alias=item.deliverySourceUrl+'#'+item.kind;
          if(item.completionTimeBasis==='announcement' && observed.has(alias))observedStages.set(alias,noticeStage(item));
        }
      }
      if(Array.isArray(tracking.previewVersions)) {
        for(const [id,version] of tracking.previewVersions.slice(-500))
          if(alertIdentity(id)&&typeof version==='string'&&version.length<4000)previewVersions.set(id,version);
      } else {
        // Old completed/hint notices are retired; already-read previews stay read.
        for(const row of [...snapshot.items,...snapshot.history])
          if(isResetPreview(row,now())&&observed.has(row.id))previewVersions.set(row.id,previewVersion(row));
      }
      for(const entry of (Array.isArray(tracking.unread) ? tracking.unread : []).slice(0,100)) {
        const identity = alertIdentity(entry?.id);
        const record = identity && [...snapshot.items,...snapshot.history].find(item=>item.id===identity.id && canNotify(item));
        if(record && identity.kind === entry.kind && observed.has(identity.id))unread.set(identity.id,previewEntry(record));
      }
    }
  } catch {}
  const project = () => {
    const items = snapshot.items.filter(item => active(item, now()));
    return { ...snapshot, items, history: deduplicate([...snapshot.history, ...snapshot.items.filter(item => !active(item, now()))])
      .sort((a,b)=>Date.parse(b.announcedAt || 0)-Date.parse(a.announcedAt || 0)).slice(0,50),
      stale: snapshot.stale || !sourceFresh(snapshot.sourceUpdatedAt,now()) };
  };
  const persist = async () => {
    if(!file)return;
    writes = writes.catch(()=>{}).then(async()=>{
      await mkdir(dirname(file), { recursive: true }); const temp = file + '.' + process.pid + '.tmp';
      await writeFile(temp, JSON.stringify({ version:1, ...project(), alertTracking: {
        version:1, baselineAt, observed:[...observed].slice(-500), observedStages:[...observedStages].slice(-500), previewVersions:[...previewVersions].slice(-500), unread:alerts().unread,
      } }), { mode:0o600 }); await rename(temp,file);
    });
    // Storage failure must not erase confirmed live data or unread notices.
    await writes.catch(()=>{});
  };
  return {
    get state() { return project(); },
    get alerts() { return alerts(); },
    async acknowledge(ids) {
      for(const entry of (Array.isArray(ids) ? ids : []).slice(0,100)) {
        const id=typeof entry==='string'?entry:entry?.id,current=unread.get(id);
        if(current && (typeof entry==='string'||entry?.version===current.version))unread.delete(id);
      }
      await persist();
      return alerts();
    },
    async update(input) {
      const fresh=input?.status === 'ok' && !input.stale && sourceFresh(input.sourceUpdatedAt,now());
      const eligible = item => !Array.isArray(input?.noticeEvidence) || input.noticeEvidence.some(evidence =>
        [item.id,item.deliverySourceUrl+'#'+item.kind].includes(evidence.id) && evidence.stage === noticeStage(item));
      const inactiveHints = new Set(fresh && Array.isArray(input.inactiveHintUrls)
        ? input.inactiveHintUrls.map(officialPostUrl).filter(Boolean) : []);
      const withdrawHint = item => item.sourceHint && inactiveHints.has(item.sourceUrl)
        ? { ...item, sourceHint: 'inactive', sourceWithdrawn: true } : item;
      const incomingItems = clean(input?.items), incomingHistory = clean(input?.history);
      const knownItems = [...snapshot.history,...snapshot.items].map(withdrawHint);
      const authorities = [...knownItems, ...incomingHistory, ...incomingItems];
      const known=new Map(deduplicate(knownItems, authorities).map(item=>[item.id,item]));
      const mergeKnown=item=>known.has(item.id)?deduplicate([known.get(item.id),item])[0]:item;
      const freshItems = deduplicate(incomingItems, authorities).map(mergeKnown), freshHistory = deduplicate(incomingHistory, authorities).map(mergeKnown);
      // Measure freshness before merging cached metadata into generic mirror rows.
      const hintEvidence = new Set([...incomingHistory, ...incomingItems].filter(item=>item.sourceHint &&
        (item.sourceSites.includes('codex-reset.com') || !knownItems.some(old=>old.sourceUrl===item.sourceUrl&&old.sourceSites.includes('codex-reset.com')))).map(item=>item.sourceUrl));
      if(fresh) {
        for(const item of [...freshItems,...freshHistory].filter(eligible)) {
          const version=previewVersion(item);
          if(canNotify(item) && previewVersions.get(item.id)!==version)unread.set(item.id,previewEntry(item));
          if(isResetPreview(item,now()) || canNotify(item))previewVersions.set(item.id,version);
        }
        if(baselineAt===null)baselineAt=now();
        for(const item of [...freshHistory,...freshItems].filter(eligible)) {
          observed.add(item.id);
          observedStages.set(item.id,noticeStage(item));
          if(item.completionTimeBasis === 'announcement' && item.deliverySourceUrl) {
            observed.add(item.deliverySourceUrl + '#' + item.kind);
            observedStages.set(item.deliverySourceUrl+'#'+item.kind,noticeStage(item));
          }
        }
      }
      for(const item of [...freshHistory,...freshItems])if(!canNotify(item))unread.delete(item.id);
      const previous = project();
      previous.items = deduplicate(previous.items.map(withdrawHint), authorities);
      previous.history = deduplicate(previous.history.map(withdrawHint), authorities);
      const previousItems = previous.items;
      const evidence = new Map([...freshHistory, ...freshItems].map(item => [item.id, item]));
      // Absence only changes status when both complete, fresh feeds agree. Failure
      // or an empty single-source lookup must preserve the pending announcement.
      const reconciled=fresh && Array.isArray(input.reconciledIds) && input.reconciledIds.every(id=>alertIdentity(id)) ? new Set(input.reconciledIds) : null;
      const retained = previousItems.map(item => evidence.has(item.id) ? deduplicate([item, evidence.get(item.id)])[0] :
        reconciled && !reconciled.has(item.id) && !item.deliveredAt ? {...item,sourceWithdrawn:true} : item);
      for(const item of retained)if(item.sourceWithdrawn)unread.delete(item.id);
      const records = linkCompletions([...previous.history, ...retained, ...freshHistory, ...freshItems]);
      for (const item of records) {
        if (!canNotify(item)) unread.delete(item.id);
        // A cached source can improve an existing record without being fresh
        // enough to create a notice. Keep its unread type aligned with the card.
        else if (unread.has(item.id)) unread.set(item.id, previewEntry(item));
      }
      const hintUrls = new Set(knownItems.filter(item=>item.sourceHint).map(item=>item.sourceUrl));
      for (const item of records) if (item.kindBasis === 'original' || item.sourceHint || hintUrls.has(item.sourceUrl)) {
        if(item.multiKind)continue;
        const oldId = item.sourceUrl + (item.kind === 'banked' ? '#regular' : '#banked');
        if (observed.has(oldId)) observed.add(item.id);
        if(observedStages.has(oldId) && !observedStages.has(item.id))observedStages.set(item.id,observedStages.get(oldId));
        if (unread.delete(oldId) && noticeEligible(item)) unread.set(item.id, previewEntry(item));
      }
      for (const item of records) if (item.deliverySourceUrl && item.deliverySourceUrl !== item.sourceUrl) {
        const alias = item.deliverySourceUrl + '#' + item.kind;
        if (unread.delete(alias)) unread.set(item.id, {id:item.id,kind:item.kind});
      }
      const currentIds = new Set([...retained, ...freshItems].map(item=>item.id));
      const historicalIds = new Set([...previous.history, ...freshHistory, ...retained.filter(item=>item.sourceWithdrawn)].map(item=>item.id));
      const currentRecords = records.filter(item => currentIds.has(item.id) || currentIds.has(item.deliverySourceUrl + '#' + item.kind));
      snapshot = { status: input?.status === 'ok' ? 'ok' : 'unavailable',
        partial: input?.partial === true,
        providerHealth: (Array.isArray(input?.providerHealth) ? input.providerHealth : snapshot.providerHealth || []).map(provider => ({...provider,
          lastSuccessAt: provider.status === 'ok' ? now() : (snapshot.providerHealth || []).find(old => old.site === provider.site)?.lastSuccessAt || null})),
        diagnostics: [...(snapshot.diagnostics || []),...(Array.isArray(input?.diagnostics) ? input.diagnostics : [])].slice(-100),
        reason: input?.status === 'ok' ? null : ['source-stale','invalid-data'].includes(input?.reason) ? input.reason : 'request-failed',
        lastFetchedAt: fresh ? now() : snapshot.lastFetchedAt,
        items: currentRecords,
        history: records.filter(item=>historicalIds.has(item.id) || historicalIds.has(item.deliverySourceUrl + '#' + item.kind)),
        sourceUpdatedAt: timestamp(input?.sourceUpdatedAt, now()) || snapshot.sourceUpdatedAt,
        stale: input?.status !== 'ok' || input?.stale === true || currentRecords.some(item => !item.sourceWithdrawn &&
          (item.sourceHint ? !hintEvidence.has(item.sourceUrl) :
            !evidence.has(item.id) && !evidence.has(item.deliverySourceUrl + '#' + item.kind))) };
      await persist();
      return project();
    },
  };
}

export function normalizeResets(data, now = Date.now()) {
  if (data?.schema_version !== 1 || !recentTimestamp(data.generated_at, now) ||
      !Array.isArray(data.events)) return null;
  const latest = data.events.filter(event => event?.kind === 'regular' &&
    Number.isFinite(Date.parse(event.announced_at)) && Date.parse(event.announced_at) <= now)
    .sort((a, b) => Date.parse(b.announced_at) - Date.parse(a.announced_at))[0];
  if (!latest) return null;
  const deliveredAt = latest.delivered_at && Number.isFinite(Date.parse(latest.delivered_at)) &&
    Date.parse(latest.delivered_at) <= now ? latest.delivered_at : null;
  return {
    announcedAt: latest.announced_at,
    deliveredAt,
    scope: typeof latest.scope === 'string' ? latest.scope : null,
    sourceUrl: safeHttpsUrl(latest.url),
    deliverySourceUrl: deliveredAt ? safeHttpsUrl(latest.delivered_source_url) : null,
    sourceUpdatedAt: data.generated_at,
  };
}

async function fetchJson(url, fetchFn) {
  let response;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      response = await fetchFn(url, { headers: { Accept: 'application/json',
        'User-Agent': 'codex-quota-widget/0.1.0 (+https://github.com/AjiaGit)' }, signal: AbortSignal.timeout(15000) });
      break;
    } catch (error) {
      if (attempt || !['ECONNRESET','ETIMEDOUT'].includes(error?.cause?.code)) throw error;
    }
  }
  if (!response.ok) {
    const retry=response.headers?.get?.('retry-after');
    const retryAfterMs=retry ? Math.max(60000,Math.min(3600000,/^\d+$/.test(retry)?Number(retry)*1000:Date.parse(retry)-Date.now())) : null;
    throw Object.assign(new Error(`External API returned ${response.status}`),{retryAfterMs:Number.isFinite(retryAfterMs)?retryAfterMs:null});
  }
  try { return await response.json(); }
  catch (error) {
    if (error instanceof SyntaxError) throw Object.assign(new Error('External API returned invalid JSON', { cause: error }), { code: 'invalid-data' });
    throw error;
  }
}

export async function queryExternal({ fetchFn = fetch, now = Date.now(), backoff = new Map() } = {}) {
  const [primary, backup] = await Promise.allSettled(PROVIDERS.map(async url=>{
    const until=backoff.get(url)||0;
    if(until>now)throw Object.assign(new Error('Source cooldown'),{retryAfterMs:until-now});
    try {const result=await fetchJson(url,fetchFn);backoff.delete(url);return result;}
    catch(error){if(error.retryAfterMs)backoff.set(url,now+error.retryAfterMs);throw error;}
  }));
  const failed = result => emptyAnnouncements(result.reason?.code === 'invalid-data' ? 'invalid-data' : 'request-failed');
  const archive = backup.status === 'fulfilled' ? normalizeCodexHistory(backup.value,now) : failed(backup);
  const kinds = new Map(archive.history.map(item=>[item.sourceUrl,item.kind]));
  const feed = primary.status === 'fulfilled' ? normalizeCodexFeed(primary.value,now,kinds) : failed(primary);
  const views = [archive,feed];
  const providerHealth = views.map((view,index)=>({site:index===0?'codexreset.dev':'codex-reset.com',
    status:view.status,reason:view.reason,sourceUpdatedAt:view.sourceUpdatedAt,lastFetchedAt:now,
    retryAfterMs:(index===0?backup:primary).reason?.retryAfterMs||null}));
  const fresh = views.filter(view=>view.status === 'ok' && !view.stale);
  const noticeEvidence = fresh.flatMap(view=>view.history.filter(item=>item.evidenceFresh!==false).map(item=>({id:item.id,stage:noticeStage(item)})));
  const records = linkCompletions(views.flatMap(view=>view.history));
  const activeIds = new Set(views.flatMap(view=>view.items).map(item=>item.id));
  const sourceUpdatedAt = (fresh.length ? fresh : views).map(view=>view.sourceUpdatedAt).filter(Boolean).sort().at(-1) || null;
  const announcementView = { status: fresh.length ? 'ok' : 'unavailable',
    reason: fresh.length ? null : views.some(view=>view.reason === 'source-stale') ? 'source-stale' :
      views.some(view=>view.reason === 'invalid-data') ? 'invalid-data' : 'request-failed',
    items: records.filter(item=>active(item, now) && (activeIds.has(item.id) || activeIds.has(item.deliverySourceUrl + '#' + item.kind))),
    history: records, sourceUpdatedAt, stale: !fresh.length, partial: fresh.length > 0 && fresh.length < views.length,
    providerHealth, noticeEvidence,
    diagnostics: [...providerHealth.map(provider=>({site:provider.site,status:provider.status,reason:provider.reason,checkedAt:now,
      retained:views[provider.site==='codexreset.dev'?0:1].history.length})),...(feed.decisions||[]).map(row=>({...row,site:'codex-reset.com'}))],
    inactiveHintUrls: feed.inactiveHintUrls || [] };
  // These feeds are partial and retain different event stages. Absence cannot withdraw a promise.
  const latest = records.filter(item=>item.kind === 'regular' && item.announcedAt && !item.sourceHint)
    .sort((a,b)=>Date.parse(b.deliveredAt || b.announcedAt)-Date.parse(a.deliveredAt || a.announcedAt))[0];
  const lastGlobal = latest ? { announcedAt: latest.announcedAt, deliveredAt: latest.deliveredAt,
    sourceUrl: latest.sourceUrl, deliverySourceUrl: latest.deliverySourceUrl, scope: latest.scope,
    sourceUpdatedAt, completionTimeBasis: latest.completionTimeBasis } : null;
  return {
    status: lastGlobal || announcementView.status === 'ok' ? 'ok' : 'unavailable',
    lastGlobal,
    announcements: announcementView,
    sources: ['https://codex-reset.com/', 'https://codexreset.dev/'],
    updatedAt: now,
  };
}
