# Limit

A small, open-source iOS app that shows the posted speed limit for the road you are on in Aotearoa New Zealand, next to your GPS speed. Limits come from the NZTA National Speed Limit Register, downloaded and kept in sync on the device. Nothing leaves the phone: no account, no analytics.

Speed limit data is from the [National Speed Limit Register](https://opendata-nzta.opendata.arcgis.com/datasets/NZTA::national-speed-limit-register-nslr/about) by Waka Kotahi NZ Transport Agency, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). We filter it to the limits currently in force, merge repeated records, and read school times from its notes. Waka Kotahi doesn't endorse this app.

On iOS it appears in the app, and as a Live Activity on the Lock Screen, in the Dynamic Island and on the CarPlay dashboard. On Android it appears in the app, as an ongoing drive notification, on a home-screen widget, a Quick Settings tile, and Android Auto. Design: the Limit design system (colours, sign, readout, and the driving-surface rules in `docs/design.md`).

## Responsible use

Limit is an aid for staying within the speed limit, not a way to get away with exceeding it. A speed limit is a maximum, not a target, and the app never suggests a speed that is safe or acceptable to drive at. The "over" tolerance exists only to absorb GPS error: it is a display setting, not an allowance. The app has no speed camera or enforcement features, and nothing sounds when you go over. Always obey the posted limits and the NZ Road Code, and set the app up before you drive.

## Layout

| Path | What |
| --- | --- |
| `data/` | Local copies of the speed-limit register (gitignored). Shared by the apps. |
| `docs/` | Design notes, data-source notes, privacy, status. |
| `design/` | Design system files. |
| `iOS/` | The iOS app, widget, and Swift core. See `iOS/README.md`. |
| `android/` | The Android app and Kotlin core. Two Gradle modules: `:core` (JVM) and `:app` (Compose). |

## Develop

iOS (macOS with Xcode 16+): see `iOS/README.md`.

Android (JDK 21 and Android SDK 36). From the repo root:

```sh
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
./gradlew -p android :core:test :app:assembleDebug
```

Open `android/` in Android Studio to install on an emulator or a phone. Application id: `com.joshmcarthur.limit`.

## Status

See `docs/status.md` for what is built, what is unverified, and what is still to do.
