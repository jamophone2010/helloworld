local M = {}

local machine = require("slotmachine.machine")
local credits = require("slotmachine.credits")
local audio = require("slotmachine.audio")
local ui = require("slotmachine.ui")

local gameState = {}

function M.load()
  gameState.machine = machine.new()
  gameState.bank = credits.new(100)
  gameState.wins = {}
  gameState.totalWinnings = 0

  audio.load()
  ui.load()
end

function M.update(dt)
  machine.update(gameState.machine, dt)

  if gameState.machine.state == "checking" then
    local wins, totalWinnings = machine.checkWins(gameState.machine, gameState.bank.currentBet)

    gameState.wins = wins
    gameState.totalWinnings = totalWinnings

    if totalWinnings > 0 then
      credits.addWinnings(gameState.bank, totalWinnings)
      audio.playWin()
      gameState.machine.state = "payout"
    else
      gameState.machine.state = "idle"
    end
  end
end

function M.draw()
  love.graphics.setBackgroundColor(0.1, 0.2, 0.1)

  ui.drawReels(gameState.machine)
  ui.drawUI(gameState.bank, gameState.machine.state)

  if gameState.machine.state == "payout" then
    ui.drawWins(gameState.wins, gameState.totalWinnings)
  end
end

function M.keypressed(key)
  if key == "space" and gameState.machine.state == "idle" then
    if credits.canPlaceBet(gameState.bank) then
      credits.placeBet(gameState.bank)
      machine.spin(gameState.machine)
      gameState.wins = {}
      gameState.totalWinnings = 0
      audio.playSpin()
    end
  elseif key == "up" then
    credits.increaseBet(gameState.bank)
  elseif key == "down" then
    credits.decreaseBet(gameState.bank)
  end
end

return M
