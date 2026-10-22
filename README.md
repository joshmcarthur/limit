# Limit

A small, open-source iOS app that shows the posted speed limit for the road you are on in Aotearoa New Zealand, next to your GPS speed. Limits come from the NZTA National Speed Limit Register, downloaded and kept in sync on the device. Nothing leaves the phone: no account, no analytics.

It appears in the app, as a Live Activity (Lock Screen and Dynamic Island), and later as a CarPlay widget. Design: the Limit design system (colours, sign, readout, and the driving-surface rules in `docs/design.md`).

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

Set your own bundle identifiers and team in `project.yml` (`com.example.Limit` is a placeholder).

## CI

`.github/workflows/ci.yml` builds and tests the core on Linux and macOS, and builds the app for the iOS simulator.

## Status

See `docs/status.md` for what is built, what is unverified, and what is still to do.
