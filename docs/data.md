# Speed limit data

Source: the NZTA speed limit zone layer, an ArcGIS feature service:

```
https://services.arcgis.com/CXBb7LAjgIIdcsPt/ArcGIS/rest/services/SpeedLimitZoneFull__View/FeatureServer/0/query
```

`RegisterEndpoint.nzta` queries it with `where=1=1`, `outFields=*`, `outSR=4326`, `geometryPrecision=6`, `f=pgeojson`, paged with `resultOffset` / `resultRecordCount` (2,000 per page, which is the service's transfer limit).

## The layer (checked against the live service, October 2026)

- Limit field: `speedLimitZoneValue`, a string such as `"50"`. Other fields we read: `speedLimitZoneId`, `speedLimitZoneName`, `speedLimitZoneVariableSpeed` (the reduced school limit, e.g. `"40 km/h"`, or a list for highway variable-speed signs) and `speedLimitZoneVarPrdDesc` (free text for when it applies).
- 91,912 records, but 64,048 have `whenIneffective` set (superseded or expired). The download asks for `whenIneffective IS NULL`: 27,864 records.
- Records repeat: the same zone id with the same shape appears several times. After removing exact repeats, 25,975 zones remain.
- Geometry is polygons in layers, not road centre-lines: a `DEFAULT SPEED LIMIT` 100 area, urban areas on top (`WELLINGTON CITY UTA`, 50), then zones (`WELLINGTON CENTRAL`, 30), then single streets (`CUBA STREET`, 10, a 12-point polygon). The smallest area containing the point wins, so there is no "nearest line" matching and intersections resolve themselves.
- Not checked: 3 in-force records have a `whenEffective` in the future; they are included now.

## Staying current

`FeatureServer/0?f=json` (about 5 KB compressed) reports `editingInfo.dataLastEditDate`. The stored copy remembers it; a sync downloads only if the source date is newer, otherwise it just refreshes the "checked" date. A missing or unreadable date means download.

## Swapping in new data safely

The register is stored blue-green. Each copy sits in its own folder under `Register/` and a small `current` file names the one in use. An update:

1. downloads everything in memory (a cancelled or failed run writes nothing);
2. checks it: at least 99% of the records the source reported at the start, at least 20,000 zones, and at least 80% of the zones in the copy now in use;
3. writes it to a new folder beside the live one and reads it back against a checksum;
4. moves `current` to the new folder (one atomic write), then deletes the old folder.

Anything that fails a step is discarded and the old register stays in use; the app shows the usual "couldn't update" state. Folders left by a crash are cleared on the next write.

Why: on 22 October 2026 the NZTA layer was rebuilt while we were testing. It went from about 92,000 records to about 1,250 and then climbed back through 5,000. A plain overwrite would have replaced a good register with a partial one. The 20,000 floor is a guess about how small a legitimate national register could get (it is about 26,000 now); lower it if NZTA ever consolidates records.

Not done: a rejected download still counts as "failed", so the app tries again on the next foreground, which costs a full download each time while the source stays broken. It needs a back-off.

## School zones

`speedLimitZoneVarPrdDesc` is free text with 876 distinct wordings across 5,917 records. `SchoolPeriodParser` reads the clock times when there are one or two plain windows (3,120 records on the last check) and the zone then shows its reduced limit on weekdays in those windows, in NZ time. It deliberately skips: wording relative to the bell ("35 minutes before the start of school"), lists of several schools, times that differ by day, and highway variable-speed notices. Those zones keep their permanent limit. There are no term dates in the data, so school holidays still show the reduced limit in the windows.

## Size and speed (`swift run -c release RegisterCheck`, on a Mac)

25,975 zones, 7.1 million vertices, 55 MB stored, loaded in 0.9 s, a lookup in about 10 microseconds. Full download about 75 s. Memory and load time on a phone are unmeasured; simplifying polygons is the obvious way to shrink it if they matter.

## To do

- Check the licence and attribution requirements, and update the About screen.
- Add a back-off for repeated rejected downloads.
- Measure load time and memory on a device.
