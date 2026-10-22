# App Store screenshots

Raw captures for the listing, from the iOS 26.5 simulator on an iPhone 17 Pro Max, which gives the 6.9-inch size (1320 × 2868; the landscape one is 2868 × 1320). They have no captions or device frames.

| File | Shows |
| --- | --- |
| `screenshots/6.9-inch/01-drive-light.png` | Driving at 28 km/h in a 30 zone, Wellington Central |
| `screenshots/6.9-inch/02-over-the-limit-104-in-100.png` | A realistic over-the-limit case: 104 km/h on a 100 km/h state highway (the Desert Road, SH 1), "+4 over" |
| `screenshots/6.9-inch/03-drive-dark.png` | Dark mode, 26 km/h in the 30 zone |
| `screenshots/6.9-inch/04-landscape-dark.png` | Landscape, 27 km/h in the 30 zone |
| `screenshots/6.9-inch/05-lock-screen.png` | The Lock Screen Live Activity, 96 km/h on a 100 km/h state highway |
| `screenshots/6.9-inch/06-welcome.png` | The first screen: what it does, offline, no account |

## Things to know

- **Optics:** every shot is at or under the limit except 02, which is a small, realistic 4 km/h over. Keep it that way if you retake them.
- **Data:** road names and limits are real, from a copy of the NZTA layer taken on 22 October 2026 while NZTA was rebuilding it, so coverage was not complete. Nothing shown is made up. (The seasonal-limit label screenshots in `docs/screenshots` use a made-up demo zone and are deliberately not here.)
- **Status bar:** 9:41, full signal, charging. The Lock Screen shot shows "Carrier" on the left because the simulator ignores the status bar override there.
- **Retaking:** `docs/screenshots` holds the larger set used to check the build against the design; see `docs/design.md`. These store shots were scripted with `xcrun simctl` (location, appearance) and a throwaway UI test for rotation.
- **Not made:** an iPad set, other languages, and the caption text and frames the store page would normally add.
