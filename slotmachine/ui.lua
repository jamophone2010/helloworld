local M = {}
local reel = require("slotmachine.reel")
local credits = require("slotmachine.credits")

local fonts = {}
local SYMBOL_WIDTH = 150
local SYMBOL_HEIGHT = 120
local SYMBOL_SPACING = 15
local SLOT_HEIGHT = SYMBOL_HEIGHT + SYMBOL_SPACING
local VISIBLE_ROWS = 3
local REEL_Y = 150
local REEL_X_POSITIONS = {200, 360, 520}

function M.load()
  fonts.normal = love.graphics.newFont(20)
  fonts.large = love.graphics.newFont(36)
  fonts.huge = love.graphics.newFont(48)
end

function M.drawReels(machine)
  local clipX = 200
  local clipY = REEL_Y
  local clipWidth = 470
  local clipHeight = VISIBLE_ROWS * SLOT_HEIGHT

  love.graphics.setScissor(clipX, clipY, clipWidth, clipHeight)

  for i, r in ipairs(machine.reels) do
    M.drawReel(r)
  end

  love.graphics.setScissor()

  love.graphics.setColor(1, 1, 1, 0.3)
  love.graphics.rectangle("line", clipX, clipY + SLOT_HEIGHT, clipWidth, SYMBOL_HEIGHT)
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

function M.drawWins(wins, totalWinnings, paylines)
  if totalWinnings > 0 then
    M.drawWinningPaylines(wins, paylines)

    love.graphics.setFont(fonts.huge)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("WIN: " .. totalWinnings, 0, 480, 800, "center")

    love.graphics.setFont(fonts.normal)
    local y = 540
    for _, win in ipairs(wins) do
      love.graphics.printf(win.payline .. ": " .. win.symbol .. " x3 = " .. win.amount, 0, y, 800, "center")
      y = y + 25
    end
  end
end

function M.drawWinningPaylines(wins, paylines)
  love.graphics.setColor(1, 0.84, 0)
  love.graphics.setLineWidth(3)

  for _, win in ipairs(wins) do
    for _, payline in ipairs(paylines) do
      if payline.name == win.payline then
        for _, pos in ipairs(payline.positions) do
          local reelNum = pos[1]
          local symbolPos = pos[2]
          local x = REEL_X_POSITIONS[reelNum]
          local y = REEL_Y + (symbolPos - 1) * SLOT_HEIGHT
          love.graphics.rectangle("line", x - 2, y - 2, SYMBOL_WIDTH + 4, SYMBOL_HEIGHT + 4)
        end
        break
      end
    end
  end

  love.graphics.setLineWidth(1)
end

return M
