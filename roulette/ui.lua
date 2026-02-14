local M = {}

local wheel = require("roulette.wheel")
local rouletteTable = require("roulette.table")
local credits = require("roulette.credits")
local winFx = require("casino_win_fx")

local fonts = {}
local uiTime = 0

local WHEEL_X = 530
local WHEEL_Y = 560
local WHEEL_RADIUS = 170

-- ─── CASINO COLOR PALETTE ────────────────────────────────────
local C = {
  -- Felt & table
  felt         = {0.03, 0.28, 0.1},
  feltLight    = {0.05, 0.35, 0.14},
  feltDark     = {0.01, 0.18, 0.06},
  -- Wood rail
  rail         = {0.32, 0.2, 0.08},
  railLight    = {0.48, 0.32, 0.14},
  railDark     = {0.18, 0.1, 0.04},
  -- Accents
  gold         = {0.85, 0.72, 0.2},
  goldDim      = {0.65, 0.55, 0.18, 0.5},
  silver       = {0.78, 0.8, 0.84},
  cream        = {0.95, 0.92, 0.85},
  -- Roulette colors
  red          = {0.75, 0.08, 0.08},
  redLight     = {0.88, 0.15, 0.12},
  black        = {0.08, 0.08, 0.1},
  blackLight   = {0.18, 0.18, 0.2},
  green        = {0.05, 0.45, 0.12},
  greenLight   = {0.08, 0.55, 0.18},
  -- UI
  panelBg      = {0, 0, 0, 0.55},
  panelBorder  = {0.85, 0.72, 0.2, 0.35},
}

function M.load()
  fonts.tiny = love.graphics.newFont(10)
  fonts.small = love.graphics.newFont(12)
  fonts.normal = love.graphics.newFont(16)
  fonts.large = love.graphics.newFont(28)
  fonts.xlarge = love.graphics.newFont(36)
  fonts.tableNum = love.graphics.newFont(15)
  fonts.tableLabel = love.graphics.newFont(12)
  fonts.wheelNum = love.graphics.newFont(11)
  fonts.wheelNumBold = love.graphics.newFont(13)
  fonts.credits = love.graphics.newFont(18)
end

-- ─── UTILITY ─────────────────────────────────────────────────

local function formatNumber(n)
  return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- ─── POKER CHIP ──────────────────────────────────────────────

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
  love.graphics.setFont(fonts.small)
  local textDark = (value == 1 or value == 25 or value == 10000 or value == 1000000)
  love.graphics.setColor(textDark and {0.1, 0.1, 0.1} or {1, 1, 1})
  local tw = fonts.small:getWidth(label)
  love.graphics.print(label, x - tw / 2, cy - 6)

  -- Shine highlight
  love.graphics.setColor(1, 1, 1, 0.12)
  love.graphics.arc("fill", x, cy, radius - 2, -math.pi * 0.8, -math.pi * 0.2)
end

local function drawChipStack(x, y, stack)
  local totalHeight = 0
  for _, chip in ipairs(stack) do
    for j = 1, math.min(chip.count, 10) do
      drawPokerChip(x, y, chip.value, -totalHeight)
      totalHeight = totalHeight + 4
    end
    if chip.count > 10 then
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 1, 0)
      love.graphics.print("x" .. chip.count, x + 18, y - totalHeight - 5)
    end
  end
end

-- ─── WHEEL RENDERING ─────────────────────────────────────────

function M.drawWheel(w)
  -- Outer decorative frame (dark mahogany)
  love.graphics.setColor(C.railDark)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS + 18)
  -- Mahogany ring
  love.graphics.setColor(C.rail)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS + 14)
  -- Rail highlight (top crescent)
  love.graphics.setColor(C.railLight[1], C.railLight[2], C.railLight[3], 0.4)
  love.graphics.arc("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS + 14, -math.pi * 0.85, -math.pi * 0.15)

  -- Gold trim ring
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.7)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", WHEEL_X, WHEEL_Y, WHEEL_RADIUS + 8)
  love.graphics.setLineWidth(1)

  -- Chrome ball track ring
  love.graphics.setColor(0.55, 0.58, 0.6)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS + 6)
  love.graphics.setColor(0.4, 0.42, 0.45)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS + 1)

  -- Main wheel face (dark)
  love.graphics.setColor(0.06, 0.06, 0.08)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS)

  -- Pocket segments
  local numPockets = #wheel.POCKETS
  local pocketAngle = 2 * math.pi / numPockets

  for i = 1, numPockets do
    local angle = w.angle + (i - 1) * pocketAngle
    local number = wheel.POCKETS[i]
    local color = wheel.getColor(number)

    local startAngle = angle - pocketAngle / 2
    local endAngle = angle + pocketAngle / 2

    -- Pocket color
    if color == "red" then
      love.graphics.setColor(C.red)
    elseif color == "black" then
      love.graphics.setColor(C.black)
    else
      love.graphics.setColor(C.green)
    end
    love.graphics.arc("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS - 4, startAngle, endAngle)

    -- Lighter inner edge for 3D depth
    if color == "red" then
      love.graphics.setColor(C.redLight[1], C.redLight[2], C.redLight[3], 0.35)
    elseif color == "black" then
      love.graphics.setColor(C.blackLight[1], C.blackLight[2], C.blackLight[3], 0.35)
    else
      love.graphics.setColor(C.greenLight[1], C.greenLight[2], C.greenLight[3], 0.35)
    end
    love.graphics.arc("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS - 30, startAngle, endAngle)

    -- Pocket divider lines (gold)
    love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.5)
    love.graphics.setLineWidth(1)
    local sx = WHEEL_X + math.cos(startAngle) * (WHEEL_RADIUS - 45)
    local sy = WHEEL_Y + math.sin(startAngle) * (WHEEL_RADIUS - 45)
    local ex = WHEEL_X + math.cos(startAngle) * (WHEEL_RADIUS - 4)
    local ey = WHEEL_Y + math.sin(startAngle) * (WHEEL_RADIUS - 4)
    love.graphics.line(sx, sy, ex, ey)

    -- Number text
    local textRadius = WHEEL_RADIUS - 22
    local tx = WHEEL_X + math.cos(angle) * textRadius
    local ty = WHEEL_Y + math.sin(angle) * textRadius
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.wheelNum)
    love.graphics.printf(tostring(number), tx - 12, ty - 6, 24, "center")
  end

  -- Inner decorative rings
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.4)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", WHEEL_X, WHEEL_Y, WHEEL_RADIUS - 45)
  love.graphics.setLineWidth(1)

  -- Inner cone (dark gradient center)
  love.graphics.setColor(0.12, 0.12, 0.14)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS - 48)

  -- Cone spokes
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.3)
  for spoke = 0, 7 do
    local a = w.angle + spoke * math.pi / 4
    local ix = WHEEL_X + math.cos(a) * 18
    local iy = WHEEL_Y + math.sin(a) * 18
    local ox = WHEEL_X + math.cos(a) * (WHEEL_RADIUS - 50)
    local oy = WHEEL_Y + math.sin(a) * (WHEEL_RADIUS - 50)
    love.graphics.line(ix, iy, ox, oy)
  end

  -- Center hub
  love.graphics.setColor(0.35, 0.35, 0.38)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, 20)
  love.graphics.setColor(0.45, 0.45, 0.48)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, 15)
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.6)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, 8)
  love.graphics.setColor(0.5, 0.5, 0.52)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, 4)

  -- Metallic shine on wheel
  love.graphics.setColor(1, 1, 1, 0.04)
  love.graphics.arc("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS - 5, -math.pi * 0.7, -math.pi * 0.3)

  -- Wheel marker / fret (diamond indicator at top)
  love.graphics.setColor(C.gold)
  local markerX = WHEEL_X
  local markerY = WHEEL_Y - WHEEL_RADIUS - 10
  love.graphics.polygon("fill",
    markerX, markerY + 12,
    markerX - 6, markerY,
    markerX + 6, markerY
  )
  -- Marker shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.polygon("fill",
    markerX + 1, markerY + 13,
    markerX - 5, markerY + 1,
    markerX + 7, markerY + 1
  )
end

function M.drawBall(b, w)
  local ballTrackRadius = WHEEL_RADIUS + 2
  local pocketRadius = WHEEL_RADIUS - 18
  local angle = b.angle

  -- When settling/stopped, ball drops into the pocket
  local radius
  if b.phase == "stopped" and b.finalPocket then
    angle = w.angle + (b.finalPocket - 1) * (2 * math.pi / b.numPockets)
    radius = pocketRadius
  elseif b.phase == "settling" then
    -- Interpolate from track to pocket
    local t = math.min(b.timer / 0.5, 1)
    radius = ballTrackRadius + (pocketRadius - ballTrackRadius) * t
  else
    radius = ballTrackRadius
  end

  local bx = WHEEL_X + math.cos(angle) * radius
  local by = WHEEL_Y + math.sin(angle) * radius

  -- Ball shadow
  love.graphics.setColor(0, 0, 0, 0.4)
  love.graphics.circle("fill", bx + 2, by + 2, 6)

  -- Silver ball body
  love.graphics.setColor(0.82, 0.84, 0.86)
  love.graphics.circle("fill", bx, by, 5.5)

  -- Shine highlight
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.circle("fill", bx - 1.5, by - 1.5, 2.5)

  -- Edge definition
  love.graphics.setColor(0.5, 0.52, 0.55, 0.6)
  love.graphics.circle("line", bx, by, 5.5)
end

-- ─── TABLE RENDERING ─────────────────────────────────────────

function M.drawTable(tbl)
  local gridX = tbl.gridX
  local gridY = tbl.gridY
  local cellW = tbl.cellWidth
  local cellH = tbl.cellHeight
  local tableW = 13 * cellW + 30
  local tableH = 7 * cellH + 30

  -- Outer wooden frame
  love.graphics.setColor(C.railDark)
  love.graphics.rectangle("fill", gridX - 18, gridY - 18, tableW + 6, tableH + 6, 10)
  love.graphics.setColor(C.rail)
  love.graphics.rectangle("fill", gridX - 15, gridY - 15, tableW, tableH, 8)
  love.graphics.setColor(C.railLight[1], C.railLight[2], C.railLight[3], 0.3)
  love.graphics.rectangle("fill", gridX - 14, gridY - 14, tableW - 2, 4, 8)

  -- Gold trim
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.5)
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", gridX - 12, gridY - 12, tableW - 6, tableH - 6, 6)
  love.graphics.setLineWidth(1)

  -- Felt background
  love.graphics.setColor(C.felt)
  love.graphics.rectangle("fill", gridX - 10, gridY - 10, tableW - 10, tableH - 10, 4)

  -- Felt texture (subtle noise)
  love.graphics.setColor(C.feltLight[1], C.feltLight[2], C.feltLight[3], 0.06)
  math.randomseed(99)
  for _ = 1, 200 do
    local fx = gridX - 8 + math.random() * (tableW - 14)
    local fy = gridY - 8 + math.random() * (tableH - 14)
    love.graphics.circle("fill", fx, fy, 0.8)
  end
  math.randomseed(os.time())

  love.graphics.setFont(fonts.tableNum)

  -- ─── Zero cells ─────────
  -- 0 cell
  local function drawNumberCell(x, y, w, h, number, isGreen)
    local clr = wheel.getColor(number)
    if isGreen or clr == "green" then
      love.graphics.setColor(C.green)
    elseif clr == "red" then
      love.graphics.setColor(C.red)
    else
      love.graphics.setColor(C.black)
    end
    love.graphics.rectangle("fill", x, y, w, h, 2)

    -- Subtle inner bevel (lighter top-left)
    if clr == "red" then
      love.graphics.setColor(C.redLight[1], C.redLight[2], C.redLight[3], 0.2)
    elseif clr == "green" then
      love.graphics.setColor(C.greenLight[1], C.greenLight[2], C.greenLight[3], 0.2)
    else
      love.graphics.setColor(C.blackLight[1], C.blackLight[2], C.blackLight[3], 0.2)
    end
    love.graphics.rectangle("fill", x, y, w, 2)
    love.graphics.rectangle("fill", x, y, 2, h)

    -- Cell border
    love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.35)
    love.graphics.rectangle("line", x, y, w, h, 2)

    -- Number text
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(tostring(number), x, y + h / 2 - 8, w, "center")
  end

  drawNumberCell(gridX, gridY, cellW, cellH, "0", true)
  drawNumberCell(gridX + cellW, gridY, cellW, cellH, "00", true)

  -- ─── Number grid ─────────
  for row = 1, 3 do
    for col = 1, 12 do
      local x = gridX + (col - 1) * cellW
      local y = gridY + row * cellH
      local number = rouletteTable.GRID_NUMBERS[row][col]
      drawNumberCell(x, y, cellW, cellH, number, false)
    end
  end

  -- ─── Dozen bets ─────────
  love.graphics.setFont(fonts.tableLabel)
  local dozenLabels = {"1st 12", "2nd 12", "3rd 12"}
  for i = 1, 3 do
    local x = gridX + (i - 1) * 4 * cellW
    local y = gridY + 4 * cellH
    love.graphics.setColor(C.feltDark)
    love.graphics.rectangle("fill", x, y, 4 * cellW, cellH, 2)
    love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.35)
    love.graphics.rectangle("line", x, y, 4 * cellW, cellH, 2)
    love.graphics.setColor(C.cream)
    love.graphics.printf(dozenLabels[i], x, y + cellH / 2 - 6, 4 * cellW, "center")
  end

  -- ─── Column bets ─────────
  for i = 1, 3 do
    local x = gridX + 12 * cellW
    local y = gridY + i * cellH
    love.graphics.setColor(C.feltDark)
    love.graphics.rectangle("fill", x, y, cellW, cellH, 2)
    love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.35)
    love.graphics.rectangle("line", x, y, cellW, cellH, 2)
    love.graphics.setColor(C.cream)
    love.graphics.printf("2:1", x, y + cellH / 2 - 6, cellW, "center")
  end

  -- ─── Outside bets (bottom row) ─────────
  local outsideLabels = {"1-18", "EVEN", "RED", "BLACK", "ODD", "19-36"}
  local sectionWidth = (12 * cellW) / 6
  for i = 1, 6 do
    local x = gridX + (i - 1) * sectionWidth
    local y = gridY + 5 * cellH
    local label = outsideLabels[i]

    if label == "RED" then
      love.graphics.setColor(C.red)
    elseif label == "BLACK" then
      love.graphics.setColor(C.black)
    else
      love.graphics.setColor(C.feltDark)
    end
    love.graphics.rectangle("fill", x, y, sectionWidth, cellH, 2)

    -- Bevel
    if label == "RED" then
      love.graphics.setColor(C.redLight[1], C.redLight[2], C.redLight[3], 0.2)
    elseif label == "BLACK" then
      love.graphics.setColor(C.blackLight[1], C.blackLight[2], C.blackLight[3], 0.2)
    else
      love.graphics.setColor(1, 1, 1, 0.05)
    end
    love.graphics.rectangle("fill", x, y, sectionWidth, 2)

    love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.35)
    love.graphics.rectangle("line", x, y, sectionWidth, cellH, 2)

    -- Diamond icon for RED/BLACK cells
    if label == "RED" or label == "BLACK" then
      local cx = x + sectionWidth / 2
      local cy = y + cellH / 2
      love.graphics.setColor(1, 1, 1, 0.8)
      love.graphics.polygon("fill",
        cx, cy - 8,
        cx + 6, cy,
        cx, cy + 8,
        cx - 6, cy
      )
      if label == "RED" then
        love.graphics.setColor(C.red)
      else
        love.graphics.setColor(C.black)
      end
      love.graphics.polygon("fill",
        cx, cy - 5,
        cx + 4, cy,
        cx, cy + 5,
        cx - 4, cy
      )
    else
      love.graphics.setColor(C.cream)
      love.graphics.printf(label, x, y + cellH / 2 - 6, sectionWidth, "center")
    end
  end
end

-- ─── BETS ON TABLE ───────────────────────────────────────────

local function getBetPosition(bet, tbl)
  local gridX = tbl.gridX
  local gridY = tbl.gridY
  local cellW = tbl.cellWidth
  local cellH = tbl.cellHeight
  local sectionWidth = (12 * cellW) / 6

  if bet.type == "straight" then
    local number = bet.numbers[1]
    if number == 0 or number == "0" then
      return gridX + cellW / 2, gridY + cellH / 2, cellW
    elseif number == "00" then
      return gridX + cellW + cellW / 2, gridY + cellH / 2, cellW
    else
      local x, y = rouletteTable.getNumberPosition(tbl, number)
      if x and y then
        return x + cellW / 2, y + cellH / 2, cellW
      end
    end
  elseif bet.type == "dozen" then
    local firstNum = bet.numbers[1]
    local section = math.floor((firstNum - 1) / 12)
    return gridX + section * 4 * cellW + 2 * cellW, gridY + 4 * cellH + cellH / 2, 4 * cellW
  elseif bet.type == "column" then
    local firstNum = bet.numbers[1]
    local row = (firstNum == 3) and 1 or (firstNum == 2) and 2 or 3
    return gridX + 12 * cellW + cellW / 2, gridY + row * cellH + cellH / 2, cellW
  elseif bet.type == "low" then
    return gridX + sectionWidth / 2, gridY + 5 * cellH + cellH / 2, sectionWidth
  elseif bet.type == "even" then
    return gridX + sectionWidth + sectionWidth / 2, gridY + 5 * cellH + cellH / 2, sectionWidth
  elseif bet.type == "red" then
    return gridX + 2 * sectionWidth + sectionWidth / 2, gridY + 5 * cellH + cellH / 2, sectionWidth
  elseif bet.type == "black" then
    return gridX + 3 * sectionWidth + sectionWidth / 2, gridY + 5 * cellH + cellH / 2, sectionWidth
  elseif bet.type == "odd" then
    return gridX + 4 * sectionWidth + sectionWidth / 2, gridY + 5 * cellH + cellH / 2, sectionWidth
  elseif bet.type == "high" then
    return gridX + 5 * sectionWidth + sectionWidth / 2, gridY + 5 * cellH + cellH / 2, sectionWidth
  end
  return nil, nil, nil
end

function M.drawBets(bets, tbl)
  for _, bet in ipairs(bets.active) do
    local cx, cy, width = getBetPosition(bet, tbl)
    if cx and cy then
      local chipStack = credits.getChipStack(bet.amount)
      drawChipStack(cx, cy, chipStack)

      if bet.amount >= 1000 then
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(1, 1, 1)
        local amountText = bet.amount >= 1000000 and (bet.amount / 1000000) .. "M" or
                          bet.amount >= 1000 and (bet.amount / 1000) .. "K" or
                          tostring(bet.amount)
        local tw = fonts.small:getWidth(amountText)
        love.graphics.print(amountText, cx - tw / 2, cy + 20)
      end
    end
  end
end

-- ─── HISTORY ─────────────────────────────────────────────────

function M.drawHistory(history)
  -- History panel
  local px = 780
  local py = 15
  local panelW = 195
  local panelH = 70

  love.graphics.setColor(C.panelBg)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 8)
  love.graphics.setColor(C.panelBorder)
  love.graphics.rectangle("line", px, py, panelW, panelH, 8)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.goldDim)
  love.graphics.print("HISTORY", px + 8, py + 5)

  love.graphics.setFont(fonts.tableNum)
  local boxSize = 30
  local startX = px + 10
  local startY = py + 22

  for i, number in ipairs(history) do
    local x = startX + (i - 1) * (boxSize + 5)
    local color = wheel.getColor(number)

    if color == "red" then
      love.graphics.setColor(C.red)
    elseif color == "black" then
      love.graphics.setColor(C.black)
    else
      love.graphics.setColor(C.green)
    end

    love.graphics.rectangle("fill", x, startY, boxSize, boxSize, 5)

    -- Top bevel
    if color == "red" then
      love.graphics.setColor(C.redLight[1], C.redLight[2], C.redLight[3], 0.25)
    elseif color == "black" then
      love.graphics.setColor(C.blackLight[1], C.blackLight[2], C.blackLight[3], 0.25)
    else
      love.graphics.setColor(C.greenLight[1], C.greenLight[2], C.greenLight[3], 0.25)
    end
    love.graphics.rectangle("fill", x, startY, boxSize, 3, 5)

    love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.3)
    love.graphics.rectangle("line", x, startY, boxSize, boxSize, 5)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(tostring(number), x, startY + 7, boxSize, "center")
  end
end

-- ─── PAYOUT TABLE ────────────────────────────────────────────

function M.drawPayoutTable(tbl)
  local x = tbl.gridX + 13 * tbl.cellWidth + 25
  local y = tbl.gridY + 50
  local lineHeight = 20
  local panelW = 155
  local panelH = lineHeight * 6 + 20

  -- Panel background
  love.graphics.setColor(C.panelBg)
  love.graphics.rectangle("fill", x - 8, y - 8, panelW, panelH, 8)
  love.graphics.setColor(C.panelBorder)
  love.graphics.rectangle("line", x - 8, y - 8, panelW, panelH, 8)

  -- Title
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.gold)
  love.graphics.print("PAYOUTS", x, y)
  y = y + lineHeight

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(C.cream)
  local payouts = {
    {"Single #", "35:1"},
    {"Dozen", "2:1"},
    {"Column", "2:1"},
    {"Odd/Even", "1:1"},
    {"Red/Black", "1:1"},
  }

  for _, payout in ipairs(payouts) do
    love.graphics.setColor(C.cream[1], C.cream[2], C.cream[3], 0.85)
    love.graphics.print(payout[1], x, y)
    love.graphics.setColor(C.gold)
    love.graphics.print(payout[2], x + 105, y)
    -- Subtle separator
    love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.1)
    love.graphics.line(x, y + lineHeight - 2, x + panelW - 20, y + lineHeight - 2)
    y = y + lineHeight
  end
end

-- ─── CREDITS & CHIP SELECTOR ─────────────────────────────────

local function drawCreditsPanel(bank)
  local px = 15
  local py = 15
  local panelW = 200
  local panelH = 55

  -- Glowing border during win FX
  winFx.drawCreditCounter(px, py, panelW, panelH, "CREDITS")

  love.graphics.setColor(C.panelBg)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 8)
  love.graphics.setColor(C.panelBorder)
  love.graphics.rectangle("line", px, py, panelW, panelH, 8)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.goldDim)
  love.graphics.print("CREDITS", px + 12, py + 6)

  -- Use animated credit count if win FX is active
  local displayCredits = winFx.getDisplayedCredits() or bank.balance

  love.graphics.setFont(fonts.credits)
  love.graphics.setColor(C.cream)
  love.graphics.print(formatNumber(math.floor(displayCredits)), px + 12, py + 24)
end

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

  -- Currently selected chip (large, featured)
  local chipValue = credits.getSelectedChipValue(bank)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(C.cream)
  love.graphics.print("Active:", px + 12, py + 24)
  drawPokerChip(px + 90, py + 32, chipValue)
  love.graphics.setColor(C.cream)
  love.graphics.print(credits.getChipLabel(chipValue), px + 110, py + 26)

  -- All available chips in grid
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

-- ─── SPIN BUTTON ─────────────────────────────────────────────

local function drawSpinPrompt(state)
  if state ~= "betting" then return end

  local px = 15
  local py = 210
  local panelW = 200
  local panelH = 40

  -- Pulsing glow
  local pulse = 0.6 + 0.4 * math.sin(uiTime * 3)

  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 8)
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], pulse * 0.5)
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", px, py, panelW, panelH, 8)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(C.cream[1], C.cream[2], C.cream[3], pulse)
  love.graphics.printf("SPACE to Spin", px, py + 10, panelW, "center")
end

-- ─── WINNING NUMBER DISPLAY ──────────────────────────────────

local function drawWinningNumber(result, payout)
  if not result then return end

  local cx = WHEEL_X
  local cy = WHEEL_Y - WHEEL_RADIUS - 50

  -- Background panel
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", cx - 80, cy - 30, 160, 60, 10)
  love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", cx - 80, cy - 30, 160, 60, 10)
  love.graphics.setLineWidth(1)

  -- Winning number in its color
  local color = wheel.getColor(result)
  if color == "red" then
    love.graphics.setColor(C.redLight)
  elseif color == "black" then
    love.graphics.setColor(0.7, 0.7, 0.75)
  else
    love.graphics.setColor(C.greenLight)
  end

  love.graphics.setFont(fonts.xlarge)
  love.graphics.printf(tostring(result), cx - 80, cy - 25, 160, "center")

  -- Payout below
  if payout > 0 then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(0.3, 1, 0.4)
    love.graphics.printf("+" .. formatNumber(payout), cx - 80, cy + 35, 160, "center")
  end
end

-- ─── CLICK-TO-PLACE HINT ─────────────────────────────────────

local function drawPlaceHint(state)
  if state ~= "betting" then return end
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(C.cream[1], C.cream[2], C.cream[3], 0.4)
  love.graphics.print("Click table to place bets", 18, 260)
end

-- ─── MAIN UI DRAW ────────────────────────────────────────────

function M.drawUI(bank, state, result, history, tbl, payout)
  uiTime = uiTime + (love.timer.getDelta and love.timer.getDelta() or 0.016)

  drawCreditsPanel(bank)
  drawChipSelector(bank)
  drawSpinPrompt(state)
  drawPlaceHint(state)

  if history and #history > 0 then
    M.drawHistory(history)
  end
  M.drawPayoutTable(tbl)

  -- Show winning number during payout
  if state == "payout" and result then
    drawWinningNumber(result, payout)
  end
end

return M
