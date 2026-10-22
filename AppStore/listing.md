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

The limits come from the NZTA National Speed Limit Register. Limit downloads the register to your phone (about 24 MB the first time), then checks for updates when you open it, at most once a week. It still works when you have no reception.

If you go over, your speed turns amber and tells you by how much, for example "+8 over". Nothing beeps and nothing flashes while you drive. There's a small tolerance to allow for GPS error, which you can change in Settings.

The sign also appears on your Lock Screen and in the Dynamic Island. If the speed stops updating, the Lock Screen dims it, so you're not reading a number that's out of date.

Some roads have no limit of their own in the register. For those, Limit shows an open-road sign (a circle with a diagonal line) and says "Open road".

School zones follow the time of day. Seasonal and temporary limits say "obey the posted signs". If the GPS is weak or the data is too old, Limit shows a dash, not a number it can't vouch for.

When you get out of the car and walk away, Limit asks whether the drive is over, so your phone isn't left tracking location in your pocket. If you don't answer, or you stay put for a while, it ends the drive itself. You can turn this off in Settings.

Outside New Zealand there are no limits to show. Limit says so, and still shows your speed.

There's no account and no analytics. Your location and your movement stay on your phone.

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
- **Privacy ("App Privacy" answers):** Data Not Collected. Location is used on the device to find the road and measure speed, and Motion & Fitness is used on the device to notice when the person has got out and walked away. Neither is ever sent anywhere. The only network request is the register download, which carries no user data.
- **Copyright:** the licence holder's name and year, to be filled in at submission.
- **Support URL and privacy policy URL:** not set up yet. Both are required. A page in the repo's GitHub Pages would do.

## Notes for App Review

> Limit shows the posted speed limit for the road the user is on in New Zealand, from the NZTA National Speed Limit Register, next to their GPS speed.
>
> Location: requested "When In Use" during onboarding, before any driving. Background location is on only while a drive is running, so the Lock Screen Live Activity stays current. The system's blue location indicator shows throughout, and "End drive" turns it off. Location never leaves the device and there is no account or analytics.
>
> The app has no speed camera, police or enforcement features and gives no alerts or sounds while driving.
>
> The app only has data for New Zealand. Outside the country it shows "Outside New Zealand" and still shows the GPS speed, which is expected. A screen recording of a drive in New Zealand is attached. To try it yourself, simulate a location in New Zealand, for example Wellington (-41.2865, 174.7762); `AppStore/README.md` lists more points with the result at each. The first launch downloads the register, about 24 MB, which took about 36 seconds in our testing.
>
> Motion & Fitness and notifications: both are asked for at the end of onboarding, and the app works if either is declined. They exist for one feature, "Suggest ending my drive" (on by default, off in Settings). When the phone detects the user has got out and walked away, the app sends a notification asking whether to end the drive, so location isn't left on in a pocket. After 15 minutes without moving it ends the drive by itself. Motion data is read on the device and not stored or sent.
>
> If location access is declined, the app says "Location needed" and what to turn on.

## To check before submitting

- "It still works when you have no reception": follows from the register being stored on the device, but the app hasn't been run on a physical device yet (`docs/status.md`). Confirm it, or soften it.
- "Checks for updates when you open it, at most once a week" and "about 24 MB the first time": match `SyncSchedule` and `docs/data.md` (about 24 MB over the wire, 36 seconds in testing). Change them if either changes.
- "Open-road sign" sentence: matches commit `9f28c10`. The raw screenshots predate it, so retake them, then rerun `Tools/frame-screenshots.py`. The rural 100 shots (02 and 05) may now show the open-road sign.
- The welcome screen says "Every road, even offline" and "anywhere in Aotearoa New Zealand". That is in-app copy that overclaims, given the known gaps in the register, and it shows in the framed welcome slide. Reword it in the app before submitting.
- The App Review note says a screen recording is attached. Make one (a short simulated drive) and attach it in App Store Connect.
- `MARKETING_VERSION` is `0.1.0` in `project.yml`. Set it to `1.0.0` for the first release.
- "Suggest ending my drive" paragraph and the Motion & Fitness review note: the CoreMotion walk-off, the notification and its two buttons, and the 15 minute ending have not been run on a device (`docs/status.md`). Try them on a real drive, or soften the copy.
- "If the speed stops updating, the Lock Screen dims it": checked in the simulator by freezing the app, not on a device, where the system may throttle updates differently.
- Add the Motion & Fitness usage string (`NSMotionUsageDescription` in `project.yml`) to any App Privacy answers App Store Connect asks for.
- "Background location is on only while a drive is running": matches `LocationService`, which turns it off when a drive ends. Confirm on a device.
- The register copy the screenshots came from was incomplete (see `README.md` here). The description says nothing about coverage, so re-check the claim "limit for the road you're on" against the live register before launch.
