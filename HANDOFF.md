# Project maintenance notes

## 2026-10-25 — Complete GDI link glyphs on Windows

- Applies to the Windows widget's full-caption, always-underlined GDI links. The native `LinkLabel` visual region excluded GDI glyph padding while its painter still added that padding; the last strokes were clipped even in a wider control. This affected original-post and monitoring-site links in Chinese and English.
- Keep direct GDI window painting for crisp text. `WidgetLinkLabel` now uses explicit left padding and unpadded GDI drawing for this supported link shape, matching the native mouse hit region. Other link shapes retain the native painter, and native keyboard/mouse activation remains in place. No shared text, recognition rules or macOS sources change.
- Verification: the added native-font regressions failed before the fix on four captions and passed afterward, comparing glyph pixels against an unclipped underlined GDI label and checking the trailing pixels against native link hit testing. Comparing two differently sized `LinkLabel` controls is insufficient: both can inherit the same internal clip. Physical desktop appearance and actual clicks remain a separate acceptance step.
