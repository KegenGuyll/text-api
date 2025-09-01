-- TextAPI (Shared)
-- Minimal public interface and common helpers

if TextAPI == nil then TextAPI = {} end

TextAPI.Version = "0.1.0"

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

function TextAPI._normalizeOpts(opts)
  opts = opts or {}
  local o = {}
  o.duration = tonumber(opts.duration) or 3
  local c = opts.color or { 1, 1, 1, 1 }
  o.color = { clamp01(tonumber(c[1]) or 1), clamp01(tonumber(c[2]) or 1), clamp01(tonumber(c[3]) or 1), clamp01(tonumber(
    c[4]) or 1) }
  o.scale = tonumber(opts.scale) or 1.0
  -- Height above ground to anchor the text (world Z units); ~0.75 is near head height
  o.headZ = tonumber(opts.headZ) or 0.75
  -- Extra pixel offset upwards after projection
  o.pixelOffset = tonumber(opts.pixelOffset) or 8
  -- Queue behavior: one-at-a-time (queue) or simultaneous (stack)
  local b = tostring(opts.behavior or "queue"):lower()
  o.behavior = (b == "stack") and "stack" or "queue"
  -- Wrapping
  o.wrap = (opts.wrap == true)
  o.wrapWidthPx = tonumber(opts.wrapWidthPx)
  return o
end

-- Networking keys
TextAPI.Net = {
  Show = "TextAPI_ShowOverhead",
  ClearAll = "TextAPI_ClearAll"
}

return TextAPI
