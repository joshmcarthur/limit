# Status

## Verified

- `swift test` passes (173 tests) from `iOS/` and the app and widget build for the iOS simulator.
- The live layer was queried: field names, record counts, the update check and a full download were run with `RegisterCheck`.
- Run in the iOS 18 simulator with a simulated drive: onboarding, driving (light, dark, over, landscape), settings, about and the Lock Screen Live Activity. Also run on a real iPhone: the Live Activity showed as a card on a car's CarPlay dashboard (23 October 2026, from photos). Not yet run: the CarPlay simulator, signing.
- CI exists but is left alone to save build minutes.

## Verified (Android)

- `./gradlew -p android :core:test` and `:app:assembleDebug` on JDK 21.
- Emulator `Medium_Phone_Play_Store` (API 36), 31 October 2026: Setup (location and notifications granted), Done, Start drive, `adb emu geo fix 174.77557 -41.29346` (Cuba Street, Wellington). GPS good. Sign 30, road name Wellington Central (the current register area, not a 10). End drive stops the service. Start again restores the same sign. Landscape: sign left, speed right, FAB icon-only.
- Over-limit on that emulator: `geo fix` velocity 30 knots → 56 km/h, +26 over, caution container (not red). Notification shade: “Limit · Driving”, “30 km/h · Wellington Central”, “Your speed 56 km/h · 26 over”, End drive, sign large icon.
- Dark theme: chrome uses the Material background after wrapping `RootScreen` in a `Surface`. Sign ring stays `#c8102e`.
- Notifications denied (`POST_NOTIFICATIONS` revoked): Setup still offers Allow, Done stays enabled, drive starts, the location foreground service still runs.
- The copied `data/register-check` LMTZ loads after `largeHeap` and an IO decode (about a minute on this AVD).
- `Medium_Phone` AVD was rebuilt onto API 36 `google_apis` (the old image was missing android-32).

## Built (Android)

- `android/`: Gradle modules `:core` (JVM Kotlin port of LimitCore) and `:app` (Compose Material 3).
- Drive start is explicit. Location uses `LocationManager` (while-using, precise; no Play Services, no background location). Ongoing notification is the Lock Screen surface. Stop detection v1 is GPS idle only.
- Android Auto: Car App Library `PaneTemplate` (category NAVIGATION). Glance 2×2 / 4×1 home widget and a Quick Settings Drive tile.
- CI: Ubuntu JDK 21, `:core:test` and `:app:assembleDebug`. Desktop Head Unit is installed (`extras;google;auto`).

## Unverified (Android)

- Phone hardware, manufacturer notification shade, and Play Store listing.
- Android Auto on a car head unit. DHU 2.0 is installed. ADB transport to port 5277 connects, then drops: this Play Store image ships an Android Auto stub with no head-unit server.
- Live Updates promoted ongoing chip on API 36.
- Home widget and Quick Settings tile on a real launcher.
- NZTA download on the emulator (the live fetch failed; the copied register was used).

## Built

- `LimitCore`: geometry and point-in-polygon, GeoJSON zone parser, grid-indexed register lookup, binary store, ArcGIS downloader with paging and progress, over-limit hysteresis, sign state and freshness, drive engine, settings, sync copy, VoiceOver labels, design tokens.
- Data: in-force zones only, repeated records dropped, update check before downloading, a weekly check schedule with back-off, manual checks with a floor, school-zone reduced limits by time of day, zone change confirmed over two samples, and blue-green register swaps with a verification gate.
- Drive-stop check: CoreMotion travel-mode change and a GPS idle backstop, with a notification to end the drive. Unchecked on a device.
- App: onboarding (3 screens), driving screen (portrait and landscape), settings, about, sync status, location service, Live Activity controller.
- Widget extension: Live Activity for the Lock Screen, Dynamic Island and CarPlay dashboard (iOS 26 and later). CarPlay needs no separate widget or entitlement.
- CI: macOS core tests, iOS simulator build.

## Not built

- Background register refresh (`BGAppRefreshTask`); it checks on foreground, at most weekly.
- App icon, launch screen, localisation, UI tests, snapshot tests.
- Signing, bundle identifiers, App Store metadata.

## Known risks

See `docs/data.md`: the store is about 23 MB with 3 million vertices, so device load time and memory are still the open question. On the API 36 emulator the copied 36 MB LMTZ takes about a minute to decode, and the first frame can show only the sign.
