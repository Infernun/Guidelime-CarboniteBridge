# Changelog

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
