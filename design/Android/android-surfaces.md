# Android surfaces

Where Limit shows up outside its own screen, and the Android rules each surface follows. All of these are glance surfaces, so the driving rules from iOS apply: sign then speed, two numbers at most, nothing to tap while moving, no flashing.

## Ongoing notification (the Lock Screen surface)

- Required anyway: a location foreground service must show a notification while it runs. Make it useful rather than a “Limit is running” placeholder.
- Use the standard notification template, not a custom view: it adapts to every manufacturer’s shade, to dark mode and to the Lock Screen. Title carries the limit and road, text carries your speed, one action: **End drive**.
- Large icon is the sign, rendered to a bitmap at the current limit. Small (status bar) icon is the monochrome sign outline.
- Own notification channel, “Drive in progress”, low importance: silent, no heads-up, no vibration. A second, default-off channel “Limit changes” can carry the optional chime.
- Update the notification when the *limit* changes; update speed no more than once every few seconds. Rapid updates can be rate-limited by the system and cost battery.
- Recent Android versions add promoted “Live Updates” with a status bar chip. A speed-limit drive may or may not meet the eligibility rules; treat the chip as a bonus to verify, not something the design depends on.

## Home screen widget

- Built with Jetpack Glance. Resizable: 2×2 (sign and speed) and 4×1 (sign, road, speed, End drive).
- Idle, it’s a launcher for **Start drive** and shows data freshness. During a drive the app pushes updates to it; widgets aren’t refreshed fast enough on their own to show live speed.
- Use the system widget corner radius and, with dynamic colour, the system widget colours.

## Quick Settings tile

- One tile, **Drive**, inactive/active. Tapping starts or ends a drive without opening the app: the most Android-native shortcut there is, usable before setting off.
- If location permission hasn’t been granted, tapping opens the app’s setup instead.

## Android Auto

- Android Auto apps must use the Car App Library’s templates and fit an allowed category. A speed-limit display isn’t obviously in one. Treat Android Auto as unconfirmed until checked against Google’s current categories and quality guidelines.
- If it qualifies, use a simple pane template with the sign as an image and speed as a row: no custom drawing.
- Until then, the mounted phone is the in-car surface. That’s why the main screen has a landscape layout.

## Battery and background rules

- Never ask users to turn off battery optimisation for the app. Play policy restricts it, and a foreground service doesn’t need it.
- Ask only for “While using the app” location. A foreground service started from a visible action keeps working with the screen off, so background location (and its extra Play review) isn’t needed.
- Stop the service when the drive ends, and stop it automatically after a long period stationary, telling the user in the notification first.
