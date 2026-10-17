// Bounded, deterministic interpretation of the fixed public sources. A post's
// type and stage come from the same clause; archive labels are not completion.
const kinds = ['regular', 'banked'];
export function publicPostUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password &&
      ['x.com', 'twitter.com', 'www.twitter.com'].includes(url.hostname) &&
      /^\/thsottiaux\/status\/\d+$/.test(url.pathname) ? 'https://x.com' + url.pathname : null;
  } catch { return null; }
}
const idUrl = value => /^\d+$/.test(String(value || '')) ? `https://x.com/thsottiaux/status/${value}` : null;
const author = value => typeof value === 'string' ? value.replace(/^@/, '').toLowerCase() : null;
function quoteIdentities(post,quoted=null) {
  const fields=[[post?.quoted_url,publicPostUrl],[post?.quoted_tweet_id,idUrl],[post?.quoted_status_id,idUrl],
    [quoted?.url,publicPostUrl],[quoted?.id,idUrl],[quoted?.id_str,idUrl]];
  const urls=fields.filter(([value])=>value!==undefined && value!==null && value!=='').map(([value,parse])=>parse(value));
  return urls.some(url=>!url) || new Set(urls).size>1 ? null : urls;
}
function quotedPost(post) {
  const quoted = post?.quoted_tweet || post?.quoted_status;
  if (!quoted || typeof quoted !== 'object') return null;
  const handle = author(quoted.author?.screen_name || quoted.author?.username || quoted.user?.screen_name);
  if (handle && handle !== 'thsottiaux') return null;
  if(!quoteIdentities(post,quoted))return null;
  const url = publicPostUrl(quoted.url) || (handle === 'thsottiaux' ? idUrl(quoted.id || quoted.id_str) : null);
  return url ? { ...quoted, url } : null;
}
export function publicRelations(post) {
  const quoted = quotedPost(post), replyAuthor = author(post?.replying_to);
  const nested=post?.quoted_tweet || post?.quoted_status;
  const quoteUrls=nested ? [quoted?.url] : quoteIdentities(post)||[];
  return [...new Set([
    ...quoteUrls,
    !replyAuthor || replyAuthor === 'thsottiaux' ? idUrl(post?.in_reply_to_tweet_id || post?.in_reply_to_status_id) : null,
  ].filter(Boolean))];
}
export function publicPostIndex(posts) {
  const result = new Map();
  for (const post of posts) {
    const url = publicPostUrl(post?.url);
    if (url) result.set(url, post);
    const quoted = quotedPost(post);
    if (quoted && !result.has(quoted.url)) result.set(quoted.url, quoted);
  }
  return result;
}
const cleanText = value => typeof value === 'string' ? value.slice(0, 2000).replace(/https:\/\/\S+/g, '').trim() : '';
const kindIn = value => /\bbanked resets?\b|\breset credits?\b/i.test(value) ? 'banked' :
  /\b(?:global|quota|codex) resets?\b|\breset (?:rate|usage) limits\b/i.test(value) ? 'regular' : null;
const allKinds = value => [
  /\b(?:global|quota|codex) resets?\b|\breset (?:rate|usage) limits\b/i.test(value) && 'regular',
  /\bbanked resets?\b|\breset credits?\b/i.test(value) && 'banked',
].filter(Boolean);
// Independently checked campaign: 2026-10-04, 28 days of improvements OR a
// full reset. Only an explicit Reset day can supply a related reply's topic.
function campaignReset(post) {
  const at=Date.parse(post?.declared_at??post?.at),start=Date.parse('2026-10-04T20:33:43Z');
  return at>=start&&at<start+28*86400000&&
    /^Day\s+(?:[1-9]|1\d|2[0-8])\s*[/:-]\s*(?:Full )?Reset[.!]?\s*$/im.test(cleanText(post?.text));
}
const unsafe = value => /\?\s*$|\b(if|would|could|might|maybe|when|once|unless|until|assuming|provided|whether|never)\b|as long as/i.test(value);
const negative = value => /\b(?:not|no)\b|n't\b/i.test(value);
const future = value => /\b(will|going to|should|plan|planning|expect|tomorrow|tonight|soon|later|by)\b/i.test(value);
function stage(sentence, context = false) {
  if (unsafe(sentence) || negative(sentence)) return 'unconfirmed';
  if(/\b(?:some|selected) accounts\b|\bpartial(?:ly)?\b|\bin progress\b|\bstill rolling out\b/i.test(sentence))return 'unconfirmed';
  if (!future(sentence) && (/^(?:(?:the|this) )?(?:(?:global|codex|quota|banked) )?resets? (?:(?:has|have) been processed|(?:is|are) (?:complete|done|live)|(?:all )?propagated|(?:has|have) (?:landed|arrived))/i.test(sentence) ||
      /^(?:(?:the|this) )?(?:banked resets?|reset credits?) (?:have|has) been (?:granted|delivered|added)/i.test(sentence) ||
      context && /^(?:done and dusted|it(?:['’]s| is) (?:done|complete|completed)|all propagated|confirmed (?:landed|delivered)(?: across all accounts)?|all reset for everyone)[.!]?$/i.test(sentence))) return 'complete';
  if (/^global reset (?:by|at|today|tomorrow|tonight|landing)\b|^global reset will (?:happen|occur|take place|be (?:issued|applied|performed|rolled out))\b/i.test(sentence) ||
      /^(?:(?:we|i)(?:'re|'m| are| am) )?(?:loading|granting|giving) (?:a |one |the )?(?:new )?(?:banked |global )reset\b/i.test(sentence) ||
      /^(?:(?:we|i)(?:'ll| will|(?:'re|'m| are| am) going to)|will|going to) (?:(?:load|grant|give|perform|issue|apply|roll out|do) (?:a |one |the )?(?:new )?(?:banked |global )reset\b|reset (?:rate|usage) limits\b)/i.test(sentence) ||
      context && /^landing (?:within|in|by)\b/i.test(sentence)) return 'announced';
  return 'unconfirmed';
}
export function analyzePublicPost(post, index = new Map(), fallbackKind = null) {
  const text = cleanText(post?.text), relatedUrls = publicRelations(post);
  const clauses = text.split(/(?<=[.!?])\s+|\n|;\s*|\s+(?:and|but)\s+(?=(?:we|i|a|the|global|banked|quota|codex)\b)/i).map(value => value.trim()).filter(Boolean);
  const mentioned = [...new Set(clauses.map(kindIn).filter(Boolean))];
  const related = relatedUrls.map(url => index.get(url)).filter(Boolean);
  const contextKinds = [...new Set(related.filter(value => !unsafe(cleanText(value.text)) && !negative(cleanText(value.text)))
    .flatMap(value => campaignReset(value)?['regular']:allKinds(cleanText(value.text))))];
  const contextual = mentioned.length === 1 ? mentioned[0] : !mentioned.length && contextKinds.length === 1 ? contextKinds[0] : null;
  const rhetorical = clauses.some((clause, i) => i > 0 && /^it(?:['’]s| is) (?:done|complete|completed)[.!]?$/i.test(clause) &&
    /^what would you like with your side of (?:a |the )?(?:(?:global|banked) )?reset\?$/i.test(clauses[i - 1]));
  const exactArchiveCompletion = /^(?:all propagated|confirmed (?:landed|delivered) across all accounts)[.!]?$/i.test(text);
  const samePostContext = rhetorical || /^put the reset in the bag[.!]/i.test(text);
  const inferred = contextual || (samePostContext || exactArchiveCompletion ? fallbackKind || 'regular' : null);
  const subjects = mentioned.length ? mentioned : [inferred || fallbackKind].filter(value => kinds.includes(value));
  return subjects.map(kind => {
    const relevant = clauses.filter(clause => kindIn(clause) === kind || !kindIn(clause) &&
      (inferred === kind || samePostContext || exactArchiveCompletion));
    const correction = relevant.some(clause => !unsafe(clause) && negative(clause) && /\bcomplete|\bdone|\bprocessed|\bdelivered|\bgranted/i.test(clause)) ? 'not-complete' :
      relevant.some(clause => !unsafe(clause) && !negative(clause) && /\b(cancelled|canceled)\b/i.test(clause)) ? 'cancelled' :
      relevant.some(clause => !unsafe(clause) && !negative(clause) && /\b(postponed|delayed)\b/i.test(clause)) ? 'delayed' : null;
    const safeTopic = mentioned.length === 1 && clauses.some(clause => kindIn(clause) === kind && !unsafe(clause) && !negative(clause) && !future(clause) &&
      !/\b(ui|button|patch|interface|redesign)\b/i.test(clause));
    const stages = relevant.map(clause => stage(clause, contextKinds.includes(kind) || safeTopic || samePostContext || exactArchiveCompletion));
    const claim = correction ? 'unconfirmed' : stages.includes('complete') ? 'complete' : stages.includes('announced') ? 'announced' : 'unconfirmed';
    return { kind, claim, correction, relatedUrls, timeText:relevant.filter(clause=>!unsafe(clause)&&!negative(clause)).join('\n'),
      previewContextUrls:kind==='regular'?related.filter(campaignReset).map(value=>publicPostUrl(value.url)).filter(Boolean):[],
      multiKind: mentioned.length > 1, kindKnown: Boolean(mentioned.includes(kind) || inferred),
      originalKind: mentioned.includes(kind), contextValidated: Boolean(contextKinds.includes(kind)),
      // Generic archive completions remain the website's interpretation.
      originalStatement: Boolean(mentioned.includes(kind) || contextual || rhetorical) };
  });
}
