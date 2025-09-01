-- TextAPI (Client Helpers)
-- Utilities for measuring, wrapping, and drawing centered text

local M = {}

-- Draw text centered at screen coordinates
function M.drawStringCentreCompat(sx, sy, text, r, g, b, a)
  getTextManager():DrawStringCentre(sx, sy, text, r, g, b, a)
end

-- Measure string width in pixels using the chosen font (defaults to Medium)
function M.measureWidthPx(text)
  local tm = getTextManager()
  if not tm or not tm.MeasureStringX or not UIFont then
    return (text and #tostring(text) or 0) * 7
  end
  local font = (TextAPI and TextAPI._font) or (UIFont and UIFont.Medium) or nil
  return tm:MeasureStringX(font, tostring(text or ""))
end

-- Get line height in pixels (matching the chosen font)
function M.lineHeightPx()
  local tm = getTextManager()
  if tm and tm.getFontHeight and UIFont then
    local font = (TextAPI and TextAPI._font) or (UIFont and UIFont.Medium) or nil
    return tm:getFontHeight(font)
  end
  return 18
end

-- Greedy word-wrap preserving explicit newlines
function M.wrapTextWords(text, maxWidth)
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
          if M.measureWidthPx(try) <= maxWidth then
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

return M
