# Limit for iOS

The iOS app, Live Activity widget, and Swift core.

## Layout

| Path | What |
| --- | --- |
| `Sources/LimitCore` | Platform-independent logic (Foundation only, so it builds and tests on Linux): geometry, the register, over-limit evaluation, drive state, sync, tokens. |
| `Tests/LimitCoreTests` | Unit tests for the core. |
| `App` | The iOS app (SwiftUI, CoreLocation, ActivityKit). |
| `Shared` | Views and types used by both the app and the widget extension. |
| `Widgets` | The Live Activity widget extension. |
| `project.yml` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec. The `.xcodeproj` is generated, not committed. |
| `AppStore/` | Store listing copy and screenshots. |

Speed-limit register copies live in `../data/` (gitignored).

## Develop

From this directory. Core (any platform with Swift 5.9+):

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

To download a local copy of the register into the shared `data/` folder:

```sh
swift run RegisterCheck ../data/register-check
swift run RegisterCheck ../data/register-check --lookup -41.17,174.83
swift run RegisterCheck ../data/register-check --along -41.17,174.83 -41.13,174.84 --step 200
swift run RegisterCheck ../data/register-check --export corridor.geojson --bbox -41.18,174.80,-41.12,174.86
```

`--lookup` and `--along` print the limit the app would show. `--export` writes the stored zones. `--bbox` is `minLat,minLon,maxLat,maxLon`.

## CI

`.github/workflows/ci.yml` builds and tests the core on macOS, and builds the app for the iOS simulator, from this directory.
