-- TextAPI (Server)
-- Provides a server-side API to show text over a player's head on clients.

if TextAPI == nil then TextAPI = {} end
local Shared = require "TextAPI_Shared"

-- Public: ServerShowOverheadText(playerOrUsername, text, opts)
-- If passed a username (string), will attempt to resolve to a player
function TextAPI.ServerShowOverheadText(playerOrName, text, opts)
  local ply = playerOrName
  if type(playerOrName) == "string" then
    ply = getPlayerFromUsername and getPlayerFromUsername(playerOrName) or nil
  end
  if ply == nil then return false end
  if not ply.getOnlineID then return false end
  local onlineID = ply:getOnlineID()
  if not onlineID then return false end
  local payload = {
    onlineID = onlineID,
    text = tostring(text or ""),
    opts = Shared._normalizeOpts(opts or {})
  }
  -- Send to the owning client only (overload that accepts player object if available)
  if sendServerCommand and type(sendServerCommand) == "function" then
    local ok
    -- Prefer targeted send if supported by server
    pcall(function()
      sendServerCommand(ply, "TextAPI", Shared.Net.Show, payload)
      ok = true
    end)
    if not ok then
      -- Fallback: broadcast (client will filter by onlineID)
      sendServerCommand("TextAPI", Shared.Net.Show, payload)
    end
  end
  return true
end

-- Clears all active and queued messages on all clients
function TextAPI.ClearAll()
  if sendServerCommand and type(sendServerCommand) == "function" then
    -- Broadcast a ClearAll command; clients will wipe their state
    sendServerCommand("TextAPI", Shared.Net.ClearAll, {})
    return true
  end
  return false
end

return TextAPI
