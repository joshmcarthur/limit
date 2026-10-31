# Limit

Limit is a small, open-source iOS app that shows the posted speed limit for the road you’re on in Aotearoa New Zealand, next to your GPS speed. Limits come from the NZTA National Speed Limit Register, downloaded and kept in sync on the device. It appears in three places: the app, a Live Activity (Lock Screen and Dynamic Island), and later a CarPlay widget. This system follows Apple’s Human Interface Guidelines everywhere and borrows CarPlay’s rules for the driving surfaces — see **Driving surfaces**.

This is a first, deliberately small system built from no existing source: colours, the sign red and every value here are proposals to be checked on device.

## Principles

1. **The road sign wins.** Limit is a reference, not an authority. Register data can be out of date, temporary limits and roadworks aren’t in it, and GPS drifts. The app never implies otherwise, and always shows how fresh its data is.
2. **Two numbers, one glance.** The limit and your speed. Everything else is secondary and can be removed without loss.
3. **Calm, not alarming.** No flashing, no sirens, no red. Going over the limit changes one thing quietly (see SpeedReadout).
4. **Native and boring.** SwiftUI, SF Pro, SF Symbols, system materials and list styles. No custom fonts, no custom chrome, so it stays maintainable and looks right on every iOS release.

## Content fundamentals

- NZ English: *kilometres*, *metres*, *colour*. Units are always `km/h`, lowercase, with a space before (`50 km/h`) except inside the sign and the readout, where the unit sits beneath.
- Say what the data is, not what the driver did. “Over by 7”, not “You’re speeding”. “Limit unknown”, not “Error”.
- Times relative when recent, absolute when old: “Checked today, 6:40 am”, “Last updated 3 Oct”.
- Name the source plainly: “NZTA National Speed Limit Register”. Check the register’s licence and attribute as it requires on the About screen.
- VoiceOver reads the sign as “Speed limit 50 kilometres per hour” and the readout as “Your speed 57 kilometres per hour”.

## Visual foundations

**Colour.** The sign colours (`sign-face`, `sign-ring`, `sign-ink`) are constant across themes because the sign is a road object, not UI. `sign-ring` red is reserved for the sign — never an error, badge or button. The app’s interactive colour is `tint` (blue). Over the limit uses `caution` (amber) as a fill with `on-caution` text, and `caution-ink` when amber has to be text or an icon. Over-limit is never shown by colour alone: the readout gains a pill and a “+7” label.

**Type.** Three SF families, each with one job. `display` (SF Pro Bold) is only for sign numerals. `rounded` (SF Pro Rounded Heavy) is only for measured speed, so it can never be mistaken for a sign. `sans` (SF Pro Text) is everything else, using the HIG text styles so it follows Dynamic Type. Always monospaced digits for speed (`.monospacedDigit()`), so numbers don’t jitter.

**Spacing and shape.** An 8-point grid with a 4-point half step; `space-5` (20) is the screen margin. Three radii: `radius-sm` for small pills, `radius-md` for grouped lists, `radius-lg` for cards. On device, prefer the container shapes the system gives Live Activities and widgets over hard-coded radii.

**Depth.** None of our own. Use system materials and the grouped list style; no custom shadows.

## Iconography

SF Symbols only, rendered in `ink-muted` or `tint` (hierarchical where it helps). Suggested symbols: `location.fill` (GPS), `location.slash` (no fix), `arrow.triangle.2.circlepath` (syncing), `checkmark.circle` (up to date), `exclamationmark.triangle` (stale or failed, in `caution-ink`), `info.circle` (about the data). The speed sign itself is drawn, not a symbol: a `sign-face` disc with a `sign-ring` ring 11% of its diameter.

## Components

SpeedSign, SpeedReadout, SyncStatus, LiveActivity and CarPlayWidget. Each card shows the states the SwiftUI view must handle.
