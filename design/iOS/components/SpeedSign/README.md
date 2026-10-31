# SpeedSign

The posted speed limit, drawn as an NZ regulatory sign: a `sign-face` disc, a `sign-ring` ring 11% of the diameter, numerals in the `sign-numeral` style at 42% of the diameter (36% for 100+).

**States.** *Limit* (the normal case). *Stale* adds a small `caution` badge when register data is older than the freshness threshold; the limit still shows. *Unknown* swaps the ring to `unknown` and the numerals for an en dash when there’s no GPS fix, the position is off the register, or the data is too old to trust.

**Sizes.** 120 pt on the driving screen, 72 in CarPlay, 56 on the Lock Screen, 24 in the Dynamic Island (drop the badge below 40 pt).

**Rules.** Identical in light and dark. Never tappable, never animated except the numeral’s numeric transition. Never use the red ring anywhere else in the app. Accessibility label “Speed limit 50 kilometres per hour”; for unknown, “Speed limit unknown”.

**The consumer provides** the limit (Int?) and a freshness flag; the view decides the state.
