# Play Store screenshots

Raw captures from the API 36 `Medium_Phone_Play_Store` emulator (1080 × 2400; landscape is 2400 × 1080). They have no device frames. Clock is 9:41 via System UI demo mode.

| File | Shows |
| --- | --- |
| `screenshots/01-drive-light.png` | Driving at 28 km/h in a 30 zone, Wellington Central |
| `screenshots/02-over-the-limit-104-in-100.png` | 104 km/h on a 100 km/h state highway (the Desert Road, SH 1), "+4 over" |
| `screenshots/03-drive-dark.png` | Dark mode, 26 km/h in the 30 zone |
| `screenshots/04-landscape-dark.png` | Landscape, 27 km/h in the 30 zone |
| `screenshots/05-lock-screen.png` | The ongoing drive notification (Android’s Lock Screen surface), 96 km/h in a 100 |
| `screenshots/06-welcome.png` | First-run Setup. Location off, register not downloaded yet |

Optics match the iOS set: every shot is at or under the limit except 02, which is a small 4 km/h over.

05 is the notification shade, not the keyguard. The emulator lock screen did not show the `IMPORTANCE_LOW` foreground-service notification.

06 is Setup, not the iOS marketing welcome. The live NZTA download failed on this emulator, so the first-run card shows that error.

## App Review demo video

`review-video/limit-review-demo.mp4` is a captioned slideshow of those stills plus Porirua 50, Desert Road 96, Settings, and End drive. It is not a live screen recording (the emulator recorder writes too few frames, and Circle to Search stole the second take).

Not in it: About, outside New Zealand, open road, Android Auto (this Play Store image has no head-unit server), the widget, or the tile.
