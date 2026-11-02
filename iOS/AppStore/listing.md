# App Store listing

Copy for App Store Connect's New Zealand storefront. Limit's voice is plain and direct, with no hype.

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

The limits come from the NZTA National Speed Limit Register. The app downloads it to your phone (about 24 MB the first time), then checks for updates when you open it, at most once a week. It still works without reception.

If you go over, your speed turns amber and tells you by how much, for example "+8 over". Nothing beeps and nothing flashes while you drive. There's a small tolerance to allow for GPS error, which you can change in Settings.

The sign also appears on your Lock Screen and in the Dynamic Island. If your car supports it, you'll see it on the CarPlay dashboard too (iOS 26 or later). If the speed stops updating, the Lock Screen dims it so you can tell the reading is out of date.

Some roads have no limit listed in the register. Limit shows an open-road sign (a circle with a diagonal line) and says "Open road".

School zones follow the time of day. Seasonal and temporary limits say "obey the posted signs". If GPS is weak or the data is too old, Limit shows a dash instead of a reading it can't trust.

When you get out of the car and walk away, Limit asks if the drive is over, so your phone isn't left tracking your location in your pocket. If you don't answer, the drive ends after 15 minutes without movement. You can turn this off in Settings.

Outside New Zealand there are no limits to show. Limit says so, and still shows your speed.

There's no account and no analytics. Your location and your movement stay on your phone.

Limit is an aid, not permission to speed. A speed limit is a maximum, not a target. Limit has no speed camera or enforcement features. Set it up before you drive, then follow the posted signs and the Road Code.

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

The first three appear before someone scrolls. They show the limit on your road, what happens when you go over, and the Lock Screen view.

## Other fields

- **Category:** Navigation (primary), Travel (secondary).
- **Age rating:** 4+. No user content, no web access beyond downloading the register, no gambling or mature themes.
- **Privacy ("App Privacy" answers):** Data Not Collected. Location is used on the device to find the road and measure speed, and Motion & Fitness is used on the device to notice when the person has got out and walked away. Neither is ever sent anywhere. The only network request is the register download, which carries no user data.
- **Header and search results image:** optional, shown on iOS 27 and later, and uploaded from Asset Library without a new app version. `creative-assets/signs-16x9.png` is ready (see `README.md`). Check the crops in App Store Connect's preview tool before submitting it.
- **Copyright:** the licence holder's name and year, to be filled in at submission.
- **Support URL and privacy policy URL:** not set up yet. Both are required. A page in the repo's GitHub Pages would do.

## Notes for App Review

> Limit shows the posted speed limit for the road the user is on in New Zealand, from the NZTA National Speed Limit Register, next to their GPS speed.
>
> Location is requested as "When In Use" during onboarding, before any driving. Background location runs only while a drive is active, keeping the Lock Screen Live Activity current. The system's blue location indicator stays visible throughout. "End drive" turns location off. Location never leaves the device, and there's no account or analytics.
>
> The app has no speed camera, police, or enforcement features. It gives no alerts or sounds while driving.
>
> The Live Activity appears on the CarPlay dashboard on supported cars with iOS 26 or later. The app isn't a CarPlay app and has no CarPlay entitlement.
>
> Limit has data for New Zealand only. Elsewhere it shows "Outside New Zealand" and the GPS speed. That's expected. A screen recording of about 100 seconds is attached. It was made in the iOS Simulator with simulated locations, and says so on screen. It shows onboarding and the permission prompts, drives through 30, 50 and 100 zones, the over-limit state, the Lock Screen and Dynamic Island, Settings and About, the outside-New-Zealand and open-road states, and ending a drive. The simulator can't run the Motion & Fitness walk-away detection or show CarPlay, so those aren't in it. To try the app yourself, simulate a location in New Zealand, such as Wellington (-41.2865, 174.7762). `iOS/AppStore/README.md` lists more test locations and their results. The first launch downloads the register (about 24 MB); it took about 36 seconds in our testing.
>
> Motion & Fitness and notifications are requested at the end of onboarding. The app works if either is declined. Both support one feature, "Suggest ending my drive" (on by default, off in Settings). When the phone detects that you've got out and walked away, it sends a notification asking whether to end the drive, so location isn't left running in your pocket. The drive also ends automatically after 15 minutes without movement. Motion data is read on the device, not stored or sent.
>
> If you decline location access, the app says "Location needed" and tells you what to turn on.

## To check before submitting

- "It still works when you have no reception": follows from the register being stored on the device, but the app hasn't been run on a physical device yet (`docs/status.md`). Confirm it, or soften it.
- "Checks for updates when you open it, at most once a week" and "about 24 MB the first time": match `SyncSchedule` and `docs/data.md` (about 24 MB over the wire, 36 seconds in testing). Change them if either changes.
- "Open-road sign" sentence: matches commit `9f28c10`. The raw screenshots predate it, so retake them, then rerun `Tools/frame-screenshots.py`. The rural 100 shots (02 and 05) may now show the open-road sign.
- The welcome screen says "Every road, even offline" and "anywhere in Aotearoa New Zealand". That is in-app copy that overclaims, given the known gaps in the register, and it shows in the framed welcome slide. Reword it in the app before submitting.
- The App Review note says a screen recording is attached. It's made (`iOS/AppStore/review-video/limit-review-demo.mp4`, not in git; see `README.md`). Attach it in App Store Connect, and make a new one if the app's screens change before submission, as the recording shows the current UI. Apple's guidance is that attachments are re-uploaded with each version.
- `MARKETING_VERSION` is an integer in `project.yml`. It is `2`. Bump it by one for each release. `CURRENT_PROJECT_VERSION` is the build. It is `1`. Bump it only when you upload again for the same version.
- "Suggest ending my drive" paragraph and the Motion & Fitness review note: the CoreMotion walk-off, the notification and its two buttons, and the 15 minute ending have not been run on a device (`docs/status.md`). Try them on a real drive, or soften the copy.
- "If the speed stops updating, the Lock Screen dims it": checked in the simulator by freezing the app, not on a device, where the system may throttle updates differently.
- Add the Motion & Fitness usage string (`NSMotionUsageDescription` in `project.yml`) to any App Privacy answers App Store Connect asks for.
- CarPlay line: Apple says Live Activities show on the CarPlay dashboard from iOS 26, with no CarPlay app needed, but names no car models, hence "in cars that support it". Check which layout CarPlay uses (the compact Dynamic Island view or the small one) and whether the Lock Screen dimming also happens there. The CarPlay simulator hasn't been run (`docs/status.md`).
- "CarPlay" is Apple's mark. It is in the description only to say the app works with it. It is not in the keywords: Guideline 2.3.7 warns against trademarked terms there, and I couldn't confirm that Apple's own marks are exempt. Say if you want it in the keywords in place of "offline", and read the guideline and Apple's trademark rules first.
- "Background location is on only while a drive is running": matches `LocationService`, which turns it off when a drive ends. Confirm on a device.
- The register copy the screenshots came from was incomplete (see `README.md` here). The description says nothing about coverage, so re-check the claim "limit for the road you're on" against the live register before launch.
