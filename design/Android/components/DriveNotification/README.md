# DriveNotification

The ongoing notification a drive shows: Android’s Lock Screen and shade surface for Limit, built from the standard notification template.

**Anatomy.** Small icon: the monochrome sign silhouette. Header: “Limit · Driving”. Large icon: the sign bitmap at the current limit. Title: “50 km/h · Main North Road”. Text: “Your speed 47 km/h”, or “Your speed 57 km/h · 7 over”. One action: **End drive**.

**States.** Normal; over (text only: notifications can’t carry our caution container, and shouldn’t shout); unknown (“Limit unknown · finding your road”, unknown sign icon).

**Rules.** Channel “Drive in progress”, low importance, silent, ongoing, only alerts once. Content updates on limit change, speed at most every few seconds. Tapping opens the main screen.

**Status bar chip.** On Android versions with promoted Live Updates, the limit can appear as a short chip (“50”). Eligibility for this use is unconfirmed: the notification must stand on its own without it.

**The consumer provides** limit, road name, speed and over amount, from the foreground service.
