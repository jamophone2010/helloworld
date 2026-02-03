local M = {}

local wheel = require("roulette.wheel")
local table = require("roulette.table")
local credits = require("roulette.credits")

local fonts = {}
local WHEEL_X = 500
local WHEEL_Y = 540
local WHEEL_RADIUS = 180

function M.load()
  fonts.small = love.graphics.newFont(14)
  fonts.normal = love.graphics.newFont(18)
  fonts.large = love.graphics.newFont(32)
end

function M.drawWheel(w)
  love.graphics.setColor(0.2, 0.1, 0.05)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS + 10)

  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS)

  local numPockets = #wheel.POCKETS
  for i = 1, numPockets do
    local angle = w.angle + (i - 1) * (2 * math.pi / numPockets)
    local number = wheel.POCKETS[i]
    local color = wheel.getColor(number)

    local startAngle = angle - math.pi / numPockets
    local endAngle = angle + math.pi / numPockets

    if color == "red" then
      love.graphics.setColor(0.8, 0.1, 0.1)
    elseif color == "black" then
      love.graphics.setColor(0.1, 0.1, 0.1)
    else
      love.graphics.setColor(0.1, 0.5, 0.1)
    end

    love.graphics.arc("fill", WHEEL_X, WHEEL_Y, WHEEL_RADIUS - 5, startAngle, endAngle)

    love.graphics.setColor(0, 0, 0)
    love.graphics.arc("line", WHEEL_X, WHEEL_Y, WHEEL_RADIUS - 5, startAngle, endAngle)

    local textRadius = WHEEL_RADIUS - 20
    local tx = WHEEL_X + math.cos(angle) * textRadius
    local ty = WHEEL_Y + math.sin(angle) * textRadius
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.small)
    love.graphics.printf(tostring(number), tx - 10, ty - 7, 20, "center")
  end

  love.graphics.setColor(0.3, 0.3, 0.3)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, 20)
end

function M.drawBall(b, w)
  local ballRadius = WHEEL_RADIUS - 10
  local angle = b.angle

  -- When stopped, position ball relative to wheel rotation
  if b.phase == "stopped" and b.finalPocket then
    angle = w.angle + (b.finalPocket - 1) * (2 * math.pi / b.numPockets)
  end

  local bx = WHEEL_X + math.cos(angle) * ballRadius
  local by = WHEEL_Y + math.sin(angle) * ballRadius

  love.graphics.setColor(1, 1, 1)
  love.graphics.circle("fill", bx, by, 6)
  love.graphics.setColor(0, 0, 0)
  love.graphics.circle("line", bx, by, 6)
end

function M.drawTable(tbl)
  local gridX = tbl.gridX
  local gridY = tbl.gridY
  local cellW = tbl.cellWidth
  local cellH = tbl.cellHeight

  love.graphics.setColor(0, 0.5, 0)
  love.graphics.rectangle("fill", gridX - 10, gridY - 10, 13 * cellW + 20, 7 * cellH + 20)

  love.graphics.setFont(fonts.normal)

  love.graphics.setColor(0.1, 0.5, 0.1)
  love.graphics.rectangle("fill", gridX, gridY, cellW, cellH)
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", gridX, gridY, cellW, cellH)
  love.graphics.printf("0", gridX, gridY + cellH / 2 - 9, cellW, "center")

  love.graphics.setColor(0.1, 0.5, 0.1)
  love.graphics.rectangle("fill", gridX + cellW, gridY, cellW, cellH)
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", gridX + cellW, gridY, cellW, cellH)
  love.graphics.printf("00", gridX + cellW, gridY + cellH / 2 - 9, cellW, "center")

  for row = 1, 3 do
    for col = 1, 12 do
      local x = gridX + (col - 1) * cellW
      local y = gridY + row * cellH
      local number = table.GRID_NUMBERS[row][col]
      local color = wheel.getColor(number)

      if color == "red" then
        love.graphics.setColor(0.7, 0.1, 0.1)
      elseif color == "black" then
        love.graphics.setColor(0.1, 0.1, 0.1)
      else
        love.graphics.setColor(0.1, 0.5, 0.1)
      end

      love.graphics.rectangle("fill", x, y, cellW, cellH)
      love.graphics.setColor(1, 1, 1)
      love.graphics.rectangle("line", x, y, cellW, cellH)
      love.graphics.printf(tostring(number), x, y + cellH / 2 - 9, cellW, "center")
    end
  end

  love.graphics.setFont(fonts.small)

  local labels = {"1st 12", "2nd 12", "3rd 12"}
  for i = 1, 3 do
    local x = gridX + (i - 1) * 4 * cellW
    local y = gridY + 4 * cellH
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, 4 * cellW, cellH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, 4 * cellW, cellH)
    love.graphics.printf(labels[i], x, y + cellH / 2 - 7, 4 * cellW, "center")
  end

  for i = 1, 3 do
    local x = gridX + 12 * cellW
    local y = gridY + i * cellH
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, cellW, cellH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, cellW, cellH)
    love.graphics.printf("2:1", x, y + cellH / 2 - 7, cellW, "center")
  end

  local outsideLabels = {"1-18", "EVEN", "RED", "BLACK", "ODD", "19-36"}
  local sectionWidth = (12 * cellW) / 6
  for i = 1, 6 do
    local x = gridX + (i - 1) * sectionWidth
    local y = gridY + 5 * cellH

    if outsideLabels[i] == "RED" then
      love.graphics.setColor(0.7, 0.1, 0.1)
    elseif outsideLabels[i] == "BLACK" then
      love.graphics.setColor(0.1, 0.1, 0.1)
    else
      love.graphics.setColor(0.2, 0.2, 0.2)
    end

    love.graphics.rectangle("fill", x, y, sectionWidth, cellH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, sectionWidth, cellH)
    love.graphics.printf(outsideLabels[i], x, y + cellH / 2 - 7, sectionWidth, "center")
  end
end

local function getBetPosition(bet, tbl)
  local gridX = tbl.gridX
  local gridY = tbl.gridY
  local cellW = tbl.cellWidth
  local cellH = tbl.cellHeight
  local sectionWidth = (12 * cellW) / 6

  if bet.type == "straight" then
    local number = bet.numbers[1]
    if number == 0 then
      return gridX + cellW / 2, gridY + cellH / 2, cellW
    elseif number == "00" then
      return gridX + cellW + cellW / 2, gridY + cellH / 2, cellW
    else
      local x, y = table.getNumberPosition(tbl, number)
      if x and y then
        return x + cellW / 2, y + cellH / 2, cellW
      end
    end
  elseif bet.type == "dozen" then
    local firstNum = bet.numbers[1]
    local section = math.floor((firstNum - 1) / 12)
    local x = gridX + section * 4 * cellW + 2 * cellW
    local y = gridY + 4 * cellH + cellH / 2
    return x, y, 4 * cellW
  elseif bet.type == "column" then
    local firstNum = bet.numbers[1]
    local row = (firstNum == 3) and 1 or (firstNum == 2) and 2 or 3
    local x = gridX + 12 * cellW + cellW / 2
    local y = gridY + row * cellH + cellH / 2
    return x, y, cellW
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
  love.graphics.setFont(fonts.small)
  for _, bet in ipairs(bets.active) do
    local cx, cy, width = getBetPosition(bet, tbl)
    if cx and cy then
      love.graphics.setColor(1, 1, 0, 0.7)
      love.graphics.circle("fill", cx, cy, 12)
      love.graphics.setColor(0, 0, 0)
      love.graphics.printf(tostring(bet.amount), cx - width / 2, cy - 7, width, "center")
    end
  end
end

function M.drawHistory(history)
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Last 5:", 785, 20)

  local boxSize = 28
  local startX = 785
  local startY = 45

  for i, number in ipairs(history) do
    local x = startX + (i - 1) * (boxSize + 4)
    local color = wheel.getColor(number)

    if color == "red" then
      love.graphics.setColor(0.8, 0.1, 0.1)
    elseif color == "black" then
      love.graphics.setColor(0.1, 0.1, 0.1)
    else
      love.graphics.setColor(0.1, 0.5, 0.1)
    end

    love.graphics.rectangle("fill", x, startY, boxSize, boxSize, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, startY, boxSize, boxSize, 4)
    love.graphics.printf(tostring(number), x, startY + 6, boxSize, "center")
  end
end

function M.drawPayoutTable(tbl)
  love.graphics.setFont(fonts.small)

  local x = tbl.gridX + 13 * tbl.cellWidth + 20
  local y = tbl.gridY + 50
  local lineHeight = 18

  love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
  love.graphics.rectangle("fill", x - 5, y - 5, 145, lineHeight * 6 + 10, 4)

  love.graphics.setColor(1, 1, 0)
  love.graphics.print("PAYOUTS", x, y)
  y = y + lineHeight

  love.graphics.setColor(1, 1, 1)
  local payouts = {
    {"Single#", "35:1"},
    {"Dozen Bet", "2:1"},
    {"Odd/Even", "1:1"},
    {"Red/Black", "1:1"},
    {"1-18/19-36", "1:1"}
  }

  for _, payout in ipairs(payouts) do
    love.graphics.print(payout[1], x, y)
    love.graphics.print(payout[2], x + 100, y)
    y = y + lineHeight
  end
end

function M.drawUI(bank, state, result, history, tbl, payout)
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Credits: " .. bank.balance, 20, 20)

  local chipValue = credits.getSelectedChipValue(bank)
  love.graphics.print("Chip: " .. chipValue, 20, 50)
  love.graphics.print("UP/DOWN: Change Chip", 20, 80)
  love.graphics.print("Click Table: Place Bet", 20, 110)

  if history and #history > 0 then
    M.drawHistory(history)
  end
  M.drawPayoutTable(tbl)

  if state == "betting" then
    love.graphics.print("SPACE: Spin", 20, 140)
  elseif state == "payout" and result and payout and payout > 0 then
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Result: " .. tostring(result), 20, 500)
  end
end

return M
