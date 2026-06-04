# Changelog

## v6.1.0

* Promoted the latest stable tested build from the `v6.0.7-test` line.
* Improved synchronization with Guidelime's native map marker update flow.
* Carbonite now refreshes mainly after Guidelime finishes `M.updateStepsMapIcons()`, instead of using repeated periodic destructive refreshes.
* Reduced repeated marker flickering caused by frequent `Clear() + Add() + Refresh()` cycles.
* Improved active `DO:` behavior.
* Active `DO:` steps can appear as the active temporary waypoint/arrow marker when Guidelime uses them that way.
* `DO:` markers remain visible while Guidelime keeps them active.
* The bridge avoids creating duplicate active green arrows.
* Preserved numbered Guidelime route markers.
* Preserved active Guidelime waypoint marker behavior.
* Kept separate scale controls:

  * `/glcarb size`
  * `/glcarb stepsize`
  * `/glcarb arrowsize`
* Kept `smart` mode as the recommended default.
* Added/kept DO-related controls:

  * `/glcarb do on|off`
  * `/glcarb doarrow on|off`
* `/glcarb status` now reports native sync behavior with `sync=native`.

## v6.0.0

* Fixed a false active-arrow issue where Guidelime `DO:` quest objective steps could be mirrored into Carbonite as an additional green arrow.
* Improved `smart` mode so dynamic objective markers generated from mobs, items, objects, loot, or quest objectives are not treated as normal route waypoints.
* Added internal annotation around Guidelime map icons to better distinguish real route markers from objective markers.
* Kept Carbonite/Questie objective data from being duplicated by the bridge.
* Added `/glcarb arrowmode route` as the recommended behavior.
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
