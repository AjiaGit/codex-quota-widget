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
  const utc=text.match(/\b(?:at|by) ([01]?\d|2[0-3]):([0-5]\d) (UTC|GMT)\b/i);
  if(utc) {
    const prefix=text.slice(0,utc.index),qualifier=prefix.match(/\b(tomorrow|today|on\s+[^.;!?]+|next\s+[^.;!?]+)\s*$/i);
    if(qualifier&&!/^(?:tomorrow|today)\s*$/i.test(qualifier[1]))return {...empty,scheduleText:qualifier[0].trim()+' '+utc[0],schedulePrecision:'text'};
    const date=new Date(published);
    if(qualifier&&/^tomorrow/i.test(qualifier[1]))date.setUTCDate(date.getUTCDate()+1);
    date.setUTCHours(Number(utc[1]),Number(utc[2]),0,0);
    if(date.getTime()>=published)return {...empty,scheduleText:(qualifier?qualifier[0].trim()+' ':'')+utc[0],scheduledAt:date.toISOString(),schedulePrecision:/^by/i.test(utc[0])?'deadline':'instant'};
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
