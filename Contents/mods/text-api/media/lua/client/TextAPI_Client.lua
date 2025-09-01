-- TextAPI (Client)
-- Responsible for rendering text above players' heads and receiving commands

require "ISUI/ISUIElement"

if TextAPI == nil then TextAPI = {} end
local Shared = require "TextAPI_Shared"

TextAPI._active = TextAPI._active or {}

-- Compatibility: In some docs, DrawStringCentre has a UIFont-first overload.
-- This build supports the 8-arg variant (x, y, text, r, g, b, a), which we use here.
local function drawStringCentreCompat(sx, sy, text, r, g, b, a)
  getTextManager():DrawStringCentre(sx, sy, text, r, g, b, a)
end

-- Internal: add a text bubble entry
local function addTextForPlayer(playerObj, text, opts)
  local o = Shared._normalizeOpts(opts)
  local entry = {
    player = playerObj,
    text = tostring(text or ""),
    color = o.color,
    scale = o.scale,
    headZ = o.headZ,
    pixelOffset = o.pixelOffset,
    expireAt = getTimestampMs() + (o.duration * 1000)
  }
  table.insert(TextAPI._active, entry)
end

-- Internal: add a screen-centered text entry
local function addScreenText(text, opts)
  local o = Shared._normalizeOpts(opts)
  local entry = {
    player = nil,
    text = tostring(text or ""),
    color = o.color,
    scale = o.scale,
    screenCenter = true,
    expireAt = getTimestampMs() + (o.duration * 1000)
  }
  table.insert(TextAPI._active, entry)
end

-- Network receive (MP):
local function onReceiveShowText(args)
  -- args: { onlineID=number, text=string, opts=table }
  if not args then return end
  local playerObj = getPlayerByOnlineID and getPlayerByOnlineID(args.onlineID) or nil
  if not playerObj then return end
  addTextForPlayer(playerObj, args.text or "", args.opts or {})
end

-- Public API (client-only direct):
function TextAPI.ShowOverheadText(playerObj, text, opts)
  if not playerObj or not instanceof(playerObj, 'IsoPlayer') then return false end
  addTextForPlayer(playerObj, text, opts)
  return true
end

-- Public API (client-only): draw at screen center (for testing)
function TextAPI.ShowScreenText(text, opts)
  addScreenText(text, opts)
  return true
end

-- Renderer: draw above head during player render
local function renderText(entry)
  if getTimestampMs() > entry.expireAt then return false end

  -- If screen-centered debug entry, draw in the middle of the screen
  if entry.screenCenter then
    local sw = getCore() and getCore():getScreenWidth() or 1920
    local sh = getCore() and getCore():getScreenHeight() or 1080
    local sx = math.floor(sw / 2)
    local sy = math.floor(sh / 2)
    local r, g, b, a = entry.color[1], entry.color[2], entry.color[3], entry.color[4]
    a = a or 1
    drawStringCentreCompat(sx + 1, sy + 1, entry.text, 0, 0, 0, a)
    drawStringCentreCompat(sx, sy, entry.text, r, g, b, a)
    return true
  end

  local chr = entry.player
  if not chr or chr:isDead() then return false end

  -- World to screen (account for camera & split-screen offsets)
  local x = chr:getX()
  local y = chr:getY()
  local z = chr:getZ()
  local pn = (chr.getPlayerNum and chr:getPlayerNum()) or 0
  -- Project a point slightly above the character's head in world space
  local sx = IsoUtils.XToScreen(x, y, z + (entry.headZ or 0.85), 0) - IsoCamera.getOffX() - getPlayerScreenLeft(pn)
  local sy = IsoUtils.YToScreen(x, y, z + (entry.headZ or 0.85), 0) - IsoCamera.getOffY() - getPlayerScreenTop(pn)

  -- Apply a small constant pixel offset upwards after projection to counter zoom drift
  sy = sy - (entry.pixelOffset or 14)

  -- Visibility bounds check
  local sw = getCore() and getCore():getScreenWidth() or 1920
  local sh = getCore() and getCore():getScreenHeight() or 1080
  if sx < -200 or sx > sw + 200 or sy < -100 or sy > sh + 100 then
    return true
  end

  local r, g, b, a = entry.color[1], entry.color[2], entry.color[3], entry.color[4]
  a = a or 1

  -- Draw a small shadow first for readability
  drawStringCentreCompat(sx + 1, sy + 1, entry.text, 0, 0, 0, a)
  drawStringCentreCompat(sx, sy, entry.text, r, g, b, a)
  return true
end

-- Hook: render each frame
local function onPostRender()
  if not TextAPI._active or #TextAPI._active == 0 then return end
  local now = getTimestampMs()
  local keep = {}
  for _, entry in ipairs(TextAPI._active) do
    if now <= entry.expireAt and (entry.screenCenter or (entry.player and not entry.player:isDead())) then
      renderText(entry)
      table.insert(keep, entry)
    end
  end
  TextAPI._active = keep
end

-- Events
Events.OnPostRender.Add(onPostRender)

-- MP wiring
if isClient() then
  Events.OnServerCommand.Add(function(module, command, args)
    if module == "TextAPI" and command == Shared.Net.Show then
      onReceiveShowText(args)
    end
  end)
end

return TextAPI
