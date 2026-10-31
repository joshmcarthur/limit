# HomeWidget

A resizable home screen widget built with Jetpack Glance: a shortcut to start a drive, and a live view of it while it runs.

**Sizes.** *2×2*: sign top-start, speed bottom-start, or “Start drive” when idle. *4×1*: sign, road, speed and an End drive icon button, or idle with data freshness.

**States.** Idle (last checked time and a Start drive button); driving; over (speed in a `caution` container, `corner-small`).

**Rules.** Use the system widget corner radius and, with dynamic colour, the system widget background. The app pushes updates during a drive; the widget never polls GPS itself. When idle it shows no speed at all rather than a stale one. Content descriptions on every image and button.

**The consumer provides** state, limit, road, speed and freshness from the app’s data store.
