const en = {
  previewCancelled:'Quota-reset notice cancelled',previewDelayed:'Quota-reset notice postponed',
  previewBefore:'Expected by {time}',previewAround:'Expected around {time}',previewLiteral:'Expected: {time} (original wording)',previewExpired:'The estimated time has passed; no further update is available.',
  latestRecovery:'Last quota recovery noticed: {time}', observationType:'Website monitoring', categoryUnverifiedShort:'Unverified', relatedUnknown:'Reset-related news',
  categoryPreview:'Advance notice', categoryComplete:'Completion update', categoryUnverified:'Unverified update',
  unverifiedHelp:'It is not yet clear whether this is an advance notice or a completion message.',
  unknownHintHelp:'The event type and whether this is an advance notice or a completion message are unclear.',
  observedGrant:'{source} detected: monitoring accounts received reset credits',
  observedReset:'{source} detected: monitoring-account quota recovered', observationTime:'Website detected', siteRecordTime:'Website record updated',
  publicPartial:'Some message sources are unavailable', publicPartialHelp:'Updates may be incomplete. Working sources are still shown.',
  providerUnavailable:'{site}: unavailable', providerDelayed:'{site}: updates delayed', providerInvalid:'{site}: unusable data',
  viewWebsiteRecord:'View site record', monitoringScope:'Website monitoring accounts', freeScope:'Free accounts',
  correctionNotice:'Message corrected: the previous completion statement was withdrawn.',
  cancelledNotice:'The source cancelled this announcement.', delayedNotice:'The source postponed this announcement.',
  activityHeading:'Messages and records', accountType:'Your account', publicType:'Public message', recoveryRestored:'Your quota has recovered',
  recoveryHelp:'Observed from local quota readings. Detection time is not the exact recovery time and does not establish its cause.',
  earlierUpdates:'Earlier updates ({count})', activityEmpty:'No new messages', activityHistory:'View history ({count})', historyCollapse:'Collapse history', activityEmptyHelp:'Expand to view older records.',
  localTimeNote:'All times are local (currently {zone})', publicRefreshFailed:'Monitoring-site updates could not be fetched', publicStale:'Monitoring-site data has not updated',
  publicInvalid:'Monitoring-site data is unusable', publicSourceDelayed:'Recent updates may not be included', publicSourceTime:'Source data updated {time}',
  publicCache:'Showing saved records', publicNoCache:'No saved records are available.', publicRetry:'Retry',
  lastFetched:'Last successful refresh {time}', publicChecked:'Monitoring updates fetched {time}', publicLoading:'Fetching monitoring-site updates…',
  dataSources:'Data sources', moreMessage:'Message details', completionNotProvided:'No completion record available',
  confirmedPreview:'Confirmed announcement', upcomingGrantTitle:'Reset credits will be granted', upcomingResetTitle:'Quota will be reset',
  deliveredGrantTitle:'Reset credits granted', deliveredResetTitle:'Quota has been reset',
  unconfirmedGrantTitle:'Reset credit update awaiting verification', unconfirmedResetTitle:'Quota-reset update awaiting verification',
  siteHintTitle:'Reset update awaiting verification', siteHintSource:'Open monitoring site',
  siteHintStatus:'It is unclear whether this concerns reset credits or a quota reset, or what stage it has reached.',
  siteHintExpired:'Earlier site hint; subsequent progress is unknown.', siteHintInactive:'The site stopped flagging this hint; subsequent progress is unknown.',
  recoveryMore:'About this record', publicRetrying:'Fetching monitoring-site updates…',
  recoveryTitle:'My quota recoveries', recoveryDetected:'Noticed locally: {time}', recoveryObserved:'Previous reading: {time}', recoveryCount:'{count} records', recoveryNone:'No records',
  recoveryExplanation:'Changes to your own quota.',
  recoveryTracking:'Recording since {time}.', recoveryEmpty:'No new quota recovery recorded yet.',
  recoveryUnavailable:'Tracking unavailable. Refresh after signing in to Codex.', recoveryUnsaved:'Local saving failed; these new records may be lost when the app closes.',
  updatedNow:'Updated just now', updatedAgo:'Updated {minutes} min ago',
  resetActivity:'Quota recoveries and reset news', confirmedAnnouncements:'Public reset information', confirmedGrant:'Reset credit grant announced', confirmedReset:'Quota reset announced',
  relatedGrant:'Reset credit news', relatedReset:'Quota-reset news', sourceUnconfirmed:'Progress unclear', sourceScope:'Tracker scope: {scope}', sourceSummary:'{summary}', posted:'Posted: {time}', viewSource:'View original post',
  noAnnouncements:'Monitored sites have no new reset-update records', announcementsUnavailable:'Monitoring-site updates unavailable', informationPending:'Monitoring-site data pending update',
  upcoming:'Upcoming', waitingDelivery:'Scheduled time passed; no completion message available', announcedWaiting:'Specific time not announced', historyDeliveryUnknown:'Completion status unclear', grantDone:'Source reports reset credits granted', resetDone:'Source reports quota reset',
  scheduledGrant:'Expected grant: {time}', scheduledReset:'Expected reset: {time}', originalGrant:'Originally expected grant: {time}', originalReset:'Originally expected reset: {time}',
  localAnnouncementTime:'{date} (local {zone})', dateOnlySchedule:'{date} (time not announced)', scheduleUnknown:'Specific time not announced', published:'Published: {time}',
  sourceTimeZoneNote:'Converted from {zone} by the monitoring source; see original post.', sourceWithdrawn:'The monitoring site removed this record; this does not establish cancellation or completion.', withdrawnRecord:'Record removed by monitoring site',
  scheduled:'Scheduled', source:'Source', announcementHistory:'History', historyEmpty:'No history yet', compact:'Switch to compact', hide:'Hide floating widget',
  viewAnnouncement:'View original post', details:'Details', completionPosted:'Completion message posted', completed:'Completion time recorded by site', original:'Scheduled', retention:'Completion messages move to older records after 24h', publicPending:'Public information pending update', lastSuccess:'Last source update', cadence:'Auto-refresh: quota and reset previews every 1 min',
  historyAttribution:'Earlier historical records', activityMore:'Show {count} more',activityLess:'Show latest 3',
  brand:'Codex quota', remaining:'Remaining', weekly:'Weekly remaining', updated:'Updated', loading:'Loading', querying:'Reading Codex quota',
  unavailable:'Unavailable', stale:'Data expired', waiting:'Waiting for new cycle', waitingData:'Waiting for updated quota', resetPassed:'Reset time reached; waiting for an update',
  reset:'Resets at', countdown:'Time to reset', lastUpdate:'Last updated', resets:'Available resets', refresh:'Refresh now', interval:'Quota refreshes every minute',
  fiveHour:'Plus · 5-hour quota', global:'Quota resets', announcement:'Last announcement', delivery:'Completion record',
  language:'Language', auto:'System default',
  paid:'Paid accounts', all:'All accounts', unknownScope:'Account scope not specified', delivered:'Completion recorded by site', deliveryUnknown:'Completion status unclear',
  dataTime:'Source updated', sourceUnavailable:'Source data unavailable',
  cli_missing:'Install Codex CLI or the Codex desktop app, then reopen the widget.',
  signed_out:'Sign in to Codex, then click Refresh.', timeout:'Codex took too long. Retrying automatically.',
  network:'Connection failed. Retrying automatically.', unsupported:'This account does not report a weekly Codex quota.',
  service_unavailable:'The local widget service is not connected. Reopen the app.', query_failed:'Cannot read Codex quota. Update Codex and retry.',
  resetDetails:'Reset credit details', detailsUnknown:'Grant and expiry details are not provided.', detailsEmpty:'No detail rows were provided.', detailsPending:'Quota data unavailable or expired; refresh to view reset credit details.',
  detailsPartial:'Each reset credit is one manual quota-reset opportunity in Codex. Details may be incomplete; the available count above is authoritative.', granted:'Granted', expires:'Expires', dateUnknown:'Not provided',
  genericReset:'Reset credit', nextGrant:'Future grant dates are not provided by Codex.', resetCount:'{count}', resetOne:'1', percentRemaining:'{percent}% remaining',
  daysHours:'{days}d {hours}h', hoursMinutes:'{hours}h {minutes}m', hoursOnly:'{hours}h', minutesOnly:'{minutes}m',
  installCodex:'Codex setup instructions',
  monitorRecord:'Monitoring site',
  siteAttribution:'Record collected by {sites}',
  originalAttribution:'Record collected by {sites}',
  unknownAttribution:'Collecting site not recorded',
  hintAttribution:'Site hint',
  publisherSays:'{source} reports: {message}',
  publisherAnnounces:'{source} announces: {message}',
  siteRecords:'{source} reports: {message}',
  waitingGrantTitle:'{source}: reset credit grant schedule passed',
  waitingResetTitle:'{source}: quota-reset schedule passed',
  historicalGrantTitle:'{source}: earlier reset credit grant announcement',
  historicalResetTitle:'{source}: earlier quota-reset announcement',
  waitingGrant:'No grant-completion message available.',
  waitingReset:'No reset-completion message available.',
  unknownGrant:'Whether reset credits were granted is unclear.',
  unknownReset:'Whether quota was reset is unclear.',
  scheduleUnknownGrant:'Grant time not announced',
  scheduleUnknownReset:'Reset time not announced',
  completionHelpGrant:'This is a source report of completion; it does not confirm that your account received reset credits.',
  completionHelpReset:'This is a source report of completion; it does not confirm recovery of your account quota.',
};
const zh = {
  previewCancelled:'额度重置预告已取消',previewDelayed:'额度重置预告已延期',
  previewBefore:'预计 {time} 前',previewAround:'预计 {time} 左右',previewLiteral:'预计：{time}（原文表述）',previewExpired:'预计时段已过，暂无后续更新。',
  latestRecovery:'最近检测到额度恢复：{time}', observationType:'网站监测', categoryUnverifiedShort:'待核实', relatedUnknown:'重置相关消息',
  categoryPreview:'预告', categoryComplete:'完成消息', categoryUnverified:'待核实消息',
  unverifiedHelp:'暂无法判断是预告还是完成消息。', unknownHintHelp:'暂无法判断具体事项，以及是预告还是完成消息。',
  observedGrant:'{source} 检测到：监测账号收到重置卡', observedReset:'{source} 检测到：监测账号额度已恢复', observationTime:'网站检测', siteRecordTime:'网站记录时间',
  publicPartial:'部分来源暂不可用', publicPartialHelp:'消息可能不完整，仍在显示可用来源的记录。',
  providerUnavailable:'{site}：暂不可用', providerDelayed:'{site}：更新延迟', providerInvalid:'{site}：数据不可用',
  viewWebsiteRecord:'查看网站记录', monitoringScope:'网站监测账号', freeScope:'免费账号',
  correctionNotice:'消息已更正：此前的完成说法已撤回。', cancelledNotice:'来源已取消本次预告事项。', delayedNotice:'来源已推迟本次预告事项。',
  activityHeading:'消息与记录', accountType:'我的账号', publicType:'公开消息', recoveryRestored:'本账号额度已恢复',
  recoveryHelp:'根据本机额度变化记录。发现时间不等于准确恢复时间，也不能确认恢复原因。',
  earlierUpdates:'较早消息（{count}）', activityEmpty:'暂无新消息', activityHistory:'查看历史记录（{count}）', historyCollapse:'收起历史记录', activityEmptyHelp:'可展开查看更多历史记录。',
  localTimeNote:'所有时间均为本地时间（当前 {zone}）', publicRefreshFailed:'暂时无法更新消息', publicStale:'监控网站数据尚未更新',
  publicInvalid:'监控网站返回的数据暂不可用', publicSourceDelayed:'新消息可能尚未收录', publicSourceTime:'来源数据更新于 {time}',
  publicCache:'正在显示上次保存的记录', publicNoCache:'暂无已保存的记录。', publicRetry:'重试',
  lastFetched:'上次成功获取 {time}', publicChecked:'监控消息获取于 {time}', publicLoading:'正在获取监控网站消息…',
  dataSources:'数据来源', moreMessage:'消息详情', completionNotProvided:'尚未取得完成记录',
  confirmedPreview:'已确认预告', upcomingGrantTitle:'将赠送重置卡', upcomingResetTitle:'将重置额度',
  deliveredGrantTitle:'重置卡已发放', deliveredResetTitle:'额度已重置',
  unconfirmedGrantTitle:'重置卡消息待核实', unconfirmedResetTitle:'额度重置消息待核实',
  siteHintTitle:'重置相关消息待核实', siteHintSource:'打开监控网站',
  siteHintStatus:'尚不明确是赠送重置卡还是重置额度，也未确认进展。',
  siteHintExpired:'较早的网站提示，后续进展未知。', siteHintInactive:'网站已停止这条提示，后续进展未知。',
  recoveryMore:'记录说明', publicRetrying:'正在获取监控网站消息…',
  resetActivity:'额度恢复与重置消息',
  recoveryTitle:'我的额度恢复', recoveryDetected:'本机发现：{time}', recoveryObserved:'上次读取：{time}', recoveryCount:'{count} 条记录', recoveryNone:'暂无记录',
  recoveryExplanation:'这里只记录你自己的额度变化。',
  recoveryTracking:'从 {time} 开始记录。', recoveryEmpty:'还没有新的额度恢复记录。',
  recoveryUnavailable:'记录暂不可用，登录 Codex 后刷新。', recoveryUnsaved:'本地保存失败，本次新记录可能在关闭应用后丢失。',
  updatedNow:'刚刚更新', updatedAgo:'{minutes} 分钟前更新',
  confirmedAnnouncements:'公开重置信息', confirmedGrant:'重置卡赠送预告', confirmedReset:'额度重置预告',
  relatedGrant:'重置卡相关消息', relatedReset:'额度重置相关消息', sourceUnconfirmed:'进展尚不明确', sourceScope:'网站标注：{scope}', sourceSummary:'{summary}', posted:'消息发布 {time}', viewSource:'查看原文',
  noAnnouncements:'监控网站暂无新的重置动态记录', announcementsUnavailable:'监控网站消息暂不可用', informationPending:'监控网站数据待更新',
  upcoming:'即将到来', waitingDelivery:'原定时间已过，尚未取得完成消息', announcedWaiting:'具体时间尚未公布', historyDeliveryUnknown:'是否已完成尚不明确', grantDone:'来源表示重置卡已发放', resetDone:'来源表示额度已重置',
  scheduledGrant:'预计发放：{time}', scheduledReset:'预计重置：{time}', originalGrant:'原定发放：{time}', originalReset:'原定重置：{time}',
  localAnnouncementTime:'{date}（本地 {zone}）', dateOnlySchedule:'{date}（具体时间未公布）', scheduleUnknown:'具体时间尚未公布', published:'公告发布 {time}',
  sourceTimeZoneNote:'来源按 {zone} 时区换算；原文见公告。', sourceWithdrawn:'监控网站已撤下此记录，不代表事情已取消或完成。', withdrawnRecord:'监控网站已撤下此记录',
  scheduled:'预定', source:'来源', announcementHistory:'历史记录', historyEmpty:'暂无历史记录', compact:'切换到极简', hide:'隐藏悬浮窗',
  viewAnnouncement:'查看原帖', details:'详情', completionPosted:'完成消息发布于', completed:'网站记录完成时间', original:'原定', retention:'完成消息保留，24小时后归入历史记录', publicPending:'公开数据待更新', lastSuccess:'上次来源更新', cadence:'自动刷新：额度与重置预告每 1 分钟',
  historyAttribution:'早期历史记录', activityMore:'再显示 {count} 条',activityLess:'收起，保留最近 3 条',
  brand:'Codex 额度悬浮窗', remaining:'剩余', weekly:'本周剩余', updated:'数据已更新', loading:'正在读取', querying:'正在查询 Codex 额度',
  unavailable:'暂不可用', stale:'数据已过期', waiting:'等待新周期数据', waitingData:'正在等待新的额度数据', resetPassed:'重置时间已到，正在等待更新',
  reset:'重置时间', countdown:'距离重置', lastUpdate:'最近更新', resets:'可用重置卡', refresh:'立即刷新', interval:'每分钟读取一次额度',
  fiveHour:'Plus · 5 小时额度', global:'额度重置', announcement:'上次公告', delivery:'完成记录',
  language:'语言', auto:'跟随系统',
  paid:'付费账号', all:'所有账号', unknownScope:'适用范围未明确', delivered:'网站记录完成', deliveryUnknown:'是否已完成尚不明确',
  dataTime:'数据时间', sourceUnavailable:'站点数据暂不可用',
  cli_missing:'请安装 Codex CLI 或 Codex 桌面应用，然后重新打开工具。', signed_out:'请先登录 Codex，然后点击刷新。',
  timeout:'Codex 查询超时，正在自动重试。', network:'网络连接失败，正在自动重试。', unsupported:'当前账号未提供七天 Codex 额度。',
  service_unavailable:'本机监控服务未连接，请重新打开工具。', query_failed:'无法读取 Codex 额度，请更新 Codex 后重试。',
  resetDetails:'重置卡明细', detailsUnknown:'Codex 未提供发放和到期详情。', detailsEmpty:'Codex 未提供详情条目。', detailsPending:'额度数据暂不可用或已过期，请刷新后查看重置卡明细。',
  detailsPartial:'每张重置卡代表一次在 Codex 中手动重置额度的机会。明细可能不完整，可用数量以上方显示为准。', granted:'发放时间', expires:'到期时间', dateUnknown:'未提供',
  genericReset:'重置卡', nextGrant:'Codex 未提供未来发放日期。', resetCount:'{count} 张', resetOne:'1 张', percentRemaining:'{percent}% 剩余',
  daysHours:'{days}天 {hours}小时', hoursMinutes:'{hours}小时 {minutes}分钟', hoursOnly:'{hours}小时', minutesOnly:'{minutes}分钟',
  installCodex:'Codex 安装说明',
  monitorRecord:'监控网站',
  siteAttribution:'消息收录：{sites}',
  originalAttribution:'消息收录：{sites}',
  unknownAttribution:'收录网站未记录',
  hintAttribution:'网站提示',
  publisherSays:'{source} 表示：{message}',
  publisherAnnounces:'{source} 预告：{message}',
  siteRecords:'{source} 表示：{message}',
  waitingGrantTitle:'{source} 的重置卡赠送预告：原定时间已过',
  waitingResetTitle:'{source} 的额度重置预告：原定时间已过',
  historicalGrantTitle:'{source} 的历史重置卡赠送预告',
  historicalResetTitle:'{source} 的历史额度重置预告',
  waitingGrant:'预计时间已过，暂未查到发放完成消息。',
  waitingReset:'预计时间已过，暂未查到重置完成消息。',
  unknownGrant:'是否已发放尚不明确。',
  unknownReset:'是否已重置尚不明确。',
  scheduleUnknownGrant:'具体时间尚未公布',
  scheduleUnknownReset:'具体时间尚未公布',
  completionHelpGrant:'此为来源的发放完成消息，不能据此确认本账号已收到重置卡。',
  completionHelpReset:'此为来源的重置完成消息，不能据此确认本账号额度已恢复。',
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
