# SpeedReadout

Measured GPS speed in `speed-readout` (Roboto Flex 900, width 112, tabular), with the unit beneath in `label-large` and `on-surface-variant`.

**States.** *Normal*, plain `on-surface`. *Over*: the number sits in a `caution` container with `corner-extra-large`, `on-caution` text, and the unit line becomes “+8 over” in `caution-ink`, so the state doesn’t depend on colour. *No fix*: an en dash in `on-surface-variant` and “No GPS”.

**Motion.** `AnimatedContent` for the number. The container fades and scales from 92% with Material’s standard easing, no spring overshoot. Instant when system animations are off.

**Threshold.** Limit plus the user’s tolerance (Settings slider, 0–10 km/h), with hysteresis.

**The consumer provides** speed (`Float?`, km/h) and limit (`Int?`).
