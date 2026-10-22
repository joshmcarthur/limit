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
- **Data:** road names and limits are real, from a copy of the NZTA layer taken on 22 October 2026 while NZTA was rebuilding it, so coverage was not complete. Nothing shown is made up. Shots of the seasonal-limit label would need a made-up demo zone, so there are none here.
- **Status bar:** 9:41, full signal, charging. The Lock Screen shot shows "Carrier" on the left because the simulator ignores the status bar override there.
- **Retaking:** run `Tools/store-screenshots.sh` (needs Xcode, XcodeGen and an iPhone 17 Pro Max simulator, and downloads the register into `data/register-check` the first time; `REFRESH=1` fetches it again). It builds the app, installs it on a clean simulator, drives simulated trips with `xcrun simctl location`, and turns the phone with a small UI test in `Tools/screenshots/rotate` because the Simulator's rotate shortcut can't be scripted. It takes a few minutes and rewrites 01 to 04 and 06.
- **Lock Screen (05) is by hand.** `simctl` can't lock and wake the phone, so the script ends by starting the trip and printing the three steps. Keep the phone awake long enough to capture it.
- **Framed versions:** `screenshots/6.9-inch-framed/` has the captioned slides, in `portrait/` (1320 × 2868, five slides) and `landscape/` (2868 × 1320, six). They are generated, not edited by hand: change a caption in `listing.md` and run `python3 -I Tools/frame-screenshots.py`, which needs ImageMagick, `rsvg-convert` and fontTools. The whole screen is shown, uncropped, so the register credit and "checked" line stay visible. The output is flattened RGB with no alpha, which the App Store requires.
- **Not made:** an iPad set (the app is iPhone-only) and other languages.

## Points to try in the simulator

For anyone who can simulate a location (Simulator: Features, Location, Custom Location; or Xcode: Debug, Simulate Location). Each result was read from the app's own register lookup on 23 October 2026 (`RegisterCheck`), so a later register may differ. Drive a short route through a point, since the sign waits for two samples to agree.

| Place | Latitude, longitude | The app shows |
| --- | --- | --- |
| Wellington CBD | -41.2865, 174.7762 | 30, "Wellington Central" |
| Auckland, Queen St | -36.8485, 174.7633 | 30, "Auckland Central Business District" |
| Christchurch, Gloucester St | -43.5314, 172.6358 | 30, "Christchurch Central" |
| Desert Road, SH 1 | -39.2941, 175.7408 | 100, "Turangi To Waiouru, SH 1" |
| Plimmerton, Steyne Ave | -41.0795, 174.8667 | 50, "Porirua City" |
| Plimmerton, Freshfields Place | -41.0767, 174.8709 | the open-road sign and "Open road": the register has no zone for this street |
| Cupertino | 37.3349, -122.0090 | a dash and "Outside New Zealand", with the speed still shown |

Anywhere outside New Zealand and the Chatham Islands gives the last row's result. If location access is declined, the screen says "Location needed" and what to turn on.
