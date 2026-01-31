local M = {}

local wheel = require("roulette.wheel")
local table = require("roulette.table")
local credits = require("roulette.credits")

local fonts = {}
local WHEEL_X = 400
local WHEEL_Y = 350
local WHEEL_RADIUS = 120

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

    love.graphics.setColor(1, 1, 1)
    love.graphics.arc("line", WHEEL_X, WHEEL_Y, WHEEL_RADIUS - 5, startAngle, endAngle)

    local textRadius = WHEEL_RADIUS - 20
    local tx = WHEEL_X + math.cos(angle) * textRadius
    local ty = WHEEL_Y + math.sin(angle) * textRadius
    love.graphics.setFont(fonts.small)
    love.graphics.printf(tostring(number), tx - 10, ty - 7, 20, "center")
  end

  love.graphics.setColor(0.3, 0.3, 0.3)
  love.graphics.circle("fill", WHEEL_X, WHEEL_Y, 20)
end

function M.drawBall(b)
  local ballRadius = WHEEL_RADIUS - 10
  local bx = WHEEL_X + math.cos(b.angle) * ballRadius
  local by = WHEEL_Y + math.sin(b.angle) * ballRadius

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

function M.drawBets(bets, tbl)
  for _, bet in ipairs(bets.active) do
    if bet.type == "straight" and #bet.numbers == 1 then
      local number = bet.numbers[1]
      local x, y = table.getNumberPosition(tbl, number)

      if x and y then
        love.graphics.setColor(1, 1, 0, 0.7)
        love.graphics.circle("fill", x + tbl.cellWidth / 2, y + tbl.cellHeight / 2, 12)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(fonts.small)
        love.graphics.printf(tostring(bet.amount), x, y + tbl.cellHeight / 2 - 7, tbl.cellWidth, "center")
      end
    end
  end
end

function M.drawUI(bank, state, result)
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Credits: " .. bank.balance, 20, 20)

  local chipValue = credits.getSelectedChipValue(bank)
  love.graphics.print("Chip: " .. chipValue, 20, 50)
  love.graphics.print("UP/DOWN: Change Chip", 20, 80)
  love.graphics.print("Click Table: Place Bet", 20, 110)

  if state == "betting" then
    love.graphics.print("SPACE: Spin", 20, 140)
  elseif state == "spinning" or state == "settling" then
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("SPINNING...", 0, 500, 800, "center")
  elseif state == "payout" and result then
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("Result: " .. tostring(result), 0, 500, 800, "center")
  end
end

return M
