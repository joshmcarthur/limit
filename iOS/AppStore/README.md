# App Store screenshots

Raw captures for the listing, from the iOS 26.5 simulator on an iPhone 17 Pro Max, which gives the 6.9-inch size (1320 × 2868; the landscape one is 2868 × 1320). They have no captions or device frames.

| File | Shows |
| --- | --- |
| `screenshots/6.9-inch/01-drive-light.png` | Driving at 28 km/h in a 30 zone, Wellington Central |
| `screenshots/6.9-inch/02-over-the-limit-104-in-100.png` | A realistic over-the-limit case: 104 km/h on a 100 km/h state highway (the Desert Road, SH 1), "+4 over" |
| `screenshots/6.9-inch/03-drive-dark.png` | Dark mode, 26 km/h in the 30 zone |
| `screenshots/6.9-inch/04-landscape-dark.png` | Landscape, 27 km/h in the 30 zone |
| `screenshots/6.9-inch/05-lock-screen.png` | The Lock Screen card: the 100 sign and the zone name Turangi To Waiouru, SH 1. A permanent limit, so no second line |
| `screenshots/6.9-inch/07-lock-screen-variable.png` | The same card on a variable limit: Horokiwi To Ngauranga, SH 2, an empty red circle, with "Variable limit, obey the posted signs" |
| `screenshots/6.9-inch/08-lock-screen-seasonal.png` | The same card on a seasonal limit: Waipu Cove Road, 60, with "Seasonal limit, obey the posted signs". In force about late October to early April |
| `screenshots/6.9-inch/06-welcome.png` | The first screen: what it does, offline, no account |

## Things to know

- **Optics:** every shot is at or under the limit except 02, which is a small, realistic 4 km/h over. Keep it that way if you retake them.
- **Data:** road names and limits are real. Nothing shown is made up. The Lock Screen variable and seasonal shots use the register downloaded on 2 November 2026. Wellington Central is still 30 and Turangi To Waiouru is still 100, so the earlier drive shots stay. This copy has no emergency zone, so there is no temporary-limit shot. The seasonal shot only matches while that limit is in force, about late October to early April.
- **Status bar:** 9:41, full signal, charging. The Lock Screen shot shows "Carrier" on the left because the simulator ignores the status bar override there.
- **Retaking:** run `Tools/store-screenshots.sh` (needs Xcode, XcodeGen and an iPhone 17 Pro Max simulator, and downloads the register into `../data/register-check` the first time; `REFRESH=1` fetches it again). It builds the app, installs it on a clean simulator, drives simulated trips with `xcrun simctl location`, and turns the phone with a small UI test in `Tools/screenshots/rotate` because the Simulator's rotate shortcut can't be scripted. It takes a few minutes and rewrites 01 to 04 and 06.
- **Lock Screen (05, 07, 08) is by hand.** `simctl` can't lock and wake the phone, so the script ends by starting the permanent trip and printing the routes for the variable and seasonal cards. Keep the phone awake long enough to capture each one.
- **Framed versions:** `screenshots/6.9-inch-framed/` has the captioned slides, in `portrait/` (1320 × 2868, seven slides) and `landscape/` (2868 × 1320, eight). They are generated, not edited by hand: change a caption in `listing.md` and run `python3 -I Tools/frame-screenshots.py`, which needs ImageMagick, `rsvg-convert` and fontTools. The whole screen is shown, uncropped, so the register credit and "checked" line stay visible. The output is flattened RGB with no alpha, which the App Store requires.
- **Not made:** an iPad set (the app is iPhone-only) and other languages.

## App Review demo video

`review-video/limit-review-demo.mp4` is for App Review, not the store page. It is not in git: it shows one version's screens, and attachments are uploaded to App Store Connect by hand for each version. It is about 100 seconds, H.264, 1320 × 3128, and about 3 MB.

It was recorded in the iOS Simulator with simulated locations, and says so on a title card and under every scene. Each scene has a caption in a strip below the screen, so nothing in the app is covered.

| Time | Scene |
| --- | --- |
| 0:00 | Title card, what it is and what it can't show |
| 0:04 | First run: welcome, then the location explanation and system prompt |
| 0:16 | Set-up screen: Lock Screen card, over-limit tolerance, "Suggest ending my drive" |
| 0:23 | The notifications prompt |
| 0:27 | A drive: Wellington Central 30, Porirua City 50, the Desert Road 100 |
| 0:44 | Over the limit: 104 in a 100, amber and "+4 over" |
| 0:52 | Lock Screen: the Live Activities prompt, then the card |
| 1:03 | The Dynamic Island, with the app in the background |
| 1:09 | Settings, then About the data (attribution, licence, "doesn't endorse") |
| 1:22 | Outside New Zealand, then the open-road sign |
| 1:34 | End drive, then "Drive ended" |

Not in it: the Motion & Fitness walk-away detection and CarPlay, which the simulator can't run (its CarPlay screen doesn't show the Live Activity).

To make a new one: build the app, install it on a clean simulator with permissions reset and the register copied in (as `Tools/store-screenshots.sh` does), start `xcrun simctl io <device> recordVideo --codec=h264`, and step through the app with `xcrun simctl location start` for each route and taps for the rest. Then trim and caption it with `ffmpeg`. The recorder writes frames only when the screen changes and loses the last frame's duration, so hold the final frame from a still. Check the machine isn't busy first: a slow simulator made the first attempt stall.

## Header and search results image

Optional, and only shown to people on iOS 27 or later. One universal 16:9 image (5244 × 2950, PNG, no alpha) covers both placements, and App Store Connect's preview tool shows how each one crops it.

`creative-assets/signs-16x9.png` is three real drive screens side by side: 30 in Wellington Central, 50 in Porirua City and 100 on the Desert Road, at 28, 47 and 96 km/h. It has no text. It also leaves out the register credit, which the listing and the app carry. The three panels sit well inside the area that the 21:9 and 3:2 crops share (about 4405 × 2247 px, if the crops are centred).

To regenerate it, run `Tools/creative-asset-capture.sh`. It needs what the screenshot script needs, takes a few minutes, and retakes the raw captures into `creative-assets/raw/`. Then run `python3 -I Tools/frame-creative-asset.py`; add `--preview DIR` to also write centred 21:9 and 3:2 crops. Check the road name, sign and speed in each raw capture first, because a change to the register can move a route into a different zone.

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
