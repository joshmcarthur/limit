# Speed limit data

Source: the NZTA speed limit zone layer, an ArcGIS feature service:

```
https://services.arcgis.com/CXBb7LAjgIIdcsPt/ArcGIS/rest/services/SpeedLimitZoneFull__View/FeatureServer/0/query
```

`RegisterEndpoint.nzta` queries it with `where=1=1`, `outFields=*`, `outSR=4326`, `geometryPrecision=6`, `f=pgeojson`, paged with `resultOffset` / `resultRecordCount` (2,000 per page, which is the service's transfer limit).

## What the sample dump showed

A gzipped GeoJSON dump (one page, 2,000 features) was used to shape the parser:

- Geometry is `Polygon` (1,916) and `MultiPolygon` (84): zones with area, not centre-lines.
- The only property is `speedLimitZoneName` (for example `GLOUCESTER STREET`, `WELLINGTON CITY UTA`, `OHANGAI ROAD SEASONAL SPEED LIMIT`).
- `properties.exceededTransferLimit` is `true`, so there are more pages.
- **There is no numeric speed limit field in the dump.** The curl used `outFields=` (empty), which may have returned only the default field.

## Consequences

- `GeoJSONZoneParser` reads the limit from the first property whose name (ignoring case and punctuation) is one of `speedlimit`, `speedlimitvalue`, `speedlimitkmh`, `postedspeedlimit`, `speed`, `limit`, `limitkmh`, and accepts a number or a string like `"60 km/h"` between 10 and 110 in steps of 5. **This list is a guess.**
- Features with no usable limit are counted, never given a made-up value. If the first page has features but none carry a limit, the download stops with `RegisterSyncError.noLimitsInSource`, and the app shows "Couldn't update speed limits".
- Overlapping zones: the one with the smallest bounding box wins, then the lower limit. Unverified against real overlaps.

## To do

- Inspect the layer's fields (`.../FeatureServer/0?f=json`) and replace the guessed key list with the real one.
- Check the licence and attribution requirements, and update the About screen.
- Measure the full register's size and load time on a device. If it is too large, simplify polygons on download or tile the store.
