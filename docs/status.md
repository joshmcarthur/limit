# Status

## Verified

- `swift test` passes (150 tests) and the app and widget build for the iOS simulator.
- The live layer was queried: field names, record counts, the update check and a full download were run with `RegisterCheck`.
- Not yet run: the app on a device or in the simulator with a drive, signing for a device.
- CI exists but is left alone to save build minutes.

## Built

- `LimitCore`: geometry and point-in-polygon, GeoJSON zone parser, grid-indexed register lookup, binary store, ArcGIS downloader with paging and progress, over-limit hysteresis, sign state and freshness, drive engine, settings, sync copy, VoiceOver labels, design tokens.
- Data: in-force zones only, repeated records dropped, update check before downloading, school-zone reduced limits by time of day, zone change confirmed over two samples, and blue-green register swaps with a verification gate.
- App: onboarding (3 screens), driving screen (portrait and landscape), settings, about, sync status, location service, Live Activity controller.
- Widget extension: Live Activity for Lock Screen and Dynamic Island.
- CI: Linux and macOS core tests, iOS simulator build.

## Not built

- CarPlay widget (the design system recommends checking current CarPlay support first).
- Background register refresh (`BGAppRefreshTask`); it syncs on foreground when more than a day old.
- Chime on limit change (the setting exists but does nothing).
- App icon, launch screen, localisation, UI tests, snapshot tests.
- Signing, bundle identifiers, App Store metadata.

## Known risks

See `docs/data.md`: the store is 55 MB with 7.1 million vertices, so device load time and memory are the open question.
