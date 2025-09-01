-- TextAPI Test Hotkey (Client)
-- NUMPAD7 -> screen-centered test
-- NUMPAD8 -> overhead (local player) test
-- NUMPAD9 -> both screen-centered and overhead

if not TextAPI then TextAPI = {} end

local lastTrigger = 0
local cooldownMs = 300 -- faster iterations

local function triggerScreen()
  print("[TextAPI] NUMPAD7/9 -> ShowScreenText")
  TextAPI.ShowScreenText("TextAPI draw test", { duration = 3, color = { 1, 1, 0.2, 1 } })
end

local function triggerOverhead()
  local player = getPlayer()
  if not player then return end
  print("[TextAPI] NUMPAD8/9 -> ShowOverheadText on local player")
  TextAPI.ShowOverheadText(player, "Overhead test", { duration = 3, color = { 0.2, 0.9, 1.0, 1.0 } })
end

local function onKeyPressed(key)
  local now = getTimestampMs()
  if now - lastTrigger < cooldownMs then return end

  if key == Keyboard.KEY_7 then
    lastTrigger = now
    triggerScreen()
    return
  end

  if key == Keyboard.KEY_8 then
    lastTrigger = now
    triggerOverhead()
    return
  end

  if key == Keyboard.KEY_9 then
    lastTrigger = now
    triggerScreen()
    triggerOverhead()
    return
  end
end

Events.OnKeyPressed.Add(onKeyPressed)
