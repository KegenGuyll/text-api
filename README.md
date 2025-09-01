# Text API (Project Zomboid)

A lightweight API to display floating text above players' heads. Intended as a shared dependency for your other mods.

## Features
- Client-side drawing of short text above a specific player's head
- Behaviors: queue (one-at-a-time FIFO) and stack (simultaneous with vertical spacing)
- Screen-centered test draw for debugging
- Zoom-stable overhead placement with `headZ` + `pixelOffset`
- Server-to-client command to trigger text in multiplayer
- Global safety cap for pending queue items across all players
- Server `ClearAll` command to wipe all client queues/actives

## Public API

Client:
- `TextAPI.ShowOverheadText(playerObj, text, opts)`
  - `playerObj`: IsoPlayer (local)
  - `text`: string
  - `opts` (all optional):
    - `duration`: number (seconds, default 3)
  - `color`: `{r,g,b,a}` (0..1 or 0..255 for RGB, default `{1,1,1,1}`)
    - `behavior`: `"queue"` (default) | `"stack"`
    - `headZ`: world height offset above ground for anchor (default `0.75`)
    - `pixelOffset`: extra pixels upward after projection (default `8`)
    - `scale`: reserved for future
  - `wrap`: boolean (default `false`) — enable word wrapping
  - `wrapWidthPx`: number (pixels, default `220` if `wrap=true`) — wrapping width
- `TextAPI.ShowScreenText(text, opts)`
  - Draws text centered on the screen (for testing).
- `TextAPI.SetFont(font)`
  - Sets the UIFont used for measuring (wrapping) and generally recommended for drawing consistency.
  - Accepts values from `UIFont` (e.g., `UIFont.Small`, `UIFont.Medium`, `UIFont.Large`).

Server:
- `TextAPI.ServerShowOverheadText(playerOrUsername, text, opts)`
  - `playerOrUsername`: IsoPlayer or username string
- `TextAPI.ClearAll()`
  - Broadcasts a command to clients to clear all active and queued messages.

## Behavior details
- Queue (default):
  - One message per player at a time; next starts when the current expires.
  - Unlimited FIFO per-player queue (items are only removed after being displayed).
- Stack:
  - Messages display simultaneously for a player, with vertical spacing to avoid overlap.

## Usage Examples

Client (queue example):
```lua
local p = getPlayer()
TextAPI.ShowOverheadText(p, "Q1", { duration = 2 })
TextAPI.ShowOverheadText(p, "Q2", { duration = 2 })
TextAPI.ShowOverheadText(p, "Q3", { duration = 2 })
```

Client (stack example):
```lua
local p = getPlayer()
TextAPI.ShowOverheadText(p, "Stack A", { behavior = "stack", color = {1,1,1,1} })
TextAPI.ShowOverheadText(p, "Stack B", { behavior = "stack", color = {1,0.8,0.2,1} })
TextAPI.ShowOverheadText(p, "Stack C", { behavior = "stack", color = {0.2,0.9,1.0,1} })
```

Client (screen-centered test):
```lua
TextAPI.ShowScreenText("TextAPI draw test", { duration = 3 })
```

Client (choose a font):
```lua
-- Set the font used for wrapping measurements (and recommended for consistent visuals)
TextAPI.SetFont(UIFont.Medium)

-- Now draw wrapped overhead text sized according to that font
local p = getPlayer()
TextAPI.ShowOverheadText(p, "Wrapped with Medium font size for consistency.", {
  duration = 3,
  wrap = true,
  wrapWidthPx = 260
})
```

Server:
```lua
-- Show a message to a specific user
TextAPI.ServerShowOverheadText("SomeUsername", "Welcome!", { duration = 5 })

-- Clear all client-side queues and active messages
TextAPI.ClearAll()
```

## Debugging & testing
- Enable debug overlay (shows stack indices and anchor cross):
```lua
TextAPI.SetDebug(true) -- optional second arg to override stack spacing: TextAPI.SetDebug(true, 24)
```
- Test hotkeys are DISABLED by default. Enable them explicitly:
```lua
TextAPI.EnableTestHotkeys(true)   -- enable
-- TextAPI.EnableTestHotkeys(false) -- disable
```
- Available hotkeys (once enabled in this repo's sample):
  - `7`: screen-centered
  - `8`: overhead
  - `9`: both
  - `6`: stack burst (3 at once)
  - `0`: queue burst (sequential)
  - `I`: overhead WRAP demo (local player)

## Global settings
- These are client-side controls you can set early (e.g., on game start) to tune behavior:

```lua
-- Run once on startup (client)
Events.OnGameStart.Add(function()
  -- Fix the font used for wrapping calculations (affects perceived width/line breaks)
  TextAPI.SetFont(UIFont.Medium)

  -- Toggle debug overlay and optionally set stack spacing in pixels
  TextAPI.SetDebug(false)               -- or true
  -- TextAPI.SetDebug(true, 22)         -- enable + custom spacing

  -- Increase the global safety cap for queued items across all players
  TextAPI._globalMaxPending = 1000      -- default is 500

  -- Optionally define default options for all calls (duration, color, behavior, etc.)
  local LimeGreenColor = { 93, 219, 79, 1 }  -- 0..255 color supported; alpha 0..1
  TextAPI.SetDefaults({
    color = LimeGreenColor,
    headZ = 1.5,
    behavior = 'stack',
    wrap = true,
    wrapWidthPx = 300,
    pixelOffset = 20
  })
end)
```

- Notes:
  - `SetFont` influences wrapping measurements; drawing uses the engine’s current default font, so choosing a font here keeps wrap width predictable.
  - `SetDebug(enabled, spacingPx)` overlays indices and a small anchor marker to help tune placement and spacing.
  - `_globalMaxPending` caps only queued (pending) items across all players; active items are not counted.

## Notes
- Overhead positioning anchors at `z + headZ` and then applies a small fixed `pixelOffset` for stability across zoom levels.
- In MP, the server sends a command and the client resolves the target by `onlineID`.
- Global pending cap defaults to 500 across all players; you can adjust `TextAPI._globalMaxPending` on the client if needed.
- Wrapping uses a greedy word-wrap with the current font; explicit \n breaks are preserved.
- Fonts: `TextAPI.SetFont(UIFont.X)` lets you lock the font used for wrapping calculations so your wrapped width and visual size stay predictable. Without setting a font, wrapping assumes a default.
