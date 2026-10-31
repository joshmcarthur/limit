# DriveFab

The main screen’s one action: an Extended FAB, bottom end, that starts and ends a drive (the foreground service).

**States.** *Start drive*: `primary-container`, `directions_car` icon. *End drive*: `secondary-container`, `stop_circle` icon: still visible, deliberately less prominent while driving. *Collapsed*: icon-only 56 dp in landscape, where width is precious; it keeps its content description.

**Why a FAB.** It is Android’s idiom for a screen’s primary action, it sits in the thumb zone, and it makes the start of background tracking an explicit, visible choice. On iOS the equivalent is a plain button because the Live Activity starts more quietly.

**Rules.** 56 dp tall, `corner-large`, 16 dp from the edges plus the navigation bar inset. The drive can also be ended from the notification and the Quick Settings tile; all three stay in sync.

**The consumer provides** `isDriving` and the two callbacks.
