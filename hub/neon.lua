-- hub/neon.lua
-- Neon art style renderer for the space station hub
-- Inspired by the Coruscant speeder chase scene in Star Wars: Attack of the Clones
-- with lots of neon signage, glowing edges, and atmospheric lighting

local M = {}

-- Draw a neon-outlined rectangle with glow
function M.drawNeonRect(x, y, w, h, r, g, b, alpha, glowLayers)
  alpha = alpha or 1.0
  glowLayers = glowLayers or 3

  -- Outer glow layers
  for i = glowLayers, 1, -1 do
    local expand = i * 3
    local glowAlpha = (alpha * 0.12) / i
    love.graphics.setColor(r, g, b, glowAlpha)
    love.graphics.rectangle("fill", x - expand, y - expand, w + expand*2, h + expand*2, 4)
  end

  -- Core neon line
  love.graphics.setColor(r, g, b, alpha * 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 2)
  love.graphics.setLineWidth(1)
end

-- Draw a neon line with glow
function M.drawNeonLine(x1, y1, x2, y2, r, g, b, alpha, thickness)
  alpha = alpha or 1.0
  thickness = thickness or 2

  -- Glow
  for i = 3, 1, -1 do
    local glowAlpha = (alpha * 0.15) / i
    love.graphics.setColor(r, g, b, glowAlpha)
    love.graphics.setLineWidth(thickness + i * 4)
    love.graphics.line(x1, y1, x2, y2)
  end

  -- Core
  love.graphics.setColor(r, g, b, alpha)
  love.graphics.setLineWidth(thickness)
  love.graphics.line(x1, y1, x2, y2)
  love.graphics.setLineWidth(1)
end

-- Draw neon text with glow
function M.drawNeonText(text, x, y, font, r, g, b, alpha, align, width)
  alpha = alpha or 1.0
  align = align or "left"
  width = width or 400

  love.graphics.setFont(font)

  -- Glow layers
  for i = 3, 1, -1 do
    local glowAlpha = (alpha * 0.15) / i
    love.graphics.setColor(r, g, b, glowAlpha)
    for dx = -i, i do
      for dy = -i, i do
        if dx ~= 0 or dy ~= 0 then
          love.graphics.printf(text, x + dx, y + dy, width, align)
        end
      end
    end
  end

  -- Core text
  love.graphics.setColor(r, g, b, alpha)
  love.graphics.printf(text, x, y, width, align)
end

-- Draw a neon circle with glow
function M.drawNeonCircle(cx, cy, radius, r, g, b, alpha, segments)
  alpha = alpha or 1.0
  segments = segments or 32

  for i = 3, 1, -1 do
    local glowAlpha = (alpha * 0.12) / i
    love.graphics.setColor(r, g, b, glowAlpha)
    love.graphics.setLineWidth(2 + i * 3)
    love.graphics.circle("line", cx, cy, radius, segments)
  end

  love.graphics.setColor(r, g, b, alpha)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", cx, cy, radius, segments)
  love.graphics.setLineWidth(1)
end

-- Draw a neon sign (rectangle with text inside)
function M.drawNeonSign(text, x, y, w, h, font, r, g, b, time)
  time = time or 0
  local flicker = 0.85 + 0.15 * math.sin(time * 3 + x * 0.1)

  -- Sign background
  love.graphics.setColor(r * 0.1, g * 0.1, b * 0.1, 0.8)
  love.graphics.rectangle("fill", x, y, w, h, 3)

  -- Neon border
  M.drawNeonRect(x, y, w, h, r, g, b, flicker)

  -- Neon text
  love.graphics.setFont(font)
  local textY = y + h/2 - font:getHeight()/2
  M.drawNeonText(text, x, textY, font, r, g, b, flicker, "center", w)
end

-- Draw a building with Coruscant-style neon architecture
function M.drawNeonBuilding(b, gs, time)
  local bx, by = b.x * gs, b.y * gs
  local bw, bh = b.w * gs, b.h * gs
  local nr, ng, nb = b.neonColor[1], b.neonColor[2], b.neonColor[3]
  local br, bg, bb = b.color[1], b.color[2], b.color[3]
  local flicker = 0.8 + 0.2 * math.sin(time * 2.5 + b.x * 0.3)

  -- Building body (dark with slight color tint)
  love.graphics.setColor(br * 0.4, bg * 0.4, bb * 0.4, 0.95)
  love.graphics.rectangle("fill", bx, by, bw, bh, 2)

  -- Window grid on building face
  local windowRows = math.max(1, math.floor(b.h - 2))
  local windowCols = math.max(1, math.floor(b.w - 2))
  for wy = 0, windowRows - 1 do
    for wx = 0, windowCols - 1 do
      local winX = bx + gs + wx * (bw - gs*2) / windowCols
      local winY = by + gs * 0.5 + wy * (bh - gs*1.5) / windowRows
      local winW = (bw - gs*2) / windowCols - 4
      local winH = (bh - gs*1.5) / windowRows - 4
      -- Window glow
      local windowAlpha = 0.15 + 0.1 * math.sin(time * 1.5 + wx * 0.7 + wy * 1.3)
      love.graphics.setColor(nr, ng, nb, windowAlpha)
      love.graphics.rectangle("fill", winX, winY, winW, winH)
    end
  end

  -- Neon border outline
  M.drawNeonRect(bx, by, bw, bh, nr, ng, nb, flicker * 0.7, 2)

  -- Horizontal neon accent lines
  M.drawNeonLine(bx, by + bh * 0.3, bx + bw, by + bh * 0.3, nr, ng, nb, flicker * 0.3, 1)
  M.drawNeonLine(bx, by + bh * 0.7, bx + bw, by + bh * 0.7, nr, ng, nb, flicker * 0.3, 1)

  -- Door (glowing portal)
  local doorX = b.doorX * gs
  local doorY = b.doorY * gs
  -- Door glow
  for i = 3, 1, -1 do
    love.graphics.setColor(nr, ng, nb, 0.1 * flicker / i)
    love.graphics.rectangle("fill", doorX - i*4, doorY - i*2, gs + i*8, gs + i*4, 2)
  end
  love.graphics.setColor(nr * 0.3, ng * 0.3, nb * 0.3, 0.8)
  love.graphics.rectangle("fill", doorX, doorY, gs, gs, 2)
  love.graphics.setColor(nr, ng, nb, flicker * 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", doorX, doorY, gs, gs, 2)
  love.graphics.setLineWidth(1)

  -- Building name sign (above building)
  local nameFont = love.graphics.getFont()
  local nameW = nameFont:getWidth(b.name) + 20
  local nameH = 22
  local nameX = bx + bw/2 - nameW/2
  local nameY = by - nameH - 6
  M.drawNeonSign(b.name, nameX, nameY, nameW, nameH, nameFont, nr, ng, nb, time)
end

-- Draw floor tile pattern (space station plating)
function M.drawFloorTiles(width, height, gs, colorScheme, time)
  local bgr, bgg, bgb = colorScheme.bg[1], colorScheme.bg[2], colorScheme.bg[3]
  local nr, ng, nb = colorScheme.neon[1], colorScheme.neon[2], colorScheme.neon[3]

  -- Base floor
  love.graphics.setColor(bgr, bgg, bgb)
  love.graphics.rectangle("fill", 0, 0, width * gs, height * gs)

  -- Metal plating grid
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      -- Subtle tile borders
      local tileShade = 0.03 + 0.01 * ((x + y) % 2)
      love.graphics.setColor(bgr + tileShade, bgg + tileShade, bgb + tileShade)
      love.graphics.rectangle("fill", x * gs + 1, y * gs + 1, gs - 2, gs - 2)
    end
  end

  -- Ambient neon floor strips (Coruscant-style running lights)
  for y = 0, height - 1, 4 do
    local stripAlpha = 0.04 + 0.02 * math.sin(time * 0.8 + y * 0.5)
    love.graphics.setColor(nr, ng, nb, stripAlpha)
    love.graphics.rectangle("fill", 0, y * gs, width * gs, 2)
  end
  for x = 0, width - 1, 6 do
    local stripAlpha = 0.03 + 0.015 * math.sin(time * 0.6 + x * 0.4)
    love.graphics.setColor(nr, ng, nb, stripAlpha)
    love.graphics.rectangle("fill", x * gs, 0, 2, height * gs)
  end
end

-- Draw walking path with neon guide lights
function M.drawPath(path, gs, nr, ng, nb, time)
  local px = path.x1 * gs
  local py = path.y1 * gs
  local pw = (path.x2 - path.x1 + 1) * gs
  local ph = (path.y2 - path.y1 + 1) * gs

  -- Path surface (slightly lighter)
  love.graphics.setColor(0.06, 0.06, 0.1, 0.8)
  love.graphics.rectangle("fill", px, py, pw, ph)

  -- Edge guide lights
  local isHorizontal = pw > ph
  if isHorizontal then
    -- Horizontal path: lights along top and bottom edges
    local numLights = math.floor(pw / 24)
    for i = 0, numLights do
      local lx = px + i * 24
      local pulse = 0.3 + 0.4 * math.sin(time * 2 + i * 0.5)
      love.graphics.setColor(nr, ng, nb, pulse * 0.5)
      love.graphics.circle("fill", lx, py + 2, 2)
      love.graphics.circle("fill", lx, py + ph - 2, 2)
    end
    -- Center line
    love.graphics.setColor(nr, ng, nb, 0.08)
    love.graphics.rectangle("fill", px, py + ph/2 - 1, pw, 2)
  else
    -- Vertical path
    local numLights = math.floor(ph / 24)
    for i = 0, numLights do
      local ly = py + i * 24
      local pulse = 0.3 + 0.4 * math.sin(time * 2 + i * 0.5)
      love.graphics.setColor(nr, ng, nb, pulse * 0.5)
      love.graphics.circle("fill", px + 2, ly, 2)
      love.graphics.circle("fill", px + pw - 2, ly, 2)
    end
    love.graphics.setColor(nr, ng, nb, 0.08)
    love.graphics.rectangle("fill", px + pw/2 - 1, py, 2, ph)
  end
end

-- Draw elevator pad on the floor
function M.drawElevatorPad(elevPos, gs, neonColor, time)
  local ex = (elevPos.x - 1) * gs
  local ey = (elevPos.y - 1) * gs
  local ew = gs * 3
  local eh = gs * 3
  local nr, ng, nb = neonColor[1], neonColor[2], neonColor[3]
  local pulse = 0.6 + 0.4 * math.sin(time * 2)

  -- Platform base
  love.graphics.setColor(0.08, 0.08, 0.15, 0.9)
  love.graphics.rectangle("fill", ex, ey, ew, eh, 4)

  -- Neon border
  M.drawNeonRect(ex, ey, ew, eh, nr, ng, nb, pulse * 0.7, 2)

  -- "E" symbol / arrows
  love.graphics.setColor(nr, ng, nb, pulse * 0.5)
  local cx = ex + ew/2
  local cy = ey + eh/2
  -- Up/down arrows
  love.graphics.polygon("fill", cx - 8, cy - 8, cx + 8, cy - 8, cx, cy - 18)
  love.graphics.polygon("fill", cx - 8, cy + 8, cx + 8, cy + 8, cx, cy + 18)

  -- Corner dots
  for _, corner in ipairs({{ex+6, ey+6}, {ex+ew-6, ey+6}, {ex+6, ey+eh-6}, {ex+ew-6, ey+eh-6}}) do
    love.graphics.setColor(nr, ng, nb, pulse * 0.8)
    love.graphics.circle("fill", corner[1], corner[2], 3)
  end
end

-- Draw crates (Slateport-style for warehouse floor)
function M.drawCrate(crate, gs, time)
  local cx = crate.x * gs
  local cy = crate.y * gs
  local cw = (crate.w or 1) * gs
  local ch = (crate.h or 1) * gs
  local cr, cg, cb = crate.color[1], crate.color[2], crate.color[3]

  -- Crate body
  love.graphics.setColor(cr, cg, cb)
  love.graphics.rectangle("fill", cx + 1, cy + 1, cw - 2, ch - 2, 2)

  -- Dark edges (3D effect)
  love.graphics.setColor(cr * 0.6, cg * 0.6, cb * 0.6)
  love.graphics.rectangle("fill", cx + cw - 4, cy + 2, 3, ch - 4) -- right shadow
  love.graphics.rectangle("fill", cx + 2, cy + ch - 4, cw - 4, 3) -- bottom shadow

  -- Highlight
  love.graphics.setColor(cr * 1.3, cg * 1.3, cb * 1.3, 0.5)
  love.graphics.rectangle("fill", cx + 2, cy + 2, cw - 6, 3) -- top highlight
  love.graphics.rectangle("fill", cx + 2, cy + 2, 3, ch - 6) -- left highlight

  -- Cross bands
  love.graphics.setColor(cr * 0.8, cg * 0.8, cb * 0.8)
  love.graphics.setLineWidth(2)
  love.graphics.line(cx + 2, cy + ch/2, cx + cw - 2, cy + ch/2)
  if cw > gs then
    love.graphics.line(cx + cw/2, cy + 2, cx + cw/2, cy + ch - 2)
  end
  love.graphics.setLineWidth(1)
end

return M
