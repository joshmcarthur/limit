# SpeedReadout

The driver’s measured GPS speed in the `speed-readout` style (SF Pro Rounded Heavy), with `km/h` beneath in `footnote` and `ink-muted`.

**States.** *Normal* is plain `ink`. *Over limit* puts the number on a `caution` pill with `on-caution` text and replaces the unit with “+7 over” in `caution-ink`, so the state reads without colour. *No fix* shows an en dash in `ink-muted` — never a frozen last value.

**Threshold.** Over-limit triggers above the limit plus a small tolerance (user setting, default a few km/h) and clears with hysteresis so it doesn’t flicker at the boundary.

**Rules.** Monospaced digits; `.contentTransition(.numericText())`. No flashing, no sound on going over. Accessibility label “Your speed 57 kilometres per hour, 7 over the limit”.

**The consumer provides** speed (Double?, km/h) and the current limit (Int?).
