# Design notes

The screens follow the "Limit — onboarding and main screen" canvas, and the tokens, components and driving rules follow the "Limit" design system.

## Mapping

| Design | Code |
| --- | --- |
| `tokens.json` colours, spacing, radii | `DesignTokens` (core), `Palette` (app). Contrast promises are unit tested. |
| SpeedSign | `SpeedSignView`, state in `SignState`, proportions in `SignMetrics` |
| SpeedReadout | `SpeedReadoutView`, hysteresis in `OverLimitEvaluator` |
| SyncStatus | `SyncStatusRow`, state and copy in `SyncState` / `FreshnessText` |
| LiveActivity | `Widgets/DriveLiveActivity.swift`, state in `DriveActivityAttributes` |
| CarPlayWidget | Not built yet |
| Onboarding 1–3 | `OnboardingWelcomeView`, `OnboardingLocationView`, `OnboardingReadyView` |
| Driving: light, dark, over, finding location, landscape | `DriveView` (one view; state and size class choose the variant) |

## Rules enforced in code

- Sign, then speed, in that order on every surface.
- Never a frozen number: a location sample older than 5 s, or with accuracy worse than 100 m, shows as no speed and an unknown limit (`DriveEngine`). The Live Activity is marked stale after 10 s and falls back to the same state.
- The sign never shows the last known limit when data is too old (`FreshnessPolicy`).
- Over the limit is never colour alone: pill, "+N over", and an arrow in the compact Island.
- Calm motion: only numeric transitions and a short fade, removed under Reduce Motion.
- Location permission is requested in onboarding, parked. No alerts while driving.
- `sign-ring` red appears only on the sign.

## Assumptions to confirm

- After "End drive" the main screen stays up with a "Start drive" button. The design doesn't cover this state.
- Freshness thresholds (stale after 30 days, unknown after 180) are proposals.
- Over-limit shows from the tolerance upward (`delta >= tolerance`) and clears at `tolerance - 2` (minimum 0).
- App icon, launch screen and the About screen's licence wording are not designed yet.

## Screenshots and design check (iPhone 16 Pro Max, iOS 18, simulator)

`docs/screenshots/` holds captures at the 6.9" App Store size (1320×2868, landscape 2868×1320) with the status bar set to 9:41. The driving screens used a saved register and a simulated drive through Wellington (`xcrun simctl location`); the limits and names are real register data.

| File | Screen |
| --- | --- |
| 01–03 | Onboarding: welcome, location, almost ready (03 shows the "couldn't update" state, which is what the app showed when the live source was incomplete and the download was rejected) |
| 05–07, 09 | Driving: light, over the limit (light and dark), rural 100 in dark |
| 08 | Driving: searching for GPS |
| 10, 11, 11b | Settings, About, About's attribution section |
| 12 | Lock Screen Live Activity |
| 13 | Driving in landscape (dark) |

Compared with `design/limit-screens.pdf`:

- Onboarding 1 and 2, the driving screens (light, over, dark, searching) and landscape match in layout, colour and structure. The copy is intentionally different now (see the copy pass); the design file's wording is no longer the source of truth.
- Landscape follows the design (sign left, speed right, End drive in the top bar) with one addition: the "Speed limits checked…" line sits under the content. The design has no footer in landscape.
- Onboarding 3 still differs from the design: the download card title, the "+3 km/h" tolerance sitting outside the − / + stepper, system-green toggles where the design uses blue, and "Done" not pinned to the bottom.
- The "No GPS yet" dash is a rounded pill where the design has a thin bar.
- The road-name line shows the register's zone name, so areas read "Wellington Central" and "Default Speed Limit" where the design shows roads ("State Highway 1"). `speedLimitZoneReasonName` could help tell areas from roads.

Landscape and the Lock Screen were checked in the simulator by rotating with a small throwaway UI test (`XCUIDevice.shared.orientation`), since the simulator's rotate shortcut isn't scriptable from here. The Lock Screen check found and fixed a bug: unchanged content went stale after 10 s.
