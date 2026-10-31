# Play Store listing

Copy for Google Play Console, New Zealand default listing. Limit's voice is plain and direct, with no hype. Most of this is the App Store listing, with Apple surfaces swapped for Android ones.

Limits are Google's: name 30, short description 80, full description 4000, release notes 500. There is no keyword field.

## Name

Limit: NZ Speed Limits

22 characters. "Limit" on its own is probably taken, so check availability in Play Console before relying on this.

## Short description

The posted limit beside your GPS speed. NZTA data. No account, no tracking.

75 characters. This is the line above "Read more". Don't paste it into the full description.

## Description

Limit shows the posted speed limit for the road you're on in New Zealand. It's the red-ring sign you already know, with your GPS speed underneath.

The limits come from the NZTA National Speed Limit Register. The app downloads it to your phone (about 24 MB the first time), then checks for updates when you open it, at most once a week. It still works without reception.

If you go over, your speed turns amber and tells you by how much, for example "+8 over". Nothing beeps and nothing flashes while you drive. There's a small tolerance to allow for GPS error, which you can change in Settings.

The sign also appears in an ongoing notification while you drive. You can add a home-screen widget or a Quick Settings tile. If your car supports Android Auto, you'll see it there too.

Some roads have no limit listed in the register. Limit shows an open-road sign (a circle with a diagonal line) and says "Open road".

School zones follow the time of day. Seasonal and temporary limits say "obey the posted signs". If GPS is weak or the data is too old, Limit shows a dash instead of a reading it can't trust.

If you leave a drive running, Limit ends it after 15 minutes without movement, so location isn't left on. You can turn this off in Settings.

Outside New Zealand there are no limits to show. Limit says so, and still shows your speed.

There's no account and no analytics. Your location stays on your phone.

Limit is an aid, not permission to speed. A speed limit is a maximum, not a target. Limit has no speed camera or enforcement features. Set it up before you drive, then follow the posted signs and the Road Code.

Speed limit data is from the National Speed Limit Register by Waka Kotahi NZ Transport Agency, licensed under CC BY 4.0. Waka Kotahi doesn't endorse this app.

## Release notes (first release)

First release.

## Screenshots

Raw captures are in `screenshots/` (see `README.md`). Phone only: 1080 × 2400 portrait, 2400 × 1080 landscape, no device frames. Play wants two to eight phone screenshots, JPEG or 24-bit PNG with no alpha. Upload all six. Order and captions:

| Order | File | Caption |
| --- | --- | --- |
| 1 | `01-drive-light.png` | The limit for the road you're on |
| 2 | `02-over-the-limit-104-in-100.png` | See at a glance if you've crept over the limit |
| 3 | `05-lock-screen.png` | On your notification shade too |
| 4 | `04-landscape-dark.png` | Fits a dash mount, either way up |
| 5 | `03-drive-dark.png` | Easy on the eyes after dark |
| 6 | `06-welcome.png` | Made in New Zealand. Set it up before you set off. |

The first three appear before someone scrolls. They show the limit on your road, what happens when you go over, and the ongoing drive notification.

Play captions are alt text, not on-image taglines. Do not burn the captions into the PNGs.

No 7-inch or 10-inch tablet set, no Chromebook set, no Automotive OS screenshot set. The app is a phone app with a projected Android Auto session, not an Automotive OS APK.

## Other fields

- **App icon (Play):** 512 × 512 32-bit PNG with alpha. This is not the launcher mipmap. Not made yet.
- **Feature graphic:** required, 1024 × 500 JPEG or 24-bit PNG, no alpha. Not made yet.
- **Promo video:** optional YouTube URL. The App Review clip is not for the store page.
- **Category:** Maps & Navigation.
- **Tags:** Speedometer, Offline, if Console still offers them. Don't stuff.
- **Content rating:** IARC questionnaire. Everyone. No user content, no web access beyond downloading the register, no gambling or mature themes.
- **Data safety:** Data is not collected. Location is used on the device to find the road and measure speed. It is not stored as a history and is not sent anywhere. The only network request is the register download, which carries no user data. Mark location as not collected (ephemeral, on-device). Notifications are used to show the drive; they are not data collection.
- **Privacy policy URL:** required because the app uses location. Not set up yet. A page in the repo's GitHub Pages would do, same as iOS.
- **Contact email:** required.
- **Copyright:** the licence holder's name and year, to be filled in at submission.

## Notes for Play review

> Limit shows the posted speed limit for the road the user is on in New Zealand, from the NZTA National Speed Limit Register, next to their GPS speed.
>
> Location is requested as while-using (precise) during setup, before any driving. There is no `ACCESS_BACKGROUND_LOCATION` permission. A location foreground service runs only while a drive is active, so the notification stays current when the app isn't in front. "End drive" stops the service. Location never leaves the device, and there's no account or analytics.
>
> The app has no speed camera, police, or enforcement features. It gives no alerts or sounds while driving.
>
> Android Auto uses the Car App Library (`PaneTemplate`, category NAVIGATION). It is a projected phone session, not an Android Automotive OS app.
>
> Limit has data for New Zealand only. Elsewhere it shows "Outside New Zealand" and the GPS speed. That's expected. A screen recording is attached. It was made on the Android emulator with simulated GPS, and says so on screen. It shows setup, drives through 30, 50 and 100 zones, the over-limit state, the ongoing notification, Settings, and ending a drive. The emulator image has no Android Auto head-unit server, so Auto isn't in it. Home widget and Quick Settings tile aren't in it either. To try the app yourself, send a GPS fix in New Zealand, such as Wellington (latitude -41.2865, longitude 174.7762). `android/AppStore/README.md` lists more test locations. The first launch downloads the register (about 24 MB).
>
> Notifications are requested during setup. The app works if they're declined: the drive still starts, and the location foreground service still runs. Notifications support the ongoing drive card and the "Suggest ending my drive" ping.
>
> "Suggest ending my drive" (on by default, off in Settings) ends the drive after 15 minutes without GPS movement, so location isn't left on. Android v1 does not use Activity Recognition or a walk-away sensor.
>
> If you decline location access, the app stays on Setup and tells you Limit needs location to find the road.

## To check before submitting

- Phone screenshots are 1080 × 2400. Play rejects a screenshot whose long side is more than twice the short side (2400 / 1080 ≈ 2.22). Crop or recapture at 1080 × 2160 or 1080 × 1920 before upload.
- 05 is the notification shade, not the keyguard. The emulator lock screen did not show the `IMPORTANCE_LOW` foreground-service notification. Soften the caption if that is still true on a phone.
- 06 is Setup, and the current still shows a failed NZTA download. Retake it on a clean first run, or don't use that shot.
- Feature graphic (1024 × 500) and Play 512 icon are required and not in this folder.
- "It still works without reception": follows from the register being stored on the device. Confirm on a phone (`docs/status.md`), or soften it.
- "Checks for updates when you open it, at most once a week" and "about 24 MB the first time": match `SyncSchedule` and `docs/data.md`. Change them if either changes.
- Home widget, Quick Settings tile, and Android Auto are built. Widget and tile have not been checked on a real launcher. Android Auto has not been checked on a car head unit (`docs/status.md`). Try them, or drop those sentences.
- The review note says a screen recording is attached. Make a live one (`android/Tools/capture-store.py`); the current file is a captioned slideshow. It is not in git (`android/AppStore/review-video/`). Attach it in Play Console. Make a new one if the screens change.
- `versionName` is `0.1.0` in `android/app/build.gradle.kts`. Set it to `1.0.0` for the first release.
- "Android Auto" is Google's mark. It is in the description only to say the app works with it.
- Location while a drive is running: matches `LocationService` and `DriveForegroundService`. Confirm on a phone that ending the drive stops the service.
- Privacy policy URL and a contact email are required. Neither is set up yet.
- Data safety: fill the form as no data collected. Location is ephemeral on-device use, not a stored track.
- The register copy the screenshots came from was incomplete (see `README.md` here). The description says nothing about coverage, so re-check the claim "limit for the road you're on" against the live register before launch.
