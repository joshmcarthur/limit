# QuickSettingsTile

A Quick Settings tile, **Drive**, that starts and ends a drive from the notification shade without opening the app.

**States.** *Inactive*: “Drive”, “Off”. *Active*: “Drive”, the current limit as secondary text (“50 km/h limit”). *Unavailable*: if setup isn’t finished, tapping opens Setup.

**Rules.** The system draws the tile; we supply a monochrome icon (`directions_car`), label and subtitle. Keep the subtitle short; tiles truncate. State mirrors the FAB and notification.

**The consumer provides** state and limit via the tile service.
