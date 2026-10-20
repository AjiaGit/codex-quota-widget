# 术语与公开数据来源

**本账号额度恢复 / Account quota recoveries**是本工具对本机观测到的额度回升所用的名称，不是官方重置类型。记录展示恢复前后百分比、上次观测与本次检测的时间区间；无法据此确定恢复原因、准确时刻或其他账号的送达状态，界面与公共消息按时间合并显示，但两类证据保持独立。

[English](TERMINOLOGY.md) | 简体中文

## 重置术语

| 英文术语 | 本工具中文名称 | 含义 |
| --- | --- | --- |
| Reset credit / banked reset | 重置卡 / 可用重置卡 | 保存在账号中，可在到期前由用户手动使用的一次额度重置。 |
| Quota reset（来源也称 global / automatic reset） | 额度重置 | 直接对公告所列符合条件的账号生效，不会增加可保留的重置卡。 |
| Credits | 付费使用额度 | 单独购买的额外使用额度，与重置卡不同。 |
| Usage limits | 用量限制 | 账号适用的使用额度限制。 |
| Weekly / 5-hour usage window | 每周 / 5 小时用量周期 | 账号的常规用量周期，与活动赠送的重置分别处理。 |

英文名称及含义依据 [OpenAI 的 Banked reset 说明](https://help.openai.com/en/articles/20001498-how-banked-codex-resets-work)。中文名称是本工具按官方含义采用的译法，并非声称 OpenAI 已统一使用这些中文名称。重置卡不是现金、充值卡或 API 额度；资格、到期时间和重置范围按具体活动及账号的 Usage 页面为准。

英文界面将可留存的重置机会称为 **Reset credits**，数量栏使用 **Available resets**；中文称为**重置卡**，数量单位为**张**。[Codex App Server 文档](https://learn.chatgpt.com/docs/app-server#8-earned-rate-limit-resets-chatgpt)也区分了 earned reset credits 与使用额度。

## 自动刷新是什么意思？

- **额度每 1 分钟：**通过本机 Codex App Server 读取已登录账号的额度；可用重置卡也来自该账号的返回数据。
- **公共信息每 10 分钟：**读取下列第三方监控站点的公开公告与完成记录。这是工具检查的间隔，不是 OpenAI 发放或重置的间隔。
- 本工具不会向这些公开站点发送个人额度或登录凭据。

| 内容 | 结构化数据来源 |
| --- | --- |
| 全局与储备重置历史 | `https://codexreset.dev/api/history` |
| 公告原帖列表 | `https://codex-reset.com/api/feed` |

来源说明见 [Codex Reset API 文档](https://codex-reset.com/developers)与 [CodexReset.dev](https://codexreset.dev/api/)。它们是独立监控站点，不是 OpenAI 官方 API。

工具不会搜索 X、直接抓取 X 或调用 AI，而是对站点提供的原文做保守短语匹配，识别明确预告与完成声明；分类、预测及条件性表述不足以确认重置。完成声明发布时间不等于个人账号恢复时间。未注明时区的 EOD 不会推断为具体日期、时刻或时区。codexreset.dev 转发 Codex Resets 的历史，镜像记录一致不构成独立验证。两家接口均为部分覆盖，缺失记录不会撤销缓存的预告。

新信息要等站点收录、工具成功刷新后才能显示，无法保证无遗漏、站点判断始终准确或即时到达。接口失败、格式变化或数据过旧时会显示不可用或待更新，已知的确认公告会保留。历史记录是公开站点的记录，不代表个人账号已经收到重置。

标明“演示数据”的截图使用虚构日期与数量，仅说明界面布局，不代表真实公告或发放证据。
