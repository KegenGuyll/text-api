-- TextAPI (Shared)
-- Minimal public interface and common helpers

if TextAPI == nil then TextAPI = {} end

TextAPI.Version = "0.1.0"

-- Global defaults (client can override via TextAPI.SetDefaults)
TextAPI.Defaults = TextAPI.Defaults or {
  duration = 3,
  color = { 1, 1, 1, 1 },
  scale = 1.0,
  headZ = 0.75,
  pixelOffset = 8,
  behavior = "queue",
  wrap = false,
  wrapWidthPx = 220,
}

-- Public contract:
-- TextAPI.ShowOverheadText(player, text, opts)
--   player: IsoPlayer or username (server-side)
--   text: string
--   opts: {
--     duration=seconds (default 3),
--     color={r,g,b,a} 0..1,
--     scale=number,
--     headZ=number (default 0.75),
--     pixelOffset=number (default 8),
--     behavior="queue"|"stack" (default "queue")
--     wrap=true|false (default false),
--     wrapWidthPx=number (pixels; default 220 when wrap=true)
--   }
-- Returns: boolean success

local function clamp01(x) return math.max(0, math.min(1, x)) end

local function normalizeColor(c)
  -- Accept 0..1 or 0..255; detect by max component
  local r = tonumber(c[1]) or 1
  local g = tonumber(c[2]) or 1
  local b = tonumber(c[3]) or 1
  local a = tonumber(c[4]) or 1
  if r > 1 or g > 1 or b > 1 or a > 1 then
    r = r / 255; g = g / 255; b = b / 255; -- a is commonly 0..1; if 255 assume fully opaque
    if a > 1 then a = a / 255 end
  end
  return { clamp01(r), clamp01(g), clamp01(b), clamp01(a) }
end

---@alias TextAPI_Behavior '"queue"'|'"stack"'
---@alias TextAPI_ColorRGBA { [1]: number, [2]: number, [3]: number, [4]: number }

---Unnormalized user options for ShowOverheadText
---@class TextAPI_OverheadOpts
---@field duration? number        -- seconds; default 3
---@field color? TextAPI_ColorRGBA -- 0..1 each; default {1,1,1,1}
---@field scale? number           -- default 1.0
---@field headZ? number           -- world Z; default 0.75
---@field pixelOffset? number     -- pixels; default 8
---@field behavior? TextAPI_Behavior -- "queue" or "stack"; default "queue"
---@field wrap? boolean           -- default false
---@field wrapWidthPx? number     -- used only when wrap=true; default 220 (client-side)

---Normalized options after defaults/clamping
---@class TextAPI_NormalizedOpts
---@field duration number
---@field color TextAPI_ColorRGBA
---@field scale number
---@field headZ number
---@field pixelOffset number
---@field behavior TextAPI_Behavior
---@field wrap boolean
---@field wrapWidthPx number|nil

---@param opts? TextAPI_OverheadOpts
---@return TextAPI_NormalizedOpts
function TextAPI._normalizeOpts(opts)
  opts = opts or {}
  local d = TextAPI.Defaults or {}
  local o = {}
  o.duration = tonumber(opts.duration) or d.duration or 3
  local c = opts.color or d.color or { 1, 1, 1, 1 }
  o.color = normalizeColor(c)
  o.scale = tonumber(opts.scale) or d.scale or 1.0
  -- Height above ground to anchor the text (world Z units); ~0.75 is near head height
  o.headZ = tonumber(opts.headZ) or d.headZ or 0.75
  -- Extra pixel offset upwards after projection
  o.pixelOffset = tonumber(opts.pixelOffset) or d.pixelOffset or 8
  -- Queue behavior: one-at-a-time (queue) or simultaneous (stack)
  local b = tostring(opts.behavior or d.behavior or "queue"):lower()
  o.behavior = (b == "stack") and "stack" or "queue"
  -- Wrapping
  o.wrap = (opts.wrap == true) or (d.wrap == true)
  o.wrapWidthPx = tonumber(opts.wrapWidthPx)
  if o.wrap and (o.wrapWidthPx == nil) then
    o.wrapWidthPx = (d and d.wrapWidthPx) or 220
  end
  return o
end

---Update global defaults used by _normalizeOpts. Supply only the fields you want to change.
---@param newDefaults TextAPI_OverheadOpts
function TextAPI.SetDefaults(newDefaults)
  if not newDefaults then return end
  local d = TextAPI.Defaults or {}
  if newDefaults.duration ~= nil then d.duration = tonumber(newDefaults.duration) or d.duration or 3 end
  if newDefaults.color ~= nil then d.color = normalizeColor(newDefaults.color) end
  if newDefaults.scale ~= nil then d.scale = tonumber(newDefaults.scale) or d.scale or 1.0 end
  if newDefaults.headZ ~= nil then d.headZ = tonumber(newDefaults.headZ) or d.headZ or 0.75 end
  if newDefaults.pixelOffset ~= nil then d.pixelOffset = tonumber(newDefaults.pixelOffset) or d.pixelOffset or 8 end
  if newDefaults.behavior ~= nil then
    local b = tostring(newDefaults.behavior):lower()
    d.behavior = (b == "stack") and "stack" or "queue"
  end
  if newDefaults.wrap ~= nil then d.wrap = (newDefaults.wrap == true) end
  if newDefaults.wrapWidthPx ~= nil then d.wrapWidthPx = tonumber(newDefaults.wrapWidthPx) or d.wrapWidthPx or 220 end
  TextAPI.Defaults = d
end

-- Networking keys
TextAPI.Net = {
  Show = "TextAPI_ShowOverhead",
  ClearAll = "TextAPI_ClearAll"
}

return TextAPI
