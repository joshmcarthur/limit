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

`docs/screenshots/` holds 1320×2868 captures (the 6.9" App Store size) with the status bar set to 9:41. The driving screens used a saved register and a simulated drive through Wellington; the limit and name shown are real register data.

Compared with `design/limit-screens.pdf`:

| Screen | Result |
| --- | --- |
| Onboarding 1 (welcome), 2 (location) | Match. |
| Driving: light, over-limit (orange pill, "+8 over"), dark, searching for GPS | Match in layout, colour and copy. The "No GPS yet" dash is a rounded pill where the design has a thin bar. |
| Onboarding 3 (almost ready) | Differs: the card says "Updating speed limits…" where the design says "Downloading speed limits…" with "42% of [size]"; the "+3 km/h" tolerance sits outside the stepper rather than between − and +; the toggles are system green where the design uses the blue tint; "Done" sits under the content rather than pinned to the bottom. |
| Settings, About | Not in the design; they follow the design system's tokens. |
| Lock Screen Live Activity | Shows "No GPS yet" after the app was locked mid-drive, even with a simulated drive running. Unverified whether the simulator doesn't deliver location to a locked app or the activity isn't updating; check on a device. |
| Landscape | Not captured: nothing here can rotate the simulator. |

Other findings:
- The road-name line shows the register's zone name, so area zones read "Wellington Central" and "Default Speed Limit" where the design shows a road ("Main North Road", "State Highway 1"). Area names probably shouldn't be shown as roads.
- Over-limit and dark states look right on the data from the real register.
