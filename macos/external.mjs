import { readFile, mkdir, writeFile, rename } from 'node:fs/promises';
import { dirname } from 'node:path';
import { setDefaultResultOrder } from 'node:dns';
// Prefer the working IPv4 route on networks whose IPv6 TLS path resets connections.
// This changes only this service process and retains IPv6 as a fallback.
setDefaultResultOrder('ipv4first');
const PROVIDERS = ['https://codex-reset.com/api/feed', 'https://codexreset.dev/api/history'];
const MAX_AGE_MS = 24 * 60 * 60 * 1000;

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
  return {
    id: sourceUrl + '#' + kind,
    kind, announcedAt, certainty: raw.certainty === 'announced' ? 'announced' : 'unconfirmed',
    scheduledAt: Number.isFinite(scheduledMs) ? new Date(scheduledMs).toISOString() : null,
    scheduledDate: dateOnly(persisted ? raw.scheduledDate : scheduled ? raw.day ?? raw.date : null),
    scheduledTimeZone: text(persisted ? raw.scheduledTimeZone : scheduled ? raw.tz_label : null),
    deliveredAt, scope: text(raw.scope), scopeLabel: text(persisted ? raw.scopeLabel : raw.scope_label),
    sourceUrl, deliverySourceUrl: deliveredAt ? safeHttpsUrl(persisted ? raw.deliverySourceUrl : raw.delivered_source_url) : null,
    summary: text(raw.summary ?? (scheduled ? raw.note_en : null)), summaryZh: text(persisted ? raw.summaryZh : raw.summary_zh ?? (scheduled ? raw.note_zh : null)),
    sourceWithdrawn: persisted && raw.sourceWithdrawn === true,
    completionTimeBasis: persisted && raw.completionTimeBasis === 'announcement' ? 'announcement' : null,
    kindBasis: persisted && raw.kindBasis === 'original' ? 'original' : null,
  };
}
function deduplicate(items, knownItems = []) {
  // The complete original post overrides a mirror's category, including a
  // previously cached category. Keep that authority across partial refreshes.
  const originalKinds = new Map([...knownItems, ...items].filter(item => item.kindBasis === 'original')
    .map(item => [item.sourceUrl, item.kind]));
  const map = new Map();
  for (let item of items) {
    const kind = originalKinds.get(item.sourceUrl);
    if (kind) item = { ...item, kind, id: item.sourceUrl + '#' + kind, kindBasis: 'original' };
    const previous = map.get(item.id);
    map.set(item.id, previous ? { ...previous, ...item,
      announcedAt: item.announcedAt || previous.announcedAt,
      scheduledAt: item.scheduledAt || previous.scheduledAt,
      scheduledDate: item.scheduledDate || previous.scheduledDate,
      certainty: item.certainty === 'announced' || previous.certainty === 'announced' ? 'announced' : 'unconfirmed',
      deliveredAt: item.deliveredAt || previous.deliveredAt,
      kindBasis: item.kindBasis || previous.kindBasis,
      completionTimeBasis: item.deliveredAt ? item.completionTimeBasis : previous.completionTimeBasis,
      deliverySourceUrl: item.deliverySourceUrl || previous.deliverySourceUrl } : item);
  }
  // If the original completion post proves a different type, release an older
  // inferred pairing instead of retaining its completion fields through merging.
  for (const item of map.values()) {
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
  for (const completion of [...records]) {
    if (!completion.deliveredAt || completion.completionTimeBasis !== 'announcement' ||
        completion.deliverySourceUrl !== completion.sourceUrl) continue;
    // Associate only one recent, same-kind promise with a later completion statement.
    // Ambiguous multiple promises stay separate rather than guessing a relationship.
    const pending = records.filter(item => item !== completion && !item.deliveredAt && item.certainty === 'announced' &&
      officialPostUrl(item.sourceUrl) && item.kind === completion.kind && item.announcedAt &&
      Date.parse(item.announcedAt) < Date.parse(completion.deliveredAt) &&
      Date.parse(completion.deliveredAt) - Date.parse(item.announcedAt) <= 2 * MAX_AGE_MS);
    if (pending.length !== 1) continue;
    const item = pending[0];
    item.deliveredAt = completion.deliveredAt;
    item.deliverySourceUrl = completion.deliverySourceUrl || completion.sourceUrl;
    item.completionTimeBasis = 'announcement';
    item.sourceWithdrawn = false;
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

function postClaim(value) {
  const sentences = ((text(value) || '').match(/[^.!?\n]+[.!?]?/g) || []).map(sentence => sentence.trim().toLowerCase());
  const usable = sentences.filter(sentence => !/\?\s*$/.test(sentence) &&
    !/\b(if|would|could|might|maybe|when|once|unless|until|assuming|provided|whether|not|never|no)\b|as long as|n't\b/.test(sentence));
  // A short affirmative follow-up can resolve this reset-specific rhetorical
  // question. Require adjacent clauses; an unrelated or hypothetical "it" is not evidence.
  const contextualComplete = sentences.some((sentence, i) => i > 0 &&
    /^it(?:['’]s| is) (?:done|complete|completed)[.!]?$/.test(sentence) &&
    /^what would you like with your side of (?:a |the )?(?:(?:global|banked) )?reset\?$/.test(sentences[i - 1]));
  // Match affirmative completion clauses, not mentions inside questions or hypotheticals.
  const complete = contextualComplete || usable.some(sentence => !/\b(will|going to|should|plan|planning|expect|tomorrow|tonight|soon|later|by)\b/.test(sentence) &&
    /^(?:all propagated|confirmed (?:landed|delivered)|all reset for everyone|(?:(?:the|this) )?(?:global |codex |quota )?resets? (?:(?:has|have) been processed|(?:is|are) (?:complete|done|live)|(?:all )?propagated))\b/.test(sentence));
  // Require an actual action or an explicit promise, rather than a modal suggestion or request.
  const announced = usable.some(sentence => /^global reset (?:by|at|today|tomorrow|tonight|landing)\b|^global reset will (?:happen|occur|take place|be (?:issued|applied|performed|rolled out))\b/.test(sentence) ||
    /^(?:(?:we|i)(?:'re|'m| are| am) )?(?:loading|granting|giving) (?:a |one |the )?(?:new )?(?:banked |global )reset\b/.test(sentence) ||
    /^(?:(?:we|i)(?:'ll| will|(?:'re|'m| are| am) going to)|will|going to) (?:(?:load|grant|give|perform|issue|apply|roll out|do) (?:a |one |the )?(?:new )?(?:banked |global )reset\b|reset (?:rate|usage) limits\b)/.test(sentence));
  return complete ? 'complete' : announced ? 'announced' : 'unconfirmed';
}

function publicRecord({kind, url, at, summary, claim, scope = null, kindBasis = null}) {
  if (!kind || !url) return null;
  const announcedAt = at;
  const deliveredAt = claim === 'complete' && at ? at : null;
  return { id: url + '#' + kind, kind, sourceUrl: url, announcedAt, deliveredAt,
    deliverySourceUrl: deliveredAt ? url : null, completionTimeBasis: deliveredAt ? 'announcement' : null,
    certainty: claim === 'announced' || deliveredAt ? 'announced' : 'unconfirmed',
    scheduledAt: null, scheduledDate: null, scheduledTimeZone: null, scope, scopeLabel: null, kindBasis,
    summary: text(summary), summaryZh: null, sourceWithdrawn: false };
}

function providerView(records, sourceUpdatedAt, now, stale = false, keepPending = true) {
  const history = deduplicate(records).sort((a,b)=>Date.parse(b.announcedAt || 0)-Date.parse(a.announcedAt || 0));
  const expired = !recentTimestamp(sourceUpdatedAt, now) || stale;
  return { status: expired ? 'unavailable' : 'ok', reason: expired ? 'source-stale' : null,
    items: history.filter(item => active(item, now) && (keepPending || item.announcedAt && now - Date.parse(item.announcedAt) < MAX_AGE_MS)),
    history, sourceUpdatedAt, stale: expired };
}

function normalizeCodexFeed(data, now, archiveKinds) {
  if (data?.version !== 1 || !Array.isArray(data.tweets) || data.profile?.handle !== 'thsottiaux' ||
      !timestamp(data.fetched_at, now)) return emptyAnnouncements('invalid-data');
  const categories = new Map((Array.isArray(data.events) ? data.events : []).map(event =>
    [officialPostUrl(event?.url), event?.reset_kind === 'banked' || event?.group === 'credits' ? 'banked' : event?.group === 'reset' ? 'regular' : null]));
  const records = [];
  for (const post of data.tweets) {
    const url = officialPostUrl(post?.url), summary = text(post?.text), at = timestamp(post?.declared_at ?? post?.at, now);
    if (!url || !summary || !at) continue;
    const kind = /\bbanked reset\b/i.test(summary) ? 'banked' : /\bglobal reset\b/i.test(summary) ? 'regular' :
      archiveKinds.get(url) || categories.get(url) || (/\breset\b/i.test(summary) ? 'regular' : null);
    const claim = postClaim(summary);
    // Site categories and classifier flags alone cannot confirm an announcement.
    if (claim === 'unconfirmed') continue;
    const scope = /\bpaid accounts\b|\bplus,? pro(?:,? and)? business\b/i.test(summary) ? 'paid' : null;
    const kindBasis = /\b(?:banked|global) reset\b/i.test(summary) ? 'original' : null;
    const item = publicRecord({kind, url, at, summary, claim, scope, kindBasis});
    if (item) records.push(item);
  }
  return providerView(records, data.fetched_at, now, data.stale === true);
}

function normalizeCodexHistory(data, now) {
  if (!Array.isArray(data?.events) || !['partial','complete'].includes(data.coverage)) return emptyAnnouncements('invalid-data');
  const records = [], sourceTimes = [];
  for (const event of data.events) {
    const supported = ['banked_reset','global_reset'].includes(event?.type);
    const evidence = text(event?.evidence_text) || '';
    const kind = !supported ? null : /\bbanked reset\b/i.test(evidence) ? 'banked' :
      /\bglobal reset\b/i.test(evidence) ? 'regular' : event.type === 'banked_reset' ? 'banked' : 'regular';
    const url = officialPostUrl(event?.source_url);
    const checked = timestamp(event?.retrieved_at, now);
    if (checked) sourceTimes.push(checked);
    if (!kind || !url || !['recorded','verified'].includes(event?.status)) continue;
    // effective_at can contain a tracker's observation time or the publication time.
    // Neither is evidence of when this user's account received a reset.
    const at = event.time_basis === 'announcement' ? timestamp(event.announced_at, now) : null;
    const summary = event.evidence_text || event.summary;
    const item = publicRecord({kind, url, at, summary, claim: postClaim(event.evidence_text), scope: text(event.scope)});
    if (item) records.push(item);
  }
  const sourceUpdatedAt = sourceTimes.sort().at(-1) || null;
  // An empty archive is valid, but without an upstream check time it cannot establish freshness.
  return providerView(records, sourceUpdatedAt, now, false, false);
}
const active = (item, now) => !item.sourceWithdrawn && (item.deliveredAt
  ? now - Date.parse(item.deliveredAt) < MAX_AGE_MS
  : item.certainty === 'announced' || item.announcedAt && now - Date.parse(item.announcedAt) < MAX_AGE_MS);
const confirmedAnnouncement = item => item.certainty === 'announced' || Boolean(item.deliveredAt);

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
  const observed = new Set(), unread = new Map();
  const alertIdentity = id => {
    if(typeof id !== 'string')return null;
    const kind = id.endsWith('#banked') ? 'banked' : id.endsWith('#regular') ? 'regular' : null;
    return kind && safeHttpsUrl(id.slice(0, -kind.length - 1)) ? { id, kind } : null;
  };
  const alerts = () => ({ unread: [...unread.values()] });
  const clean = entries => (Array.isArray(entries) ? entries : []).slice(0,100)
    .map(item => normalizedAnnouncement(item, now(), false, true)).filter(Boolean);
  try {
    const saved = JSON.parse(await readFile(file, 'utf8'));
    if (saved.version === 1) snapshot = { ...snapshot, items: clean(saved.items), history: clean(saved.history),
      sourceUpdatedAt: timestamp(saved.sourceUpdatedAt, now()),
      lastFetchedAt: Number.isFinite(saved.lastFetchedAt) && saved.lastFetchedAt >= 0 && saved.lastFetchedAt <= now() ? saved.lastFetchedAt : null, stale: true };
    const tracking = saved.version === 1 && saved.alertTracking;
    if(tracking?.version === 1 && Number.isFinite(tracking.baselineAt) && tracking.baselineAt <= now()) {
      baselineAt = tracking.baselineAt;
      for(const id of (Array.isArray(tracking.observed) ? tracking.observed : []).slice(-500))if(alertIdentity(id))observed.add(id);
      for(const entry of (Array.isArray(tracking.unread) ? tracking.unread : []).slice(0,100)) {
        const identity = alertIdentity(entry?.id);
        if(identity && identity.kind === entry.kind && observed.has(identity.id) &&
          [...snapshot.items,...snapshot.history].some(item=>item.id===identity.id && confirmedAnnouncement(item)))unread.set(identity.id,identity);
      }
    }
  } catch {}
  const project = () => {
    const items = snapshot.items.filter(item => active(item, now()));
    return { ...snapshot, items, history: deduplicate([...snapshot.history, ...snapshot.items.filter(item => !active(item, now()))])
      .sort((a,b)=>Date.parse(b.announcedAt || 0)-Date.parse(a.announcedAt || 0)).slice(0,50),
      stale: snapshot.stale || !snapshot.sourceUpdatedAt || now() - Date.parse(snapshot.sourceUpdatedAt) > MAX_AGE_MS };
  };
  const persist = async () => {
    if(!file)return;
    writes = writes.catch(()=>{}).then(async()=>{
      await mkdir(dirname(file), { recursive: true }); const temp = file + '.' + process.pid + '.tmp';
      await writeFile(temp, JSON.stringify({ version:1, ...project(), alertTracking: {
        version:1, baselineAt, observed:[...observed].slice(-500), unread:alerts().unread,
      } }), { mode:0o600 }); await rename(temp,file);
    });
    // Storage failure must not erase confirmed live data or unread notices.
    await writes.catch(()=>{});
  };
  return {
    get state() { return project(); },
    get alerts() { return alerts(); },
    async acknowledge(ids) {
      for(const id of (Array.isArray(ids) ? ids : []).slice(0,100))unread.delete(id);
      await persist();
      return alerts();
    },
    async update(input) {
      const known=new Map([...snapshot.history,...snapshot.items].map(item=>[item.id,item]));
      const mergeKnown=item=>known.has(item.id)?deduplicate([known.get(item.id),item])[0]:item;
      const incomingItems = clean(input?.items), incomingHistory = clean(input?.history);
      const originals = [...known.values(), ...incomingHistory, ...incomingItems].filter(item=>item.kindBasis === 'original');
      const freshItems = deduplicate(incomingItems, originals).map(mergeKnown), freshHistory = deduplicate(incomingHistory, originals).map(mergeKnown);
      const fresh=input?.status === 'ok' && !input.stale && recentTimestamp(input.sourceUpdatedAt,now());
      if(fresh) {
        if(baselineAt !== null)for(const item of freshItems) {
          const completionId = item.deliverySourceUrl + '#' + item.kind;
          const newCompletion = item.completionTimeBasis === 'announcement' && item.deliveredAt &&
            !observed.has(completionId) && known.get(item.id)?.deliverySourceUrl !== item.deliverySourceUrl;
          const publication = newCompletion ? item.deliveredAt : item.announcedAt;
          if(confirmedAnnouncement(item) && (newCompletion || !observed.has(item.id) || known.has(item.id) && !confirmedAnnouncement(known.get(item.id))) && publication && Date.parse(publication) >= baselineAt)
            unread.set(item.id,{id:item.id,kind:item.kind});
        }
        else baselineAt = now();
        for(const item of [...freshHistory,...freshItems]) {
          observed.add(item.id);
          if(item.completionTimeBasis === 'announcement' && item.deliverySourceUrl)observed.add(item.deliverySourceUrl + '#' + item.kind);
        }
      }
      for(const item of [...freshHistory,...freshItems])if(!confirmedAnnouncement(item))unread.delete(item.id);
      const previous = project(), previousItems = previous.items;
      const evidence = new Map([...freshHistory, ...freshItems].map(item => [item.id, item]));
      // Absence only changes status when both complete, fresh feeds agree. Failure
      // or an empty single-source lookup must preserve the pending announcement.
      const reconciled=fresh && Array.isArray(input.reconciledIds) && input.reconciledIds.every(id=>alertIdentity(id)) ? new Set(input.reconciledIds) : null;
      const retained = previousItems.map(item => evidence.has(item.id) ? deduplicate([item, evidence.get(item.id)])[0] :
        reconciled && !reconciled.has(item.id) && !item.deliveredAt ? {...item,sourceWithdrawn:true} : item);
      for(const item of retained)if(item.sourceWithdrawn)unread.delete(item.id);
      const records = linkCompletions([...previous.history, ...retained, ...freshHistory, ...freshItems]);
      for (const item of records) if (item.kindBasis === 'original') {
        const oldId = item.sourceUrl + (item.kind === 'banked' ? '#regular' : '#banked');
        if (unread.delete(oldId)) unread.set(item.id, {id:item.id,kind:item.kind});
      }
      for (const item of records) if (item.deliverySourceUrl && item.deliverySourceUrl !== item.sourceUrl) {
        const alias = item.deliverySourceUrl + '#' + item.kind;
        if (unread.delete(alias)) unread.set(item.id, {id:item.id,kind:item.kind});
      }
      const currentIds = new Set([...retained, ...freshItems].map(item=>item.id));
      const historicalIds = new Set([...previous.history, ...freshHistory, ...retained.filter(item=>item.sourceWithdrawn)].map(item=>item.id));
      const currentRecords = records.filter(item => currentIds.has(item.id) || currentIds.has(item.deliverySourceUrl + '#' + item.kind));
      snapshot = { status: input?.status === 'ok' ? 'ok' : 'unavailable',
        reason: input?.status === 'ok' ? null : ['source-stale','invalid-data'].includes(input?.reason) ? input.reason : 'request-failed',
        lastFetchedAt: fresh ? now() : snapshot.lastFetchedAt,
        items: currentRecords,
        history: records.filter(item=>historicalIds.has(item.id) || historicalIds.has(item.deliverySourceUrl + '#' + item.kind)),
        sourceUpdatedAt: timestamp(input?.sourceUpdatedAt, now()) || snapshot.sourceUpdatedAt,
        stale: input?.status !== 'ok' || input?.stale === true || currentRecords.some(item => !item.sourceWithdrawn &&
          !evidence.has(item.id) && !evidence.has(item.deliverySourceUrl + '#' + item.kind)) };
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
  if (!response.ok) throw new Error(`External API returned ${response.status}`);
  try { return await response.json(); }
  catch (error) {
    if (error instanceof SyntaxError) throw Object.assign(new Error('External API returned invalid JSON', { cause: error }), { code: 'invalid-data' });
    throw error;
  }
}

export async function queryExternal({ fetchFn = fetch, now = Date.now() } = {}) {
  const [primary, backup] = await Promise.allSettled(PROVIDERS.map(url=>fetchJson(url,fetchFn)));
  const failed = result => emptyAnnouncements(result.reason?.code === 'invalid-data' ? 'invalid-data' : 'request-failed');
  const archive = backup.status === 'fulfilled' ? normalizeCodexHistory(backup.value,now) : failed(backup);
  const kinds = new Map(archive.history.map(item=>[item.sourceUrl,item.kind]));
  const feed = primary.status === 'fulfilled' ? normalizeCodexFeed(primary.value,now,kinds) : failed(primary);
  const views = [archive,feed];
  const fresh = views.filter(view=>view.status === 'ok' && !view.stale);
  const records = linkCompletions(views.flatMap(view=>view.history));
  const activeIds = new Set(views.flatMap(view=>view.items).map(item=>item.id));
  const sourceUpdatedAt = (fresh.length ? fresh : views).map(view=>view.sourceUpdatedAt).filter(Boolean).sort().at(-1) || null;
  const announcementView = { status: fresh.length ? 'ok' : 'unavailable',
    reason: fresh.length ? null : views.some(view=>view.reason === 'source-stale') ? 'source-stale' :
      views.some(view=>view.reason === 'invalid-data') ? 'invalid-data' : 'request-failed',
    items: records.filter(item=>active(item, now) && (activeIds.has(item.id) || activeIds.has(item.deliverySourceUrl + '#' + item.kind))),
    history: records, sourceUpdatedAt, stale: !fresh.length };
  // These feeds are partial and retain different event stages. Absence cannot withdraw a promise.
  const latest = records.filter(item=>item.kind === 'regular' && item.announcedAt)
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
