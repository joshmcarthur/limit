# SetupStep

One card in the single Setup screen. Each step explains why before Android’s system dialog appears, and shows a way back if the user said no.

**States.** *To do*: `primary-container` icon well and a filled “Allow” button. *Done*: muted icon well with `check_circle`, no button. *In progress*: a linear progress indicator (used for the speed limit download). *Blocked*: after a second denial Android won’t show its dialog again, so the step explains what’s missing in `caution-ink` and offers an outlined “Open settings” that deep-links to the app’s settings page.

**Steps.** Location (precise, while using the app), Notifications (Android 13+; optional, explains the Lock Screen loses Limit without it), Speed limits (download, automatic).

**Why one screen, not a carousel.** Android users grant permissions as they meet them, and a checklist lets each step be retried on its own; a paged flow would trap a denied step behind a Back gesture.

**The consumer provides** title, supporting text, state and the action.
