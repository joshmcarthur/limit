# Status

## Verified

- `swift test` passes (173 tests) and the app and widget build for the iOS simulator.
- The live layer was queried: field names, record counts, the update check and a full download were run with `RegisterCheck`.
- Run in the iOS 18 simulator with a simulated drive: onboarding, driving (light, dark, over, landscape), settings, about and the Lock Screen Live Activity. Not yet run: a device, CarPlay, signing.
- CI exists but is left alone to save build minutes.

## Built

- `LimitCore`: geometry and point-in-polygon, GeoJSON zone parser, grid-indexed register lookup, binary store, ArcGIS downloader with paging and progress, over-limit hysteresis, sign state and freshness, drive engine, settings, sync copy, VoiceOver labels, design tokens.
- Data: in-force zones only, repeated records dropped, update check before downloading, a weekly check schedule with back-off, manual checks with a floor, school-zone reduced limits by time of day, zone change confirmed over two samples, and blue-green register swaps with a verification gate.
- App: onboarding (3 screens), driving screen (portrait and landscape), settings, about, sync status, location service, Live Activity controller.
- Widget extension: Live Activity for Lock Screen and Dynamic Island.
- CI: Linux and macOS core tests, iOS simulator build.

## Not built

- CarPlay widget (the design system recommends checking current CarPlay support first).
- Background register refresh (`BGAppRefreshTask`); it checks on foreground, at most weekly.
- App icon, launch screen, localisation, UI tests, snapshot tests.
- Signing, bundle identifiers, App Store metadata.

## Known risks

See `docs/data.md`: the store is about 23 MB with 3 million vertices, so device load time and memory are still the open question.
