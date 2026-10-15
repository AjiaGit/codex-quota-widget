const en = {
  activityHeading:'Reset updates', accountType:'Your account', publicType:'Public update', recoveryRestored:'Your quota recovered',
  recoveryHelp:'Observed from local quota readings. The detection time is not the exact reset time and does not confirm a global cause.',
  earlierUpdates:'Earlier updates ({count})', activityEmpty:'No recent updates', activityEmptyHelp:'Earlier records are available in History.',
  localTimeNote:'All times are local (currently {zone})', publicRefreshFailed:'Public updates could not be fetched', publicStale:'Public announcement source has not updated',
  publicInvalid:'Public source returned unusable data', publicSourceDelayed:'Recent announcements may not be included', publicSourceTime:'Source data updated {time}',
  publicCache:'Showing saved public updates', publicNoCache:'No saved public updates are available.', publicRetry:'Retry',
  lastFetched:'Last successful refresh {time}', publicChecked:'Public information checked {time}', publicLoading:'Reading public updates',
  dataSources:'Data sources', moreMessage:'Message details', completionNotProvided:'Completion time: not provided by source',
  confirmedPreview:'Confirmed announcement', upcomingGrantTitle:'Banked reset grant announced', upcomingResetTitle:'Global reset announced',
  deliveredGrantTitle:'Source recorded a reset grant', deliveredResetTitle:'Source recorded a global reset',
  unconfirmedGrantTitle:'Reset grant update', unconfirmedResetTitle:'Quota reset update',
  siteHintTitle:'Monitoring-site hint', siteHintSource:'Source: codex-reset.com',
  siteHintStatus:'Site signal; not a confirmed reset announcement',
  siteHintExpired:'Site hint expired; no reset confirmation inferred', siteHintInactive:'Site no longer marks this signal as active',
  recoveryMore:'About this record', publicRetrying:'Refreshing public updates',
  recoveryTitle:'My quota recoveries', recoveryDetected:'Noticed locally: {time}', recoveryObserved:'Previous reading: {time}', recoveryCount:'{count} records', recoveryNone:'No records',
  recoveryExplanation:'Changes to your own quota.',
  recoveryTracking:'Recording since {time}.', recoveryEmpty:'No new quota recovery recorded yet.',
  recoveryUnavailable:'Tracking unavailable. Refresh after signing in to Codex.', recoveryUnsaved:'Local saving failed; these new records may be lost when the app closes.',
  updatedNow:'Updated just now', updatedAgo:'Updated {minutes} min ago',
  resetActivity:'Quota recoveries and reset news', confirmedAnnouncements:'Public reset information', confirmedGrant:'Confirmed banked reset grant', confirmedReset:'Confirmed global reset',
  relatedGrant:'Banked reset news', relatedReset:'Global reset news', sourceUnconfirmed:'Tracker has no completion time', sourceScope:'Tracker scope: {scope}', sourceSummary:'{summary}', posted:'Posted: {time}', viewSource:'View original post',
  noAnnouncements:'Monitored sources report no confirmed banked reset grant or global reset announcements', announcementsUnavailable:'Announcement information unavailable', informationPending:'Information pending update',
  upcoming:'Upcoming', waitingDelivery:'Scheduled time passed; monitoring sources have no completion record', announcedWaiting:'Announced; awaiting delivery', historyDeliveryUnknown:'Source did not provide a delivery record', grantDone:'Granted', resetDone:'Reset confirmed',
  scheduledGrant:'Scheduled grant: {time}', scheduledReset:'Scheduled reset: {time}', originalGrant:'Originally scheduled grant: {time}', originalReset:'Originally scheduled reset: {time}',
  localAnnouncementTime:'{date} (local {zone})', dateOnlySchedule:'{date} (time not announced)', scheduleUnknown:'Delivery time not announced', published:'Published: {time}',
  sourceTimeZoneNote:'Converted from {zone} by the monitoring source; see original post.', sourceWithdrawn:'Monitoring sources no longer list this record', withdrawnRecord:'Record withdrawn by sources',
  scheduled:'Scheduled', source:'Source', announcementHistory:'History', historyEmpty:'No history yet', compact:'Switch to compact', hide:'Hide floating widget',
  viewAnnouncement:'View announcement', details:'Details', completionPosted:'Completion statement posted', completed:'Completed', original:'Scheduled', retention:'Completed results retained for 24h', publicPending:'Public information pending update', lastSuccess:'Last source update', cadence:'Auto-refresh: quota every 1 min · public data every 10 min',
  historyAttribution:'Earlier historical records', activityMore:'Show {count} more',activityLess:'Show latest 5',
  brand:'Codex quota', remaining:'Remaining', weekly:'Weekly remaining', updated:'Updated', loading:'Loading', querying:'Reading Codex quota',
  unavailable:'Unavailable', stale:'Data expired', waiting:'Waiting for new cycle', waitingData:'Waiting for updated quota', resetPassed:'Reset time reached; waiting for an update',
  reset:'Resets at', countdown:'Time to reset', lastUpdate:'Last updated', resets:'Banked resets', refresh:'Refresh now', interval:'Quota refreshes every minute',
  fiveHour:'Plus · 5-hour quota', global:'Public global resets', announcement:'Last announcement', delivery:'Delivery record',
  language:'Language', auto:'System default',
  paid:'Paid accounts', all:'All accounts', unknownScope:'Account scope: see announcement', delivered:'Delivery recorded by source', deliveryUnknown:'Delivery time not confirmed',
  dataTime:'Source updated', sourceUnavailable:'Source data unavailable',
  cli_missing:'Install Codex CLI or the Codex desktop app, then reopen the widget.',
  signed_out:'Sign in to Codex, then click Refresh.', timeout:'Codex took too long. Retrying automatically.',
  network:'Connection failed. Retrying automatically.', unsupported:'This account does not report a weekly Codex quota.',
  service_unavailable:'The local widget service is not connected. Reopen the app.', query_failed:'Cannot read Codex quota. Update Codex and retry.',
  resetDetails:'Available reset details', detailsUnknown:'Grant and expiry details are not provided.', detailsEmpty:'No detail rows were provided.', detailsPending:'Quota data unavailable or expired; refresh to view current reset details.',
  detailsPartial:'The list may be incomplete; the available count above is authoritative.', granted:'Granted', expires:'Expires', dateUnknown:'Not provided',
  genericReset:'Banked reset', nextGrant:'Future grant dates are not provided by Codex.', resetCount:'{count} resets', resetOne:'1 reset', percentRemaining:'{percent}% remaining',
  daysHours:'{days}d {hours}h', hoursMinutes:'{hours}h {minutes}m', hoursOnly:'{hours}h', minutesOnly:'{minutes}m',
  installCodex:'Codex setup instructions',
};
const zh = {
  activityHeading:'重置动态', accountType:'我的账号', publicType:'公开消息', recoveryRestored:'本账号额度已恢复',
  recoveryHelp:'依据本机额度变化记录。发现时间不是准确重置时刻，也不能确认全局重置原因。',
  earlierUpdates:'较早消息（{count}）', activityEmpty:'最近没有新动态', activityEmptyHelp:'历史消息仍可在下方查看。',
  localTimeNote:'所有时间均为本地时间（当前 {zone}）', publicRefreshFailed:'暂时无法获取公共信息', publicStale:'公告源暂未更新',
  publicInvalid:'公告源数据暂不可用', publicSourceDelayed:'新公告可能尚未收录', publicSourceTime:'来源数据更新于 {time}',
  publicCache:'正在显示已保存的公共信息', publicNoCache:'暂无已保存的公共信息。', publicRetry:'重试',
  lastFetched:'上次成功获取 {time}', publicChecked:'公共信息获取于 {time}', publicLoading:'正在读取公共信息',
  dataSources:'数据来源', moreMessage:'消息详情', completionNotProvided:'完成时间：来源未提供',
  confirmedPreview:'已确认预告', upcomingGrantTitle:'重置次数赠送预告', upcomingResetTitle:'全局额度重置预告',
  deliveredGrantTitle:'来源已记录重置次数赠送', deliveredResetTitle:'来源已记录全局额度重置',
  unconfirmedGrantTitle:'重置次数赠送消息', unconfirmedResetTitle:'额度重置消息',
  siteHintTitle:'监控网站提示', siteHintSource:'来源：codex-reset.com',
  siteHintStatus:'网站信号，尚未确认为重置预告',
  siteHintExpired:'提示已过期，不代表重置已完成', siteHintInactive:'网站已停止提示这条信号',
  recoveryMore:'记录说明', publicRetrying:'正在刷新公共信息',
  resetActivity:'额度恢复与重置消息',
  recoveryTitle:'我的额度恢复', recoveryDetected:'本机发现：{time}', recoveryObserved:'上次读取：{time}', recoveryCount:'{count} 条记录', recoveryNone:'暂无记录',
  recoveryExplanation:'这里只记录你自己的额度变化。',
  recoveryTracking:'从 {time} 开始记录。', recoveryEmpty:'还没有新的额度恢复记录。',
  recoveryUnavailable:'记录暂不可用，登录 Codex 后刷新。', recoveryUnsaved:'本地保存失败，本次新记录可能在关闭应用后丢失。',
  updatedNow:'刚刚更新', updatedAgo:'{minutes} 分钟前更新',
  confirmedAnnouncements:'公开重置信息', confirmedGrant:'已确认重置次数赠送', confirmedReset:'已确认全局额度重置',
  relatedGrant:'重置次数赠送消息', relatedReset:'全局重置消息', sourceUnconfirmed:'网站未提供完成时间', sourceScope:'网站标注：{scope}', sourceSummary:'{summary}', posted:'消息发布 {time}', viewSource:'查看原文',
  noAnnouncements:'监控来源暂无已确认的赠送或全局额度重置公告', announcementsUnavailable:'预告信息暂不可用', informationPending:'信息待更新',
  upcoming:'即将到来', waitingDelivery:'预定时间已过，监控来源未提供完成记录', announcedWaiting:'已公告，等待送达确认', historyDeliveryUnknown:'来源未提供送达记录', grantDone:'已赠送', resetDone:'已重置',
  scheduledGrant:'预定送达 {time}', scheduledReset:'预定重置 {time}', originalGrant:'原定送达 {time}', originalReset:'原定重置 {time}',
  localAnnouncementTime:'{date}（本地 {zone}）', dateOnlySchedule:'{date}（具体时间未公布）', scheduleUnknown:'送达时间尚未公布', published:'公告发布 {time}',
  sourceTimeZoneNote:'来源按 {zone} 时区换算；原文见公告。', sourceWithdrawn:'监控来源已撤下此记录', withdrawnRecord:'来源已撤下的公告记录',
  scheduled:'预定', source:'来源', announcementHistory:'历史记录', historyEmpty:'暂无历史记录', compact:'切换到极简', hide:'隐藏悬浮窗',
  viewAnnouncement:'查看公告', details:'详情', completionPosted:'完成声明发布', completed:'确认完成', original:'原定', retention:'完成结果保留 24 小时', publicPending:'公开数据待更新', lastSuccess:'上次来源更新', cadence:'自动刷新：额度每 1 分钟 · 公共信息每 10 分钟',
  historyAttribution:'早期历史记录', activityMore:'再显示 {count} 条',activityLess:'只看最近 5 条',
  brand:'Codex 周额度', remaining:'剩余', weekly:'本周剩余', updated:'数据已更新', loading:'正在读取', querying:'正在查询 Codex 额度',
  unavailable:'暂不可用', stale:'数据已过期', waiting:'等待新周期数据', waitingData:'正在等待新的额度数据', resetPassed:'重置时间已到，正在等待更新',
  reset:'重置时间', countdown:'距离重置', lastUpdate:'最近更新', resets:'可用重置', refresh:'立即刷新', interval:'每分钟读取一次额度',
  fiveHour:'Plus · 5 小时额度', global:'公开全局额度重置', announcement:'上次公告', delivery:'送达记录',
  language:'语言', auto:'跟随系统',
  paid:'付费账号', all:'所有账号', unknownScope:'适用范围详见公告', delivered:'站点记录已送达', deliveryUnknown:'送达时间未确认',
  dataTime:'数据时间', sourceUnavailable:'站点数据暂不可用',
  cli_missing:'请安装 Codex CLI 或 Codex 桌面应用，然后重新打开工具。', signed_out:'请先登录 Codex，然后点击刷新。',
  timeout:'Codex 查询超时，正在自动重试。', network:'网络连接失败，正在自动重试。', unsupported:'当前账号未提供七天 Codex 额度。',
  service_unavailable:'本机监控服务未连接，请重新打开工具。', query_failed:'无法读取 Codex 额度，请更新 Codex 后重试。',
  resetDetails:'可用重置详情', detailsUnknown:'Codex 未提供发放和到期详情。', detailsEmpty:'Codex 未提供详情条目。', detailsPending:'额度数据暂不可用或已过期，请刷新后查看重置详情。',
  detailsPartial:'列表可能不完整，可用数量以上方显示为准。', granted:'发放', expires:'到期', dateUnknown:'未提供',
  genericReset:'可用重置', nextGrant:'Codex 未提供未来发放日期。', resetCount:'{count} 次', resetOne:'1 次', percentRemaining:'{percent}% 剩余',
  daysHours:'{days}天 {hours}小时', hoursMinutes:'{hours}小时 {minutes}分钟', hoursOnly:'{hours}小时', minutesOnly:'{minutes}分钟',
  installCodex:'Codex 安装说明',
};
export const dictionaries = { en, 'zh-CN': zh };
export function resolveLanguage(setting='auto', systemLanguage='en') {
  return setting === 'zh-CN' || (setting === 'auto' && /^zh\b/i.test(systemLanguage)) ? 'zh-CN' : 'en';
}
export function t(language, key, vars={}) {
  return (dictionaries[language]?.[key] || en[key] || key).replace(/\{(\w+)\}/g, (_,name)=>String(vars[name] ?? ''));
}
export function formatDate(milliseconds, timeZone, language) {
  if (!Number.isFinite(milliseconds) || Math.abs(milliseconds)>8640000000000000) return t(language,'dateUnknown');
  return new Intl.DateTimeFormat(language, {timeZone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false}).format(new Date(milliseconds));
}
export function formatRelativeUpdate(milliseconds, now=Date.now(), language='en') {
  if (!Number.isFinite(milliseconds) || milliseconds > now || now-milliseconds > 10*60*1000) return t(language,'unavailable');
  const minutes=Math.floor((now-milliseconds)/60000);
  return minutes < 1 ? t(language,'updatedNow') : t(language,'updatedAgo',{minutes});
}
export function formatShortDate(milliseconds,timeZone,language,now=Date.now(),dateOnly=false) {
  if (!Number.isFinite(milliseconds) || Math.abs(milliseconds)>8640000000000000) return t(language,'dateUnknown');
  const year = new Intl.DateTimeFormat('en',{timeZone,year:'numeric'});
  const options={timeZone,month:'2-digit',day:'2-digit'};
  if(year.format(milliseconds)!==year.format(now))options.year='numeric';
  if(!dateOnly)Object.assign(options,{hour:'2-digit',minute:'2-digit',hourCycle:'h23'});
  return new Intl.DateTimeFormat(language,options).format(milliseconds);
}
export function formatLocalAnnouncementDate(milliseconds,timeZone,language,now=Date.now()) {
  if (!Number.isFinite(milliseconds) || Math.abs(milliseconds)>8640000000000000) return t(language,'dateUnknown');
  // The offset must belong to the event instant, including future DST changes.
  const offset=new Intl.DateTimeFormat('en',{timeZone,timeZoneName:'longOffset'}).formatToParts(milliseconds).find(part=>part.type==='timeZoneName').value;
  const zone=offset==='GMT'?'UTC+00:00':offset.replace('GMT','UTC');
  return t(language,'localAnnouncementTime',{date:formatShortDate(milliseconds,timeZone,language,now),zone});
}
export function localTimeZone(timeZone,now=Date.now()) {
  const name=new Intl.DateTimeFormat('en',{timeZone,timeZoneName:'shortOffset'}).formatToParts(now).find(part=>part.type==='timeZoneName').value;
  if(name==='GMT')return 'UTC+00:00';
  return name.replace(/^GMT([+-])(\d{1,2})(?::(\d{2}))?$/,(_,sign,hours,minutes)=>`UTC${sign}${hours.padStart(2,'0')}:${minutes||'00'}`);
}
export function formatCompactLocalDate(milliseconds,timeZone,language,now=Date.now()) {
  return localTimeZone(timeZone,milliseconds)===localTimeZone(timeZone,now)
    ? formatShortDate(milliseconds,timeZone,language,now)
    : formatLocalAnnouncementDate(milliseconds,timeZone,language,now);
}
