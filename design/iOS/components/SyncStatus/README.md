# SyncStatus

One row in the app’s settings and About screen saying how fresh the speed limit data is, in an inset grouped list on `surface`.

**States.** *Up to date* (`checkmark.circle`, `ink-muted`). *Updating* (`arrow.triangle.2.circlepath` in `tint`, with determinate progress). *Stale* (`exclamationmark.triangle` in `caution-ink`) past the freshness threshold. *Failed* (same icon) when the register couldn’t be reached, saying what the app is using instead and offering a retry.

**Copy.** Title says the state; subtitle says when, and from where. Never show raw error codes.

**Rules.** Sync quietly in the background (Wi‑Fi preferred); never block the driving screen on a sync. Only the stale state surfaces on driving screens, as the SpeedSign badge.

**The consumer provides** the state, last-checked date and progress.
