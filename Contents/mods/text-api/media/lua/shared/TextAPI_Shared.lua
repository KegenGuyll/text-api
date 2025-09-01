-- TextAPI (Shared)
-- Minimal public interface and common helpers

if TextAPI == nil then TextAPI = {} end

TextAPI.Version = "0.1.0"

-- Public contract:
-- TextAPI.ShowOverheadText(player, text, opts)
--   player: IsoPlayer or username (server-side)
--   text: string
--   opts: { duration=seconds (default 3), color={r,g,b,a} 0..1, scale=number }
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
  return o
end

-- Networking keys
TextAPI.Net = {
  Show = "TextAPI_ShowOverhead"
}

return TextAPI
