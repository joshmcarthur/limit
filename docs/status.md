# Status

## Verified

Nothing has been compiled or run in the session that wrote this code: the build VM could not reach `download.swift.org`, so there was no Swift toolchain. The only verification is CI (`.github/workflows/ci.yml`) once it has run. Treat anything not green there as unverified.

## Built

- `LimitCore`: geometry and point-in-polygon, GeoJSON zone parser, grid-indexed register lookup, binary store, ArcGIS downloader with paging and progress, over-limit hysteresis, sign state and freshness, drive engine, settings, sync copy, VoiceOver labels, design tokens.
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

See `docs/data.md`: the limit field name is a guess, and the full register's size is unknown.
