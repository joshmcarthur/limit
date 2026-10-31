# SpeedSign

The posted limit drawn as an NZ regulatory sign, identical to the iOS edition: `sign-face` disc, `sign-ring` ring at 11% of the diameter, `sign-numeral` (Roboto Flex 700, width 80) at 42% of the diameter, 34% for three digits.

**States.** Limit; *stale* (a `caution` badge with the `schedule` symbol when register data is past the freshness threshold); *unknown* (`unknown` ring and an en dash: no fix, off the register, or data too old).

**Android sizes.** 200 dp main screen, 72 dp widget, 40 dp in Setup. Drawn with Compose `Canvas`, not an image, so it’s sharp at any density.

**Two extra renderings Android needs.** A **bitmap** of the sign at the current limit for the notification’s large icon (render at 96 dp × density). A **monochrome silhouette** for the status bar small icon: ring outline with numerals cut out, one colour, transparent elsewhere, because Android tints small icons and drops colour.

**Rules.** Never tappable. Fixed colours regardless of dynamic colour or theme. Content description “Speed limit 50 kilometres per hour”, or “Speed limit unknown”.

**The consumer provides** the limit (`Int?`) and a stale flag.
