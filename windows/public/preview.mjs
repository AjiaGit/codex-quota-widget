// Public-message rules shared by the service and browser. No account data.
const DAY=86400000;
const stamp=value=>typeof value==='string'&&/^\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d(?:\.\d+)?)?(?:Z|[+-]\d\d:\d\d)$/i.test(value)?Date.parse(value):NaN;
export function parsePreviewTime(value,publishedAt) {
  const text=typeof value==='string'?value.slice(0,2000):'',published=stamp(publishedAt);
  const empty={scheduleText:null,scheduledFrom:null,scheduledAt:null,schedulePrecision:null};
  if(!Number.isFinite(published))return empty;
  const relative=text.match(/\b(within (?:the next )?|in )(\d{1,3}) (minutes?|hours?)\b/i);
  if(relative) {
    const duration=Number(relative[2])*(/^hour/i.test(relative[3])?3600000:60000);
    if(duration>0&&duration<=7*DAY)return {scheduleText:relative[0],scheduledFrom:new Date(published).toISOString(),
      scheduledAt:new Date(published+duration).toISOString(),schedulePrecision:/^within/i.test(relative[1])?'window':'approximate'};
  }
  const absolute=text.match(/\b(?:at|by) (\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d(?:\.\d+)?)?(?:Z|[+-]\d\d:\d\d))\b/i);
  if(absolute&&Number.isFinite(stamp(absolute[1])))return {...empty,scheduleText:absolute[0],scheduledAt:new Date(stamp(absolute[1])).toISOString(),schedulePrecision:/^by/i.test(absolute[0])?'deadline':'instant'};
  const pacific=text.match(/\b(?:at|by|before) (1[0-2]|0?[1-9])(?::([0-5]\d))?\s*(am|pm) (PST|PDT|PT)\b/i);
  if(pacific) {
    const prefix=text.slice(0,pacific.index),suffix=text.slice(pacific.index+pacific[0].length);
    const calendar=String.raw`(?:tomorrow|today)(?:\s+(?:morning|afternoon|evening|night))?\b|tonight\b|(?:on|next|this)\s+[^.;!?]+|(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|January|February|March|April|May|June|July|August|September|October|November|December|\d{4}-\d\d-\d\d)\b[^.;!?]*`;
    const before=prefix.match(new RegExp(String.raw`\b(${calendar})\s*$`,'i'));
    const after=suffix.match(new RegExp(String.raw`^\s+(${calendar})`,'i'));
    const qualifiers=[before?.[1],after?.[1]].filter(Boolean).map(value=>value.trim().toLowerCase());
    const scheduleText=[before?.[0].trim(),pacific[0],after?.[0].trim()].filter(Boolean).join(' ');
    if(/^PT$/i.test(pacific[4])||qualifiers.some(value=>!/^(?:tomorrow|today)$/.test(value))||new Set(qualifiers).size>1)
      return {...empty,scheduleText,schedulePrecision:'text'};
    // Literal PST/PDT offsets: tomorrow follows the publication date in the
    // stated zone, which may still be yesterday relative to UTC or the user.
    const offset=/^PST$/i.test(pacific[4])?-8:-7,date=new Date(published+offset*3600000);
    if(qualifiers.includes('tomorrow'))date.setUTCDate(date.getUTCDate()+1);
    date.setUTCHours(Number(pacific[1])%12+(/^pm$/i.test(pacific[3])?12:0),Number(pacific[2]||0),0,0);
    const scheduledAt=new Date(date.getTime()-offset*3600000).toISOString();
    return {...empty,scheduleText,scheduledAt,schedulePrecision:/^at/i.test(pacific[0])?'instant':'deadline'};
  }
  const utc=text.match(/\b(?:at|by) ([01]?\d|2[0-3]):([0-5]\d) (UTC|GMT)\b/i);
  if(utc) {
    const prefix=text.slice(0,utc.index),suffix=text.slice(utc.index+utc[0].length);
    const before=prefix.match(/\b(tomorrow|today|on\s+[^.;!?]+|next\s+[^.;!?]+)\s*$/i);
    const after=suffix.match(/^\s+(tomorrow\b|today\b|on\s+[^.;!?]+|next\s+[^.;!?]+)/i);
    const qualifiers=[before?.[1],after?.[1]].filter(Boolean).map(value=>value.trim());
    const scheduleText=[before?.[0].trim(),utc[0],after?.[0].trim()].filter(Boolean).join(' ');
    if(qualifiers.some(value=>!/^(?:tomorrow|today)$/i.test(value))||new Set(qualifiers.map(value=>value.toLowerCase())).size>1)
      return {...empty,scheduleText,schedulePrecision:'text'};
    const date=new Date(published);
    if(qualifiers.some(value=>/^tomorrow$/i.test(value)))date.setUTCDate(date.getUTCDate()+1);
    date.setUTCHours(Number(utc[1]),Number(utc[2]),0,0);
    if(date.getTime()>=published)return {...empty,scheduleText,scheduledAt:date.toISOString(),schedulePrecision:/^by/i.test(utc[0])?'deadline':'instant'};
  }
  const vague=text.match(/\b(?:by EOD(?:\s+(?:PST|PDT|PT|UTC|GMT)(?: time)?)?|tomorrow|tonight|soon|later today)\b/i);
  return vague?{...empty,scheduleText:vague[0],schedulePrecision:'text'}:empty;
}
export function previewDeadline(item) {
  const scheduled=stamp(item?.scheduledAt),published=stamp(item?.announcedAt);
  if(Number.isFinite(scheduled))return scheduled;
  if(item?.scheduledDate&&/^\d{4}-\d\d-\d\d$/.test(item.scheduledDate))return Date.parse(item.scheduledDate+'T00:00:00Z')+DAY;
  return Number.isFinite(published)?published+DAY:NaN;
}
export function isResetPreview(item,now=Date.now()) {
  const published=stamp(item?.announcedAt);
  return item?.kind==='regular'&&item.certainty==='announced'&&!item.deliveredAt&&!item.correction&&!item.sourceWithdrawn&&
    item.announcementBasis==='original'&&/^https:\/\/x\.com\/thsottiaux\/status\/\d+$/.test(item.sourceUrl||'')&&
    Number.isFinite(published)&&published<=now&&previewDeadline(item)>now;
}
export function previewVersion(item) {
  return JSON.stringify([item.kind,item.correction||null,item.scheduledAt||null,item.scheduledFrom||null,item.scheduledDate||null,
    item.schedulePrecision||null,!item.scheduledAt?item.scheduleText?.toLowerCase().trim().replace(/\s+/g,' ')||null:null,item.scope||null,item.scopeLabel||null]);
}
