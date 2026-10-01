# Terms and public data sources

English | [简体中文](TERMINOLOGY.zh-CN.md)

## Reset terminology

| Official English term | Chinese UI wording | Meaning |
| --- | --- | --- |
| Banked reset | 可用重置 / 可用重置次数 | A saved, one-time usage-limit reset that the account holder can apply before it expires. |
| Global reset / automatic reset | 全局额度重置 / 自动额度重置 | A reset applied directly to the eligible accounts described in the announcement. It does not create a saved reset. |
| Credits | 付费使用额度 | Additional usage purchased separately; not a banked reset. |
| Usage limits | 用量限制 | The account's applicable usage allowances. |
| Weekly / 5-hour usage window | 每周 / 5 小时用量周期 | The normal account usage windows, separate from a promotional reset. |

The English reset names and distinctions follow [OpenAI's banked-reset guide](https://help.openai.com/en/articles/20001498-how-banked-codex-resets-work). The Chinese labels are this project's translations of those meanings, not a claim that OpenAI has standardized these exact Chinese labels. A banked reset is not cash, a recharge card, or API credit. Eligibility, expiry and affected windows vary by offer; the account's Usage page is authoritative.

## What updates automatically?

- **Quota every 1 minute:** reads the signed-in account through the local Codex App Server. The available banked-reset count comes from that account response.
- **Public data every 10 minutes:** fetches public announcement, delivery and historical-estimate data from the third-party services below. This interval is how often the widget checks, not how often OpenAI issues resets.
- The public services receive no account quota or sign-in credentials from this widget.

| Data | Structured source |
| --- | --- |
| Recorded global resets | `https://codexreset.ai/api/v1/resets.json` |
| Historical global-reset odds | `https://codexreset.ai/api/v1/forecast.json` (relays whenreset.app estimates) |
| Confirmed scheduled announcements and history | `https://whenreset.app/api/v1/resets.json` |

See the [CodexReset API documentation](https://codexreset.ai/developers/) and [WhenReset](https://whenreset.app/). These are independent trackers, not OpenAI APIs.

The widget does not search X, scrape posts, or use an AI model to interpret them. Source links supplied by the trackers can point to X announcement posts or other evidence. Only a structured `announced` schedule is treated as confirmed; a hinted schedule or historical probability is not a confirmed announcement. Delivery is displayed only when the source provides a delivery timestamp; an elapsed scheduled time is not proof of delivery.

New information appears after the provider records it and the widget successfully refreshes. Completeness, provider accuracy and instant delivery cannot be guaranteed. Failed, malformed or expired responses are shown as unavailable or pending update; previously known confirmed announcements are retained. The history contains public provider records, not proof that an individual account received a reset.

Screenshots explicitly labeled as sample data contain fictional dates and counts. They are illustrations, not real announcements or grant evidence.
