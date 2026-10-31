# Limit for Android

The Android edition of Limit: the posted NZ speed limit for the road you’re on, from the NZTA National Speed Limit Register, beside your GPS speed. It shares the iOS edition’s principles and its speed sign, and nothing else by default. Everything around the sign is Material 3 and Android’s own way of doing things: a foreground-service notification instead of a Live Activity, a home screen widget and a Quick Settings tile instead of Lock Screen widgets, runtime permissions explained in place, dynamic colour, edge-to-edge layout and predictive back.

This is a first system built from no existing source. Values are proposals to test on real devices, including at least one non-Pixel phone.

## Principles (shared with iOS)

1. **The road sign wins.** Limit is a reference, not an authority, and always shows how fresh its data is.
2. **Two numbers, one glance.** The limit and your speed.
3. **Calm, not alarming.** No flashing or sirens. Going over changes one thing quietly.
4. **Native and boring.** Jetpack Compose with Material 3 components, Material Symbols, system fonts for text. Custom only where Android has nothing: the sign and the readout.

## What’s different on Android, and why

- **A drive is a foreground service.** While the app is open it simply shows the limit. Keeping it running with the screen off needs a location foreground service, which Android requires to show an ongoing notification. So the notification *is* the Lock Screen surface, and “Start drive” is an explicit, visible action (an Extended FAB), not something that happens silently.
- **Permissions are asked in context, one at a time,** each with a reason on screen first, and each with a recovery path, because a second denial on Android is permanent until the user visits Settings. Notifications are a permission too (Android 13+); without it the drive still works but there’s nothing on the Lock Screen, and Setup says so.
- **Dynamic colour is on.** App chrome takes the user’s wallpaper colours. The sign, caution and unknown colours are fixed and never dynamic, so the sign always looks like a road sign.
- **Text uses the system font** (Roboto on most phones, the manufacturer’s font on others) and follows font scale. The two numerals use bundled Roboto Flex, so they look the same on every phone and can use its width axis: condensed in the sign, wide for your speed.
- **Edge-to-edge, gesture navigation, predictive back.** No back buttons in our UI; screens draw behind the system bars and pad content by the window insets.
- **Touch targets are 48 dp,** not 44.

## Content fundamentals

- NZ English: *kilometres*, *metres*, *colour*. Units are always `km/h`, lowercase, with a space before (`50 km/h`) except inside the sign and the readout, where the unit sits beneath.
- Say what the data is, not what the driver did. “Over by 7”, not “You’re speeding”. “Limit unknown”, not “Error”.
- Times relative when recent, absolute when old: “Checked today, 6:40 am”, “Last updated 3 Oct”.
- Name the source plainly: “NZTA National Speed Limit Register”. Check the register’s licence and attribute as it requires on the About screen.
- TalkBack reads the sign as “Speed limit 50 kilometres per hour” and the readout as “Your speed 57 kilometres per hour”, set as each composable’s content description. Don’t make the readout a live region: TalkBack would announce every speed change. A change of limit can be announced once, politely.
- The same wording carries into the notification, widget and Quick Settings tile: “50 km/h · Main North Road”, “Your speed 47 km/h”, “Limit unknown”.
- Android conventions on top: button and menu labels are sentence case and start with a verb (“Start drive”, “Allow”, “Open settings”). Material snackbars confirm background actions (“Speed limits updated”) instead of dialogs. Notification channel names are user-facing in system settings, so write them as plain labels: “Drive in progress”, “Limit changes”.

## Visual foundations

**Colour.** Material 3 roles (`primary`, `surface`, `on-surface-variant` and so on) for all chrome, generated from a blue seed as the fallback when dynamic colour is off or unavailable. Fixed colours outside the scheme: `sign-face`, `sign-ring`, `sign-ink` for the sign, `caution`/`on-caution`/`caution-ink` for over the limit and warnings, `unknown` for the unknown sign. `sign-ring` red is never used for anything else, including errors: the app has no error state that needs red.

**Type.** The Material type scale in the system font for all text. `sign-numeral` and `speed-readout` in Roboto Flex for the two numbers.

**Shape.** Material 3’s corner scale. Buttons and switches are fully round (`corner-full`), cards `corner-large`, the over-limit container `corner-extra-large`. The sign is a circle, as on the road.

**Elevation.** Tonal, not shadowed: surfaces step through `surface-container-*` roles. The only shadow is the FAB’s, from the Material component.

**Motion.** Material’s standard easing and duration tokens. The over-limit container fades and scales in once, with no overshoot or bounce, even though Material 3 Expressive’s springy motion is available. Numbers change with an animated content transition. With animations off in system settings, both are instant.

## Iconography

Material Symbols Rounded, weight 400, optical size matched to use. Suggested: `navigation` (GPS), `location_off`, `sync`, `check_circle`, `warning`, `notifications`, `directions_car` (drive), `stop_circle` (end drive), `tune` (settings). The notification’s status bar icon must be a single-colour silhouette: a ring outline of the sign (see SpeedSign).

## Components

SpeedSign, SpeedReadout, DriveFab, SetupStep, DriveNotification, HomeWidget and QuickSettingsTile. The **Android surfaces** section covers the notification, widget, tile and Android Auto in more depth.
