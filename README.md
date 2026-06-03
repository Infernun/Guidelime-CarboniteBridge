# Guidelime Carbonite Bridge

Guidelime Carbonite Bridge is a small compatibility bridge for **Guidelime** and **Carbonite** in World of Warcraft Classic/TBC.

It mirrors Guidelime's numbered route step markers, such as `1`, `2`, `3`, `4`, and the active Guidelime arrow/next-step marker into the Carbonite map.

Carbonite already integrates quest/objective data from Questie in many cases. This bridge is focused specifically on the Guidelime route markers and the active guide waypoint that normally appear on the default World of Warcraft map.

## Purpose

The goal is to make Carbonite display the same Guidelime route information that appears on the default WoW map:

* Numbered Guidelime route steps.
* The active Guidelime waypoint/arrow marker.
* Tooltips from Guidelime where available.
* Separate size controls for global scale, numbered steps, and the active arrow marker.

## Current limitation

This is currently not a standalone addon in the usual sense.

The file must be loaded from inside the `Guidelime` addon folder because Guidelime's internal map marker data is stored in its local addon table, especially:

* `addon.M.mapIcons`
* `addon.M.arrowFrame.element`
* `addon.M.getMapTooltip(...)`
* `addon.M.updateStepsMapIcons(...)`

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
/glcarb smart
/glcarb arrow on
/glcarb size 1.40
/glcarb stepsize 1.00
/glcarb arrowsize 1.00
/glcarb refresh
```

## Commands

| Command                  | Description                                                                                                                  |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| `/glcarb`                | Same as `/glcarb status`.                                                                                                    |
| `/glcarb status`         | Shows bridge status, mode, sizes, pin counts, skipped pins, Carbonite API availability, and detected marker types.           |
| `/glcarb refresh`        | Rebuilds Carbonite pins from Guidelime markers.                                                                              |
| `/glcarb r`              | Short alias for `/glcarb refresh`.                                                                                           |
| `/glcarb on`             | Enables the bridge.                                                                                                          |
| `/glcarb off`            | Disables the bridge and clears its Carbonite layer.                                                                          |
| `/glcarb smart`          | Recommended mode. Mirrors route-related Guidelime markers while avoiding duplicate Questie-style mob/loot/objective markers. |
| `/glcarb all`            | Diagnostic mode. Mirrors all Guidelime marker types. This may duplicate information already shown by Questie/Carbonite.      |
| `/glcarb debug`          | Prints detected Guidelime map marker types and active arrow information.                                                     |
| `/glcarb size`           | Shows the global scale multiplier.                                                                                           |
| `/glcarb size 1.60`      | Sets the global scale multiplier. Range: `0.50` to `3.00`.                                                                   |
| `/glcarb stepsize`       | Shows the numbered-step marker scale multiplier.                                                                             |
| `/glcarb stepsize 1.20`  | Makes numbered step markers larger without changing the active arrow marker.                                                 |
| `/glcarb arrowsize`      | Shows the active arrow/next-step marker scale multiplier.                                                                    |
| `/glcarb arrowsize 1.20` | Makes the active arrow marker larger without changing numbered step markers.                                                 |
| `/glcarb arrow on`       | Shows the active Guidelime arrow/next-step marker on Carbonite.                                                              |
| `/glcarb arrow off`      | Hides the active Guidelime arrow/next-step marker from Carbonite.                                                            |

## Size logic

The bridge uses three size multipliers:

```text
final step marker size = size × stepsize
final arrow marker size = size × arrowsize
```

Defaults:

```text
size = 1.40
stepsize = 1.00
arrowsize = 1.00
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
```

## Technical notes

The bridge reads Guidelime's existing map marker data from:

```lua
addon.M.mapIcons
```

It also tries to mirror the active next-step marker from:

```lua
addon.M.arrowFrame.element
```

or, as a fallback, from the current active guide step.

For Carbonite, it uses the public Map Provider API:

```lua
Carbonite.Map:CreateProvider("GuidelimeCarboniteBridge")
provider:DefinePin(...)
provider:Add(...)
provider:Clear()
provider:SetEnabled(...)
```

Guidelime uses `mapID`, `x`, and `y` coordinates, while Carbonite world pins expect world coordinates. The bridge converts them through:

```lua
Nx.Map:GetWorldPos(mapID, x, y)
```

The bridge also copies the texture coordinates from Guidelime's marker atlas so that the Carbonite map displays the same numbered markers as the default WoW map.

## Why this is useful

Players who use both Guidelime and Carbonite can follow the guide directly from the Carbonite map without constantly switching back to the default WoW map to see the numbered Guidelime route steps.

## Integration request

Ideally, this functionality could become either:

1. An optional Guidelime integration loaded only when Carbonite is installed, or
2. A small public Guidelime API exposing current map markers and the active waypoint to external addons.

That would allow the bridge to become a clean standalone addon without needing to be loaded from inside the Guidelime TOC.

## Tested environment

This bridge was created for WoW Classic/TBC-style Guidelime usage with Carbonite installed.

Please report issues with:

* WoW client version.
* Guidelime version.
* Carbonite version.
* Questie version, if installed.
* Output from `/glcarb status`.
* Output from `/glcarb debug`.
