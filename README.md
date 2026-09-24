# FALLEN / RIFT for Matcha

Matcha Lua script for [Fallen Survival](https://www.roblox.com/games/10228136016/Fallen-Survival).

## Run it

Open `fallen_rift.lua` and paste the complete file into Matcha while in the game, or use this one-line loader for the public GitHub copy:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hidude455/fallen-matcha/main/fallen_rift.lua"))()
```

Use the raw file URL, not a `github.com/.../blob/...` page. The sample `ata-777` URL was only an example; this project is hosted in `hidude455/fallen-matcha`.

Matcha's [classes documentation](https://docs.matchascripts.com/classes) lists `game:HttpGet(url)`; its [HTTP documentation](https://docs.matchascripts.com/docs/http) also lists the equivalent global `httpget(url)`. Its [scripting guide](https://docs.matchascripts.com/writing-scripts) says scripts run inside Matcha's Lua VM. The remote loader needs network access and a publicly readable raw URL. I have syntax-checked the Lua source but have not run it in Matcha or Fallen.

## Project files

- `fallen_rift.lua`: the complete script and raw GitHub entry point.
- `menu-preview.html`: browser mockup of the menu design.
- `README.md`: setup, controls, and feature notes.

## Controls and features

- **Right Shift** opens or hides the compact menu. Left Shift does nothing.
- **End** unloads the script and removes its Drawing objects.
- Player ESP shows boxes, labels, range, health, and optional snaplines.
- Optional aim assist moves the mouse toward the nearest on-screen player inside the FOV circle while right mouse is held and the menu is closed.
- World ESP scans names for nodes, barrels, crates, and plants. **Alt + left click** a visible world marker with the menu hidden to select its object; the selected object gets a projected outline with a soft glow. Matching names can miss objects or include unrelated objects until exact Explorer paths are available.
- Misc includes opt-in local noclip and wall climb. Noclip writes `CanCollide = false` on the local character and restores each original value when switched off or unloaded. Spider climb raises the local root's velocity while holding W against a raycast wall. These movement features depend on Matcha property writes and Fallen's server behavior; they have not been verified in-game.
- Camera FOV and world range sliders are in Misc. Camera FOV is restored on unload.

The script uses Matcha's `Drawing`, `WorldToScreen`, `Players`, `Workspace:Raycast`, and input APIs. The main script does not use `Instance.new`, direct memory writes, or game remotes. The optional one-line loader above fetches that same source file over HTTP. Matcha does not expose a mesh silhouette API here, so the selected-object outline is a projected convex hull of its visible parts. It cannot be verified as undetected; game moderation and Matcha behavior can change.

The menu follows the screenshot you supplied: narrow sidebar, top tabs, dark panel, and violet active state. `menu-preview.html` is a browser mockup of that design; the Lua file builds the real Matcha Drawing menu.

API references: [Matcha UI and scripting](https://docs.matchascripts.com/writing-scripts), [Drawing](https://docs.matchascripts.com/docs/drawing), [classes](https://docs.matchascripts.com/classes), [input](https://docs.matchascripts.com/docs/console).
