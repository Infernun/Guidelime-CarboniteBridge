# Changelog

## v6.0.0

* Fixed a false active-arrow issue where Guidelime `DO:` quest objective steps could be mirrored into Carbonite as an additional green arrow.
* Improved `smart` mode so dynamic objective markers generated from mobs, items, objects, loot, or quest objectives are not treated as route waypoints.
* Added internal annotation around Guidelime map icons to better distinguish real route markers from objective markers.
* Kept Carbonite/Questie objective data from being duplicated by the bridge.
* Added/kept `/glcarb arrowmode route` as the recommended behavior.
* Added `/glcarb arrowmode any` as a diagnostic/legacy mode.
* The bridge still mirrors numbered Guidelime route steps and the real active route arrow into Carbonite.

## v5
- Added `/glcarb arrowsize`.
- Kept `/glcarb size` as global scale.
- Kept `/glcarb stepsize` for numbered step markers.
- Added separate sizing logic:
  - `step = size × stepsize`
  - `arrow = size × arrowsize`

## v4
- Added `/glcarb stepsize`.
- Matched numbered step marker size to the active Guidelime arrow marker by default.

## v3
- Added active Guidelime arrow/next-step marker support.
- Added `/glcarb arrow on|off`.

## v2
- Fixed Carbonite coordinate conversion.
- Mirrored Guidelime numbered map markers from `addon.M.mapIcons`.

## v1
- Initial bridge prototype.
