# LiveActivity

The Lock Screen and Dynamic Island presentation while a drive is active: sign leading, speed trailing, everywhere.

**Lock Screen.** `surface` card, `space-4` padding. SpeedSign at 56 pt; road name in `headline`, one line, truncating; “Limit from NZTA register” in `caption`; speed at 44 pt rounded with `km/h` beneath. Over the limit uses the `caution` pill.

**Dynamic Island.** Always `island` black with `on-island` text. *Compact*: 24 pt sign leading, speed trailing. *Minimal*: the sign alone. *Expanded*: the Lock Screen layout without the meta line.

**Rules.** Start when a drive is detected or from a button in the app; end when the drive ends. Updates are best-effort and may be throttled, so never show a number older than a few seconds: fall back to “–”. No alerts from the activity.

**The consumer provides** ActivityAttributes with limit, speed, road name and a stale flag.
