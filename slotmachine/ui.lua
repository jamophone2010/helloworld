local M = {}
local reel = require("slotmachine.reel")
local credits = require("slotmachine.credits")

local fonts = {}
local SYMBOL_WIDTH = 100
local SYMBOL_HEIGHT = 80
local SYMBOL_SPACING = 10

function M.load()
  fonts.normal = love.graphics.newFont(20)
  fonts.large = love.graphics.newFont(36)
  fonts.huge = love.graphics.newFont(48)
end

function M.drawReels(machine)
  for i, r in ipairs(machine.reels) do
    M.drawReel(r)
  end

  love.graphics.setColor(1, 1, 1, 0.3)
  love.graphics.rectangle("line", 235, 265, 330, 90)
end

function M.drawReel(r)
  local numSymbols = #r.symbols
  local offset = reel.getOffset(r)

  for i = -1, 3 do
    local yPos = r.y + i * (SYMBOL_HEIGHT + SYMBOL_SPACING) - offset

    if yPos >= r.y - SYMBOL_HEIGHT and yPos <= r.y + 3 * SYMBOL_HEIGHT then
      local symbolIndex = (math.floor(offset / SYMBOL_HEIGHT) + i) % numSymbols + 1
      local symbol = r.symbols[symbolIndex]

      M.drawSymbol(symbol, r.x, yPos, SYMBOL_WIDTH, SYMBOL_HEIGHT)
    end
  end
end

function M.drawSymbol(symbol, x, y, width, height)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.rectangle("fill", x, y, width, height)

  love.graphics.setColor(symbol.color)
  love.graphics.rectangle("fill", x + 5, y + 5, width - 10, height - 10)

  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(fonts.normal)
  love.graphics.printf(symbol.id:upper(), x, y + height/2 - 10, width, "center")
end

function M.drawUI(bank, state)
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)

  love.graphics.print("CREDITS: " .. bank.credits, 20, 20)
  love.graphics.print("BET/LINE: " .. bank.currentBet, 20, 50)
  love.graphics.print("TOTAL BET: " .. credits.getTotalBet(bank), 20, 80)

  if state == "idle" then
    love.graphics.setFont(fonts.normal)
    love.graphics.print("SPACE: Spin", 20, 500)
    love.graphics.print("UP/DOWN: Adjust Bet", 20, 530)
  elseif state == "spinning" then
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("SPINNING...", 0, 150, 800, "center")
  end
end

function M.drawWins(wins, totalWinnings)
  if totalWinnings > 0 then
    love.graphics.setFont(fonts.huge)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("WIN: " .. totalWinnings, 0, 400, 800, "center")

    love.graphics.setFont(fonts.normal)
    local y = 460
    for _, win in ipairs(wins) do
      love.graphics.printf(win.payline .. ": " .. win.symbol .. " x3 = " .. win.amount, 0, y, 800, "center")
      y = y + 25
    end
  end
end

return M
