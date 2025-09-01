# Text API (Project Zomboid)

A lightweight API to display floating text above players' heads. Intended as a shared dependency for your other mods.

## Features
- Client-side drawing of short text above a specific player's head
- Server-to-client command to trigger text in multiplayer
- Simple API surface with duration and color options

## Public API

Shared (client-only immediate draw):
- `TextAPI.ShowOverheadText(playerObj, text, opts)`
  - `playerObj`: IsoPlayer (local)
  - `text`: string
  - `opts`: table `{ duration=3, color={r,g,b,a}, scale=1 }`

Server:
- `TextAPI.ServerShowOverheadText(playerOrUsername, text, opts)`
  - `playerOrUsername`: IsoPlayer or username string

## Usage Examples

Client (e.g., from another client mod file):
```lua
local player = getPlayer() -- local player
TextAPI.ShowOverheadText(player, "Hello there!", { duration = 3, color = {1,0.8,0.2,1} })
```

Server (from another server mod file):
```lua
TextAPI.ServerShowOverheadText("SomeUsername", "Welcome!", { duration = 5 })
```

## Notes
- Drawing uses TextManager's world-to-screen to center text. Adjust the vertical offset in `TextAPI_Client.lua` if needed.
- In MP, the server sends a command; the client resolves the target by `onlineID`.
- This is an early version; API surface may change.
