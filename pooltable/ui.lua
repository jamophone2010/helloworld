-- pooltable/ui.lua
-- Rendering for the pool table minigame (casino-style, matching Blackjack/Roulette aesthetic)

local M = {}

local balls = require("pooltable.balls")
local credits = require("pooltable.credits")
local winFx = require("casino_win_fx")

local fonts = {}
local uiTime = 0

M.buttons = {}

-- ─── CASINO COLOR PALETTE (matching Blackjack/Roulette) ──────
local C = {
  -- Felt & table
  felt        = {0.03, 0.32, 0.12},
  feltLight   = {0.06, 0.38, 0.16},
  feltDark    = {0.01, 0.2, 0.07},
  -- Wood rail
  rail        = {0.35, 0.22, 0.08},
  railLight   = {0.5, 0.35, 0.15},
  railDark    = {0.2, 0.12, 0.04},
  -- Accents
  gold        = {0.85, 0.72, 0.2},
  goldDim     = {0.65, 0.55, 0.18, 0.5},
  silver      = {0.78, 0.8, 0.84},
  cream       = {0.95, 0.92, 0.85},
  -- UI
  panelBg     = {0, 0, 0, 0.55},
  panelBorder = {0.85, 0.72, 0.2, 0.35},
}

function M.load()
  fonts.tiny = love.graphics.newFont(10)
  fonts.small = love.graphics.newFont(12)
  fonts.normal = love.graphics.newFont(16)
  fonts.large = love.graphics.newFont(28)
  fonts.xlarge = love.graphics.newFont(36)
  fonts.credits = love.graphics.newFont(18)
  fonts.ballNum = love.graphics.newFont(9)
  fonts.title = love.graphics.newFont(11)
end

local function formatNumber(n)
  return tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- ─── BUTTON RENDERING (matching Blackjack style) ─────────────

function M.drawButton(text, x, y, width, height, enabled)
  -- Button shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.rectangle("fill", x + 2, y + 2, width, height, 8)

  if enabled then
    love.graphics.setColor(0.15, 0.55, 0.2)
    love.graphics.rectangle("fill", x, y, width, height, 8)
    love.graphics.setColor(0.2, 0.65, 0.28)
    love.graphics.rectangle("fill", x + 1, y + 1, width - 2, height / 2, 8)
    love.graphics.setColor(0.3, 0.75, 0.35)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, width, height, 8)
  else
    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.rectangle("fill", x, y, width, height, 8)
    love.graphics.setColor(0.35, 0.35, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, width, height, 8)
  end

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(enabled and {1, 1, 1} or {0.55, 0.55, 0.55})
  love.graphics.printf(text, x, y + height / 2 - 8, width, "center")
  love.graphics.setLineWidth(1)

  return {x = x, y = y, width = width, height = height, enabled = enabled}
end

-- ─── POKER CHIP (matching Blackjack/Roulette style) ──────────

local function drawPokerChip(x, y, value, stackHeight)
  local radius = 15
  local color = credits.getChipColor(value)
  local label = credits.getChipLabel(value)
  stackHeight = stackHeight or 0
  local cy = y + stackHeight

  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.circle("fill", x + 2, cy + 3, radius)

  love.graphics.setColor(color[1] * 0.45, color[2] * 0.45, color[3] * 0.45)
  love.graphics.circle("fill", x, cy, radius)

  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.circle("fill", x, cy, radius - 1.5)

  love.graphics.setColor(1, 1, 1, 0.55)
  for angle = 0, 7 do
    local a = angle * math.pi / 4
    local nx = x + math.cos(a) * (radius - 3)
    local ny = cy + math.sin(a) * (radius - 3)
    love.graphics.circle("fill", nx, ny, 1.8)
  end

  love.graphics.setColor(1, 1, 1, 0.45)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", x, cy, radius - 5)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(color[1] * 0.82, color[2] * 0.82, color[3] * 0.82)
  love.graphics.circle("fill", x, cy, radius - 6)

  love.graphics.setFont(fonts.small)
  local textDark = (value == 1 or value == 25 or value == 10000 or value == 1000000)
  love.graphics.setColor(textDark and {0.1, 0.1, 0.1} or {1, 1, 1})
  local tw = fonts.small:getWidth(label)
  love.graphics.print(label, x - tw / 2, cy - 6)

  love.graphics.setColor(1, 1, 1, 0.12)
  love.graphics.arc("fill", x, cy, radius - 2, -math.pi * 0.8, -math.pi * 0.2)
end

-- ─── POOL TABLE RENDERING ────────────────────────────────────

function M.drawTable(tbl)
  -- Outer wooden frame (mahogany)
  love.graphics.setColor(C.railDark)
  love.graphics.rectangle("fill", tbl.outerX - 6, tbl.outerY - 6, tbl.outerW + 12, tbl.outerH + 12, 14)

  love.graphics.setColor(C.rail)
  love.graphics.rectangle("fill", tbl.outerX - 2, tbl.outerY - 2, tbl.outerW + 4, tbl.outerH + 4, 12)

  -- Rail highlight (top edge)
  love.graphics.setColor(C.railLight[1], C.railLight[2], C.railLight[3], 0.35)
  love.graphics.rectangle("fill", tbl.outerX - 1, tbl.outerY - 1, tbl.outerW + 2, 6, 12)

  -- Gold trim
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", tbl.outerX + 2, tbl.outerY + 2, tbl.outerW - 4, tbl.outerH - 4, 10)
  love.graphics.setLineWidth(1)

  -- Cushion rails (darker wood interior)
  love.graphics.setColor(C.railDark[1] * 1.3, C.railDark[2] * 1.3, C.railDark[3] * 1.3)
  love.graphics.rectangle("fill", tbl.outerX + 4, tbl.outerY + 4, tbl.outerW - 8, tbl.outerH - 8, 8)

  -- Felt surface (inner shadow)
  love.graphics.setColor(C.feltDark)
  love.graphics.rectangle("fill", tbl.playX - 3, tbl.playY - 3, tbl.playW + 6, tbl.playH + 6, 4)

  -- Main felt
  love.graphics.setColor(C.felt)
  love.graphics.rectangle("fill", tbl.playX, tbl.playY, tbl.playW, tbl.playH, 2)

  -- Felt texture (subtle noise, deterministic)
  love.graphics.setColor(C.feltLight[1], C.feltLight[2], C.feltLight[3], 0.06)
  math.randomseed(77)
  for _ = 1, 400 do
    local fx = tbl.playX + math.random() * tbl.playW
    local fy = tbl.playY + math.random() * tbl.playH
    love.graphics.circle("fill", fx, fy, 0.8)
  end
  math.randomseed(os.time())

  -- Head string line (quarter of the way across)
  local headStringX = tbl.playX + tbl.playW * 0.25
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.2)
  love.graphics.setLineWidth(1)
  love.graphics.line(headStringX, tbl.playY + 8, headStringX, tbl.playY + tbl.playH - 8)

  -- Foot spot (where rack goes)
  local footSpotX = tbl.playX + tbl.playW * 0.72
  local footSpotY = tbl.playY + tbl.playH / 2
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.3)
  love.graphics.circle("fill", footSpotX, footSpotY, 3)

  -- Head spot
  love.graphics.circle("fill", headStringX, tbl.playY + tbl.playH / 2, 3)

  -- Center spot
  love.graphics.circle("fill", tbl.playX + tbl.playW / 2, tbl.playY + tbl.playH / 2, 3)

  -- Draw pockets
  for _, pocket in ipairs(tbl.pockets) do
    -- Pocket shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("fill", pocket.x + 1, pocket.y + 1, pocket.radius + 2)
    -- Pocket hole
    love.graphics.setColor(0.02, 0.02, 0.02)
    love.graphics.circle("fill", pocket.x, pocket.y, pocket.radius)
    -- Pocket rim (metallic)
    love.graphics.setColor(0.4, 0.38, 0.35, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", pocket.x, pocket.y, pocket.radius + 1)
    love.graphics.setLineWidth(1)
    -- Pocket shine
    love.graphics.setColor(0.6, 0.58, 0.55, 0.25)
    love.graphics.arc("fill", pocket.x, pocket.y, pocket.radius, -math.pi * 0.8, -math.pi * 0.3)
  end

  -- Cushion nose lines (gold accent along cushion edges)
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.15)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", tbl.playX - 1, tbl.playY - 1, tbl.playW + 2, tbl.playH + 2, 2)
end

-- ─── BALL RENDERING ──────────────────────────────────────────

function M.drawBall(b)
  if not b.active then return end

  local x, y = b.x, b.y
  local r = balls.BALL_RADIUS
  local color = balls.BALL_COLORS[b.id]

  -- Drop shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.circle("fill", x + 1.5, y + 2, r)

  if balls.isCueBall(b.id) then
    -- Cue ball: pure white with shine
    love.graphics.setColor(color)
    love.graphics.circle("fill", x, y, r)
    -- Shine
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.circle("fill", x - r * 0.25, y - r * 0.25, r * 0.35)
    -- Edge
    love.graphics.setColor(0.7, 0.7, 0.7, 0.4)
    love.graphics.circle("line", x, y, r)

  elseif balls.isStripe(b.id) then
    -- Stripe ball: white base with colored band
    love.graphics.setColor(0.95, 0.95, 0.92)
    love.graphics.circle("fill", x, y, r)

    -- Colored stripe band (horizontal)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x - r, y - r * 0.4, r * 2, r * 0.8)
    -- Clip to circle by redrawing white arcs
    love.graphics.setColor(0.95, 0.95, 0.92)
    love.graphics.arc("fill", x, y, r, -math.pi * 0.7, -math.pi * 0.3)
    love.graphics.arc("fill", x, y, r, math.pi * 0.3, math.pi * 0.7)

    -- Number circle (white center)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", x, y, r * 0.42)
    -- Number
    love.graphics.setFont(fonts.ballNum)
    love.graphics.setColor(0.1, 0.1, 0.1)
    local numStr = tostring(b.id)
    local nw = fonts.ballNum:getWidth(numStr)
    love.graphics.print(numStr, x - nw / 2, y - 4)

    -- Shine
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.circle("fill", x - r * 0.2, y - r * 0.2, r * 0.3)
    -- Edge
    love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
    love.graphics.circle("line", x, y, r)

  else
    -- Solid ball: full color with number
    love.graphics.setColor(color)
    love.graphics.circle("fill", x, y, r)

    -- Number circle (white center)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", x, y, r * 0.42)
    -- Number
    love.graphics.setFont(fonts.ballNum)
    love.graphics.setColor(0.1, 0.1, 0.1)
    local numStr = tostring(b.id)
    local nw = fonts.ballNum:getWidth(numStr)
    love.graphics.print(numStr, x - nw / 2, y - 4)

    -- Shine
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.circle("fill", x - r * 0.2, y - r * 0.2, r * 0.3)
    -- Edge
    love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 0.4)
    love.graphics.circle("line", x, y, r)
  end
end

function M.drawBalls(ballList)
  -- Draw in order so cue ball is on top
  for _, b in ipairs(ballList) do
    if b.active and b.id ~= 0 then
      M.drawBall(b)
    end
  end
  -- Cue ball last (on top)
  for _, b in ipairs(ballList) do
    if b.active and b.id == 0 then
      M.drawBall(b)
    end
  end
end

-- ─── CUE STICK RENDERING ────────────────────────────────────

function M.drawCue(cue, cueBall)
  if not cue.visible or not cueBall or not cueBall.active then return end

  local cx, cy = cueBall.x, cueBall.y
  local angle = cue.angle
  local pullBack = cue.pullBack

  -- Cue stick dimensions
  local cueLength = 180
  local cueThick = 4
  local tipThick = 2.5

  -- Start position: away from ball in opposite direction of aim
  local startDist = balls.BALL_RADIUS + 6 + pullBack
  local sx = cx - math.cos(angle) * startDist
  local sy = cy - math.sin(angle) * startDist
  local ex = sx - math.cos(angle) * cueLength
  local ey = sy - math.sin(angle) * cueLength

  -- Cue shadow
  love.graphics.setColor(0, 0, 0, 0.2)
  love.graphics.setLineWidth(cueThick + 2)
  love.graphics.line(sx + 2, sy + 2, ex + 2, ey + 2)

  -- Cue body (wooden shaft)
  love.graphics.setColor(0.65, 0.45, 0.2)
  love.graphics.setLineWidth(cueThick)
  love.graphics.line(sx, sy, ex, ey)

  -- Cue wrap (leather grip area, back half)
  local mx = (sx + ex) / 2
  local my = (sy + ey) / 2
  love.graphics.setColor(0.2, 0.15, 0.08)
  love.graphics.setLineWidth(cueThick + 0.5)
  love.graphics.line(mx, my, ex, ey)

  -- Cue ferrule (white band near tip)
  local ferruleX = sx - math.cos(angle) * (-3)
  local ferruleY = sy - math.sin(angle) * (-3)
  love.graphics.setColor(0.9, 0.88, 0.85)
  love.graphics.setLineWidth(tipThick + 1)
  love.graphics.line(sx, sy, ferruleX, ferruleY)

  -- Cue tip (blue chalk)
  love.graphics.setColor(0.3, 0.5, 0.8)
  love.graphics.circle("fill", sx, sy, tipThick)

  love.graphics.setLineWidth(1)

  -- Aiming line (dotted, extends from cue ball in aim direction)
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.25)
  local aimDist = 120
  local dashLen = 6
  local gapLen = 4
  local dist = 0
  local startX = cx + math.cos(angle) * (balls.BALL_RADIUS + 2)
  local startY = cy + math.sin(angle) * (balls.BALL_RADIUS + 2)
  while dist < aimDist do
    local d1 = dist
    local d2 = math.min(dist + dashLen, aimDist)
    love.graphics.line(
      startX + math.cos(angle) * d1,
      startY + math.sin(angle) * d1,
      startX + math.cos(angle) * d2,
      startY + math.sin(angle) * d2
    )
    dist = dist + dashLen + gapLen
  end
end

-- ─── POWER BAR ───────────────────────────────────────────────

function M.drawPowerBar(cue)
  local barX = 1210
  local barY = 150
  local barW = 22
  local barH = 300

  -- Background panel
  love.graphics.setColor(C.panelBg)
  love.graphics.rectangle("fill", barX - 12, barY - 30, barW + 24, barH + 50, 8)
  love.graphics.setColor(C.panelBorder)
  love.graphics.rectangle("line", barX - 12, barY - 30, barW + 24, barH + 50, 8)

  -- Label
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.goldDim)
  love.graphics.printf("POWER", barX - 12, barY - 25, barW + 24, "center")

  -- Bar background
  love.graphics.setColor(0.15, 0.15, 0.15)
  love.graphics.rectangle("fill", barX, barY, barW, barH, 4)

  -- Gradient fill (green at bottom → yellow → red at top)
  local fillH = barH * cue.power
  if fillH > 0 then
    local segments = math.floor(fillH)
    for i = 0, segments do
      local ratio = i / barH
      local r, g, b2
      if ratio < 0.5 then
        r = ratio * 2
        g = 0.8
        b2 = 0.1
      else
        r = 0.9
        g = 0.8 - (ratio - 0.5) * 1.6
        b2 = 0.1
      end
      love.graphics.setColor(r, g, b2, 0.85)
      love.graphics.rectangle("fill", barX + 1, barY + barH - i, barW - 2, 1)
    end
  end

  -- Bar outline
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.4)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", barX, barY, barW, barH, 4)

  -- Power percentage
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(C.cream)
  love.graphics.printf(math.floor(cue.power * 100) .. "%", barX - 12, barY + barH + 8, barW + 24, "center")
end

-- ─── CREDITS PANEL ───────────────────────────────────────────

local function drawCreditsPanel(bank)
  local px = 15
  local py = 15
  local panelW = 200
  local panelH = 55

  winFx.drawCreditCounter(px, py, panelW, panelH, "CREDITS")

  love.graphics.setColor(C.panelBg)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 8)
  love.graphics.setColor(C.panelBorder)
  love.graphics.rectangle("line", px, py, panelW, panelH, 8)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.goldDim)
  love.graphics.print("CREDITS", px + 12, py + 6)

  local displayCredits = winFx.getDisplayedCredits() or bank.balance

  love.graphics.setFont(fonts.credits)
  love.graphics.setColor(C.cream)
  love.graphics.print(formatNumber(displayCredits), px + 12, py + 24)
end

-- ─── POCKETED BALLS DISPLAY ─────────────────────────────────

local function drawPocketedBalls(ballList, playerType)
  local px = 15
  local py = 605
  local panelW = 200
  local panelH = 80

  love.graphics.setColor(C.panelBg)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 8)
  love.graphics.setColor(C.panelBorder)
  love.graphics.rectangle("line", px, py, panelW, panelH, 8)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.goldDim)
  love.graphics.print("YOUR BALLS: " .. (playerType and string.upper(playerType) or "TBD"), px + 8, py + 5)

  -- Draw pocketed balls in a row
  local bx = px + 18
  local by = py + 35
  local count = 0
  for _, b in ipairs(ballList) do
    if b.pocketed and b.id ~= 0 and b.id ~= 8 then
      if playerType == "solids" and balls.isSolid(b.id) then
        local color = balls.BALL_COLORS[b.id]
        love.graphics.setColor(color)
        love.graphics.circle("fill", bx + count * 22, by, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", bx + count * 22, by, 3.5)
        love.graphics.setFont(fonts.ballNum)
        love.graphics.setColor(0.1, 0.1, 0.1)
        local ns = tostring(b.id)
        love.graphics.print(ns, bx + count * 22 - fonts.ballNum:getWidth(ns) / 2, by - 4)
        count = count + 1
      elseif playerType == "stripes" and balls.isStripe(b.id) then
        love.graphics.setColor(0.9, 0.9, 0.88)
        love.graphics.circle("fill", bx + count * 22, by, 8)
        local color = balls.BALL_COLORS[b.id]
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", bx + count * 22 - 8, by - 3, 16, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", bx + count * 22, by, 3.5)
        love.graphics.setFont(fonts.ballNum)
        love.graphics.setColor(0.1, 0.1, 0.1)
        local ns = tostring(b.id)
        love.graphics.print(ns, bx + count * 22 - fonts.ballNum:getWidth(ns) / 2, by - 4)
        count = count + 1
      end
    end
  end

  if count == 0 then
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(C.cream[1], C.cream[2], C.cream[3], 0.4)
    love.graphics.print("None yet", px + 12, py + 30)
  end

  -- Opponent's pocketed balls
  local opponentType = nil
  if playerType == "solids" then opponentType = "stripes"
  elseif playerType == "stripes" then opponentType = "solids"
  end

  if opponentType then
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(C.goldDim)
    love.graphics.print("OPPONENT: " .. string.upper(opponentType), px + 8, py + 52)

    local ox = px + 18
    local oy = py + 70
    local ocount = 0
    for _, b in ipairs(ballList) do
      if b.pocketed and b.id ~= 0 and b.id ~= 8 then
        if opponentType == "solids" and balls.isSolid(b.id) then
          local color = balls.BALL_COLORS[b.id]
          love.graphics.setColor(color)
          love.graphics.circle("fill", ox + ocount * 16, oy, 5)
          ocount = ocount + 1
        elseif opponentType == "stripes" and balls.isStripe(b.id) then
          local color = balls.BALL_COLORS[b.id]
          love.graphics.setColor(color[1], color[2], color[3], 0.6)
          love.graphics.circle("fill", ox + ocount * 16, oy, 5)
          ocount = ocount + 1
        end
      end
    end
  end
end

-- ─── CHIP SELECTOR ───────────────────────────────────────────

local function drawChipSelector(bank)
  local px = 15
  local py = 80
  local panelW = 200
  local panelH = 115

  love.graphics.setColor(C.panelBg)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 8)
  love.graphics.setColor(C.panelBorder)
  love.graphics.rectangle("line", px, py, panelW, panelH, 8)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.goldDim)
  love.graphics.print("SELECT CHIP (UP/DOWN)", px + 12, py + 6)

  local chipValue = credits.getSelectedChipValue(bank)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(C.cream)
  love.graphics.print("Active:", px + 12, py + 24)
  drawPokerChip(px + 90, py + 32, chipValue)
  love.graphics.setColor(C.cream)
  love.graphics.print(credits.getChipLabel(chipValue), px + 110, py + 26)

  local chipX = px + 16
  local chipRow = 1
  for i, value in ipairs(credits.CHIP_VALUES) do
    if credits.canAfford(bank, value) then
      local chipY = (chipRow == 1) and (py + 58) or (py + 92)
      if i == bank.selectedChipIndex then
        local pulse = 0.5 + 0.4 * math.sin(uiTime * 5)
        love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], pulse * 0.45)
        love.graphics.circle("fill", chipX + 14, chipY, 18)
      end
      drawPokerChip(chipX + 14, chipY, value)
      chipX = chipX + 36
      if chipX > px + panelW - 30 and chipRow == 1 then
        chipX = px + 16
        chipRow = 2
      end
    end
  end
end

-- ─── GAME INFO PANEL ─────────────────────────────────────────

local function drawGameInfo(gameState)
  local px = 1150
  local py = 15
  local panelW = 200
  local panelH = 120

  love.graphics.setColor(C.panelBg)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 8)
  love.graphics.setColor(C.panelBorder)
  love.graphics.rectangle("line", px, py, panelW, panelH, 8)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.gold)
  love.graphics.print("8-BALL POOL", px + 8, py + 6)

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(C.cream)

  -- Turn indicator
  local turnText = gameState.isPlayerTurn and "YOUR TURN" or "OPPONENT"
  local turnColor = gameState.isPlayerTurn and {0.3, 1, 0.4} or {1, 0.4, 0.3}
  love.graphics.setColor(turnColor)
  love.graphics.print(turnText, px + 8, py + 24)

  -- Bet amount
  love.graphics.setColor(C.cream)
  love.graphics.print("Bet: " .. formatNumber(gameState.betAmount), px + 8, py + 44)

  -- Ball assignment
  love.graphics.setColor(C.goldDim)
  local assignText = "Assigned: "
  if gameState.playerType then
    assignText = assignText .. (gameState.playerType == "solids" and "Solids (1-7)" or "Stripes (9-15)")
  else
    assignText = assignText .. "TBD"
  end
  love.graphics.setFont(fonts.tiny)
  love.graphics.print(assignText, px + 8, py + 66)

  -- Shot count
  love.graphics.setColor(C.cream[1], C.cream[2], C.cream[3], 0.6)
  love.graphics.print("Shots: " .. (gameState.shotCount or 0), px + 8, py + 84)

  -- Balls remaining
  if gameState.playerType then
    local remaining = 0
    for _, b in ipairs(gameState.balls or {}) do
      if b.active and b.id ~= 0 and b.id ~= 8 then
        if gameState.playerType == "solids" and balls.isSolid(b.id) then
          remaining = remaining + 1
        elseif gameState.playerType == "stripes" and balls.isStripe(b.id) then
          remaining = remaining + 1
        end
      end
    end
    love.graphics.print("Remaining: " .. remaining, px + 8, py + 100)
  end
end

-- ─── CUE BALL PLACEMENT INDICATOR ───────────────────────────

local function drawCueBallPlacement(mouseX, mouseY, tbl)
  local pulse = 0.5 + 0.3 * math.sin(uiTime * 6)
  love.graphics.setColor(1, 1, 1, pulse * 0.5)
  love.graphics.circle("line", mouseX, mouseY, balls.BALL_RADIUS + 4)
  love.graphics.setColor(1, 1, 1, pulse * 0.3)
  love.graphics.circle("fill", mouseX, mouseY, balls.BALL_RADIUS)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.cream[1], C.cream[2], C.cream[3], 0.7)
  love.graphics.printf("Click to place cue ball", tbl.playX, tbl.playY + tbl.playH + 10, tbl.playW, "center")
end

-- ─── RESULT BANNER ───────────────────────────────────────────

local function drawResultBanner(result, payout)
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 383, 300, 600, 100, 14)
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", 383, 300, 600, 100, 14)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 1, 0.6)
  love.graphics.printf(result, 383, 310, 600, "center")

  if payout and payout > 0 then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(0.3, 1, 0.4)
    love.graphics.printf("Won: +" .. formatNumber(payout) .. " credits", 383, 355, 600, "center")
  end
end

-- ─── MAIN DRAW ───────────────────────────────────────────────

function M.drawGameUI(gameState)
  uiTime = uiTime + (love.timer.getDelta and love.timer.getDelta() or 0.016)

  love.graphics.setBackgroundColor(0.02, 0.08, 0.03)

  -- Table
  M.drawTable(gameState.table)

  -- Balls
  M.drawBalls(gameState.balls)

  -- Cue stick (only when aiming)
  if gameState.state == "aiming" and gameState.isPlayerTurn then
    local cueBall = balls.getCueBall(gameState.balls)
    M.drawCue(gameState.cue, cueBall)
    M.drawPowerBar(gameState.cue)
  end

  -- Cue ball placement
  if gameState.state == "placing_cue" then
    local mx, my = love.mouse.getPosition()
    drawCueBallPlacement(mx, my, gameState.table)
  end

  -- Credits panel
  drawCreditsPanel(gameState.bank)

  -- Pocketed balls display
  drawPocketedBalls(gameState.balls, gameState.playerType)

  -- Game info panel
  drawGameInfo(gameState)

  -- State-specific UI
  M.buttons = {}

  if gameState.state == "betting" then
    -- Bet amount in center
    if gameState.bank.currentBet > 0 then
      love.graphics.setFont(fonts.normal)
      love.graphics.setColor(C.cream)
      love.graphics.printf("Bet: " .. formatNumber(gameState.bank.currentBet), 0, 610, 1366, "center")
    end

    M.buttons.play = M.drawButton("RACK 'EM UP", 533, 660, 160, 40, credits.canPlaceBet(gameState.bank))
    M.buttons.betUp = M.drawButton("+BET", 733, 660, 80, 40, true)
    M.buttons.betDown = M.drawButton("-BET", 833, 660, 80, 40, true)

    drawChipSelector(gameState.bank)

    -- Instructions
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(C.cream[1], C.cream[2], C.cream[3], 0.5)
    love.graphics.printf("Place your bet and rack 'em up for a game of 8-Ball!", 0, 640, 1366, "center")

  elseif gameState.state == "aiming" and gameState.isPlayerTurn then
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(C.cream[1], C.cream[2], C.cream[3], 0.5)
    love.graphics.printf("Aim with mouse • Hold SPACE or click to charge • Release to shoot", 0, 740, 1366, "center")

  elseif gameState.state == "shooting" then
    -- Balls in motion, no UI

  elseif gameState.state == "opponent_turn" then
    local pulse = 0.5 + 0.3 * math.sin(uiTime * 3)
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(C.cream[1], C.cream[2], C.cream[3], pulse)
    love.graphics.printf("Opponent is thinking...", 0, 700, 1366, "center")

  elseif gameState.state == "game_over" then
    drawResultBanner(gameState.result, gameState.payout)
    M.buttons.newGame = M.drawButton("NEW GAME", 533, 660, 140, 40, true)
    M.buttons.quit = M.drawButton("QUIT", 693, 660, 100, 40, true)
  end
end

function M.checkButtonClick(x, y)
  for name, button in pairs(M.buttons) do
    if button.enabled and
       x >= button.x and x <= button.x + button.width and
       y >= button.y and y <= button.y + button.height then
      return name
    end
  end
  return nil
end

return M
