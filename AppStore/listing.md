# App Store listing

Copy for App Store Connect, for the New Zealand storefront. Written to the Limit voice: plain, short sentences, no hype. The user-facing text went through the `humanize` skill.

Limits are Apple's: name 30, subtitle 30, promotional text 170, keywords 100, description 4000, What's New 4000.

## Name

Limit: NZ Speed Limits

"Limit" on its own is probably taken, so check availability in App Store Connect before relying on this.

## Subtitle

The posted limit, at a glance

## Promotional text

The speed limit for the road you're on, beside your GPS speed. Data from NZTA, kept on your phone. No account, no tracking.

## Description

Limit shows the posted speed limit for the road you're on in New Zealand. It's the red-ring sign you already know, with your GPS speed underneath.

The limits come from the NZTA National Speed Limit Register. Limit downloads the register to your phone and checks for updates about once a week, so it still works when you have no reception.

If you go over, your speed turns amber and tells you by how much, for example "+8 over". Nothing beeps and nothing flashes while you drive. There's a small tolerance to allow for GPS error, which you can change in Settings.

The sign also appears on your Lock Screen and in the Dynamic Island.

School zones follow the time of day. Seasonal and temporary limits say "obey the posted signs". If the GPS is weak or the data is too old, Limit shows a dash, not a number it can't vouch for.

There's no account and no analytics. Your location stays on your phone.

Limit is an aid, not permission. A limit is a maximum, not a target, so there are no speed camera or enforcement features. Set it up before you drive, and obey the posted signs and the Road Code.

Speed limit data is from the National Speed Limit Register by Waka Kotahi NZ Transport Agency, licensed under CC BY 4.0. Waka Kotahi doesn't endorse this app.

## Keywords

New Zealand,Aotearoa,speedometer,driving,km/h,NZTA,Waka Kotahi,GPS,school zone,live activity,offline

Words already in the name and subtitle ("limit", "speed", "NZ", "posted") are left out, because Apple indexes them anyway.

## What's New (first release)

First release.

## Screenshots

Raw captures are in `screenshots/6.9-inch/` (see `README.md`). The app is iPhone-only, so there is no iPad set. Two framed sets are made from them by `Tools/frame-screenshots.py`, which reads this table:

- `screenshots/6.9-inch-framed/portrait/` (1320 × 2868): five slides, the table below without row 4, which is a wide capture and doesn't suit a tall canvas.
- `screenshots/6.9-inch-framed/landscape/` (2868 × 1320): all six slides, in the order below.

Whether App Store Connect accepts both orientations in one set isn't confirmed, so they're kept apart. Upload the portrait set as the main one. Order and captions:

| Order | File | Caption |
| --- | --- | --- |
| 1 | `01-drive-light.png` | The limit for the road you're on |
| 2 | `02-over-the-limit-104-in-100.png` | See at a glance if you've crept over the limit |
| 3 | `05-lock-screen.png` | On your Lock Screen too |
| 4 | `04-landscape-dark.png` | Fits a dash mount, either way up |
| 5 | `03-drive-dark.png` | Easy on the eyes after dark |
| 6 | `06-welcome.png` | Made in New Zealand. Set it up before you set off. |

The first three are the ones people see without scrolling, so they carry the idea: what it shows, what you see when you go over, and that it follows you to the Lock Screen.

## Other fields

- **Category:** Navigation (primary), Travel (secondary).
- **Age rating:** 4+. No user content, no web access beyond downloading the register, no gambling or mature themes.
- **Privacy ("App Privacy" answers):** Data Not Collected. Location is used on the device to find the road and measure speed, and is never sent anywhere. The only network request is the register download, which carries no user data.
- **Copyright:** the licence holder's name and year, to be filled in at submission.
- **Support URL and privacy policy URL:** not set up yet. Both are required. A page in the repo's GitHub Pages would do.

## Notes for App Review

> Limit shows the posted speed limit for the road the user is on in New Zealand, from the NZTA National Speed Limit Register, next to their GPS speed.
>
> Location: requested "When In Use" during onboarding, before any driving. Background location is on only while a drive is running, so the Lock Screen Live Activity stays current. The system's blue location indicator shows throughout, and "End drive" turns it off. Location never leaves the device and there is no account or analytics.
>
> The app has no speed camera, police or enforcement features and gives no alerts or sounds while driving.

## To check before submitting

- "It still works when you have no reception": follows from the register being stored on the device, but the app hasn't been run on a physical device yet (`docs/status.md`). Confirm it, or soften it.
- "Checks for updates about once a week": matches the weekly schedule in `docs/status.md`. Change this if the schedule changes.
- "Background location is on only while a drive is running": matches `LocationService`, which turns it off when a drive ends. Confirm on a device.
- The register copy the screenshots came from was incomplete (see `README.md` here). The description says nothing about coverage, so re-check the claim "limit for the road you're on" against the live register before launch.
