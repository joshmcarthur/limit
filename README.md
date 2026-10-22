# Limit

A small, open-source iOS app that shows the posted speed limit for the road you are on in Aotearoa New Zealand, next to your GPS speed. Limits come from the NZTA National Speed Limit Register, downloaded and kept in sync on the device. Nothing leaves the phone: no account, no analytics.

Speed limit data is from the [National Speed Limit Register](https://opendata-nzta.opendata.arcgis.com/datasets/NZTA::national-speed-limit-register-nslr/about) by Waka Kotahi NZ Transport Agency, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). We filter it to the limits currently in force, merge repeated records, and read school times from its notes. Waka Kotahi doesn't endorse this app.

It appears in the app, as a Live Activity (Lock Screen and Dynamic Island), and later as a CarPlay widget. Design: the Limit design system (colours, sign, readout, and the driving-surface rules in `docs/design.md`).

## Responsible use

Limit is an aid for staying within the speed limit, not a way to get away with exceeding it. A speed limit is a maximum, not a target, and the app never suggests a speed that is safe or acceptable to drive at. The "over" tolerance exists only to absorb GPS error: it is a display setting, not an allowance. The app has no speed camera or enforcement features, and nothing sounds when you go over. Always obey the posted limits and the NZ Road Code, and set the app up before you drive.

## Layout

| Path | What |
| --- | --- |
| `Sources/LimitCore` | Platform-independent logic (Foundation only, so it builds and tests on Linux): geometry, the register, over-limit evaluation, drive state, sync, tokens. |
| `Tests/LimitCoreTests` | Unit tests for the core. |
| `App` | The iOS app (SwiftUI, CoreLocation, ActivityKit). |
| `Shared` | Views and types used by both the app and the widget extension. |
| `Widgets` | The Live Activity widget extension. |
| `project.yml` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec. The `.xcodeproj` is generated, not committed. |
| `docs` | Design notes and data-source notes. |

## Develop

Core (any platform with Swift 5.9+):

```sh
swift build
swift test
```

App (macOS with Xcode 16+):

```sh
brew install xcodegen
xcodegen generate
open Limit.xcodeproj
```

Bundle identifiers and the signing team are set in `project.yml`.

## CI

`.github/workflows/ci.yml` builds and tests the core on Linux and macOS, and builds the app for the iOS simulator.

## Status

See `docs/status.md` for what is built, what is unverified, and what is still to do.
