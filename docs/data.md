# Speed limit data

Source: the NZTA speed limit zone layer, an ArcGIS feature service:

```
https://services.arcgis.com/CXBb7LAjgIIdcsPt/ArcGIS/rest/services/SpeedLimitZoneFull__View/FeatureServer/0/query
```

`RegisterEndpoint.nzta` queries it with `where=whenIneffective IS NULL`, the five `outFields` the app reads, `outSR=4326`, `geometryPrecision=6`, `f=pgeojson`, ordered by `OBJECTID` and paged with `resultOffset` / `resultRecordCount` (2,000 per page, which is the service's transfer limit).

## The layer (checked against the live service, October 2026)

- Limit field: `speedLimitZoneValue`, a string such as `"50"`. Other fields we read: `speedLimitZoneId`, `speedLimitZoneName`, `speedLimitZoneVariableSpeed` (the reduced school limit, e.g. `"40 km/h"`, or a list for highway variable-speed signs) and `speedLimitZoneVarPrdDesc` (free text for when it applies).
- 91,912 records, but 64,048 have `whenIneffective` set (superseded or expired). The download asks for `whenIneffective IS NULL`: 27,864 records.
- Records repeat: the same zone id with the same shape appears several times. After removing exact repeats, 25,975 zones remain.
- Geometry is polygons in layers, not road centre-lines: a `DEFAULT SPEED LIMIT` 100 area, urban areas on top (`WELLINGTON CITY UTA`, 50), then zones (`WELLINGTON CENTRAL`, 30), then single streets (`CUBA STREET`, 10, a 12-point polygon). The smallest area containing the point wins, so there is no "nearest line" matching and intersections resolve themselves.
- Not checked: 3 in-force records have a `whenEffective` in the future; they are included now.

## Licence and attribution

The dataset page ([NSLR on NZTA Open Data](https://opendata-nzta.opendata.arcgis.com/datasets/NZTA::national-speed-limit-register-nslr/about)) credits Waka Kotahi NZ Transport Agency and licenses the data under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). CC BY asks for: appropriate credit, a link to the licence, a note of any changes, and no suggestion of endorsement. The About screen carries all four (name and author, links to the source and the licence, what we changed, and a not-endorsed line), and the drive screen and Live Activity credit the register. Any store listing and the README should carry the same credit.

The dataset's own quality notes matter for the copy: limits were migrated from each council's bylaw, so some differ from what's signed on the road, and temporary limits other than emergency ones aren't included.

## Seasonal, emergency and ended records

Each record has a category (`speedCategoryName`: Permanent, Variable, Seasonal, and "Temporary", which are emergency limits such as a diversion after a closure), start and end dates, and a "recurs" flag.

- **Ended records.** About a fifth of in-force records have an end date in the past but were never marked ineffective (a superseded "Default Speed Limit 100", old Rotorua state highway records). They are left out of the download, and lookups also check the dates, so one that ends while the phone is offline stops applying.
- **Which limit wins.** Only records active now count. An emergency limit beats a seasonal one, which beats a permanent or variable one (the register's own overlap rules); then the smallest zone, then the lower limit.
- **Seasonal limits.** Records flagged as recurring repeat every year on the same month and day, whatever year their dates are in (Lake Brunner Motor Camp, 1 December to 30 April). Some, like Ohangai Road, have a row per school holiday per year, so repeating them yearly is only approximate and errs towards the lower limit. The drive screen and Live Activity say when the limit is seasonal or temporary.
- **Placeholders.** Start dates in 1899 and 1900 mean "always".
- **Overpass and underpass.** The dataset says a bridge and the road under it are separate overlapping records. On the layer as checked, 300 of 390 bridges have a road under them at a different limit, so a position alone can't tell the level. The engine stays on the level you were already on; with none to go on it takes the lower limit. Heading (`CLLocation.course`) could help later.

## Attributes we don't use yet

- `speedLimitZoneLanePurposeName` and `SeperateLaneSpeeds`: bus lanes and per-lane speeds; empty in the data seen so far.
- `speedLimitZoneReasonName`: why the limit exists (school, congestion, default area, park and so on). It could help tell a road from an area when showing the name.
- `speedLimitZoneMaxValue` and `speedLimitZoneMinValue`: for variable-speed signs on state highways.

## Staying current

`FeatureServer/0?f=json` (about 5 KB compressed) reports `editingInfo.dataLastEditDate`. The stored copy remembers it; a sync downloads only if the source date is newer, otherwise it just refreshes the "checked" date. A layer that answers without a date means download. A layer that can't be read at all means no download when a copy is stored (see below).

## Being a good API citizen

The source is a public service run for NZTA, so the app limits how often it asks and what it asks for. `SyncSchedule` holds the numbers; the attempt record is stored beside the register (`Register/sync-attempts.json`) so the limits hold across launches and survive a register being replaced.

- **Automatic checks at most weekly** when a copy is stored. Opening the app any number of times in between makes no request. A first run with nothing stored goes straight away. The register changes nightly, but a limit rarely changes on any one road and the sign only warns after 30 days.
- **A check is the 5 KB layer request.** The full download only happens when the layer's edit date is newer than the stored copy's.
- **Failures back off:** 15 minutes, 1 hour, 6 hours, then 24 hours between attempts, until one succeeds. A rejected download (the source mid-rebuild) counts the same, so a broken source costs one download per back-off step, not one per launch. An attempt is counted when it starts, so one killed halfway (the app suspended) counts too.
- **An unreadable layer never causes a download** when a copy is stored. Only a first run with no copy downloads without first reading the layer.
- **Manual checks** (Retry, Check now) skip the weekly wait and the back-off, but not a 5 minute floor between attempts.
- **Retries wait** 1 s then 4 s. A 429 or 503 (busy) or any other 4xx (refused) is never retried and stops the sync, including when it's the count request.
- **Pages are fetched one at a time**, only in-force records, only the fields the app reads.
- **Requests identify the app:** `User-Agent: Limit-iOS/<version> (+https://github.com/joshmcarthur/limit)`.

### Fetching only what changed (investigated, not built)

Checked against the live layer on 22 October 2026:

- The layer has no per-record edit time, no editor tracking and no change tracking (`capabilities` is `Query,Extract`, `syncEnabled` is false), so ArcGIS's incremental sync and a `last_edited > X` filter are not available.
- `whenEffective` and `whenIneffective` are legal dates, not edit times, and hold placeholders (a maximum in 2050, a minimum in 1899). A record entered late or corrected in place would be missed, so they are not safe as a cursor.
- Geometry is almost all of the download: one 2,000-record page is about 2.7 MB over the wire with geometry and 127 KB without. A full download is roughly 35 to 40 MB; the attribute-only data for every in-force record is about 1.5 to 2 MB.
- So a delta is possible: fetch an attribute-only manifest, compare it with one stored from the last sync, and fetch geometry (by `objectIds`) only for new or changed rows. Cautions: rows repeat heavily with identical ids and `speedLimitZoneGeometryCertId` (compare as a multiset of row hashes, not by zone id); `OBJECTID` isn't stable across rebuilds, so it's only for fetching within one sync; stored zones don't keep their ids; and it isn't proven that the cert id changes when a shape changes. That needs two manifests a few days apart. A forced full refresh every ~90 days would be the backstop.

## Swapping in new data safely

The register is stored blue-green. Each copy sits in its own folder under `Register/` and a small `current` file names the one in use. An update:

1. downloads everything in memory (a cancelled or failed run writes nothing);
2. checks it: at least 99% of the records the source reported at the start, at least 15,000 zones, and at least 80% of the zones in the copy now in use;
3. writes it to a new folder beside the live one and reads it back against a checksum;
4. moves `current` to the new folder (one atomic write), then deletes the old folder.

Anything that fails a step is discarded and the old register stays in use; the app shows the usual "couldn't update" state. Folders left by a crash are cleared on the next write.

Why: on 22 October 2026 the NZTA layer was rebuilt while we were testing. It went from about 92,000 records to about 1,250 and then climbed back through 5,000. A plain overwrite would have replaced a good register with a partial one. The 15,000 floor is a guess about how small a legitimate national register could get. It is about 21,000 zones once ended records are left out (about 26,000 with them), and the layer was mid-rebuild at 16,000 when this was set, so re-measure with `RegisterCheck` once NZTA has finished and adjust.

A rejected download counts as a failure for the back-off above.

## School zones

`speedLimitZoneVarPrdDesc` is free text with 876 distinct wordings across 5,917 records. `SchoolPeriodParser` reads the clock times when there are one or two plain windows (3,120 records on the last check) and the zone then shows its reduced limit on weekdays in those windows, in NZ time. It deliberately skips: wording relative to the bell ("35 minutes before the start of school"), lists of several schools, times that differ by day, and highway variable-speed notices. Those zones keep their permanent limit. There are no term dates in the data, so school holidays still show the reduced limit in the windows.

## Size and speed (`swift run -c release RegisterCheck`, on a Mac)

25,975 zones, 7.1 million vertices, 55 MB stored, loaded in 0.9 s, a lookup in about 10 microseconds. Full download about 75 s. Memory and load time on a phone are unmeasured; simplifying polygons is the obvious way to shrink it if they matter.

## To do

- Delta sync, once the cert id is shown to track geometry changes (see above).
- Measure load time and memory on a device.
