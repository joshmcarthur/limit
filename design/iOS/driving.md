# Driving surfaces

Rules for anything seen while driving: the main screen in its mounted state, the Live Activity, and the CarPlay widget. They borrow directly from Apple’s CarPlay guidelines, and apply to the phone too, because a mounted phone is a dashboard.

## Glanceable

- Understandable in a single glance of a second or two. If you have to read a sentence, it’s not glanceable.
- At most two numbers (limit, speed) and one line of text (road name). Freshness and attribution live off the driving surface, or in `footnote` at the bottom.
- Content order is always **sign, then speed**: sign leading, readout trailing. The Dynamic Island’s compact leading and trailing regions map straight onto this, so the order is the same on every surface.
- Text never smaller than `caption` (12) on a driving surface; numbers never smaller than 15.

## No interaction while moving

- Nothing on a driving surface needs a tap to be useful. No settings, no dismissing, no confirmations.
- Where there are controls (in the app), touch targets are at least 44 × 44 pt.
- Never present alerts, sheets or permission prompts while the car is moving. Ask for location permission at onboarding, parked.

## Calm motion

- The only animation is numbers changing (`.contentTransition(.numericText())`) and the over-limit pill appearing with a short, non-bouncy fade.
- No flashing, pulsing or repeating animation, ever. Respect Reduce Motion by removing the pill transition.
- An optional single haptic or chime when the *limit* changes, off by default. Nothing when you go over.

## Light and dark

- CarPlay and the Live Activity follow the system’s appearance; the in-car display may force dark. Design dark first and check light.
- The sign is identical in both: white face, red ring, black numerals.

## Platform notes to verify

- **Live Activity.** Speed updates come from the app while it receives background location. Expect the system to throttle very frequent updates and to end activities after its time limit; design the readout to look correct if it is a few seconds old, and show “—” rather than a frozen number when location is lost.
- **CarPlay.** Recent iOS releases can show widgets and Live Activities in CarPlay, which may cover the CarPlay case without a full CarPlay app. A full CarPlay app needs an Apple entitlement for an eligible category (for example driving task). Check the current CarPlay developer guide before committing.
- **Data honesty.** If the register data is stale or the location is off the register, the sign shows its unknown state rather than the last known limit.
