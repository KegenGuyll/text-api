-- TextAPI Test Hotkey (Client)
-- 7  -> screen-centered test
-- 8  -> overhead (local player) test
-- 9  -> both screen-centered and overhead
-- 6  -> STACK burst (3 messages at once) for local player
-- 0  -> QUEUE burst (5 messages, cap trims oldest) for local player

if not TextAPI then TextAPI = {} end

local lastTrigger = 0
local cooldownMs = 300 -- faster iterations

local function triggerScreen()
  print("[TextAPI] 7/9 -> ShowScreenText")
  TextAPI.ShowScreenText("TextAPI draw test", { duration = 3, color = { 1, 1, 0.2, 1 } })
end

local function triggerOverhead()
  local player = getPlayer()
  if not player then return end
  print("[TextAPI] 8/9 -> ShowOverheadText on local player")
  TextAPI.ShowOverheadText(player, "Overhead test", { duration = 3, color = { 0.2, 0.9, 1.0, 1.0 } })
end

local function triggerStackBurst()
  local player = getPlayer()
  if not player then return end
  print("[TextAPI] 6 -> STACK burst (3)")
  local items = {
    { "Stack A", { 1.0, 1.0, 1.0, 1.0 } },
    { "Stack B", { 1.0, 0.6, 0.2, 1.0 } },
    { "Stack C", { 0.2, 0.9, 1.0, 1.0 } },
  }
  for _, it in ipairs(items) do
    TextAPI.ShowOverheadText(player, it[1], { duration = 2.5, behavior = "stack", color = it[2] })
  end
end

local function triggerQueueBurst()
  local player = getPlayer()
  if not player then return end
  print("[TextAPI] 0 -> QUEUE burst (5, cap applies)")
  local items = {
    { "Q1", { 1.0, 1.0, 1.0, 1.0 } },
    { "Q2", { 1.0, 0.85, 0.2, 1.0 } },
    { "Q3", { 0.2, 0.9, 1.0, 1.0 } },
    { "Q4", { 0.8, 0.4, 1.0, 1.0 } },
    { "Q5", { 0.4, 1.0, 0.4, 1.0 } },
  }
  for _, it in ipairs(items) do
    TextAPI.ShowOverheadText(player, it[1], { duration = 1.5, behavior = "queue", color = it[2] })
  end
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

  if key == Keyboard.KEY_6 then
    lastTrigger = now
    triggerStackBurst()
    return
  end

  if key == Keyboard.KEY_0 then
    lastTrigger = now
    triggerQueueBurst()
    return
  end
end

Events.OnKeyPressed.Add(onKeyPressed)
