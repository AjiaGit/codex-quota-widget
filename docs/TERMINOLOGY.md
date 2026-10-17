# Terms and public data sources

English | [简体中文](TERMINOLOGY.zh-CN.md)

## Reset terminology

| English term | Chinese UI wording | Meaning |
| --- | --- | --- |
| Reset credit / banked reset | 重置卡 / 可用重置卡 | A saved, one-time usage-limit reset that the account holder can apply before it expires. |
| Quota reset (global / automatic reset in source descriptions) | 额度重置 | A reset applied directly to the eligible accounts described in the announcement. It does not create a saved reset. |
| Credits | 付费使用额度 | Additional usage purchased separately; not a banked reset. |
| Usage limits | 用量限制 | The account's applicable usage allowances. |
| Weekly / 5-hour usage window | 每周 / 5 小时用量周期 | The normal account usage windows, separate from a promotional reset. |

The English reset names and distinctions follow [OpenAI's banked-reset guide](https://help.openai.com/en/articles/20001498-how-banked-codex-resets-work). The Chinese labels are this project's translations of those meanings, not a claim that OpenAI has standardized these exact Chinese labels. A banked reset is not cash, a recharge card, or API credit. Eligibility, expiry and affected windows vary by offer; the account's Usage page is authoritative.

The interface calls saved reset opportunities **Reset credits**, with **Available resets** as the count label. The [Codex App Server documentation](https://learn.chatgpt.com/docs/app-server#8-earned-rate-limit-resets-chatgpt) also distinguishes earned reset credits from usage credits. The Chinese interface uses **重置卡**, counted in **张**.

## What updates automatically?

**Account quota recoveries / 本账号额度恢复** is this widget's label for locally observed quota increases, not an official reset type. It shows before/after percentages and the interval between the previous observation and detection. Personal recoveries and public news share a chronological list, while their evidence remains independent. A recovery does not establish its cause, exact time, or delivery to other accounts.

- **Quota every 1 minute:** reads the signed-in account through the local Codex App Server. The available banked-reset count comes from that account response.
- **Public previews about every minute:** fetches public announcement and delivery records from the third-party services below. This interval is how often the widget checks, not how often OpenAI issues resets.
- The public services receive no account quota or sign-in credentials from this widget.

| Data | Structured source |
| --- | --- |
| Archived global and banked resets | `https://codexreset.dev/api/history` |
| Original announcement posts | `https://codex-reset.com/api/feed` |

See the [Codex Reset API documentation](https://codex-reset.com/developers) and [CodexReset.dev](https://codexreset.dev/api/). These are independent trackers, not OpenAI APIs.

The widget does not search X, scrape X directly, or use an AI model. It conservatively matches explicit promises and completion phrases in the original text supplied by the trackers. Categories, forecasts and conditional language are insufficient. Completion-statement publication time is not personal delivery time. An unspecified EOD deadline has no inferred clock time or timezone. codexreset.dev mirrors the Codex Resets archive; mirrored agreement is not independent verification. Both APIs have partial coverage, so absence cannot withdraw a cached promise.

New information appears after the provider records it and the widget successfully refreshes. Completeness, provider accuracy and instant delivery cannot be guaranteed. Failed, malformed or expired responses are shown as unavailable or pending update; previously known confirmed announcements are retained. The history contains public provider records, not proof that an individual account received a reset.

Screenshots explicitly labeled as sample data contain fictional dates and counts. They are illustrations, not real announcements or grant evidence.
