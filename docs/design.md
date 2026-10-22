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
