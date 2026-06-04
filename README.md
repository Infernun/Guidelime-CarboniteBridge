# Guidelime Carbonite Bridge

Guidelime Carbonite Bridge is a small compatibility bridge for **Guidelime** and **Carbonite** in World of Warcraft Classic/TBC.

It mirrors Guidelime's numbered route step markers, active waypoint markers, and active `DO:` route/objective waypoints into the Carbonite map.

Carbonite already shows many Questie-style quest icons and objective areas. This bridge is focused specifically on the Guidelime route information that normally appears on the default World of Warcraft map.

## Current stable version

Current release: `v6.1.0`

This version improves the bridge behavior by synchronizing Carbonite markers through Guidelime's own map update flow instead of using a destructive periodic refresh.

It also improves `DO:` handling:

* Active `DO:` steps can appear as the active green waypoint/arrow marker.
* `DO:` markers remain visible while they are needed.
* The bridge avoids showing duplicate green arrows.
* Carbonite updates when Guidelime updates its own map markers.
* Repeated marker flickering is reduced.

## Purpose

The goal is to make Carbonite display the same useful Guidelime route information that appears on the default WoW map:

* Numbered Guidelime route steps.
* Active Guidelime waypoint/arrow marker.
* Active `DO:` waypoint marker when Guidelime uses it as the current destination.
* Tooltips from Guidelime where available.
* Separate size controls for global scale, numbered steps, and active arrow markers.

## Current limitation

This is currently not a standalone addon in the usual sense.

The file must be loaded from inside the `Guidelime` addon folder because Guidelime's internal map marker data is stored in its local addon table, especially:

```lua
addon.M.mapIcons
addon.M.arrowFrame.element
addon.M.getMapTooltip(...)
addon.M.updateStepsMapIcons(...)
```

Because those values are not exposed as a public external API, the bridge has to be added to the Guidelime TOC file.

## Installation

1. Copy this file:

```text
Guidelime_CarboniteBridge.lua
```

into:

```text
World of Warcraft/_classic_/Interface/AddOns/Guidelime/
```

2. Open the relevant Guidelime TOC file, for example:

```text
Guidelime-TBC.toc
```

3. Add this line at the end:

```text
Guidelime_CarboniteBridge.lua
```

4. Start or reload the game:

```text
/reload
```

5. Check status:

```text
/glcarb status
```

## Recommended setup

```text
/glcarb on
/glcarb smart
/glcarb arrow on
/glcarb arrowmode route
/glcarb do on
/glcarb doarrow on
/glcarb size 1.40
/glcarb stepsize 1.00
/glcarb arrowsize 1.00
/glcarb refresh
```

## Commands

| Command                   | Description                                                                                                                              |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `/glcarb`                 | Same as `/glcarb status`.                                                                                                                |
| `/glcarb status`          | Shows bridge status, mode, marker sizes, pin counts, skipped pins, Carbonite API availability, detected marker types, and sync mode.     |
| `/glcarb refresh`         | Manually rebuilds Carbonite pins from Guidelime's current map markers.                                                                   |
| `/glcarb r`               | Short alias for `/glcarb refresh`.                                                                                                       |
| `/glcarb on`              | Enables the bridge.                                                                                                                      |
| `/glcarb off`             | Disables the bridge and clears its Carbonite layer.                                                                                      |
| `/glcarb smart`           | Recommended mode. Mirrors route-related Guidelime markers while avoiding unnecessary duplication of Questie/Carbonite objective markers. |
| `/glcarb all`             | Diagnostic mode. Mirrors all Guidelime marker types. This may duplicate information already shown by Questie/Carbonite.                  |
| `/glcarb debug`           | Prints detected Guidelime map marker types, internal marker metadata, and active arrow information.                                      |
| `/glcarb size`            | Shows the global scale multiplier.                                                                                                       |
| `/glcarb size 1.40`       | Sets the global scale multiplier. Range: `0.50` to `3.00`.                                                                               |
| `/glcarb stepsize`        | Shows the numbered-step marker scale multiplier.                                                                                         |
| `/glcarb stepsize 1.00`   | Sets the numbered step marker scale multiplier.                                                                                          |
| `/glcarb arrowsize`       | Shows the active arrow/waypoint marker scale multiplier.                                                                                 |
| `/glcarb arrowsize 1.00`  | Sets the active arrow/waypoint marker scale multiplier.                                                                                  |
| `/glcarb arrow on`        | Shows the active Guidelime arrow/waypoint marker on Carbonite.                                                                           |
| `/glcarb arrow off`       | Hides the active Guidelime arrow/waypoint marker from Carbonite.                                                                         |
| `/glcarb arrowmode route` | Recommended mode. Uses route-style Guidelime waypoint behavior and avoids the old broad arrow behavior.                                  |
| `/glcarb arrowmode any`   | Diagnostic/legacy mode. Allows any Guidelime arrow element and may duplicate objective arrows.                                           |
| `/glcarb do on`           | Shows Guidelime `DO:` markers when they are present. Recommended.                                                                        |
| `/glcarb do off`          | Hides `DO:` markers from the bridge. Not recommended for normal leveling because it can hide useful destination information.             |
| `/glcarb doarrow on`      | Allows the active `DO:` step to appear as the active temporary waypoint/arrow marker. Recommended.                                       |
| `/glcarb doarrow off`     | Prevents `DO:` steps from becoming active arrow markers.                                                                                 |
| `/glcarb arrive 0.007`    | Sets the normalized arrival radius used by older/fallback arrival logic. Current native sync mainly follows Guidelime's own update flow. |

## Size logic

The bridge uses three size multipliers:

```text
final step marker size = size × stepsize
final arrow marker size = size × arrowsize
```

Default values:

```text
size = 1.40
stepsize = 1.00
arrowsize = 1.00
```

Examples:

```text
/glcarb size 1.40
/glcarb stepsize 1.00
/glcarb arrowsize 1.00
```

This makes numbered steps and active arrows use the same base visual size.

```text
/glcarb arrowsize 1.20
```

This makes only the active arrow/waypoint marker larger.

```text
/glcarb stepsize 1.20
```

This makes only the numbered route steps larger.

## DO marker behavior

Guidelime can use `DO:` steps as temporary active destinations.

In `v6.1.0`, the bridge tries to imitate Guidelime's native map behavior:

* If Guidelime makes a `DO:` step the active highlighted map marker, Carbonite mirrors it as the active waypoint marker.
* The `DO:` marker remains visible while Guidelime keeps it active.
* When Guidelime updates or releases the step, Carbonite updates with it.
* The bridge avoids creating an extra duplicate green arrow.

Recommended settings:

```text
/glcarb do on
/glcarb doarrow on
/glcarb arrowmode route
```

## Synchronization behavior

Older test builds used periodic refresh logic that could cause Carbonite markers to flicker.

`v6.1.0` uses native-style synchronization instead. It refreshes Carbonite mainly after Guidelime finishes rebuilding its own map markers through:

```lua
addon.M.updateStepsMapIcons()
```

This is closer to how Guidelime updates the default WoW map and reduces repeated `Clear() + Add() + Refresh()` cycles in Carbonite.

`/glcarb status` should show:

```text
sync=native
```

## Saved settings

The bridge stores its settings in `GuidelimeData`:

```lua
GuidelimeData.carboniteBridgeEnabled
GuidelimeData.carboniteBridgeMode
GuidelimeData.carboniteBridgeSizeScale
GuidelimeData.carboniteBridgeStepSizeScale
GuidelimeData.carboniteBridgeArrowSizeScale
GuidelimeData.carboniteBridgeShowArrowPin
GuidelimeData.carboniteBridgeArrowMode
GuidelimeData.carboniteBridgeShowDOMarkers
GuidelimeData.carboniteBridgeDoArrow
GuidelimeData.carboniteBridgeArrivalRadius
```

## Technical notes

The bridge reads Guidelime's existing map marker data from:

```lua
addon.M.mapIcons
```

It also uses active waypoint information from:

```lua
addon.M.arrowFrame.element
```

For Carbonite, it uses the public Map Provider API:

```lua
Carbonite.Map:CreateProvider("GuidelimeCarboniteBridge")
provider:DefinePin(...)
provider:Add(...)
provider:Clear()
provider:SetEnabled(...)
```

Guidelime uses `mapID`, `x`, and `y` coordinates, while Carbonite world pins expect Carbonite world coordinates. The bridge converts them through:

```lua
Nx.Map:GetWorldPos(mapID, x, y)
```

The bridge also copies texture coordinates from Guidelime's marker atlas so that Carbonite can display the same numbered markers and highlighted route markers.

## Questie

Questie is not a direct dependency of this bridge.

Carbonite and/or Guidelime may already use Questie data for quest objectives. This bridge focuses on Guidelime route markers and active Guidelime waypoint behavior.

## Tested environment

This bridge was created and tested for WoW Classic/TBC-style Guidelime usage with Carbonite installed.

Please report issues with:

* WoW client version.
* Guidelime version.
* Carbonite version.
* Questie version, if installed.
* Output from `/glcarb status`.
* Output from `/glcarb debug`.

## Credits

This bridge was developed with the help of ChatGPT, specifically GPT-5.5 Thinking.
