-- TextAPI (Client)
-- Responsible for rendering text above players' heads and receiving commands

require "ISUI/ISUIElement"

if TextAPI == nil then TextAPI = {} end
local Shared = require "TextAPI_Shared"

TextAPI._active = TextAPI._active or {}
TextAPI._queues = TextAPI._queues or {}
TextAPI._maxPerPlayer = TextAPI._maxPerPlayer or 3 -- cap queued items per player
TextAPI._debug = TextAPI._debug or { enabled = false, stackSpacingOverride = nil, logGroups = false }

function TextAPI.SetDebug(enabled, stackSpacing)
  TextAPI._debug.enabled = not not enabled
  if stackSpacing ~= nil then
    TextAPI._debug.stackSpacingOverride = tonumber(stackSpacing)
  end
end

-- Compatibility: In some docs, DrawStringCentre has a UIFont-first overload.
-- This build supports the 8-arg variant (x, y, text, r, g, b, a), which we use here.
local function drawStringCentreCompat(sx, sy, text, r, g, b, a)
  getTextManager():DrawStringCentre(sx, sy, text, r, g, b, a)
end

local function makeEntry(playerObjOrNil, text, o)
  return {
    player = playerObjOrNil,
    text = tostring(text or ""),
    color = o.color,
    scale = o.scale,
    headZ = o.headZ,
    pixelOffset = o.pixelOffset,
    behavior = o.behavior,
    createdAt = getTimestampMs(),
    expireAt = getTimestampMs() + (o.duration * 1000)
  }
end

-- Internal: add a text bubble entry immediately (active list)
local function addActiveEntry(entry)
  table.insert(TextAPI._active, entry)
end

-- Queue management: per-player key
local function getPlayerKey(ply)
  if not ply then return "__screen__" end
  if ply.getOnlineID then
    local id = ply:getOnlineID()
    if id then return "online:" .. tostring(id) end
  end
  if ply.getUsername then
    return "user:" .. tostring(ply:getUsername())
  end
  return tostring(ply)
end

local function enqueueForPlayer(ply, text, opts)
  local o = Shared._normalizeOpts(opts)
  local key = getPlayerKey(ply)
  TextAPI._queues[key] = TextAPI._queues[key] or { active = false, items = {} }
  local q = TextAPI._queues[key]

  -- Enforce per-player cap
  if #q.items >= TextAPI._maxPerPlayer then
    -- drop oldest
    table.remove(q.items, 1)
  end

  table.insert(q.items, { text = text, opts = o })

  if o.behavior == "stack" then
    addActiveEntry(makeEntry(ply, text, o))
    return
  end

  if not q.active then
    q.active = true
    addActiveEntry(makeEntry(ply, text, o))
  end
end

-- Internal: add a screen-centered text entry
local function addScreenText(text, opts)
  local o = Shared._normalizeOpts(opts)
  local entry = makeEntry(nil, text, o)
  entry.screenCenter = true
  addActiveEntry(entry)
end

-- Network receive (MP):
local function onReceiveShowText(args)
  if not args then return end
  local playerObj = getPlayerByOnlineID and getPlayerByOnlineID(args.onlineID) or nil
  if not playerObj then return end
  enqueueForPlayer(playerObj, args.text or "", args.opts or {})
end

-- Public API (client-only direct):
function TextAPI.ShowOverheadText(playerObj, text, opts)
  if not playerObj or not instanceof(playerObj, 'IsoPlayer') then return false end
  enqueueForPlayer(playerObj, text, opts)
  return true
end

-- Public API (client-only): draw at screen center (for testing)
function TextAPI.ShowScreenText(text, opts)
  addScreenText(text, opts)
  return true
end

-- Renderer: draw entries (either screen-center or above head)
local function renderText(entry, stackIndex, stackCount)
  if getTimestampMs() > entry.expireAt then return false end

  -- Screen center path
  if entry.screenCenter then
    local sw = getCore() and getCore():getScreenWidth() or 1920
    local sh = getCore() and getCore():getScreenHeight() or 1080
    local sx = math.floor(sw / 2)
    local sy = math.floor(sh / 2)
    local r, g, b, a = entry.color[1], entry.color[2], entry.color[3], entry.color[4]
    a = a or 1
    local textToDraw = entry.text
    if TextAPI._debug.enabled and stackIndex then
      textToDraw = textToDraw .. " (" .. tostring(stackIndex) .. "/" .. tostring(stackCount or "?") .. ")"
    end
    drawStringCentreCompat(sx + 1, sy + 1, textToDraw, 0, 0, 0, a)
    drawStringCentreCompat(sx, sy, textToDraw, r, g, b, a)
    return true
  end

  local chr = entry.player
  if not chr or chr:isDead() then return false end

  -- World to screen (account for camera & split-screen offsets)
  local x = chr:getX()
  local y = chr:getY()
  local z = chr:getZ()
  local pn = (chr.getPlayerNum and chr:getPlayerNum()) or 0
  local sx = IsoUtils.XToScreen(x, y, z + (entry.headZ or 0.85), 0) - IsoCamera.getOffX() - getPlayerScreenLeft(pn)
  local sy = IsoUtils.YToScreen(x, y, z + (entry.headZ or 0.85), 0) - IsoCamera.getOffY() - getPlayerScreenTop(pn)

  sy = sy - (entry.pixelOffset or 14)

  -- Apply stacking offset if multiple entries are shown for the same player
  if stackCount and stackCount > 1 and stackIndex and stackIndex > 0 then
    local spacing = (TextAPI._debug and TextAPI._debug.stackSpacingOverride) or 14 -- pixels between stacked lines
    sy = sy - spacing * (stackIndex - 1)
  end

  local sw = getCore() and getCore():getScreenWidth() or 1920
  local sh = getCore() and getCore():getScreenHeight() or 1080
  if sx < -200 or sx > sw + 200 or sy < -100 or sy > sh + 100 then
    return true
  end

  local r, g, b, a = entry.color[1], entry.color[2], entry.color[3], entry.color[4]
  a = a or 1

  local textToDraw = entry.text
  if TextAPI._debug.enabled and stackIndex then
    textToDraw = textToDraw .. " (" .. tostring(stackIndex) .. "/" .. tostring(stackCount or "?") .. ")"
  end

  -- Debug cross marker at anchor
  if TextAPI._debug.enabled then
    drawStringCentreCompat(sx, sy, "+", 1, 0, 0, 1)
  end

  drawStringCentreCompat(sx + 1, sy + 1, textToDraw, 0, 0, 0, a)
  drawStringCentreCompat(sx, sy, textToDraw, r, g, b, a)
  return true
end

-- When entries expire, advance queues for queued behavior
local function onUpdate()
  if not TextAPI._active or #TextAPI._active == 0 then return end
  local now = getTimestampMs()
  local keep = {}

  for _, entry in ipairs(TextAPI._active) do
    if now <= entry.expireAt and (entry.screenCenter or (entry.player and not entry.player:isDead())) then
      table.insert(keep, entry)
    else
      if entry.player and entry.behavior ~= "stack" then
        local key = getPlayerKey(entry.player)
        local q = TextAPI._queues[key]
        if q and q.items and #q.items > 0 then
          table.remove(q.items, 1)
          local nextItem = q.items[1]
          if nextItem then
            table.insert(keep, makeEntry(entry.player, nextItem.text, nextItem.opts))
            q.active = true
          else
            q.active = false
          end
        elseif q then
          q.active = false
        end
      end
    end
  end

  TextAPI._active = keep
end

-- Events
Events.OnPostRender.Add(function()
  if not TextAPI._active or #TextAPI._active == 0 then return end

  -- Group stacked entries by player key; render others normally
  local groups = {}
  local singles = {}
  for _, entry in ipairs(TextAPI._active) do
    if entry.screenCenter or entry.behavior ~= "stack" or not entry.player then
      table.insert(singles, entry)
    else
      local key = getPlayerKey(entry.player)
      groups[key] = groups[key] or {}
      table.insert(groups[key], entry)
    end
  end

  if TextAPI._debug.enabled and TextAPI._debug.logGroups then
    for k, arr in pairs(groups) do
      print("[TextAPI][stack] key=" .. tostring(k) .. " count=" .. tostring(#arr))
    end
  end

  -- Render non-stacked entries
  for _, entry in ipairs(singles) do
    renderText(entry)
  end

  -- Render stacked entries with vertical spacing
  for _, arr in pairs(groups) do
    -- Optional: stable order by createdAt for readability
    table.sort(arr, function(a, b) return (a.createdAt or 0) < (b.createdAt or 0) end)
    for i, entry in ipairs(arr) do
      renderText(entry, i, #arr)
    end
  end
end)

Events.OnTick.Add(onUpdate)

-- MP wiring
if isClient() then
  Events.OnServerCommand.Add(function(module, command, args)
    if module == "TextAPI" and command == Shared.Net.Show then
      onReceiveShowText(args)
    end
  end)
end

return TextAPI
