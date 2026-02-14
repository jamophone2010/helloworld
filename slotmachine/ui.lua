local M = {}
local reel = require("slotmachine.reel")
local credits = require("slotmachine.credits")
local winFx = require("casino_win_fx")

local fonts = {}
local SYMBOL_WIDTH = 150
local SYMBOL_HEIGHT = 120
local SYMBOL_SPACING = 15
local SLOT_HEIGHT = SYMBOL_HEIGHT + SYMBOL_SPACING
local VISIBLE_ROWS = 3

-- Centered for 1366x768
local SCREEN_W = 1366
local SCREEN_H = 768
local MACHINE_W = 470  -- total reel area width (3 reels)
local MACHINE_CENTER_X = SCREEN_W / 2
local REEL_X_START = MACHINE_CENTER_X - MACHINE_W / 2
local REEL_X_POSITIONS = {REEL_X_START, REEL_X_START + 160, REEL_X_START + 320}
local REEL_Y = 180

-- UI time for animations
local uiTime = 0

-- Bellagio background state
local bgTime = 0
local bgStars = {}
local bgFountainDrops = {}

function M.load()
  fonts.normal = love.graphics.newFont(20)
  fonts.large = love.graphics.newFont(36)
  fonts.huge = love.graphics.newFont(48)
  fonts.symbol = love.graphics.newFont(28)
  fonts.bar = love.graphics.newFont(32)
  fonts.seven = love.graphics.newFont(52)
  fonts.lcd = love.graphics.newFont(26)
  fonts.lcdSmall = love.graphics.newFont(18)
  fonts.winSide = love.graphics.newFont(16)
  fonts.winAmount = love.graphics.newFont(30)

  -- Generate background stars
  for i = 1, 120 do
    bgStars[i] = {
      x = math.random() * SCREEN_W,
      y = math.random() * SCREEN_H,
      size = math.random() * 2 + 0.5,
      twinkle = math.random() * math.pi * 2,
      speed = 0.5 + math.random() * 2
    }
  end

  -- Generate fountain particles
  for i = 1, 80 do
    bgFountainDrops[i] = {
      x = MACHINE_CENTER_X + (math.random() - 0.5) * 300,
      baseY = SCREEN_H,
      phase = math.random() * math.pi * 2,
      height = 100 + math.random() * 260,
      speed = 0.8 + math.random() * 1.5,
      size = 1 + math.random() * 2,
      drift = (math.random() - 0.5) * 50
    }
  end
end

-- ============================================================
-- BELLAGIO-STYLE BACKGROUND
-- ============================================================
function M.drawBackground(dt)
  bgTime = bgTime + (dt or 0.016)

  -- Night sky gradient (dark navy to deep purple) - fullscreen
  for y = 0, SCREEN_H, 2 do
    local t = y / SCREEN_H
    local r = 0.04 + 0.08 * t
    local g = 0.03 + 0.05 * t
    local b = 0.12 + 0.10 * t
    love.graphics.setColor(r, g, b, 0.7)
    love.graphics.rectangle("fill", 0, y, SCREEN_W, 2)
  end

  -- Twinkling stars (more visible)
  for _, star in ipairs(bgStars) do
    local alpha = 0.2 + 0.2 * math.sin(bgTime * star.speed + star.twinkle)
    love.graphics.setColor(0.9, 0.9, 1.0, alpha)
    love.graphics.circle("fill", star.x, star.y, star.size)
  end

  -- Distant building silhouettes - spread across full width
  love.graphics.setColor(0.08, 0.06, 0.14, 0.5)
  -- Far left building cluster
  love.graphics.rectangle("fill", 30, 420, 70, 350)
  love.graphics.rectangle("fill", 70, 380, 50, 390)
  love.graphics.rectangle("fill", 115, 400, 60, 370)
  -- Left-mid buildings
  love.graphics.rectangle("fill", 220, 440, 55, 330)
  love.graphics.rectangle("fill", 260, 410, 45, 360)
  -- Right-mid buildings
  love.graphics.rectangle("fill", 1050, 430, 50, 340)
  love.graphics.rectangle("fill", 1090, 400, 55, 370)
  -- Far right building cluster
  love.graphics.rectangle("fill", 1200, 390, 50, 380)
  love.graphics.rectangle("fill", 1240, 410, 60, 360)
  love.graphics.rectangle("fill", 1290, 370, 45, 400)
  -- Center distant tower (Bellagio-like)
  love.graphics.rectangle("fill", MACHINE_CENTER_X - 50, 480, 100, 290)
  love.graphics.polygon("fill", MACHINE_CENTER_X - 50, 480, MACHINE_CENTER_X, 440, MACHINE_CENTER_X + 50, 480)

  -- Building windows (warm light, more visible)
  love.graphics.setColor(1, 0.9, 0.5, 0.16)
  for bx = 35, 170, 15 do
    for by = 430, SCREEN_H - 10, 20 do
      if math.sin(bx * 13 + by * 7) > -0.3 then
        love.graphics.rectangle("fill", bx, by, 4, 6)
      end
    end
  end
  for bx = 225, 300, 15 do
    for by = 445, SCREEN_H - 10, 20 do
      if math.sin(bx * 11 + by * 5) > -0.3 then
        love.graphics.rectangle("fill", bx, by, 4, 6)
      end
    end
  end
  for bx = 1055, 1140, 15 do
    for by = 435, SCREEN_H - 10, 20 do
      if math.sin(bx * 11 + by * 5) > -0.3 then
        love.graphics.rectangle("fill", bx, by, 4, 6)
      end
    end
  end
  for bx = 1205, 1330, 15 do
    for by = 400, SCREEN_H - 10, 20 do
      if math.sin(bx * 13 + by * 7) > -0.3 then
        love.graphics.rectangle("fill", bx, by, 4, 6)
      end
    end
  end

  -- Water/fountain base (reflecting pool) - centered wider
  love.graphics.setColor(0.06, 0.1, 0.22, 0.4)
  love.graphics.rectangle("fill", MACHINE_CENTER_X - 350, SCREEN_H - 80, 700, 80)
  -- Water shimmer
  for wx = MACHINE_CENTER_X - 345, MACHINE_CENTER_X + 345, 8 do
    local shimmer = 0.1 + 0.08 * math.sin(bgTime * 1.5 + wx * 0.05)
    love.graphics.setColor(0.3, 0.5, 0.8, shimmer)
    love.graphics.rectangle("fill", wx, SCREEN_H - 75 + math.sin(bgTime + wx * 0.1) * 2, 5, 1)
  end

  -- Fountain jets (the signature Bellagio fountain effect)
  for _, drop in ipairs(bgFountainDrops) do
    local t = (bgTime * drop.speed + drop.phase) % (math.pi * 2)
    local progress = t / (math.pi * 2)
    local yOff = math.sin(t) * drop.height
    local dy = drop.baseY - math.abs(yOff)
    local dx = drop.x + drop.drift * math.sin(t * 0.5)
    local alpha = 0.1 + 0.08 * (1 - progress)

    -- White-blue fountain spray
    love.graphics.setColor(0.6, 0.75, 1.0, alpha)
    love.graphics.circle("fill", dx, dy, drop.size)
    -- Faint glow
    love.graphics.setColor(0.5, 0.6, 1.0, alpha * 0.4)
    love.graphics.circle("fill", dx, dy, drop.size * 2.5)
  end

  -- Golden glow around machine area (ambient casino lighting)
  for radius = 350, 80, -30 do
    local alpha = 0.02 * (1 - radius / 400)
    love.graphics.setColor(1, 0.85, 0.4, alpha)
    love.graphics.circle("fill", MACHINE_CENTER_X, 380, radius)
  end
end

-- ============================================================
-- SYMBOL DRAWING FUNCTIONS - Real Vegas slot machine symbols
-- ============================================================

local function drawCherry(x, y, w, h)
  local cx, cy = x + w/2, y + h/2

  -- Neon glow behind cherries
  love.graphics.setColor(1, 0.1, 0.2, 0.12)
  love.graphics.circle("fill", cx - 14, cy, 28)
  love.graphics.circle("fill", cx + 14, cy, 28)

  -- Stems (neon green)
  love.graphics.setColor(0.2, 1, 0.3)
  love.graphics.setLineWidth(3)
  love.graphics.line(cx - 8, cy - 20, cx - 2, cy - 40)
  love.graphics.line(cx + 8, cy - 20, cx + 2, cy - 40)
  love.graphics.line(cx - 2, cy - 40, cx + 2, cy - 40)
  -- Leaf (bright neon green)
  love.graphics.setColor(0.1, 1, 0.3)
  love.graphics.ellipse("fill", cx + 6, cy - 38, 12, 6)
  love.graphics.setColor(0.2, 1, 0.4, 0.3)
  love.graphics.ellipse("fill", cx + 6, cy - 38, 15, 8)

  -- Left cherry (neon red)
  love.graphics.setColor(1, 0.1, 0.15)
  love.graphics.circle("fill", cx - 14, cy, 18)
  love.graphics.setColor(1, 0.4, 0.4, 0.7)
  love.graphics.circle("fill", cx - 19, cy - 7, 6)
  love.graphics.setColor(1, 0.7, 0.7, 0.4)
  love.graphics.circle("fill", cx - 20, cy - 9, 3)

  -- Right cherry (neon red)
  love.graphics.setColor(1, 0.1, 0.15)
  love.graphics.circle("fill", cx + 14, cy, 18)
  love.graphics.setColor(1, 0.4, 0.4, 0.7)
  love.graphics.circle("fill", cx + 9, cy - 7, 6)
  love.graphics.setColor(1, 0.7, 0.7, 0.4)
  love.graphics.circle("fill", cx + 8, cy - 9, 3)

  love.graphics.setLineWidth(1)
end

local function drawLemon(x, y, w, h)
  local cx, cy = x + w/2, y + h/2

  -- Neon glow
  love.graphics.setColor(1, 1, 0.1, 0.1)
  love.graphics.ellipse("fill", cx, cy + 2, 38, 32)

  -- Main lemon body (neon yellow)
  love.graphics.setColor(1, 1, 0.15)
  love.graphics.ellipse("fill", cx, cy + 2, 28, 22)

  -- Bright outline
  love.graphics.setColor(1, 0.95, 0.1)
  love.graphics.setLineWidth(2)
  love.graphics.ellipse("line", cx, cy + 2, 28, 22)

  -- Lemon tip nubs
  love.graphics.setColor(1, 1, 0.15)
  love.graphics.ellipse("fill", cx - 26, cy + 2, 6, 4)
  love.graphics.ellipse("fill", cx + 26, cy + 2, 6, 4)

  -- Hot highlight
  love.graphics.setColor(1, 1, 0.7, 0.7)
  love.graphics.ellipse("fill", cx - 8, cy - 6, 12, 8)
  love.graphics.setColor(1, 1, 0.9, 0.4)
  love.graphics.ellipse("fill", cx - 6, cy - 8, 6, 4)

  -- Neon green leaf
  love.graphics.setColor(0.2, 1, 0.3)
  love.graphics.ellipse("fill", cx + 4, cy - 20, 8, 5)
  love.graphics.setColor(0.15, 0.8, 0.2)
  love.graphics.setLineWidth(1.5)
  love.graphics.line(cx + 4, cy - 20, cx, cy - 14)

  love.graphics.setLineWidth(1)
end

local function drawOrange(x, y, w, h)
  local cx, cy = x + w/2, y + h/2

  -- Neon glow
  love.graphics.setColor(1, 0.5, 0, 0.12)
  love.graphics.circle("fill", cx, cy + 2, 36)

  -- Main orange (neon)
  love.graphics.setColor(1, 0.6, 0.05)
  love.graphics.circle("fill", cx, cy + 2, 26)

  -- Bright outline
  love.graphics.setColor(1, 0.5, 0.0)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", cx, cy + 2, 26)

  -- Texture dimples (neon tint)
  love.graphics.setColor(1, 0.7, 0.1, 0.3)
  for angle = 0, math.pi * 2, 0.8 do
    for r = 8, 22, 7 do
      local dx = math.cos(angle + r * 0.3) * r
      local dy = math.sin(angle + r * 0.3) * r
      love.graphics.circle("fill", cx + dx, cy + 2 + dy, 1)
    end
  end

  -- Hot highlight
  love.graphics.setColor(1, 0.85, 0.4, 0.7)
  love.graphics.ellipse("fill", cx - 8, cy - 8, 10, 8)
  love.graphics.setColor(1, 0.95, 0.6, 0.4)
  love.graphics.ellipse("fill", cx - 7, cy - 10, 5, 3)

  -- Neon green leaf
  love.graphics.setColor(0.2, 1, 0.3)
  love.graphics.ellipse("fill", cx + 2, cy - 24, 7, 4)
  love.graphics.setColor(0.1, 0.8, 0.15)
  love.graphics.setLineWidth(1.5)
  love.graphics.line(cx, cy - 22, cx, cy - 18)

  love.graphics.setLineWidth(1)
end

local function drawPlum(x, y, w, h)
  local cx, cy = x + w/2, y + h/2

  -- Neon glow
  love.graphics.setColor(0.7, 0.1, 1, 0.12)
  love.graphics.ellipse("fill", cx, cy + 2, 34, 36)

  -- Main plum body (neon purple)
  love.graphics.setColor(0.6, 0.1, 0.75)
  love.graphics.ellipse("fill", cx, cy + 2, 24, 26)

  -- Crease line
  love.graphics.setColor(0.4, 0.0, 0.55, 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.line(cx, cy - 22, cx - 2, cy + 28)

  -- Bright outline
  love.graphics.setColor(0.8, 0.2, 1)
  love.graphics.ellipse("line", cx, cy + 2, 24, 26)

  -- Hot highlight
  love.graphics.setColor(0.9, 0.4, 1, 0.5)
  love.graphics.ellipse("fill", cx - 8, cy - 8, 10, 12)
  love.graphics.setColor(1, 0.6, 1, 0.3)
  love.graphics.ellipse("fill", cx - 6, cy - 10, 5, 6)

  -- Stem
  love.graphics.setColor(0.5, 0.35, 0.2)
  love.graphics.setLineWidth(2)
  love.graphics.line(cx, cy - 26, cx + 3, cy - 36)

  -- Neon green leaf
  love.graphics.setColor(0.2, 1, 0.3)
  love.graphics.ellipse("fill", cx + 7, cy - 33, 8, 4)

  love.graphics.setLineWidth(1)
end

local function drawBar(x, y, w, h)
  local cx, cy = x + w/2, y + h/2

  -- Neon glow behind bar
  love.graphics.setColor(1, 0.85, 0.2, 0.12)
  love.graphics.rectangle("fill", cx - 55, cy - 24, 110, 46, 6, 6)

  -- Gold metallic bar background (brighter neon gold)
  love.graphics.setColor(1, 0.88, 0.25)
  love.graphics.rectangle("fill", cx - 50, cy - 18, 100, 16)
  love.graphics.setColor(0.85, 0.7, 0.12)
  love.graphics.rectangle("fill", cx - 50, cy - 2, 100, 16)

  -- Metallic shine strip across top (brighter)
  love.graphics.setColor(1, 1, 0.6, 0.8)
  love.graphics.rectangle("fill", cx - 48, cy - 16, 96, 4)

  -- Neon border
  love.graphics.setColor(1, 0.9, 0.3)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", cx - 50, cy - 18, 100, 34, 3, 3)

  -- "BAR" text (dark on bright, high contrast)
  love.graphics.setColor(0.1, 0.05, 0)
  love.graphics.setFont(fonts.bar)
  love.graphics.printf("BAR", cx - 50, cy - 16, 100, "center")

  -- Inner highlight
  love.graphics.setColor(1, 1, 0.5, 0.2)
  love.graphics.rectangle("fill", cx - 48, cy - 16, 96, 8)

  love.graphics.setLineWidth(1)
end

local function drawSeven(x, y, w, h)
  local cx, cy = x + w/2, y + h/2
  local t = love.timer.getTime()
  local pulse = 0.8 + 0.2 * math.sin(t * 3)

  -- Multi-layer neon glow (pulsing)
  love.graphics.setColor(1, 0, 0, 0.06 * pulse)
  love.graphics.circle("fill", cx, cy, 60)
  love.graphics.setColor(1, 0.1, 0, 0.1 * pulse)
  love.graphics.circle("fill", cx, cy, 50)
  love.graphics.setColor(1, 0.15, 0.05, 0.18 * pulse)
  love.graphics.circle("fill", cx, cy, 40)
  love.graphics.setColor(1, 0.2, 0.1, 0.25 * pulse)
  love.graphics.circle("fill", cx, cy, 30)

  love.graphics.setFont(fonts.seven)

  -- Soft red glow halo (drawn large behind text)
  love.graphics.setColor(1, 0.1, 0, 0.15 * pulse)
  for dx = -4, 4 do
    for dy = -4, 4 do
      love.graphics.printf("7", cx - 26 + dx, cy - 28 + dy, 52, "center")
    end
  end

  -- Golden outline (neon gold border)
  love.graphics.setColor(1, 0.9, 0.2)
  for dx = -2, 2 do
    for dy = -2, 2 do
      if math.abs(dx) + math.abs(dy) >= 2 then
        love.graphics.printf("7", cx - 26 + dx, cy - 28 + dy, 52, "center")
      end
    end
  end

  -- Main neon red 7
  love.graphics.setColor(1, 0.1, 0.1)
  love.graphics.printf("7", cx - 26, cy - 28, 52, "center")

  -- Hot white-red center highlight
  love.graphics.setColor(1, 0.5, 0.4, 0.5)
  love.graphics.printf("7", cx - 26, cy - 29, 52, "center")
end

local function drawDiamond(x, y, w, h)
  local cx, cy = x + w/2, y + h/2
  local t = love.timer.getTime()
  local pulse = 0.8 + 0.2 * math.sin(t * 2.5)

  -- Multi-layer neon glow (pulsing cyan)
  love.graphics.setColor(0.2, 0.6, 1, 0.06 * pulse)
  love.graphics.circle("fill", cx, cy, 60)
  love.graphics.setColor(0.3, 0.7, 1, 0.1 * pulse)
  love.graphics.circle("fill", cx, cy, 50)
  love.graphics.setColor(0.4, 0.8, 1, 0.16 * pulse)
  love.graphics.circle("fill", cx, cy, 40)
  love.graphics.setColor(0.5, 0.9, 1, 0.2 * pulse)
  love.graphics.circle("fill", cx, cy, 30)

  -- Diamond shape
  local top = cy - 30
  local mid = cy
  local bot = cy + 25
  local left = cx - 28
  local right = cx + 28
  local midL = cx - 14
  local midR = cx + 14

  -- Crown facets (neon bright blues)
  love.graphics.setColor(0.3, 0.8, 1)
  love.graphics.polygon("fill", midL, top, left, mid, cx, mid)
  love.graphics.setColor(0.5, 0.95, 1.0)
  love.graphics.polygon("fill", midL, top, midR, top, cx, mid)
  love.graphics.setColor(0.25, 0.7, 1)
  love.graphics.polygon("fill", midR, top, right, mid, cx, mid)

  -- Pavilion facets (deep neon blue)
  love.graphics.setColor(0.15, 0.55, 0.95)
  love.graphics.polygon("fill", left, mid, cx, mid, cx, bot)
  love.graphics.setColor(0.1, 0.45, 0.85)
  love.graphics.polygon("fill", right, mid, cx, mid, cx, bot)

  -- Glowing outline
  love.graphics.setColor(0.6, 0.95, 1, 0.9 * pulse)
  love.graphics.setLineWidth(2)
  love.graphics.polygon("line", midL, top, midR, top, right, mid, cx, bot, left, mid)
  -- Inner facet lines (neon)
  love.graphics.setColor(0.7, 1, 1, 0.5)
  love.graphics.setLineWidth(1)
  love.graphics.line(midL, top, cx, mid)
  love.graphics.line(midR, top, cx, mid)
  love.graphics.line(left, mid, cx, bot)
  love.graphics.line(right, mid, cx, bot)
  love.graphics.line(left, mid, midL, top)
  love.graphics.line(right, mid, midR, top)

  -- Animated sparkle highlights
  local s1 = 0.5 + 0.5 * math.sin(t * 4)
  local s2 = 0.5 + 0.5 * math.sin(t * 4 + 2)
  local s3 = 0.5 + 0.5 * math.sin(t * 4 + 4)
  love.graphics.setColor(1, 1, 1, 0.9 * s1)
  love.graphics.circle("fill", cx - 5, cy - 15, 3)
  love.graphics.setColor(1, 1, 1, 0.7 * s2)
  love.graphics.circle("fill", cx + 10, cy - 8, 2.5)
  love.graphics.setColor(1, 1, 1, 0.6 * s3)
  love.graphics.circle("fill", cx - 12, cy + 5, 2)

  love.graphics.setLineWidth(1)
end

-- Symbol draw dispatch table
local symbolDrawers = {
  cherry = drawCherry,
  lemon = drawLemon,
  orange = drawOrange,
  plum = drawPlum,
  bar = drawBar,
  seven = drawSeven,
  diamond = drawDiamond
}

-- ============================================================
-- REEL AND MACHINE DRAWING
-- ============================================================

function M.drawReels(machine)
  local clipX = REEL_X_START
  local clipY = REEL_Y
  local clipWidth = MACHINE_W
  local clipHeight = VISIBLE_ROWS * SLOT_HEIGHT

  -- Machine cabinet body (dark metallic frame)
  love.graphics.setColor(0.08, 0.06, 0.12)
  love.graphics.rectangle("fill", clipX - 18, clipY - 18, clipWidth + 36, clipHeight + 36, 8, 8)
  -- Gold trim around cabinet
  love.graphics.setColor(0.7, 0.55, 0.1)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", clipX - 18, clipY - 18, clipWidth + 36, clipHeight + 36, 8, 8)
  -- Inner gold trim
  love.graphics.setColor(0.85, 0.7, 0.2, 0.5)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", clipX - 12, clipY - 12, clipWidth + 24, clipHeight + 24, 5, 5)

  -- Reel window background (dark felt)
  love.graphics.setColor(0.04, 0.04, 0.06)
  love.graphics.rectangle("fill", clipX - 6, clipY - 6, clipWidth + 12, clipHeight + 12)

  -- Draw reel divider strips (metallic separators between reels)
  love.graphics.setColor(0.15, 0.12, 0.2)
  love.graphics.rectangle("fill", REEL_X_POSITIONS[1] + SYMBOL_WIDTH + 3, clipY - 4, 5, clipHeight + 8)
  love.graphics.rectangle("fill", REEL_X_POSITIONS[2] + SYMBOL_WIDTH + 3, clipY - 4, 5, clipHeight + 8)

  -- Scissor to clip reel symbols
  love.graphics.setScissor(clipX, clipY, clipWidth, clipHeight)

  for i, r in ipairs(machine.reels) do
    M.drawReel(r)
  end

  love.graphics.setScissor()

  -- Center payline indicator (golden line across the middle row)
  love.graphics.setColor(1, 0.84, 0, 0.6)
  love.graphics.setLineWidth(2)
  local paylineY = clipY + SLOT_HEIGHT + SYMBOL_HEIGHT / 2
  -- Left arrow indicator
  love.graphics.polygon("fill", clipX - 14, paylineY, clipX - 4, paylineY - 6, clipX - 4, paylineY + 6)
  -- Right arrow indicator
  love.graphics.polygon("fill", clipX + clipWidth + 14, paylineY, clipX + clipWidth + 4, paylineY - 6, clipX + clipWidth + 4, paylineY + 6)
  -- Dashed center line
  love.graphics.setColor(1, 0.84, 0, 0.25)
  for lx = clipX, clipX + clipWidth, 12 do
    love.graphics.rectangle("fill", lx, paylineY - 0.5, 6, 1)
  end

  love.graphics.setLineWidth(1)
end

function M.drawReel(r)
  local numSymbols = #r.symbols
  local offset = reel.getOffset(r)
  local SLOT_HEIGHT = SYMBOL_HEIGHT + SYMBOL_SPACING

  local baseIndex = math.floor(offset / SLOT_HEIGHT)
  local scrollOffset = offset % SLOT_HEIGHT

  for i = 0, 3 do
    local yPos = r.y - scrollOffset + i * SLOT_HEIGHT
    local symbolIndex = (baseIndex + i) % numSymbols + 1
    local symbol = r.symbols[symbolIndex]

    if yPos >= r.y - SLOT_HEIGHT and yPos <= r.y + 3 * SLOT_HEIGHT then
      M.drawSymbol(symbol, r.x, yPos, SYMBOL_WIDTH, SYMBOL_HEIGHT)
    end
  end
end

function M.drawSymbol(symbol, x, y, width, height)
  -- Dark symbol cell background (for neon contrast)
  love.graphics.setColor(0.06, 0.05, 0.1)
  love.graphics.rectangle("fill", x + 2, y + 2, width - 4, height - 4, 4, 4)

  -- Subtle dark gradient at edges
  love.graphics.setColor(0.03, 0.02, 0.06, 0.5)
  love.graphics.rectangle("fill", x + 2, y + 2, width - 4, 10, 4, 4)
  love.graphics.rectangle("fill", x + 2, y + height - 12, width - 4, 10, 4, 4)

  -- Thin subtle border
  love.graphics.setColor(0.2, 0.18, 0.3, 0.5)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x + 2, y + 2, width - 4, height - 4, 4, 4)

  -- Draw the actual symbol graphic
  local drawer = symbolDrawers[symbol.id]
  if drawer then
    drawer(x, y, width, height)
  end
end

-- Draw an LCD-style display panel
local function drawLCDPanel(x, y, w, h, label, value, valueColor, glowing)
  -- LCD screen bezel (dark plastic frame)
  love.graphics.setColor(0.04, 0.04, 0.04)
  love.graphics.rectangle("fill", x, y, w, h, 3, 3)
  -- Inner LCD screen (very dark green/black)
  love.graphics.setColor(0.02, 0.06, 0.03)
  love.graphics.rectangle("fill", x + 3, y + 3, w - 6, h - 6, 2, 2)
  -- LCD scan line effect
  love.graphics.setColor(0, 0.03, 0.01, 0.3)
  for ly = y + 4, y + h - 4, 2 do
    love.graphics.rectangle("fill", x + 3, ly, w - 6, 1)
  end
  -- Label (dim)
  love.graphics.setFont(fonts.lcdSmall)
  love.graphics.setColor(valueColor[1] * 0.4, valueColor[2] * 0.4, valueColor[3] * 0.4)
  love.graphics.printf(label, x + 5, y + 4, w - 10, "center")
  -- LCD value (bright, glowing)
  love.graphics.setFont(fonts.lcd)
  -- Glow behind digits
  love.graphics.setColor(valueColor[1], valueColor[2], valueColor[3], 0.15)
  love.graphics.printf(tostring(value), x + 5, y + 20, w - 10, "center")
  -- Main digits
  love.graphics.setColor(valueColor[1], valueColor[2], valueColor[3])
  love.graphics.printf(tostring(value), x + 5, y + 20, w - 10, "center")
end

local function formatNumber(n)
  return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- ─── POKER CHIP DRAWING ──────────────────────────────────────

local function drawPokerChip(x, y, value, stackHeight)
  local radius = 15
  local color = credits.getChipColor(value)
  local label = credits.getChipLabel(value)
  stackHeight = stackHeight or 0
  local cy = y + stackHeight

  -- Drop shadow
  love.graphics.setColor(0, 0, 0, 0.4)
  love.graphics.circle("fill", x + 2, cy + 3, radius)

  -- Outer ring (darker edge)
  love.graphics.setColor(color[1] * 0.45, color[2] * 0.45, color[3] * 0.45)
  love.graphics.circle("fill", x, cy, radius)

  -- Main chip body
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.circle("fill", x, cy, radius - 1.5)

  -- 8 edge notches
  love.graphics.setColor(1, 1, 1, 0.55)
  for angle = 0, 7 do
    local a = angle * math.pi / 4
    local nx = x + math.cos(a) * (radius - 3)
    local ny = cy + math.sin(a) * (radius - 3)
    love.graphics.circle("fill", nx, ny, 1.8)
  end

  -- Inner white ring
  love.graphics.setColor(1, 1, 1, 0.45)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", x, cy, radius - 5)
  love.graphics.setLineWidth(1)

  -- Center disc
  love.graphics.setColor(color[1] * 0.82, color[2] * 0.82, color[3] * 0.82)
  love.graphics.circle("fill", x, cy, radius - 6)

  -- Value text
  love.graphics.setFont(fonts.lcdSmall)
  local textDark = (value == 1 or value == 25 or value == 10000 or value == 1000000)
  love.graphics.setColor(textDark and {0.1, 0.1, 0.1} or {1, 1, 1})
  local tw = fonts.lcdSmall:getWidth(label)
  love.graphics.print(label, x - tw / 2, cy - 6)

  -- Shine highlight
  love.graphics.setColor(1, 1, 1, 0.12)
  love.graphics.arc("fill", x, cy, radius - 2, -math.pi * 0.8, -math.pi * 0.2)
end

function M.drawUI(bank, state)
  uiTime = uiTime + (love.timer.getDelta and love.timer.getDelta() or 0.016)

  -- LCD panels below the machine - centered
  local panelY = REEL_Y + VISIBLE_ROWS * SLOT_HEIGHT + 50
  local panelTotalW = 155 + 10 + 120 + 10 + 155  -- 3 panels + gaps
  local panelStartX = MACHINE_CENTER_X - panelTotalW / 2

  -- Use animated credit count if win FX is active
  local displayCredits = winFx.getDisplayedCredits() or bank.credits
  local creditsX = panelStartX
  local creditsW = 155
  local creditsH = 48

  -- Draw glowing border around credits panel during win
  winFx.drawCreditCounter(creditsX, panelY, creditsW, creditsH, "CREDITS")

  drawLCDPanel(creditsX, panelY, creditsW, creditsH, "CREDITS", formatNumber(math.floor(displayCredits)), {0.2, 1, 0.3})
  drawLCDPanel(panelStartX + 165, panelY, 120, 48, "BET/LINE", formatNumber(bank.currentBet), {1, 0.85, 0.2})
  drawLCDPanel(panelStartX + 295, panelY, 155, 48, "TOTAL BET", formatNumber(credits.getTotalBet(bank)), {0.5, 0.75, 1})

  -- ─── Chip Selector Panel (left side) ─────────────────────
  local chipPanelX = REEL_X_START - 220
  local chipPanelY = REEL_Y
  local chipPanelW = 200
  local chipPanelH = 200

  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", chipPanelX, chipPanelY, chipPanelW, chipPanelH, 8, 8)
  love.graphics.setColor(0.85, 0.72, 0.2, 0.35)
  love.graphics.rectangle("line", chipPanelX, chipPanelY, chipPanelW, chipPanelH, 8, 8)

  -- Title
  love.graphics.setFont(fonts.lcdSmall)
  love.graphics.setColor(0.65, 0.55, 0.18, 0.8)
  love.graphics.print("SELECT CHIP (LEFT/RIGHT)", chipPanelX + 10, chipPanelY + 6)

  -- Currently selected chip (featured)
  local chipValue = credits.getSelectedChipValue(bank)
  love.graphics.setFont(fonts.lcdSmall)
  love.graphics.setColor(0.95, 0.92, 0.85)
  love.graphics.print("Active:", chipPanelX + 12, chipPanelY + 28)
  drawPokerChip(chipPanelX + 90, chipPanelY + 38, chipValue)
  love.graphics.setColor(0.95, 0.92, 0.85)
  love.graphics.print(credits.getChipLabel(chipValue), chipPanelX + 110, chipPanelY + 32)

  -- All available chips in grid
  local chipStartX = chipPanelX + 16
  local chipX = chipStartX
  local chipRow = 1
  for i, value in ipairs(credits.CHIP_VALUES) do
    if credits.canAfford(bank, value) then
      local chipY = (chipRow == 1) and (chipPanelY + 65) or (chipRow == 2) and (chipPanelY + 100) or (chipPanelY + 135)
      if i == bank.selectedChipIndex then
        local pulse = 0.5 + 0.4 * math.sin(uiTime * 5)
        love.graphics.setColor(0.85, 0.72, 0.2, pulse * 0.45)
        love.graphics.circle("fill", chipX + 14, chipY, 18)
      end
      drawPokerChip(chipX + 14, chipY, value)
      chipX = chipX + 36
      if chipX > chipPanelX + chipPanelW - 30 then
        chipX = chipStartX
        chipRow = chipRow + 1
      end
    end
  end

  -- Bet adjustment hint below chip panel
  love.graphics.setFont(fonts.lcdSmall)
  love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
  love.graphics.printf("UP/DOWN: Adjust Bet", chipPanelX, chipPanelY + chipPanelH + 8, chipPanelW, "center")

  -- Controls hint
  if state == "idle" then
    love.graphics.setFont(fonts.lcdSmall)
    love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
    love.graphics.printf("SPACE: Spin  |  LEFT/RIGHT: Chip  |  UP/DOWN: Bet", 0, panelY + 56, SCREEN_W, "center")
  elseif state == "spinning" then
    love.graphics.setFont(fonts.lcdSmall)
    love.graphics.setColor(1, 1, 0.3, 0.5 + 0.3 * math.sin(love.timer.getTime() * 6))
    love.graphics.printf("SPINNING...", 0, panelY + 56, SCREEN_W, "center")
  end

  -- Machine title plate at top - centered
  local titleW = 300
  local titleX = MACHINE_CENTER_X - titleW / 2
  love.graphics.setColor(0.06, 0.04, 0.1, 0.9)
  love.graphics.rectangle("fill", titleX, REEL_Y - 45, titleW, 35, 5, 5)
  love.graphics.setColor(0.8, 0.65, 0.15, 0.7)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", titleX, REEL_Y - 45, titleW, 35, 5, 5)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 0.85, 0.2)
  love.graphics.printf("★ LUCKY STARS ★", titleX, REEL_Y - 42, titleW, "center")
end

function M.drawWins(wins, totalWinnings, paylines)
  if totalWinnings > 0 then
    M.drawWinningPaylines(wins, paylines)

    local pulse = 0.85 + 0.15 * math.sin(love.timer.getTime() * 5)

    -- Side panel to the right of the machine
    local panelX = REEL_X_START + MACHINE_W + 35
    local panelY = REEL_Y - 5
    local panelW = 100
    local panelH = 265

    -- Panel background
    love.graphics.setColor(0.06, 0.03, 0.1, 0.9)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 6, 6)
    -- Gold border
    love.graphics.setColor(1, 0.84, 0, 0.7 * pulse)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 6, 6)

    -- "WIN" header
    love.graphics.setFont(fonts.winAmount)
    love.graphics.setColor(1, 1, 0, pulse)
    love.graphics.printf("WIN", panelX, panelY + 8, panelW, "center")

    -- Total amount (LCD style)
    love.graphics.setColor(0.02, 0.06, 0.03)
    love.graphics.rectangle("fill", panelX + 8, panelY + 42, panelW - 16, 30, 3, 3)
    -- Scan lines
    love.graphics.setColor(0, 0.03, 0.01, 0.3)
    for ly = panelY + 44, panelY + 70, 2 do
      love.graphics.rectangle("fill", panelX + 9, ly, panelW - 18, 1)
    end
    love.graphics.setFont(fonts.lcd)
    love.graphics.setColor(0.2, 1, 0.3)
    love.graphics.printf(tostring(totalWinnings), panelX + 8, panelY + 45, panelW - 16, "center")

    -- Individual win lines
    love.graphics.setFont(fonts.winSide)
    love.graphics.setColor(1, 0.9, 0.5)
    local y = panelY + 82
    for _, win in ipairs(wins) do
      -- Payline name
      love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
      love.graphics.printf(win.payline, panelX + 4, y, panelW - 8, "center")
      y = y + 16
      -- Symbol + amount
      love.graphics.setColor(1, 0.9, 0.4)
      love.graphics.printf(win.symbol:upper() .. " x3", panelX + 4, y, panelW - 8, "center")
      y = y + 16
      love.graphics.setColor(0.2, 1, 0.3)
      love.graphics.printf("+" .. win.amount, panelX + 4, y, panelW - 8, "center")
      y = y + 24
    end

    love.graphics.setLineWidth(1)
  end
end

function M.drawWinningPaylines(wins, paylines)
  -- Glowing gold outlines on winning cells
  local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 6)

  for _, win in ipairs(wins) do
    for _, payline in ipairs(paylines) do
      if payline.name == win.payline then
        for _, pos in ipairs(payline.positions) do
          local reelNum = pos[1]
          local symbolPos = pos[2]
          local x = REEL_X_POSITIONS[reelNum]
          local y = REEL_Y + (symbolPos - 1) * SLOT_HEIGHT

          -- Glow effect
          love.graphics.setColor(1, 0.84, 0, 0.15 * pulse)
          love.graphics.rectangle("fill", x, y, SYMBOL_WIDTH, SYMBOL_HEIGHT, 4, 4)

          -- Gold border
          love.graphics.setColor(1, 0.84, 0, pulse)
          love.graphics.setLineWidth(3)
          love.graphics.rectangle("line", x, y, SYMBOL_WIDTH, SYMBOL_HEIGHT, 4, 4)
        end
        break
      end
    end
  end

  love.graphics.setLineWidth(1)
end

return M
