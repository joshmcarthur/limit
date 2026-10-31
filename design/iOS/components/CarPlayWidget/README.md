# CarPlayWidget

A small square widget for CarPlay (and the Home and Lock Screen small widget family): the sign top-left, measured speed bottom-left, nothing else.

**Layout.** `surface` card at `radius-lg`, `space-4` padding. SpeedSign 72 pt; speed in rounded Heavy at 48 pt with `km/h` in `caption`. Over the limit uses the `caution` pill.

**CarPlay rules borrowed.** Readable in one glance; no text beyond the unit; no tap target needed; dark appearance first; no motion beyond numeric transitions. If location is unavailable, show the unknown sign and “–”.

**Platform note.** Recent iOS releases can show widgets and Live Activities in CarPlay; check the current CarPlay developer guide for supported families and refresh behaviour before building, since a widget’s refresh budget may not suit live speed. The Live Activity may be the better live surface in the car, with this widget as the at-rest fallback.

**The consumer provides** a timeline entry with limit, speed and a stale flag.
