-- TextAPI (Client)
-- Responsible for rendering text above players' heads and receiving commands

require "ISUI/ISUIElement"

if TextAPI == nil then TextAPI = {} end
local Shared = require "TextAPI_Shared"

TextAPI._active = TextAPI._active or {}
TextAPI._queues = TextAPI._queues or {}
TextAPI._globalMaxPending = TextAPI._globalMaxPending or 500 -- safety cap across all players (pending only)
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

-- Helpers for measuring and wrapping text
local function measureWidthPx(text)
  local tm = getTextManager()
  -- Fallback: assume average char width ~7 if no API
  if not tm or not tm.MeasureStringX or not UIFont then
    return (text and #tostring(text) or 0) * 7
  end
  return tm:MeasureStringX(UIFont.Medium, tostring(text or ""))
end

local function lineHeightPx()
  local tm = getTextManager()
  if tm and tm.getFontHeight and UIFont then
    return tm:getFontHeight(UIFont.Medium)
  end
  -- Fallback reasonable default
  return 18
end

local function wrapTextWords(text, maxWidth)
  -- Simple greedy word wrap. Preserves explicit \n breaks.
  local lines = {}
  if not text or text == "" then return lines end
  maxWidth = tonumber(maxWidth) or 220

  local s = tostring(text)
  local start = 1
  while true do
    local ni, nj = string.find(s, "\n", start, true)
    local paragraph
    if ni then
      paragraph = string.sub(s, start, ni - 1)
      start = nj + 1
    else
      paragraph = string.sub(s, start)
    end

    if paragraph == nil then break end
    if paragraph == "" then
      table.insert(lines, "")
    else
      local words = {}
      for w in paragraph:gmatch("%S+") do table.insert(words, w) end
      if #words == 0 then
        table.insert(lines, "")
      else
        local current = ""
        for i = 1, #words do
          local w = words[i]
          local try = (current == "") and w or (current .. " " .. w)
          if measureWidthPx(try) <= maxWidth then
            current = try
          else
            if current ~= "" then table.insert(lines, current) end
            current = w
          end
        end
        if current ~= "" then table.insert(lines, current) end
      end
    end

    if not ni then break end
  end

  return lines
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
    wrap = o.wrap,
    wrapWidthPx = o.wrapWidthPx,
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
  TextAPI._queues[key] = TextAPI._queues[key] or { current = nil, pending = {} }
  local q = TextAPI._queues[key]

  -- Stack: show immediately, do not interact with queue
  if o.behavior == "stack" then
    addActiveEntry(makeEntry(ply, text, o))
    return
  end

  -- Queue: if no current, start now; else append to pending (cap applies to pending only)
  if not q.current then
    local entry = makeEntry(ply, text, o)
    q.current = entry
    addActiveEntry(entry)
  else
    -- Unlimited FIFO per player; but enforce a global safety cap
    -- Count total pending across all players
    local totalPending = 0
    for _, v in pairs(TextAPI._queues) do
      if v.pending then totalPending = totalPending + #v.pending end
    end
    if totalPending >= (TextAPI._globalMaxPending or 500) then
      -- reject newest to avoid unbounded growth
      if TextAPI._debug.enabled then
        print("[TextAPI][queue] global cap reached; dropping new pending item")
      end
    else
      table.insert(q.pending, { text = text, opts = o })
    end
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
local function renderText(entry, stackIndex, stackCount, extraStackPx)
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
    -- Screen-center rendering supports wrapping too
    local lines
    if entry.wrap then
      local maxW = entry.wrapWidthPx or 220
      lines = wrapTextWords(textToDraw, maxW)
    end
    local lh = lineHeightPx()
    if lines and #lines > 1 then
      local totalH = (#lines - 1) * lh
      for i, ln in ipairs(lines) do
        local ly = sy - totalH / 2 + (i - 1) * lh
        drawStringCentreCompat(sx + 1, ly + 1, ln, 0, 0, 0, a)
        drawStringCentreCompat(sx, ly, ln, r, g, b, a)
      end
    else
      drawStringCentreCompat(sx + 1, sy + 1, textToDraw, 0, 0, 0, a)
      drawStringCentreCompat(sx, sy, textToDraw, r, g, b, a)
    end
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
    -- Base spacing uses font height; allow override via debug
    local base = lineHeightPx()
    local spacing = (TextAPI._debug and TextAPI._debug.stackSpacingOverride) or base
    sy = sy - spacing * (stackIndex - 1) - (extraStackPx or 0)
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

  -- Multiline render when wrapped
  local lines
  if entry.wrap then
    local maxW = entry.wrapWidthPx or 220
    lines = wrapTextWords(textToDraw, maxW)
  end
  local lh = lineHeightPx()
  if lines and #lines > 1 then
    -- Align block so the first line sits at the anchor (sy) and subsequent lines go upward
    for i, ln in ipairs(lines) do
      local ly = sy - (i - 1) * lh
      drawStringCentreCompat(sx + 1, ly + 1, ln, 0, 0, 0, a)
      drawStringCentreCompat(sx, ly, ln, r, g, b, a)
    end
  else
    drawStringCentreCompat(sx + 1, sy + 1, textToDraw, 0, 0, 0, a)
    drawStringCentreCompat(sx, sy, textToDraw, r, g, b, a)
  end
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
      -- Expired entry
      if entry.player and entry.behavior ~= "stack" then
        local key = getPlayerKey(entry.player)
        local q = TextAPI._queues[key]
        if q then
          -- Clear current if it matches this entry
          if q.current == entry then q.current = nil end
          -- Start next pending if available
          if q.pending and #q.pending > 0 then
            local nextItem = table.remove(q.pending, 1)
            local nextEntry = makeEntry(entry.player, nextItem.text, nextItem.opts)
            q.current = nextEntry
            table.insert(keep, nextEntry)
          end
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
    -- Compute cumulative offset to account for wrapped multiline entries above
    local lh = lineHeightPx()
    local cumulativePx = 0
    for i, entry in ipairs(arr) do
      renderText(entry, i, #arr, cumulativePx)
      -- Estimate how many extra lines this entry used if wrapping enabled
      if entry.wrap then
        local lines = wrapTextWords(entry.text, entry.wrapWidthPx or 220)
        if lines and #lines > 1 then
          cumulativePx = cumulativePx + ((#lines - 1) * lh)
        end
      end
    end
  end
end)

Events.OnTick.Add(onUpdate)

-- MP wiring
if isClient() then
  Events.OnServerCommand.Add(function(module, command, args)
    if module == "TextAPI" and command == Shared.Net.Show then
      onReceiveShowText(args)
    elseif module == "TextAPI" and command == Shared.Net.ClearAll then
      -- Clear actives and queues
      TextAPI._active = {}
      TextAPI._queues = {}
    end
  end)
end

return TextAPI
